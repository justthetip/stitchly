import SwiftUI
import UniformTypeIdentifiers
import UIKit

enum PatternCraftFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case knit = "Knit"
    case crochet = "Crochet"
    var id: Self { self }
    func includes(_ pattern: Pattern) -> Bool { self == .all || pattern.craft.caseInsensitiveCompare(rawValue) == .orderedSame }
}

enum PatternLibraryFiltering {
    static func apply(_ patterns: [Pattern], searchText: String, craft: PatternCraftFilter) -> [Pattern] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return patterns.filter { pattern in
            craft.includes(pattern) && (query.isEmpty || pattern.name.localizedCaseInsensitiveContains(query) || (pattern.designer?.localizedCaseInsensitiveContains(query) ?? false))
        }
    }
}

@MainActor final class LibraryStore: ObservableObject {
    @Published var patterns: [Pattern] = []
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var loadingMessage = "Loading your pattern library…"
    @Published var error: String?
    private var loadedIdentity: String?
    func load(client: APIClient, userID: String?, forceRefresh: Bool = false, message: String = "Loading your pattern library…") async {
        loadingMessage = message
        error = nil
        let identity = userID == nil || client.token == "demo" ? "guest" : userID!
        let acquiredPatterns = PatternMarketplaceOwnership.acquiredPatterns(for: identity)
        if loadedIdentity != identity {
            patterns = []
            loadedIdentity = identity
        }
        if userID == nil || client.token == "demo" {
            isLoading = true; defer { isLoading = false }
            if ProcessInfo.processInfo.arguments.contains("-simulateSlowLoading") { try? await Task.sleep(for: .seconds(6)) }
            let basePatterns = ProcessInfo.processInfo.arguments.contains("-emptyLibraryDemo") ? [] : DemoData.patterns
            patterns = PatternCollectionMerging.merge(primary: basePatterns, acquired: acquiredPatterns)
            return
        }
        guard let userID else { return }
        let cached = await AppDataCache.shared.cachedPatterns(for: userID)
        if patterns.isEmpty, let cached { patterns = PatternCollectionMerging.merge(primary: cached.value, acquired: acquiredPatterns) }
        if !forceRefresh, let cached, cached.isFresh() { return }
        let isColdLoad = cached == nil && patterns.isEmpty
        isLoading = isColdLoad
        isRefreshing = !isColdLoad
        defer { isLoading = false; isRefreshing = false }
        do {
            let refreshed = try await AppDataCache.shared.refreshPatterns(for: userID, client: client)
            patterns = PatternCollectionMerging.merge(primary: refreshed, acquired: acquiredPatterns)
        }
        catch { if patterns.isEmpty { self.error = error.localizedDescription } }
    }
}

struct LibraryView: View {
    @EnvironmentObject private var auth: AuthManager
    @StateObject private var store = LibraryStore()
    @State private var selectedSection = PatternHubSection.marketplace
    @State private var importing = false
    @State private var showImportIntroduction = false
    @State private var addingExample = false
    @State private var searchText = ""
    @State private var craftFilter = PatternCraftFilter.all
    @State private var reviewResponse: PatternResponse?
    @State private var reviewWasExample = false
    @State private var patternToDelete: Pattern?
    @State private var deletingPattern = false
    @State private var deletionError: String?
    @State private var readyPattern: Pattern?
    @State private var createdProject: Project?
    @State private var addingListingID: String?
    @FocusState private var searchIsFocused: Bool
    private var visiblePatterns: [Pattern] { PatternLibraryFiltering.apply(store.patterns, searchText: searchText, craft: craftFilter) }
    private var visibleMarketplaceListings: [MarketplacePatternListing] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return PatternMarketplaceCatalog.listings.filter { listing in
            craftFilter.includes(listing.pattern) && (
                query.isEmpty || listing.pattern.name.localizedCaseInsensitiveContains(query) ||
                (listing.pattern.designer?.localizedCaseInsensitiveContains(query) ?? false) ||
                listing.summary.localizedCaseInsensitiveContains(query)
            )
        }
    }
    private var ownedPatternIDs: Set<String> { Set(store.patterns.map(\.id)) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.ink)
                        .accessibilityHidden(true)
                    TextField("Pattern or designer", text: $searchText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .focused($searchIsFocused)
                        .lineLimit(1...2)
                        .foregroundStyle(Color.ink)
                        .tint(.brandInteractive)
                        .padding(.vertical, 14)
                        .submitLabel(.search)
                        .onSubmit { searchIsFocused = false }
                        .accessibilityLabel("Search by pattern or designer")
                        .accessibilityIdentifier("pattern-search-field")
                }
                .font(.body)
                .padding(.horizontal, 14)
                .background(Color.elevatedSurface, in: .capsule)
                .padding(.horizontal)
                .padding(.bottom, 12)

                Picker("Pattern collection", selection: $selectedSection) {
                    ForEach(PatternHubSection.allCases) { section in Text(section.rawValue).tag(section) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 10)
                .accessibilityIdentifier("patterns-section-picker")
                .accessibilityHint("Switches between the marketplace and patterns you own")

                Picker("Craft", selection: $craftFilter) {
                    ForEach(PatternCraftFilter.allCases) { filter in Text(filter.rawValue).tag(filter) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .accessibilityHint("Filters patterns by craft")

                if selectedSection == .marketplace {
                    marketplaceContent
                } else {
                    ownedPatternsContent
                }
            }
            .navigationTitle("Patterns")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { searchIsFocused = false }
                        .accessibilityIdentifier("dismiss-pattern-search-keyboard")
                }
                if selectedSection == .owned {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Import", systemImage: "plus", action: beginImport)
                            .disabled(store.isLoading || importing)
                    }
                }
            }
            .navigationDestination(for: Pattern.self) { PatternDetailView(pattern: $0) }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf]) { result in if case .success(let url) = result { Task { await importPDF(url) } } }
            .sheet(isPresented: $showImportIntroduction) {
                ImportIntroductionView {
                    showImportIntroduction = false
                    Task { try? await Task.sleep(for: .milliseconds(250)); importing = true }
                }
            }
            .sheet(isPresented: .init(get: { reviewResponse != nil }, set: { if !$0 { reviewResponse = nil } })) {
                if let response = reviewResponse { PatternImportReviewView(response: response) { saved in saved ? finishReview(response) : discardReview() } }
            }
            .sheet(item: $readyPattern) { pattern in PatternReadyView(pattern: pattern) { project in readyPattern = nil; createdProject = project } }
            .sheet(item: $createdProject) { ProjectCreatedView(project: $0) }
            .task(id: auth.contentIdentity) {
                if ProcessInfo.processInfo.arguments.contains("-resetMarketplaceForUITests") {
                    PatternMarketplaceOwnership.reset(for: auth.contentIdentity)
                }
                await store.load(client: auth.client, userID: auth.user?.id)
                if ProcessInfo.processInfo.arguments.contains("-importReviewDemo") { reviewResponse = PatternResponse(pattern: DemoData.pattern, instructions: DemoData.instructions) }
            }
            .refreshable { await store.load(client: auth.client, userID: auth.user?.id, forceRefresh: true) }
            .alert("Couldn’t load library", isPresented: .init(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("Try again") { Task { await store.load(client: auth.client, userID: auth.user?.id, forceRefresh: true) } } } message: { Text(store.error ?? "") }
            .alert("Pattern wasn’t deleted", isPresented: .init(get: { deletionError != nil }, set: { if !$0 { deletionError = nil } })) { Button("OK") {} } message: { Text(deletionError ?? "") }
            .confirmationDialog("Delete this pattern?", isPresented: .init(get: { patternToDelete != nil }, set: { if !$0 { patternToDelete = nil } }), titleVisibility: .visible, presenting: patternToDelete) { pattern in
                Button("Delete \(pattern.name)", role: .destructive) { Task { await deletePattern(pattern) } }
                Button("Cancel", role: .cancel) { patternToDelete = nil }
            } message: { pattern in
                if PatternMarketplaceOwnership.acquiredIDs(for: auth.contentIdentity).contains(pattern.id) {
                    Text("This removes the marketplace preview from My Patterns. You can add it again later.")
                } else {
                    Text("This permanently deletes \(pattern.name), its PDF, linked projects, progress, and notes.")
                }
            }
            .overlay(alignment: .top) { if store.isLoading && !store.patterns.isEmpty { LoadingBanner(message: store.loadingMessage).padding(.top, 8) } }
        }
    }

    private var marketplaceContent: some View {
        Group {
            if visibleMarketplaceListings.isEmpty {
                ContentUnavailableView {
                    Label("No matching marketplace patterns", systemImage: "magnifyingglass")
                } description: {
                    Text("Try another search or reset the active craft filter.")
                } actions: {
                    Button("Clear search and filters", action: resetFilters)
                        .buttonStyle(.borderedProminent)
                        .tint(.brandAction)
                        .accessibilityIdentifier("clear-marketplace-filters")
                }
            } else {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Find your next make", systemImage: "sparkles")
                                .font(.title2.bold())
                                .foregroundStyle(Color.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Browse free and paid pattern previews, then keep the ones you like alongside your imported PDFs.")
                                .foregroundStyle(Color.ink)
                            Label("Preview marketplace — no payment is taken", systemImage: "info.circle.fill")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.ink)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("marketplace-no-charge-note")
                        }
                        .padding(.vertical, 6)
                    }
                    let featured = visibleMarketplaceListings.filter(\.featured)
                    if !featured.isEmpty {
                        Section {
                            ForEach(featured) { listing in marketplaceRow(listing) }
                        } header: {
                            Text("Featured")
                                .font(.headline)
                                .foregroundStyle(Color.ink)
                        }
                        .headerProminence(.increased)
                    }
                    let more = visibleMarketplaceListings.filter { !$0.featured }
                    if !more.isEmpty {
                        Section {
                            ForEach(more) { listing in marketplaceRow(listing) }
                        } header: {
                            Text("More patterns")
                                .font(.headline)
                                .foregroundStyle(Color.ink)
                        }
                        .headerProminence(.increased)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollDismissesKeyboard(.interactively)
                .accessibilityValue("\(visibleMarketplaceListings.count) marketplace patterns shown")
            }
        }
    }

    @ViewBuilder private func marketplaceRow(_ listing: MarketplacePatternListing) -> some View {
        MarketplacePatternRow(
            listing: listing,
            isOwned: ownedPatternIDs.contains(listing.id),
            isAdding: addingListingID == listing.id
        ) {
            Task { await acquire(listing) }
        }
    }

    private var ownedPatternsContent: some View {
        Group {
            if store.isLoading && store.patterns.isEmpty {
                LoadingStateView(title: "Loading your patterns", message: store.loadingMessage)
            } else if store.patterns.isEmpty {
                ActionableEmptyState(
                    icon: "doc.badge.plus", title: "No patterns yet",
                    message: "Add one from the marketplace or import a PDF and Stitchly will turn its actual instructions into clear steps for review.",
                    actionTitle: "Import a PDF", actionIcon: "doc.badge.plus",
                    isDisabled: store.isLoading || importing, action: beginImport
                )
            } else if visiblePatterns.isEmpty {
                ContentUnavailableView {
                    Label("No matching patterns", systemImage: "magnifyingglass")
                } description: {
                    Text("Try another search or reset the active craft filter.")
                } actions: {
                    Button("Clear search and filters", action: resetFilters)
                        .buttonStyle(.borderedProminent)
                        .tint(.brandAction)
                        .accessibilityIdentifier("clear-library-filters")
                }
            } else {
                List(visiblePatterns) { pattern in
                    NavigationLink(value: pattern) { PatternRow(pattern: pattern) }
                        .swipeActions {
                            Button(role: .destructive) { patternToDelete = pattern } label: {
                                Label("Delete \(pattern.name)", systemImage: "trash")
                            }
                            .disabled(deletingPattern)
                        }
                }
                .listStyle(.insetGrouped)
                .accessibilityValue("\(visiblePatterns.count) owned patterns shown")
            }
        }
    }

    private func resetFilters() { searchText = ""; craftFilter = .all }

    private func acquire(_ listing: MarketplacePatternListing) async {
        guard addingListingID == nil, !ownedPatternIDs.contains(listing.id) else { return }
        addingListingID = listing.id
        defer { addingListingID = nil }
        try? await Task.sleep(for: .milliseconds(450))
        guard !Task.isCancelled else { return }
        if PatternMarketplaceOwnership.acquire(listing.id, for: auth.contentIdentity) {
            withAnimation {
                store.patterns = PatternCollectionMerging.merge(primary: store.patterns, acquired: [listing.pattern])
            }
        }
    }
    private func beginImport() {
        guard !store.isLoading, !importing, !showImportIntroduction else { return }
        guard !auth.isGuest else {
            auth.requireAuthentication(title: "Create an account to import a pattern", message: "Your PDF and its extracted instructions stay private and need an account owner.")
            return
        }
        showImportIntroduction = true
    }
    private func finishReview(_ response: PatternResponse) {
        reviewResponse = nil
        if auth.token == "demo" && reviewWasExample {
            store.patterns = [response.pattern]
            reviewWasExample = false
        } else {
            Task { await store.load(client: auth.client, userID: auth.user?.id, forceRefresh: true, message: "Refreshing your library after reviewing the pattern…") }
        }
        Task { try? await Task.sleep(for: .milliseconds(350)); readyPattern = response.pattern }
    }
    private func discardReview() {
        reviewResponse = nil
        reviewWasExample = false
        Task { await store.load(client: auth.client, userID: auth.user?.id, forceRefresh: true, message: "Refreshing your library after discarding the import…") }
    }
    private func deletePattern(_ pattern: Pattern) async {
        guard !deletingPattern else { return }
        if PatternMarketplaceOwnership.acquiredIDs(for: auth.contentIdentity).contains(pattern.id) {
            deletingPattern = true; patternToDelete = nil
            store.loadingMessage = "Removing \(pattern.name) from My Patterns…"
            store.isLoading = true
            defer { deletingPattern = false; store.isLoading = false }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            PatternMarketplaceOwnership.remove(pattern.id, for: auth.contentIdentity)
            store.patterns.removeAll { $0.id == pattern.id }
            return
        }
        guard !auth.isGuest else {
            patternToDelete = nil
            auth.requireAuthentication(title: "Sign in to manage patterns", message: "The starter catalog is read-only. Create an account to add and manage your own private patterns.")
            return
        }
        deletingPattern = true; patternToDelete = nil
        store.loadingMessage = "Deleting \(pattern.name), its PDF, and linked projects…"
        store.isLoading = true
        defer { deletingPattern = false; store.isLoading = false }
        if auth.token == "demo" { store.patterns.removeAll { $0.id == pattern.id }; return }
        do {
            let _: EmptyResponse = try await auth.client.request("/api/patterns/\(pattern.id)", method: "DELETE")
            store.patterns.removeAll { $0.id == pattern.id }
            if let userID = auth.user?.id { await AppDataCache.shared.store(patterns: store.patterns, for: userID) }
        } catch { deletionError = error.localizedDescription }
    }
    private func addExample() async {
        guard !store.isLoading, !addingExample else { return }
        if auth.token == "demo" { reviewWasExample = true; reviewResponse = PatternResponse(pattern: DemoData.pattern, instructions: DemoData.instructions); return }
        addingExample = true
        store.loadingMessage = "Copying the Stitchly starter pattern into your private library…"
        store.isLoading = true
        defer { addingExample = false; store.isLoading = false }
        do {
            let response: PatternResponse = try await auth.client.request("/api/patterns/example", method: "POST")
            store.loadingMessage = response.alreadyAdded == true ? "Opening the starter pattern you already added…" : "Preparing the starter instructions for review…"
            reviewWasExample = true
            reviewResponse = response
        } catch { store.error = error.localizedDescription }
    }
    private func importPDF(_ url: URL) async {
        guard let user = auth.user, auth.token != "demo" else { store.patterns = DemoData.patterns; return }
        store.loadingMessage = "Uploading \(url.lastPathComponent)…"
        store.isLoading = true; defer { store.isLoading = false }
        Telemetry.shared.track("pdf_import_started")
        do {
            let blob = try await auth.client.uploadPDF(url, userID: user.id)
            store.loadingMessage = "Reading the PDF and finding pattern sections…"
            struct ParseBody: Encodable { let url: String; let name: String }
            let response: PatternResponse = try await auth.client.request("/api/patterns/parse", method: "POST", body: ParseBody(url: blob.url.absoluteString, name: url.deletingPathExtension().lastPathComponent))
            store.loadingMessage = "Preparing your extracted instructions for review…"
            reviewResponse = response
            Telemetry.shared.track("pdf_import_completed")
        } catch { store.error = error.localizedDescription }
    }
}

private struct ReviewInstruction: Identifiable {
    let id: String
    let position: Int
    var section: String
    let instructionKind: String
    var sourceLabel: String
    var instructions: String
    let confidence: String
    init(_ instruction: Instruction) {
        id = instruction.id; position = instruction.position; section = instruction.section; instructionKind = instruction.instructionKind; sourceLabel = instruction.sourceLabel ?? "Step \(instruction.position)"; instructions = instruction.instructions; confidence = instruction.confidence ?? "medium"
    }
}

struct PatternImportReviewView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    let response: PatternResponse
    let onFinished: (Bool) -> Void
    @State private var drafts: [ReviewInstruction]
    @State private var isSaving = false
    @State private var isDiscarding = false
    @State private var confirmDiscard = false
    @State private var showGuidance = true
    @State private var showOriginal = false
    @State private var error: String?

    init(response: PatternResponse, onFinished: @escaping (Bool) -> Void) {
        self.response = response; self.onFinished = onFinished; _drafts = State(initialValue: response.instructions.sorted { $0.position < $1.position }.map(ReviewInstruction.init))
    }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        AuthenticatedCoverImage(path: response.pattern.coverUrl, fallbackAsset: "PatternFallback")
                            .frame(width: 84, height: 84)
                            .accessibilityIdentifier("review-pattern-cover")
                        VStack(alignment: .leading, spacing: 5) {
                            Text(response.pattern.name).font(.headline)
                            Text("Keep the finished pattern in view while you check the extracted steps.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                if showGuidance {
                    Section("What to check") {
                        Label("Compare sections, source labels, and every instruction before saving.", systemImage: "checklist")
                        Text("Confidence is a prompt to verify—not a guarantee. Preserve the PDF’s own row, round, setup, finishing, and size terminology.")
                            .foregroundStyle(.secondary)
                        Button { showOriginal = true } label: { Label("View original PDF", systemImage: "doc.richtext") }
                            .accessibilityIdentifier("review-original-pdf")
                        Button("Hide these tips") { showGuidance = false }
                            .foregroundStyle(Color.ink)
                    }
                }
                ForEach($drafts) { $draft in
                    Section {
                        if draft.confidence != "high" {
                            Label(draft.confidence == "low" ? "Low confidence — needs a careful check" : "Medium confidence — worth checking", systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(Color.ink)
                                .accessibilityIdentifier("review-confidence-\(draft.position)")
                        }
                        TextField("Section", text: $draft.section)
                        TextField("Source label", text: $draft.sourceLabel)
                        TextField("Instruction", text: $draft.instructions, axis: .vertical).lineLimit(3...10)
                            .accessibilityIdentifier("review-instruction-\(draft.position)")
                    } header: { Text("Step \(draft.position) · \(draft.instructionKind.capitalized)") }
                }
                if isSaving { Section { LoadingBanner(message: "Saving your corrected instructions and refreshing the library…") } }
                if isDiscarding { Section { LoadingBanner(message: "Discarding this imported pattern and its extracted content…") } }
            }
            .disabled(isSaving || isDiscarding)
            .navigationTitle("Review import").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Discard") { confirmDiscard = true }.disabled(isSaving || isDiscarding) }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await save() } }.disabled(isSaving || isDiscarding || drafts.contains(where: { $0.section.trimmingCharacters(in: .whitespaces).isEmpty || $0.instructions.trimmingCharacters(in: .whitespaces).isEmpty })).accessibilityIdentifier("save-import-review") }
            }
            .confirmationDialog("Discard this imported pattern?", isPresented: $confirmDiscard, titleVisibility: .visible) { Button("Discard import", role: .destructive) { Task { await discard() } }; Button("Keep reviewing", role: .cancel) {} } message: { Text("The uploaded pattern and extracted instructions will be removed.") }
            .alert("Couldn’t update the imported pattern", isPresented: .init(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("Try saving again") { Task { await save() } }; Button("Cancel", role: .cancel) {} } message: { Text(error ?? "") }
            .sheet(isPresented: $showOriginal) { OriginalPDFView(patternID: response.pattern.id, title: response.pattern.name) }
        }
        .interactiveDismissDisabled()
    }
    private func save() async {
        guard !isSaving, !isDiscarding else { return }; isSaving = true; defer { isSaving = false }
        if auth.token == "demo" { onFinished(true); dismiss(); return }
        struct DraftBody: Encodable { let position: Int; let section: String; let sectionPosition: Int; let instructionKind: String; let sourceLabel: String; let instructions: String; let confidence: String }
        struct Body: Encodable { let instructions: [DraftBody] }
        let body = Body(instructions: drafts.enumerated().map { index, draft in DraftBody(position: draft.position, section: draft.section, sectionPosition: index + 1, instructionKind: draft.instructionKind, sourceLabel: draft.sourceLabel, instructions: draft.instructions, confidence: draft.confidence) })
        do {
            let _: EmptyResponse = try await auth.client.request("/api/patterns/\(response.pattern.id)", method: "PATCH", body: body)
            if let userID = auth.user?.id { await AppDataCache.shared.invalidatePattern(for: userID, patternID: response.pattern.id) }
            onFinished(true); dismiss()
        } catch { self.error = error.localizedDescription }
    }
    private func discard() async {
        guard !isSaving, !isDiscarding else { return }; isDiscarding = true; defer { isDiscarding = false }
        if auth.token == "demo" { onFinished(false); dismiss(); return }
        do {
            let _: EmptyResponse = try await auth.client.request("/api/patterns/\(response.pattern.id)", method: "DELETE")
            if let userID = auth.user?.id { await AppDataCache.shared.invalidatePattern(for: userID, patternID: response.pattern.id) }
            onFinished(false); dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

struct PatternRow: View {
    @EnvironmentObject private var auth: AuthManager
    let pattern: Pattern
    var body: some View {
        HStack(spacing: 14) {
            ListCoverThumbnail(path: pattern.coverUrl, fallbackAsset: "PatternFallback", size: 58)
            VStack(alignment: .leading, spacing: 4) { Text(pattern.name).font(.headline); Text([pattern.designer, "\(pattern.totalInstructions) steps"].compactMap { $0 }.joined(separator: " · ")).font(.subheadline).foregroundStyle(Color.ink) }
        }.padding(.vertical, 4)
    }
}

private struct MarketplacePatternRow: View {
    let listing: MarketplacePatternListing
    let isOwned: Bool
    let isAdding: Bool
    let acquire: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    LinearGradient(
                        colors: listing.featured ? [.brandPink.opacity(0.75), .brandOrange.opacity(0.82)] : [.brandBlue.opacity(0.75), .cream],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: listing.symbol)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Color.ink)
                }
                .frame(width: 76, height: 76)
                .clipShape(.rect(cornerRadius: 18))
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(listing.pattern.name)
                            .font(.headline)
                            .foregroundStyle(Color.ink)
                        Spacer(minLength: 8)
                        Text(listing.price.displayName)
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.ink)
                    }
                    if let designer = listing.pattern.designer {
                        Text("by \(designer)")
                            .font(.subheadline)
                            .foregroundStyle(Color.ink)
                    }
                    Text(listing.summary)
                        .font(.subheadline)
                        .foregroundStyle(Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text([listing.pattern.craft, listing.pattern.difficulty].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.ink)
                }
            }

            if isOwned {
                Label("In My Patterns", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ink)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.brandBlue.opacity(0.22), in: .rect(cornerRadius: 12))
                    .accessibilityIdentifier("marketplace-owned-\(listing.id)")
            } else {
                Button(action: acquire) {
                    if isAdding {
                        LoadingButtonLabel("Adding \(listing.pattern.name)…")
                    } else {
                        Label(listing.price.acquisitionTitle, systemImage: listing.price == .free ? "arrow.down.circle" : "plus.circle")
                            .frame(maxWidth: .infinity, minHeight: 24)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.brandAction)
                .controlSize(.large)
                .disabled(isAdding)
                .accessibilityIdentifier("marketplace-add-\(listing.id)")
                .accessibilityHint("Adds this preview pattern to My Patterns. No payment is taken.")
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .contain)
    }
}

struct ListCoverThumbnail: View {
    let path: String?
    let fallbackAsset: String
    let size: CGFloat

    var body: some View {
        AuthenticatedCoverImage(path: path, fallbackAsset: fallbackAsset, showsLoadingIndicator: true)
            .frame(width: size - 8, height: size - 8)
            .clipped()
            .clipShape(.rect(cornerRadius: 10))
            .padding(4)
            .frame(width: size, height: size)
            .background(Color.cream, in: .rect(cornerRadius: 14))
    }
}

struct AuthenticatedCoverImage: View {
    @EnvironmentObject private var auth: AuthManager
    let path: String?
    let fallbackAsset: String
    var showsLoadingIndicator = false
    @State private var image: UIImage?
    @State private var isLoading = false
    var body: some View {
        ZStack {
            if let image { Image(uiImage: image).resizable().scaledToFill() }
            else { Image(fallbackAsset).resizable().scaledToFill() }
            if isLoading && showsLoadingIndicator {
                ProgressView()
                    .controlSize(.small)
                    .tint(.brandOrange)
                    .padding(6)
                    .background(Color.elevatedSurface.opacity(0.94), in: .circle)
            }
        }
        .clipShape(.rect(cornerRadius: 14))
        .task(id: path) {
            image = nil
            if let path, path.hasPrefix("/demo/"),
               let resource = path.split(separator: "/").last.map(String.init),
               let url = Bundle.main.url(forResource: (resource as NSString).deletingPathExtension, withExtension: (resource as NSString).pathExtension),
               let loaded = UIImage(contentsOfFile: url.path) {
                image = loaded
                isLoading = false
                return
            }
            guard let path, let userID = auth.user?.id else { isLoading = false; return }
            isLoading = true
            defer { isLoading = false }
            let client = auth.client
            if let data = try? await AppDataCache.shared.imageData(for: userID, path: path, client: client), let loaded = UIImage(data: data) { image = loaded }
        }
        .accessibilityHidden(true)
    }
}

struct PatternDetailView: View {
    @EnvironmentObject private var auth: AuthManager
    let pattern: Pattern
    @State private var instructions: [Instruction] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var createProject = false
    @State private var showOriginal = false
    @State private var createdProject: Project?
    @State private var selectedGlossaryTerm: PatternGlossaryTerm?
    private var marketplaceListing: MarketplacePatternListing? { PatternMarketplaceCatalog.listing(for: pattern.id) }
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    AuthenticatedCoverImage(path: pattern.coverUrl, fallbackAsset: "PatternFallback")
                        .frame(maxWidth: .infinity)
                        .frame(height: 210)
                        .accessibilityIdentifier("pattern-overview-cover")
                    CraftBadge(craft: pattern.craft)
                    Text(pattern.name).font(.largeTitle.bold())
                    if let designer = pattern.designer {
                        Text("by \(designer)")
                            .font(.subheadline)
                            .foregroundStyle(Color.ink)
                    }
                    HStack { if let yarn = pattern.yarn { Label(yarn, systemImage: "circle.fill") }; if let tool = pattern.tool { Label(tool, systemImage: "wrench.and.screwdriver") } }
                        .font(.subheadline)
                        .foregroundStyle(Color.ink)
                    if marketplaceListing == nil {
                        Button { beginProject() } label: { Label("Start a project", systemImage: "plus").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).tint(.brandAction).controlSize(.large).accessibilityIdentifier("start-pattern-project")
                        Button { showOriginal = true } label: { Label("View original PDF", systemImage: "doc.richtext").frame(maxWidth: .infinity) }.buttonStyle(.bordered).tint(.brandAction).controlSize(.large).accessibilityIdentifier("pattern-original-pdf")
                    } else {
                        Label("Marketplace preview", systemImage: "storefront.fill")
                            .font(.headline)
                            .foregroundStyle(Color.ink)
                        Text("This mocked listing includes a short preview. Checkout, the complete source pattern, and project creation will be connected in a later marketplace release.")
                            .font(.subheadline)
                            .foregroundStyle(Color.ink)
                            .accessibilityIdentifier("marketplace-pattern-preview-note")
                    }
                }.padding(.vertical)
            }
            if isLoading { Section { LoadingBanner(message: "Loading sections and laying out each instruction…").frame(maxWidth: .infinity) } }
            let glossaryTerms = PatternGlossary.terms(in: instructions)
            if !glossaryTerms.isEmpty {
                Section("Glossary") {
                    ForEach(glossaryTerms) { term in
                        Button { selectedGlossaryTerm = term } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(term.shorthand).font(.headline).foregroundStyle(Color.ink)
                                    Text(term.name).font(.subheadline).foregroundStyle(Color.ink)
                                }
                                Spacer()
                                Image(systemName: "questionmark.circle").foregroundStyle(Color.brandPink)
                            }
                        }
                        .accessibilityHint("Opens the pattern glossary")
                    }
                }
                .accessibilityIdentifier("pattern-glossary")
            }
            ForEach(instructions.patternSections) { patternSection in
                Section {
                    ForEach(patternSection.instructions) { instruction in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack { Text(instruction.sourceLabel ?? "Step \(instruction.position)").font(.headline); Spacer(); Text("Step \(instruction.position)").font(.caption).foregroundStyle(Color.ink) }
                            Text(instruction.instructions).foregroundStyle(Color.ink)
                            if let notes = instruction.notes { Label(notes, systemImage: "lightbulb").font(.callout).foregroundStyle(Color.ink) }
                        }.padding(.vertical, 4)
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(patternSection.title).foregroundStyle(Color.ink)
                        Text("Steps \(patternSection.firstPosition)–\(patternSection.lastPosition) · \(patternSection.instructions.count) instructions")
                            .font(.caption)
                            .foregroundStyle(Color.ink)
                            .textCase(nil)
                    }.accessibilityElement(children: .combine)
                }
                .headerProminence(.increased)
            }
        }
        .navigationTitle("Pattern overview")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $createProject) { CreateProjectView(initialPattern: pattern) { createdProject = $0 } }
        .sheet(isPresented: $showOriginal) { OriginalPDFView(patternID: pattern.id, title: pattern.name) }
        .sheet(item: $createdProject) { ProjectCreatedView(project: $0) }
        .sheet(item: $selectedGlossaryTerm) { GlossaryTermSheet(term: $0) }
        .task { await load() }
        .alert("Couldn’t open pattern", isPresented: .init(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("Try again") { Task { await load() } } } message: { Text(error ?? "") }
    }
    private func load() async {
        if let previewInstructions = PatternMarketplaceCatalog.instructions(for: pattern.id) {
            isLoading = true
            defer { isLoading = false }
            if ProcessInfo.processInfo.arguments.contains("-simulateSlowLoading") { try? await Task.sleep(for: .seconds(4)) }
            instructions = previewInstructions
            return
        }
        if auth.isGuest || auth.token == "demo" {
            isLoading = true; defer { isLoading = false }
            if ProcessInfo.processInfo.arguments.contains("-simulateSlowLoading") { try? await Task.sleep(for: .seconds(4)) }
            instructions = DemoData.instructions(for: pattern.id)
            return
        }
        guard let userID = auth.user?.id else { return }
        let cached = await AppDataCache.shared.cachedPatternDetail(for: userID, patternID: pattern.id)
        if instructions.isEmpty, let cached { instructions = cached.value.instructions }
        if let cached, cached.isFresh() { isLoading = false; return }
        isLoading = instructions.isEmpty
        defer { isLoading = false }
        do { instructions = try await AppDataCache.shared.refreshPatternDetail(for: userID, patternID: pattern.id, client: auth.client).instructions }
        catch { if instructions.isEmpty { self.error = error.localizedDescription } }
    }
    private func beginProject() {
        guard !auth.isGuest else {
            auth.requireAuthentication(title: "Create an account to start a project", message: "Projects save your yarn, notes, and place in the pattern across devices.")
            return
        }
        createProject = true
    }
}

private struct ImportIntroductionView: View {
    @Environment(\.dismiss) private var dismiss
    let choosePDF: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    Image("PatternFallback").resizable().scaledToFill().frame(height: 220).clipShape(.rect(cornerRadius: 24)).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 14) {
                        Text("PDF to pocket-sized steps").font(.largeTitle.bold()).foregroundStyle(Color.ink)
                        Label("Private to your account", systemImage: "lock.fill").font(.headline).foregroundStyle(Color.brandPink)
                        Text("Choose a knitting or crochet PDF up to 25 MB. Stitchly finds source-order sections, rows, rounds, setup, and finishing, then lets you check every word before saving.")
                            .foregroundStyle(.secondary)
                        Label("You’ll review the extracted instructions next", systemImage: "checklist")
                            .foregroundStyle(Color.ink)
                    }
                    Button(action: choosePDF) { Label("Choose PDF", systemImage: "doc.badge.plus").frame(maxWidth: .infinity) }
                        .buttonStyle(.borderedProminent).tint(.brandAction).controlSize(.large)
                        .accessibilityIdentifier("choose-private-pdf")
                }
                .padding()
            }
            .navigationTitle("Import a pattern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

private struct PatternReadyView: View {
    @Environment(\.dismiss) private var dismiss
    let pattern: Pattern
    let onProjectCreated: (Project) -> Void
    @State private var createProject = false
    @State private var showPattern = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    AuthenticatedCoverImage(path: pattern.coverUrl, fallbackAsset: "PatternFallback")
                        .frame(width: 180, height: 180)
                        .accessibilityIdentifier("pattern-ready-cover")
                    Label("Pattern ready", systemImage: "checkmark.seal.fill")
                        .font(.title.bold())
                        .foregroundStyle(Color.ink)
                    Text("\(pattern.name) is in your private library. Start a project now or review its sections first.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Button { createProject = true } label: { Label("Start a project", systemImage: "plus") }
                        .buttonStyle(.borderedProminent).tint(.brandAction).controlSize(.large)
                        .accessibilityIdentifier("ready-start-project")
                    Button { showPattern = true } label: { Label("Review pattern", systemImage: "list.bullet.rectangle") }
                        .buttonStyle(.bordered).tint(.brandAction).controlSize(.large)
                }
                .padding(28)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Next step")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .navigationDestination(isPresented: $showPattern) { PatternDetailView(pattern: pattern) }
            .sheet(isPresented: $createProject) { CreateProjectView(initialPattern: pattern) { project in if let project { onProjectCreated(project) } } }
        }
    }
}
