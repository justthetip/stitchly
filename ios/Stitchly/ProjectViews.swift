import SwiftUI

@MainActor final class ProjectsStore: ObservableObject {
    @Published var projects: [Project] = []; @Published var loading = false; @Published var loadingMessage = "Loading your projects and saved progress…"; @Published var error: String?
    func load(client: APIClient, message: String = "Loading your projects and saved progress…") async { loadingMessage = message; loading = true; defer { loading = false }; if ProcessInfo.processInfo.arguments.contains("-simulateSlowLoading") { try? await Task.sleep(for: .seconds(4)) }; if client.token == "demo" { projects = [DemoData.project]; return }; do { let response: ProjectListResponse = try await client.request("/api/projects"); projects = response.projects } catch { self.error = error.localizedDescription } }
}

struct ProjectsView: View {
    @EnvironmentObject private var auth: AuthManager
    @StateObject private var store = ProjectsStore()
    @State private var createProject = false
    var body: some View {
        NavigationStack {
            Group {
                if store.loading && store.projects.isEmpty { LoadingStateView(title: "Loading your projects", message: store.loadingMessage) }
                else if store.projects.isEmpty { EmptyState(icon: "square.stack.3d.up", title: "Start your first project", message: "Choose a pattern, add your yarn, and always return to the right step.") }
                else { List(store.projects) { project in NavigationLink(value: project) { ProjectRow(project: project) } }.listStyle(.insetGrouped) }
            }.navigationTitle("Projects")
                .toolbar { ToolbarItem(placement: .primaryAction) { Button("New project", systemImage: "plus") { createProject = true }.disabled(store.loading) } }
                .navigationDestination(for: Project.self) { ReaderView(project: $0) }
                .sheet(isPresented: $createProject) { CreateProjectView { Task { await store.load(client: auth.client) } } }
                .task { await store.load(client: auth.client) }.refreshable { await store.load(client: auth.client, message: "Refreshing projects and checking saved progress…") }
                .overlay(alignment: .top) { if store.loading && !store.projects.isEmpty { LoadingBanner(message: store.loadingMessage).padding(.top, 8) } }
        }
    }
}

struct ProjectRow: View {
    let project: Project
    var progress: Double { Double(project.currentInstruction) / Double(max(project.totalInstructions ?? 1, 1)) }
    var body: some View { VStack(alignment: .leading, spacing: 10) { HStack { VStack(alignment: .leading, spacing: 3) { Text(project.name).font(.headline); Text(project.patternName ?? "Pattern").font(.subheadline).foregroundStyle(.secondary) }; Spacer(); if let craft = project.craft { CraftBadge(craft: craft) } }; ProgressView(value: progress).tint(.brandOrange); Text("Step \(project.currentInstruction) of \(project.totalInstructions ?? 0)").font(.caption).foregroundStyle(.secondary) }.padding(.vertical, 6) }
}

struct ReaderView: View {
    @EnvironmentObject private var auth: AuthManager
    let project: Project
    @State private var instructions: [Instruction] = []
    @State private var position: Int
    @State private var note = ""
    @State private var showNotes = false
    @State private var showSections = false
    @State private var isLoading = true
    @State private var isSavingProgress = false
    @State private var isSavingNote = false
    @State private var readerError: String?
    init(project: Project, showSectionsInitially: Bool = false) {
        self.project = project
        _position = State(initialValue: project.currentInstruction)
        _showSections = State(initialValue: showSectionsInitially)
    }
    var current: Instruction? { instructions.first { $0.position == position } ?? instructions.first }
    var body: some View {
        ZStack {
            LinearGradient(colors: [.cream.opacity(0.65), .white], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 0) {
                HStack { Text(current?.section ?? project.patternName ?? "Pattern").font(.subheadline.weight(.semibold)).foregroundStyle(Color.ink); Spacer(); Text("\(position) / \(max(instructions.count, project.totalInstructions ?? 1))").monospacedDigit().foregroundStyle(Color.ink) }.padding()
                ProgressView(value: Double(position), total: Double(max(instructions.count, project.totalInstructions ?? 1))).tint(.brandOrange).padding(.horizontal).accessibilityHidden(true)
                if isLoading {
                    LoadingStateView(title: "Opening your project", message: "Loading pattern sections, your current step, and saved notes.")
                } else { ScrollView {
                    VStack(spacing: 18) {
                        Text(current?.sourceLabel ?? "Step \(position)").font(.title3.weight(.semibold)).foregroundStyle(Color.brandPink)
                        Text(current?.instructions ?? "Loading your next step…")
                            .font(.system(.title, design: .rounded, weight: .semibold))
                            .foregroundStyle(Color.ink)
                            .multilineTextAlignment(.center)
                            .lineSpacing(8)
                            .padding(20)
                            .background(Color.white, in: .rect(cornerRadius: 20))
                        if let stitchCount = current?.stitchCount { Label("\(stitchCount) stitches", systemImage: "number").font(.headline).foregroundStyle(Color.ink) }
                        if let notes = current?.notes { Text(notes).font(.body).foregroundStyle(.secondary).padding().background(.thinMaterial, in: .rect(cornerRadius: 16)) }
                    }.frame(maxWidth: .infinity).padding(28)
                }.defaultScrollAnchor(.center) }
                HStack(spacing: 18) {
                    Button { move(-1) } label: { Label("Previous", systemImage: "chevron.left").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).tint(.ink).controlSize(.large).disabled(isLoading || isSavingProgress || position <= 1)
                    Button { move(1) } label: { Label("Next", systemImage: "chevron.right").labelStyle(.titleAndIcon).frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).tint(.ink).controlSize(.large).disabled(isLoading || isSavingProgress || position >= max(instructions.count, project.totalInstructions ?? 1))
                }.padding()
            }
        }.navigationTitle(project.name).navigationBarTitleDisplayMode(.inline).toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Sections", systemImage: "list.bullet.rectangle") { showSections = true }.disabled(isLoading)
                    .accessibilityIdentifier("reader-sections")
                Button("Note", systemImage: "square.and.pencil") { showNotes = true }.disabled(isLoading)
            }
        }.toolbar(.hidden, for: .tabBar)
            .sheet(isPresented: $showSections) { sectionNavigator }
            .sheet(isPresented: $showNotes) { NavigationStack { Form { TextEditor(text: $note).frame(minHeight: 160); if isSavingNote { Section { LoadingBanner(message: "Saving this note to step \(position)…").frame(maxWidth: .infinity) } } }.navigationTitle("Step note").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showNotes = false }.disabled(isSavingNote) }; ToolbarItem(placement: .confirmationAction) { Button { Task { await saveNote() } } label: { if isSavingNote { ProgressView().accessibilityLabel("Saving note") } else { Text("Save") } }.disabled(isSavingNote || note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } } } }
            .task { await loadReader() }
            .overlay(alignment: .top) { if isSavingProgress { LoadingBanner(message: "Saving your place at step \(position)…").padding(.top, 8) } }
            .alert("Couldn’t update your project", isPresented: .init(get: { readerError != nil }, set: { if !$0 { readerError = nil } })) { Button("OK") {} } message: { Text(readerError ?? "") }
    }
    private var sectionNavigator: some View {
        NavigationStack {
            List(instructions.patternSections) { section in
                Button {
                    position = section.firstPosition
                    showSections = false
                    Task { await persistProgress() }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: section.firstPosition == current?.position || section.instructions.contains(where: { $0.position == position }) ? "bookmark.fill" : "bookmark")
                            .foregroundStyle(Color.brandPink)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(section.title).font(.headline).foregroundStyle(.primary)
                            Text("Steps \(section.firstPosition)–\(section.lastPosition) · \(section.instructions.count) instructions").font(.subheadline).foregroundStyle(Color.ink)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Color.ink)
                    }.padding(.vertical, 5)
                }
                .accessibilityLabel("\(section.title), steps \(section.firstPosition) to \(section.lastPosition)")
                .buttonStyle(.plain)
            }
            .scrollContentBackground(.hidden)
            .background(Color(.systemBackground))
            .navigationTitle("Pattern sections")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { showSections = false } label: { Image(systemName: "xmark") }
                        .tint(.ink)
                        .accessibilityLabel("Close sections")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Color(.systemBackground))
    }
    private func move(_ delta: Int) { position = min(max(position + delta, 1), max(instructions.count, project.totalInstructions ?? 1)); Task { await persistProgress() } }
    private func loadReader() async { Telemetry.shared.track("reader_opened"); isLoading = true; defer { isLoading = false }; if ProcessInfo.processInfo.arguments.contains("-simulateSlowLoading") { try? await Task.sleep(for: .seconds(4)) }; if auth.token == "demo" { instructions = DemoData.instructions; return }; do { let response: ProjectResponse = try await auth.client.request("/api/projects/\(project.id)"); instructions = response.instructions } catch { readerError = error.localizedDescription } }
    private func persistProgress() async { guard auth.token != "demo" else { return }; isSavingProgress = true; defer { isSavingProgress = false }; struct Body: Encodable { let currentInstruction: Int }; do { let _: EmptyResponse = try await auth.client.request("/api/projects/\(project.id)", method: "PATCH", body: Body(currentInstruction: position)); Telemetry.shared.track("reader_progressed") } catch { readerError = error.localizedDescription } }
    private func saveNote() async { guard auth.token != "demo" else { note = ""; showNotes = false; return }; isSavingNote = true; defer { isSavingNote = false }; struct Body: Encodable { let instructionPosition: Int; let body: String }; do { let _: EmptyResponse = try await auth.client.request("/api/projects/\(project.id)/notes", method: "POST", body: Body(instructionPosition: position, body: note)); note = ""; showNotes = false } catch { readerError = error.localizedDescription } }
}

struct CreateProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthManager
    let onCreated: () -> Void
    @State private var patterns: [Pattern] = []; @State private var selected = ""; @State private var name = ""; @State private var yarn = ""; @State private var notes = ""; @State private var isLoadingPatterns = true; @State private var isCreating = false; @State private var error: String?
    var body: some View { NavigationStack { Form { Section("Pattern") { if isLoadingPatterns { LoadingBanner(message: "Loading patterns from your library…").frame(maxWidth: .infinity) } else { Picker("Pattern", selection: $selected) { Text("Choose a pattern").tag(""); ForEach(patterns) { Text($0.name).tag($0.id) } } } }; Section("Project") { TextField("Project name", text: $name); TextField("Yarn", text: $yarn); TextField("Notes", text: $notes, axis: .vertical) }; if isCreating { Section { LoadingBanner(message: "Creating your project and preparing its first step…").frame(maxWidth: .infinity) } } }.disabled(isCreating).navigationTitle("New project").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(isCreating) }; ToolbarItem(placement: .confirmationAction) { Button { Task { await create() } } label: { if isCreating { ProgressView().accessibilityLabel("Creating project") } else { Text("Create") } }.disabled(isLoadingPatterns || isCreating || selected.isEmpty || name.trimmingCharacters(in: .whitespaces).isEmpty) } }.task { await loadPatterns() }.alert("Couldn’t create project", isPresented: .init(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") {} } message: { Text(error ?? "") } } }
    private func loadPatterns() async { isLoadingPatterns = true; defer { isLoadingPatterns = false }; if ProcessInfo.processInfo.arguments.contains("-simulateSlowLoading") { try? await Task.sleep(for: .seconds(4)) }; if auth.token == "demo" { patterns = [DemoData.pattern]; selected = DemoData.pattern.id; return }; do { let response: PatternListResponse = try await auth.client.request("/api/patterns"); patterns = response.patterns; selected = response.patterns.first?.id ?? "" } catch { self.error = error.localizedDescription } }
    private func create() async { isCreating = true; defer { isCreating = false }; if auth.token != "demo" { struct Body: Encodable { let patternId: String; let name: String; let yarn: String; let notes: String }; do { let _: EmptyResponse = try await auth.client.request("/api/projects", method: "POST", body: Body(patternId: selected, name: name, yarn: yarn, notes: notes)); Telemetry.shared.track("project_created") } catch { self.error = error.localizedDescription; return } }; dismiss(); onCreated() }
}
