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
    func load(client: APIClient, userID: String?, forceRefresh: Bool = false, message: String = "Loading your pattern library…") async {
        loadingMessage = message
        error = nil
        if client.token == "demo" {
            isLoading = true; defer { isLoading = false }
            if ProcessInfo.processInfo.arguments.contains("-simulateSlowLoading") { try? await Task.sleep(for: .seconds(4)) }
            patterns = ProcessInfo.processInfo.arguments.contains("-emptyLibraryDemo") ? [] : [DemoData.pattern]
            return
        }
        guard let userID else { return }
        let cached = await AppDataCache.shared.cachedPatterns(for: userID)
        if patterns.isEmpty, let cached { patterns = cached.value }
        if !forceRefresh, let cached, cached.isFresh() { return }
        let isColdLoad = cached == nil && patterns.isEmpty
        isLoading = isColdLoad
        isRefreshing = !isColdLoad
        defer { isLoading = false; isRefreshing = false }
        do { patterns = try await AppDataCache.shared.refreshPatterns(for: userID, client: client) }
        catch { if patterns.isEmpty { self.error = error.localizedDescription } }
    }
}

struct LibraryView: View {
    @EnvironmentObject private var auth: AuthManager
    @StateObject private var store = LibraryStore()
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
    private var visiblePatterns: [Pattern] { PatternLibraryFiltering.apply(store.patterns, searchText: searchText, craft: craftFilter) }
    var body: some View {
        NavigationStack {
            Group {
                if store.isLoading && store.patterns.isEmpty { LoadingStateView(title: "Loading your library", message: store.loadingMessage) }
                else if store.patterns.isEmpty { ActionableEmptyState(icon: "sparkles.rectangle.stack", title: "Try your first pattern", message: "Use Stitchly’s optional starter headband, or import a PDF of your own. Both open in review before they join your private library.", actionTitle: "Try an example pattern", actionIcon: "sparkles", isDisabled: store.isLoading || importing || addingExample, action: { Task { await addExample() } }, secondaryActionTitle: "Import my PDF", secondaryActionIcon: "doc.badge.plus", secondaryAction: beginImport) }
                else {
                    VStack(spacing: 0) {
                        Picker("Craft", selection: $craftFilter) {
                            ForEach(PatternCraftFilter.allCases) { filter in Text(filter.rawValue).tag(filter) }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        .accessibilityHint("Filters the loaded pattern library by craft")
                        if visiblePatterns.isEmpty {
                            ContentUnavailableView {
                                Label("No matching patterns", systemImage: "magnifyingglass")
                            } description: {
                                Text("Try another search or reset the active craft filter.")
                            } actions: {
                                Button("Clear search and filters", action: resetFilters)
                                    .buttonStyle(.borderedProminent)
                                    .tint(.ink)
                                    .accessibilityIdentifier("clear-library-filters")
                            }
                        } else {
                            List(visiblePatterns) { pattern in
                                NavigationLink(value: pattern) { PatternRow(pattern: pattern) }
                                    .swipeActions {
                                        Button(role: .destructive) { patternToDelete = pattern } label: { Label("Delete \(pattern.name)", systemImage: "trash") }
                                            .disabled(deletingPattern)
                                    }
                            }.listStyle(.insetGrouped)
                        }
                    }
                    .accessibilityValue("\(visiblePatterns.count) patterns shown")
                }
            }
            .navigationTitle("Library")
            .searchable(text: $searchText, prompt: "Pattern or designer")
            .toolbar { ToolbarItem(placement: .primaryAction) { Button("Import", systemImage: "plus", action: beginImport).disabled(store.isLoading || importing) } }
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
            .task { await store.load(client: auth.client, userID: auth.user?.id); if ProcessInfo.processInfo.arguments.contains("-importReviewDemo") { reviewResponse = PatternResponse(pattern: DemoData.pattern, instructions: DemoData.instructions) } }
            .refreshable { await store.load(client: auth.client, userID: auth.user?.id, forceRefresh: true) }
            .alert("Couldn’t load library", isPresented: .init(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("Try again") { Task { await store.load(client: auth.client, userID: auth.user?.id, forceRefresh: true) } } } message: { Text(store.error ?? "") }
            .alert("Pattern wasn’t deleted", isPresented: .init(get: { deletionError != nil }, set: { if !$0 { deletionError = nil } })) { Button("OK") {} } message: { Text(deletionError ?? "") }
            .confirmationDialog("Delete this pattern?", isPresented: .init(get: { patternToDelete != nil }, set: { if !$0 { patternToDelete = nil } }), titleVisibility: .visible, presenting: patternToDelete) { pattern in
                Button("Delete \(pattern.name)", role: .destructive) { Task { await deletePattern(pattern) } }
                Button("Cancel", role: .cancel) { patternToDelete = nil }
            } message: { pattern in Text("This permanently deletes \(pattern.name), its PDF, linked projects, progress, and notes.") }
            .overlay(alignment: .top) { if store.isLoading && !store.patterns.isEmpty { LoadingBanner(message: store.loadingMessage).padding(.top, 8) } }
        }
    }
    private func resetFilters() { searchText = ""; craftFilter = .all }
    private func beginImport() { guard !store.isLoading, !importing, !showImportIntroduction else { return }; showImportIntroduction = true }
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
        guard let user = auth.user, auth.token != "demo" else { store.patterns = [DemoData.pattern]; return }
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
            AuthenticatedCoverImage(path: pattern.coverUrl, fallbackAsset: "PatternFallback").frame(width: 58, height: 58)
            VStack(alignment: .leading, spacing: 4) { Text(pattern.name).font(.headline); Text([pattern.designer, "\(pattern.totalInstructions) steps"].compactMap { $0 }.joined(separator: " · ")).font(.subheadline).foregroundStyle(.secondary) }
        }.padding(.vertical, 4)
    }
}

struct AuthenticatedCoverImage: View {
    @EnvironmentObject private var auth: AuthManager
    let path: String?
    let fallbackAsset: String
    @State private var image: UIImage?
    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFill() }
            else { Image(fallbackAsset).resizable().scaledToFill() }
        }
        .clipShape(.rect(cornerRadius: 14))
        .task(id: path) {
            guard let path, let userID = auth.user?.id else { return }
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
                    if let designer = pattern.designer { Text("by \(designer)").foregroundStyle(.secondary) }
                    HStack { if let yarn = pattern.yarn { Label(yarn, systemImage: "circle.fill") }; if let tool = pattern.tool { Label(tool, systemImage: "wrench.and.screwdriver") } }.font(.subheadline).foregroundStyle(.secondary)
                    Button { createProject = true } label: { Label("Start a project", systemImage: "plus").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).tint(.ink).controlSize(.large).accessibilityIdentifier("start-pattern-project")
                    Button { showOriginal = true } label: { Label("View original PDF", systemImage: "doc.richtext").frame(maxWidth: .infinity) }.buttonStyle(.bordered).tint(.ink).controlSize(.large).accessibilityIdentifier("pattern-original-pdf")
                }.padding(.vertical)
            }
            if isLoading { Section { LoadingBanner(message: "Loading sections and laying out each instruction…").frame(maxWidth: .infinity) } }
            ForEach(instructions.patternSections) { patternSection in
                Section {
                    ForEach(patternSection.instructions) { instruction in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack { Text(instruction.sourceLabel ?? "Step \(instruction.position)").font(.headline); Spacer(); Text("Step \(instruction.position)").font(.caption).foregroundStyle(.secondary) }
                            Text(instruction.instructions).foregroundStyle(.secondary)
                            if let notes = instruction.notes { Label(notes, systemImage: "lightbulb").font(.callout).foregroundStyle(Color.ink) }
                        }.padding(.vertical, 4)
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(patternSection.title)
                        Text("Steps \(patternSection.firstPosition)–\(patternSection.lastPosition) · \(patternSection.instructions.count) instructions").font(.caption).textCase(nil)
                    }.accessibilityElement(children: .combine)
                }
            }
        }
        .navigationTitle("Pattern overview")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $createProject) { CreateProjectView(initialPattern: pattern) { createdProject = $0 } }
        .sheet(isPresented: $showOriginal) { OriginalPDFView(patternID: pattern.id, title: pattern.name) }
        .sheet(item: $createdProject) { ProjectCreatedView(project: $0) }
        .task { await load() }
        .alert("Couldn’t open pattern", isPresented: .init(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("Try again") { Task { await load() } } } message: { Text(error ?? "") }
    }
    private func load() async {
        if auth.token == "demo" {
            isLoading = true; defer { isLoading = false }
            if ProcessInfo.processInfo.arguments.contains("-simulateSlowLoading") { try? await Task.sleep(for: .seconds(4)) }
            instructions = DemoData.instructions
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
                        .buttonStyle(.borderedProminent).tint(.ink).controlSize(.large)
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
                        .buttonStyle(.borderedProminent).tint(.ink).controlSize(.large)
                        .accessibilityIdentifier("ready-start-project")
                    Button { showPattern = true } label: { Label("Review pattern", systemImage: "list.bullet.rectangle") }
                        .buttonStyle(.bordered).tint(.ink).controlSize(.large)
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
