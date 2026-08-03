import SwiftUI
import StoreKit

@MainActor final class HomeStore: ObservableObject {
    @Published var activeProject: Project?
    @Published var sourceLabel: String?
    @Published var isLoading = false
    @Published var error: String?

    func load(client: APIClient) async {
        isLoading = true; defer { isLoading = false }
        if ProcessInfo.processInfo.arguments.contains("-simulateSlowLoading") { try? await Task.sleep(for: .seconds(4)) }
        if client.token == "demo" {
            activeProject = ProcessInfo.processInfo.arguments.contains("-emptyProjectsDemo") ? nil : DemoData.project
            sourceLabel = activeProject == nil ? nil : DemoData.instructions.first(where: { $0.position == DemoData.project.currentInstruction })?.sourceLabel
            return
        }
        do {
            let response: ProjectListResponse = try await client.request("/api/projects")
            activeProject = response.projects.first(where: { $0.status == "active" })
            guard let activeProject else { sourceLabel = nil; return }
            let detail: ProjectResponse = try await client.request("/api/projects/\(activeProject.id)")
            sourceLabel = detail.instructions.first(where: { $0.position == activeProject.currentInstruction })?.sourceLabel
        } catch { self.error = error.localizedDescription }
    }
}

struct HomeView: View {
    @EnvironmentObject private var auth: AuthManager
    @StateObject private var store = HomeStore()
    let showProjects: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if store.isLoading && store.activeProject == nil {
                    LoadingStateView(title: "Finding your current project", message: "Loading your most recently worked project and saved step…")
                } else if let project = store.activeProject {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            Text("Ready to keep making?").font(.largeTitle.bold()).foregroundStyle(Color.ink)
                            VStack(alignment: .leading, spacing: 14) {
                                Label("Current project", systemImage: "sparkles").font(.headline).foregroundStyle(Color.brandPink)
                                Text(project.name).font(.title2.bold()).foregroundStyle(Color.ink)
                                Text(project.patternName ?? "Pattern").font(.headline).foregroundStyle(.secondary)
                                Text(store.sourceLabel ?? "Step \(project.currentInstruction)").font(.title3.weight(.semibold)).foregroundStyle(Color.ink)
                                ProgressView(value: Double(project.currentInstruction), total: Double(max(project.totalInstructions ?? 1, 1))).tint(.brandOrange)
                                Text("Step \(project.currentInstruction) of \(project.totalInstructions ?? 0)").font(.subheadline).foregroundStyle(.secondary)
                                NavigationLink(value: project) {
                                    Label("Resume project", systemImage: "play.fill").frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent).tint(.ink).controlSize(.large)
                                .accessibilityIdentifier("resume-current-project")
                            }
                            .padding(22)
                            .background(Color.cream, in: .rect(cornerRadius: 24))
                        }
                        .padding()
                    }
                } else {
                    ActionableEmptyState(icon: "square.stack.3d.up", title: "Choose what to make next", message: "Start a project from a pattern in your library, then resume it here anytime.", actionTitle: "View projects", actionIcon: "square.stack.3d.up", isDisabled: store.isLoading, action: showProjects)
                }
            }
            .navigationTitle("Home")
            .navigationDestination(for: Project.self) { ReaderView(project: $0) }
            .task { await store.load(client: auth.client) }
            .refreshable { await store.load(client: auth.client) }
            .overlay(alignment: .top) { if store.isLoading && store.activeProject != nil { LoadingBanner(message: "Refreshing your current project and saved step…").padding(.top, 8) } }
            .alert("Couldn’t load Home", isPresented: .init(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("Try again") { Task { await store.load(client: auth.client) } } } message: { Text(store.error ?? "") }
        }
    }
}

@MainActor final class ProjectsStore: ObservableObject {
    @Published var projects: [Project] = []; @Published var loading = false; @Published var loadingMessage = "Loading your projects and saved progress…"; @Published var error: String?
    func load(client: APIClient, message: String = "Loading your projects and saved progress…") async { loadingMessage = message; loading = true; defer { loading = false }; if ProcessInfo.processInfo.arguments.contains("-simulateSlowLoading") { try? await Task.sleep(for: .seconds(4)) }; if client.token == "demo" { projects = ProcessInfo.processInfo.arguments.contains("-emptyProjectsDemo") ? [] : [DemoData.project]; return }; do { let response: ProjectListResponse = try await client.request("/api/projects"); projects = response.projects } catch { self.error = error.localizedDescription } }
}

struct ProjectsView: View {
    @EnvironmentObject private var auth: AuthManager
    @StateObject private var store = ProjectsStore()
    @State private var createProject = false
    @State private var projectToDelete: Project?
    @State private var deletingProject = false
    @State private var deletionError: String?
    var body: some View {
        NavigationStack {
            Group {
                if store.loading && store.projects.isEmpty { LoadingStateView(title: "Loading your projects", message: store.loadingMessage) }
                else if store.projects.isEmpty { ActionableEmptyState(icon: "square.stack.3d.up", title: "Start your first project", message: "Choose a pattern, add your yarn, and always return to the right step.", actionTitle: "Create a project", actionIcon: "plus", isDisabled: store.loading || createProject, action: beginCreatingProject) }
                else {
                    List {
                        let active = store.projects.filter { $0.status != "completed" }
                        let completed = store.projects.filter { $0.status == "completed" }
                        if !active.isEmpty { Section("Active") { ForEach(active) { project in projectLink(project) } } }
                        if !completed.isEmpty { Section("Completed") { ForEach(completed) { project in projectLink(project) } } }
                    }.listStyle(.insetGrouped)
                }
            }.navigationTitle("Projects")
                .toolbar { ToolbarItem(placement: .primaryAction) { Button("New project", systemImage: "plus", action: beginCreatingProject).disabled(store.loading || createProject || deletingProject) } }
                .navigationDestination(for: Project.self) { project in ProjectOverviewView(project: project) { Task { await store.load(client: auth.client, message: "Refreshing projects after your update…") } } }
                .sheet(isPresented: $createProject) { CreateProjectView { Task { await store.load(client: auth.client) } } }
                .task { await store.load(client: auth.client) }.refreshable { await store.load(client: auth.client, message: "Refreshing projects and checking saved progress…") }
                .overlay(alignment: .top) { if store.loading && !store.projects.isEmpty { LoadingBanner(message: store.loadingMessage).padding(.top, 8) } }
                .alert("Project wasn’t deleted", isPresented: .init(get: { deletionError != nil }, set: { if !$0 { deletionError = nil } })) { Button("OK") {} } message: { Text(deletionError ?? "") }
                .confirmationDialog("Delete this project?", isPresented: .init(get: { projectToDelete != nil }, set: { if !$0 { projectToDelete = nil } }), titleVisibility: .visible, presenting: projectToDelete) { project in
                    Button("Delete \(project.name)", role: .destructive) { Task { await deleteProject(project) } }
                    Button("Cancel", role: .cancel) { projectToDelete = nil }
                } message: { project in Text("This permanently deletes \(project.name), its progress, and notes. The pattern stays in your library.") }
        }
    }
    private func beginCreatingProject() { guard !store.loading, !createProject else { return }; createProject = true }
    private func projectLink(_ project: Project) -> some View {
        NavigationLink(value: project) { ProjectRow(project: project) }
            .swipeActions {
                Button(role: .destructive) { projectToDelete = project } label: { Label("Delete \(project.name)", systemImage: "trash") }
                    .disabled(deletingProject)
            }
    }
    private func deleteProject(_ project: Project) async {
        guard !deletingProject else { return }
        deletingProject = true; projectToDelete = nil
        store.loadingMessage = "Deleting \(project.name), its progress, and notes…"
        store.loading = true
        defer { deletingProject = false; store.loading = false }
        if auth.token == "demo" { store.projects.removeAll { $0.id == project.id }; return }
        do {
            let _: EmptyResponse = try await auth.client.request("/api/projects/\(project.id)", method: "DELETE")
            store.projects.removeAll { $0.id == project.id }
        } catch { deletionError = error.localizedDescription }
    }
}

struct ProjectRow: View {
    let project: Project
    var progress: Double { Double(project.currentInstruction) / Double(max(project.totalInstructions ?? 1, 1)) }
    var body: some View { HStack(spacing: 12) { AuthenticatedCoverImage(path: project.coverUrl, fallback: "square.stack.3d.up.fill").frame(width: 64, height: 64); VStack(alignment: .leading, spacing: 10) { HStack { VStack(alignment: .leading, spacing: 3) { Text(project.name).font(.headline); Text(project.patternName ?? "Pattern").font(.subheadline).foregroundStyle(.secondary) }; Spacer(); if project.status == "completed" { Label("Completed", systemImage: "checkmark.seal.fill").font(.caption.weight(.semibold)).foregroundStyle(Color.ink) } else if let craft = project.craft { CraftBadge(craft: craft) } }; ProgressView(value: progress).tint(project.status == "completed" ? .ink : .brandOrange); Text(project.status == "completed" ? "Finished project" : "Step \(project.currentInstruction) of \(project.totalInstructions ?? 0)").font(.caption).foregroundStyle(.secondary) } }.padding(.vertical, 6) }
}

struct ProjectOverviewView: View {
    @EnvironmentObject private var auth: AuthManager
    let project: Project
    let onUpdated: () -> Void
    @State private var detail: ProjectResponse?
    @State private var isLoading = true
    @State private var isCompleting = false
    @State private var confirmCompletion = false
    @State private var isCompleted: Bool
    @State private var error: String?

    init(project: Project, onUpdated: @escaping () -> Void) {
        self.project = project; self.onUpdated = onUpdated; _isCompleted = State(initialValue: project.status == "completed")
    }

    private var currentLabel: String { detail?.instructions.first(where: { $0.position == project.currentInstruction })?.sourceLabel ?? "Step \(project.currentInstruction)" }
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack { CraftBadge(craft: project.craft ?? "pattern"); Spacer(); if isCompleted { Label("Completed", systemImage: "checkmark.seal.fill").foregroundStyle(Color.ink) } }
                    Text(project.name).font(.largeTitle.bold())
                    Text(project.patternName ?? "Pattern").font(.headline).foregroundStyle(.secondary)
                    ProgressView(value: Double(project.currentInstruction), total: Double(max(project.totalInstructions ?? 1, 1))).tint(.brandOrange)
                    Text("\(currentLabel) · Step \(project.currentInstruction) of \(project.totalInstructions ?? 0)").foregroundStyle(.secondary)
                    if let yarn = project.yarn, !yarn.isEmpty { Label(yarn, systemImage: "circle.fill") }
                }.padding(.vertical, 8)
            }
            Section {
                NavigationLink { ReaderView(project: project, exitTitle: "Project") } label: { Label(isCompleted ? "Review instructions" : "Continue project", systemImage: "play.fill") }
                    .accessibilityIdentifier("continue-project")
                if !isCompleted {
                    Button { confirmCompletion = true } label: { Label("Mark project complete", systemImage: "checkmark.circle") }
                        .disabled(isCompleting)
                        .accessibilityIdentifier("complete-project")
                }
                if isCompleting { LoadingBanner(message: "Marking this project complete and updating your library…") }
            }
            Section("Saved notes") {
                if isLoading && detail == nil { LoadingBanner(message: "Loading project details and saved notes…") }
                else if let notes = detail?.notes, !notes.isEmpty {
                    ForEach(notes) { note in VStack(alignment: .leading, spacing: 6) { if let position = note.instructionPosition { Text("Step \(position)").font(.caption.weight(.semibold)).foregroundStyle(Color.ink) }; Text(note.body); Text(note.createdAt, style: .date).font(.caption).foregroundStyle(.secondary) }.padding(.vertical, 4) }
                } else { Text("No saved notes yet.").foregroundStyle(.secondary) }
            }
        }
        .navigationTitle("Project overview").navigationBarTitleDisplayMode(.inline)
        .task { await load() }.refreshable { await load() }
        .confirmationDialog("Mark \(project.name) complete?", isPresented: $confirmCompletion, titleVisibility: .visible) { Button("Mark complete") { Task { await complete() } }; Button("Cancel", role: .cancel) {} } message: { Text("Your project and notes will stay available for review.") }
        .alert("Couldn’t update project", isPresented: .init(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("Try again") { Task { await load() } } } message: { Text(error ?? "") }
    }
    private func load() async { isLoading = true; defer { isLoading = false }; if auth.token == "demo" { detail = ProjectResponse(project: project, instructions: DemoData.instructions, notes: DemoData.notes); return }; do { detail = try await auth.client.request("/api/projects/\(project.id)") } catch { self.error = error.localizedDescription } }
    private func complete() async { guard !isCompleting, !isCompleted else { return }; isCompleting = true; defer { isCompleting = false }; if auth.token == "demo" { isCompleted = true; onUpdated(); return }; struct Body: Encodable { let status = "completed" }; do { let _: EmptyResponse = try await auth.client.request("/api/projects/\(project.id)", method: "PATCH", body: Body()); isCompleted = true; onUpdated() } catch { self.error = error.localizedDescription } }
}

struct ReaderView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    let project: Project
    @State private var instructions: [Instruction] = []
    @State private var position: Int
    @State private var note = ""
    @State private var showNotes = false
    @State private var showSections = false
    @State private var isLoading = true
    @State private var isSavingProgress = false
    @State private var isSavingNote = false
    @State private var shouldExitAfterSave = false
    @State private var readerError: String?
    let exitTitle: String
    init(project: Project, showSectionsInitially: Bool = false, exitTitle: String = "Projects") {
        self.project = project
        self.exitTitle = exitTitle
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
        }.navigationTitle(project.name).navigationBarTitleDisplayMode(.inline).navigationBarBackButtonHidden(true).toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { exitReader() } label: { Label(exitTitle, systemImage: "chevron.left") }
                    .accessibilityLabel(isSavingProgress ? "Saving your place, then return to \(exitTitle)" : "Return to \(exitTitle)")
                    .accessibilityIdentifier("reader-exit")
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Sections", systemImage: "list.bullet.rectangle") { showSections = true }.disabled(isLoading)
                    .accessibilityIdentifier("reader-sections")
                Button("Note", systemImage: "square.and.pencil") { showNotes = true }.disabled(isLoading)
            }
        }.toolbar(.hidden, for: .tabBar)
            .sheet(isPresented: $showSections) { sectionNavigator }
            .sheet(isPresented: $showNotes) { NavigationStack { Form { TextEditor(text: $note).frame(minHeight: 160); if isSavingNote { Section { LoadingBanner(message: "Saving this note to step \(position)…").frame(maxWidth: .infinity) } } }.navigationTitle("Step note").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showNotes = false }.disabled(isSavingNote) }; ToolbarItem(placement: .confirmationAction) { Button { Task { await saveNote() } } label: { if isSavingNote { ProgressView().accessibilityLabel("Saving note") } else { Text("Save") } }.disabled(isSavingNote || note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } } } }
            .task { await loadReader() }
            .onChange(of: isSavingProgress) { _, saving in
                if !saving && shouldExitAfterSave {
                    shouldExitAfterSave = false
                    dismiss()
                }
            }
            .overlay(alignment: .top) { if isSavingProgress { LoadingBanner(message: "Saving your place at step \(position)…").padding(.top, 8) } }
            .alert("Couldn’t update your project", isPresented: .init(get: { readerError != nil }, set: { if !$0 { readerError = nil } })) { Button("OK") {} } message: { Text(readerError ?? "") }
    }
    private func exitReader() {
        if isSavingProgress { shouldExitAfterSave = true }
        else { dismiss() }
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
    private func loadReader() async { Telemetry.shared.track("reader_opened"); isLoading = true; defer { isLoading = false }; if ProcessInfo.processInfo.arguments.contains("-simulateSlowLoading") { try? await Task.sleep(for: .seconds(4)) }; if auth.token == "demo" { instructions = DemoData.instructions; let savedPosition = UserDefaults.standard.integer(forKey: "demoReaderPosition"); position = savedPosition > 0 ? savedPosition : project.currentInstruction; return }; do { let response: ProjectResponse = try await auth.client.request("/api/projects/\(project.id)"); instructions = response.instructions } catch { readerError = error.localizedDescription } }
    private func persistProgress() async { if auth.token == "demo" { UserDefaults.standard.set(position, forKey: "demoReaderPosition"); return }; isSavingProgress = true; defer { isSavingProgress = false }; struct Body: Encodable { let currentInstruction: Int }; do { let _: EmptyResponse = try await auth.client.request("/api/projects/\(project.id)", method: "PATCH", body: Body(currentInstruction: position)); Telemetry.shared.track("reader_progressed") } catch { readerError = error.localizedDescription } }
    private func saveNote() async { guard auth.token != "demo" else { note = ""; showNotes = false; return }; isSavingNote = true; defer { isSavingNote = false }; struct Body: Encodable { let instructionPosition: Int; let body: String }; do { let _: EmptyResponse = try await auth.client.request("/api/projects/\(project.id)/notes", method: "POST", body: Body(instructionPosition: position, body: note)); note = ""; showNotes = false } catch { readerError = error.localizedDescription } }
}

struct CreateProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @EnvironmentObject private var auth: AuthManager
    let onCreated: () -> Void
    let initialPattern: Pattern?
    @State private var patterns: [Pattern] = []; @State private var selected = ""; @State private var name = ""; @State private var yarn = ""; @State private var notes = ""; @State private var isLoadingPatterns = true; @State private var isCreating = false; @State private var error: String?
    init(initialPattern: Pattern? = nil, onCreated: @escaping () -> Void) { self.initialPattern = initialPattern; self.onCreated = onCreated; _selected = State(initialValue: initialPattern?.id ?? ""); _name = State(initialValue: initialPattern.map { "\($0.name) project" } ?? "") }
    var body: some View { NavigationStack { Form { Section("Pattern") { if isLoadingPatterns { LoadingBanner(message: "Loading patterns from your library…").frame(maxWidth: .infinity) } else { Picker("Pattern", selection: $selected) { Text("Choose a pattern").tag(""); ForEach(patterns) { Text($0.name).tag($0.id) } } } }; Section("Project") { TextField("Project name", text: $name); TextField("Yarn", text: $yarn); TextField("Notes", text: $notes, axis: .vertical) }; if isCreating { Section { LoadingBanner(message: "Creating your project and preparing its first step…").frame(maxWidth: .infinity) } } }.disabled(isCreating).navigationTitle("New project").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(isCreating) }; ToolbarItem(placement: .confirmationAction) { Button { Task { await create() } } label: { if isCreating { ProgressView().accessibilityLabel("Creating project") } else { Text("Create") } }.disabled(isLoadingPatterns || isCreating || selected.isEmpty || name.trimmingCharacters(in: .whitespaces).isEmpty) } }.task { await loadPatterns() }.alert("Couldn’t create project", isPresented: .init(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") {} } message: { Text(error ?? "") } } }
    private func loadPatterns() async { isLoadingPatterns = true; defer { isLoadingPatterns = false }; if ProcessInfo.processInfo.arguments.contains("-simulateSlowLoading") { try? await Task.sleep(for: .seconds(4)) }; if auth.token == "demo" { patterns = [DemoData.pattern]; selected = initialPattern?.id ?? DemoData.pattern.id; return }; do { let response: PatternListResponse = try await auth.client.request("/api/patterns"); patterns = response.patterns; selected = initialPattern.flatMap { initial in response.patterns.first(where: { $0.id == initial.id })?.id } ?? response.patterns.first?.id ?? "" } catch { self.error = error.localizedDescription } }
    private func create() async {
        guard !isCreating else { return }
        isCreating = true
        defer { isCreating = false }
        var shouldRequestReview = false
        if auth.token != "demo" {
            struct Body: Encodable { let patternId: String; let name: String; let yarn: String; let notes: String }
            do {
                let response: ProjectCreationResponse = try await auth.client.request("/api/projects", method: "POST", body: Body(patternId: selected, name: name, yarn: yarn, notes: notes))
                shouldRequestReview = ReviewPromptPolicy().claimRequest(isFirstProject: response.isFirstProject)
                Telemetry.shared.track("project_created")
            } catch {
                self.error = error.localizedDescription
                return
            }
        }
        dismiss()
        onCreated()
        if shouldRequestReview {
            try? await Task.sleep(for: .seconds(1))
            requestReview()
        }
    }
}
