import SwiftUI
import UniformTypeIdentifiers

@MainActor final class LibraryStore: ObservableObject {
    @Published var patterns: [Pattern] = []
    @Published var isLoading = false
    @Published var loadingMessage = "Loading your pattern library…"
    @Published var error: String?
    func load(client: APIClient, message: String = "Loading your pattern library…") async {
        loadingMessage = message
        isLoading = true; defer { isLoading = false }
        if ProcessInfo.processInfo.arguments.contains("-simulateSlowLoading") { try? await Task.sleep(for: .seconds(4)) }
        if client.token == "demo" { patterns = [DemoData.pattern]; return }
        do { let response: PatternListResponse = try await client.request("/api/patterns"); patterns = response.patterns } catch { self.error = error.localizedDescription }
    }
}

struct LibraryView: View {
    @EnvironmentObject private var auth: AuthManager
    @StateObject private var store = LibraryStore()
    @State private var importing = false
    var body: some View {
        NavigationStack {
            Group {
                if store.isLoading && store.patterns.isEmpty { LoadingStateView(title: "Loading your library", message: store.loadingMessage) }
                else if store.patterns.isEmpty { EmptyState(icon: "doc.badge.plus", title: "Your pattern library", message: "Import a PDF and Stitchly will turn it into focused, easy-to-follow steps.") }
                else { List(store.patterns) { pattern in NavigationLink(value: pattern) { PatternRow(pattern: pattern) } }.listStyle(.insetGrouped) }
            }
            .navigationTitle("Library")
            .toolbar { ToolbarItem(placement: .primaryAction) { Button("Import", systemImage: "plus") { importing = true }.disabled(store.isLoading) } }
            .navigationDestination(for: Pattern.self) { PatternDetailView(pattern: $0) }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf]) { result in if case .success(let url) = result { Task { await importPDF(url) } } }
            .task { await store.load(client: auth.client) }
            .refreshable { await store.load(client: auth.client) }
            .alert("Couldn’t load library", isPresented: .init(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("Try again") { Task { await store.load(client: auth.client) } } } message: { Text(store.error ?? "") }
            .overlay(alignment: .top) { if store.isLoading && !store.patterns.isEmpty { LoadingBanner(message: store.loadingMessage).padding(.top, 8) } }
        }
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
            let _: PatternResponse = try await auth.client.request("/api/patterns/parse", method: "POST", body: ParseBody(url: blob.url.absoluteString, name: url.deletingPathExtension().lastPathComponent))
            store.loadingMessage = "Adding the processed pattern to your library…"
            let response: PatternListResponse = try await auth.client.request("/api/patterns")
            store.patterns = response.patterns
            Telemetry.shared.track("pdf_import_completed")
        } catch { store.error = error.localizedDescription }
    }
}

struct PatternRow: View {
    let pattern: Pattern
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: pattern.craft == "knit" ? "scissors" : "circle.hexagongrid.fill").font(.title2).foregroundStyle(Color.brandPink).frame(width: 48, height: 48).background(Color.brandPink.opacity(0.14), in: .rect(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) { Text(pattern.name).font(.headline); Text([pattern.designer, "\(pattern.totalInstructions) steps"].compactMap { $0 }.joined(separator: " · ")).font(.subheadline).foregroundStyle(.secondary) }
        }.padding(.vertical, 4)
    }
}

struct PatternDetailView: View {
    @EnvironmentObject private var auth: AuthManager
    let pattern: Pattern
    @State private var instructions: [Instruction] = []
    @State private var isLoading = true
    @State private var error: String?
    var body: some View {
        List {
            Section { VStack(alignment: .leading, spacing: 14) { CraftBadge(craft: pattern.craft); Text(pattern.name).font(.largeTitle.bold()); if let designer = pattern.designer { Text("by \(designer)").foregroundStyle(.secondary) }; HStack { if let yarn = pattern.yarn { Label(yarn, systemImage: "circle.fill") }; if let tool = pattern.tool { Label(tool, systemImage: "wrench.and.screwdriver") } }.font(.subheadline).foregroundStyle(.secondary) }.padding(.vertical) }
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
        .task { await load() }
        .alert("Couldn’t open pattern", isPresented: .init(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("Try again") { Task { await load() } } } message: { Text(error ?? "") }
    }
    private func load() async {
        isLoading = true; defer { isLoading = false }
        if ProcessInfo.processInfo.arguments.contains("-simulateSlowLoading") { try? await Task.sleep(for: .seconds(4)) }
        if auth.token == "demo" { instructions = DemoData.instructions; return }
        do { let response: PatternResponse = try await auth.client.request("/api/patterns/\(pattern.id)"); instructions = response.instructions }
        catch { self.error = error.localizedDescription }
    }
}
