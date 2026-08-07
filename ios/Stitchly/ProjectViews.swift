import SwiftUI
import StoreKit

@MainActor final class ProjectsStore: ObservableObject {
    @Published var projects: [Project] = []
    @Published var loading = false
    @Published var refreshing = false
    @Published var loadingMessage = "Loading your projects and saved progress…"
    @Published var error: String?
    private var loadedIdentity: String?

    func load(client: APIClient, userID: String?, forceRefresh: Bool = false, message: String = "Loading your projects and saved progress…") async {
        loadingMessage = message
        error = nil
        let identity = userID == nil || client.token == "demo" ? "guest" : userID!
        if loadedIdentity != identity {
            projects = []
            loadedIdentity = identity
        }
        if userID == nil || client.token == "demo" {
            loading = true; defer { loading = false }
            if ProcessInfo.processInfo.arguments.contains("-simulateSlowLoading") { try? await Task.sleep(for: .seconds(4)) }
            projects = ProcessInfo.processInfo.arguments.contains("-emptyProjectsDemo") ? [] : DemoData.projectsWithLocalProgress
            return
        }
        guard let userID else { return }
        let cached = await AppDataCache.shared.cachedProjects(for: userID)
        if projects.isEmpty, let cached { projects = cached.value }
        if !forceRefresh, let cached, cached.isFresh() { return }
        loading = cached == nil && projects.isEmpty
        refreshing = !loading
        defer { loading = false; refreshing = false }
        do { projects = try await AppDataCache.shared.refreshProjects(for: userID, client: client) }
        catch { if cached == nil { self.error = error.localizedDescription } }
    }
}

struct ProjectsView: View {
    @EnvironmentObject private var auth: AuthManager
    @StateObject private var store = ProjectsStore()
    @State private var createProject = false
    @State private var projectToDelete: Project?
    @State private var deletingProject = false
    @State private var deletionError: String?
    @State private var createdProject: Project?
    var showLibrary: () -> Void = {}
    var body: some View {
        NavigationStack {
            Group {
                if store.loading && store.projects.isEmpty { LoadingStateView(title: "Loading your projects", message: store.loadingMessage) }
                else if store.projects.isEmpty { ActionableEmptyState(icon: "square.stack.3d.up", title: "No projects on the go", message: "Import a pattern first, then start a project and always return to the right step.", actionTitle: "Choose a pattern", actionIcon: "books.vertical", isDisabled: store.loading || createProject, action: showLibrary) }
                else {
                    List {
                        let active = store.projects.filter { $0.status != "completed" }
                        let completed = store.projects.filter { $0.status == "completed" }
                        if !active.isEmpty {
                            Section {
                                ForEach(active) { project in projectLink(project) }
                            } header: {
                                ProjectStateHeader(title: "In progress", systemImage: "play.circle.fill", color: .brandPink)
                                    .accessibilityIdentifier("projects-in-progress-section")
                            }
                        }
                        if !completed.isEmpty {
                            Section {
                                ForEach(completed) { project in projectLink(project) }
                            } header: {
                                ProjectStateHeader(title: "Completed", systemImage: "checkmark.seal.fill", color: .ink)
                                    .accessibilityIdentifier("projects-completed-section")
                            }
                        }
                    }.listStyle(.insetGrouped)
                }
            }.navigationTitle("Projects")
                .toolbar { ToolbarItem(placement: .primaryAction) { Button("New project", systemImage: "plus", action: beginCreatingProject).disabled(store.loading || createProject || deletingProject) } }
                .navigationDestination(for: Project.self) { project in ProjectOverviewView(project: project) { Task { await store.load(client: auth.client, userID: auth.user?.id, forceRefresh: true, message: "Refreshing projects after your update…") } } }
                .sheet(isPresented: $createProject) { CreateProjectView { project in createdProject = project; Task { await store.load(client: auth.client, userID: auth.user?.id, forceRefresh: true) } } }
                .sheet(item: $createdProject) { ProjectCreatedView(project: $0) }
                .task(id: auth.contentIdentity) { await store.load(client: auth.client, userID: auth.user?.id) }.refreshable { await store.load(client: auth.client, userID: auth.user?.id, forceRefresh: true, message: "Refreshing projects and checking saved progress…") }
                .overlay(alignment: .top) { if store.loading && !store.projects.isEmpty { LoadingBanner(message: store.loadingMessage).padding(.top, 8) } }
                .alert("Project wasn’t deleted", isPresented: .init(get: { deletionError != nil }, set: { if !$0 { deletionError = nil } })) { Button("OK") {} } message: { Text(deletionError ?? "") }
                .confirmationDialog("Delete this project?", isPresented: .init(get: { projectToDelete != nil }, set: { if !$0 { projectToDelete = nil } }), titleVisibility: .visible, presenting: projectToDelete) { project in
                    Button("Delete \(project.name)", role: .destructive) { Task { await deleteProject(project) } }
                    Button("Cancel", role: .cancel) { projectToDelete = nil }
                } message: { project in Text("This permanently deletes \(project.name), its progress, and notes. The pattern stays in your library.") }
        }
    }
    private func beginCreatingProject() {
        guard !store.loading, !createProject else { return }
        guard !auth.isGuest else {
            auth.requireAuthentication(title: "Create an account to start a project", message: "Projects save your yarn, notes, and place in the pattern across devices.")
            return
        }
        createProject = true
    }
    private func projectLink(_ project: Project) -> some View {
        NavigationLink(value: project) { ProjectRow(project: project) }
            .swipeActions {
                Button(role: .destructive) { projectToDelete = project } label: { Label("Delete \(project.name)", systemImage: "trash") }
                    .disabled(deletingProject)
            }
    }
    private func deleteProject(_ project: Project) async {
        guard !deletingProject else { return }
        guard !auth.isGuest else {
            projectToDelete = nil
            auth.requireAuthentication(title: "Sign in to manage projects", message: "The demo project is read-only. Create an account to make and manage your own projects.")
            return
        }
        deletingProject = true; projectToDelete = nil
        store.loadingMessage = "Deleting \(project.name), its progress, and notes…"
        store.loading = true
        defer { deletingProject = false; store.loading = false }
        if auth.token == "demo" { store.projects.removeAll { $0.id == project.id }; return }
        do {
            let _: EmptyResponse = try await auth.client.request("/api/projects/\(project.id)", method: "DELETE")
            store.projects.removeAll { $0.id == project.id }
            if let userID = auth.user?.id { await AppDataCache.shared.store(projects: store.projects, for: userID) }
        } catch { deletionError = error.localizedDescription }
    }
}

struct ProjectRow: View {
    let project: Project
    var progress: Double { Double(project.currentInstruction) / Double(max(project.totalInstructions ?? 1, 1)) }
    var body: some View {
        HStack(spacing: 12) {
            ListCoverThumbnail(path: project.coverUrl, fallbackAsset: "ProjectFallback", size: 64)
            VStack(alignment: .leading, spacing: 8) {
                if DemoData.isDemoProject(project.id) {
                    Label("DEMO PROJECT", systemImage: "sparkles")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.brandPink, in: .capsule)
                }
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(project.name).font(.headline)
                        Text(project.patternName ?? "Pattern").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if project.status == "completed" { Label("Completed", systemImage: "checkmark.seal.fill").font(.caption.weight(.semibold)).foregroundStyle(Color.ink) }
                    else if let craft = project.craft { CraftBadge(craft: craft) }
                }
                ProgressView(value: progress).tint(project.status == "completed" ? .ink : .brandOrange)
                Text(project.status == "completed" ? "Finished project" : "Step \(project.currentInstruction) of \(project.totalInstructions ?? 0)").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct ProjectStateHeader: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(color)
            .textCase(nil)
    }
}

struct ProjectOverviewView: View {
    @EnvironmentObject private var auth: AuthManager
    let project: Project
    let onUpdated: () -> Void
    @State private var detail: ProjectResponse?
    @State private var isLoading = true
    @State private var isCompleting = false
    @State private var confirmCompletion = false
    @State private var showOriginal = false
    @State private var isCompleted: Bool
    @State private var error: String?
    @State private var checkedMaterials: Set<String>

    init(project: Project, onUpdated: @escaping () -> Void) {
        self.project = project; self.onUpdated = onUpdated; _isCompleted = State(initialValue: project.status == "completed")
        _checkedMaterials = State(initialValue: ProjectMaterials.loadChecks(projectID: project.id))
    }

    private var currentLabel: String { detail?.instructions.first(where: { $0.position == project.currentInstruction })?.sourceLabel ?? "Step \(project.currentInstruction)" }
    private var isGuestDemo: Bool { (auth.isGuest || auth.token == "demo") && DemoData.isDemoProject(project.id) }
    private var isExploreProject: Bool { isGuestDemo && !isCompleted }
    private var explorePattern: Pattern? { DemoData.patterns.first { $0.id == project.patternId } }
    private var materials: [ProjectMaterial] { ProjectMaterials.derive(project: project, pattern: explorePattern, instructions: detail?.instructions ?? []) }
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    AuthenticatedCoverImage(path: project.coverUrl, fallbackAsset: "ProjectFallback")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 190, maxHeight: 190)
                        .clipped()
                        .clipShape(.rect(cornerRadius: 14))
                    if isGuestDemo { DemoProjectCallout() }
                    HStack { CraftBadge(craft: project.craft ?? "pattern"); Spacer(); if isCompleted { Label("Completed", systemImage: "checkmark.seal.fill").foregroundStyle(Color.ink) } }
                    Text(project.name).font(.largeTitle.bold()).fixedSize(horizontal: false, vertical: true)
                    Text(project.patternName ?? "Pattern").font(.headline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    ProgressView(value: Double(project.currentInstruction), total: Double(max(project.totalInstructions ?? 1, 1))).tint(.brandOrange)
                    Text("\(currentLabel) · Step \(project.currentInstruction) of \(project.totalInstructions ?? 0)").foregroundStyle(.secondary)
                    if let yarn = project.yarn, !yarn.isEmpty { Label(yarn, systemImage: "circle.fill") }
                }.padding(.vertical, 8)
            }
            if isExploreProject {
                Section {
                    Text("This project started as a pattern PDF from another website—not as a tidy list of steps. Stitchly kept its original terms, then organized the instructions into a consistent format you can actually work through.")
                        .foregroundStyle(.secondary)
                    Button { showOriginal = true } label: {
                        ExploreTransformationStep(
                            number: 1,
                            icon: "doc.richtext",
                            title: "The original PDF",
                            message: "Designed for reading and printing, so finding your place means scanning pages again."
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("explore-original-pdf")
                    if let explorePattern {
                        NavigationLink {
                            PatternDetailView(pattern: explorePattern)
                        } label: {
                            ExploreTransformationStep(
                                number: 2,
                                icon: "list.bullet.rectangle",
                                title: "A standardized pattern",
                                message: "Source-order sections, rows, rounds, setup, and finishing are laid out consistently."
                            )
                        }
                        .accessibilityIdentifier("explore-standardized-pattern")
                    }
                    ExploreTransformationStep(
                        number: 3,
                        icon: "bookmark.fill",
                        title: "A live project",
                        message: "Your current step and progress are ready whenever you come back."
                    )
                } header: {
                    Text("From PDF to a project")
                        .accessibilityIdentifier("explore-project-transformation")
                } footer: {
                    Text("The focused reader below is the result of that transformation.")
                }
            }
            Section {
                if materials.isEmpty {
                    Text("No structured materials were found. Check the original PDF before starting; Stitchly won’t guess missing supplies.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(materials) { material in
                        Button { toggleMaterial(material.id) } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: checkedMaterials.contains(material.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.title3).foregroundStyle(checkedMaterials.contains(material.id) ? Color.brandPink : Color.secondary)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(material.name)
                                        .font(.headline)
                                        .foregroundStyle(Color.ink)
                                        .strikethrough(checkedMaterials.contains(material.id))
                                    if let detail = material.detail { Text(detail).font(.subheadline).foregroundStyle(.secondary) }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(material.name), \(checkedMaterials.contains(material.id) ? "ready" : "not ready")")
                        .accessibilityHint("Toggles this material in the project checklist")
                    }
                }
            } header: {
                Text("Materials checklist")
                    .accessibilityIdentifier("project-materials")
            } footer: {
                Text("Check your setup when you start or return. Your choices stay on this device.")
            }
            Section {
                NavigationLink {
                    ReaderView(project: project, exitTitle: "Project") {
                        isCompleted = true
                        onUpdated()
                    }
                } label: { Label(isCompleted ? "Review instructions" : (isExploreProject ? "Open the clear step-by-step reader" : "Continue project"), systemImage: "play.fill") }
                    .accessibilityIdentifier("continue-project")
                if !isExploreProject {
                    Button { showOriginal = true } label: { Label("View original PDF", systemImage: "doc.richtext") }
                        .accessibilityIdentifier("project-original-pdf")
                }
                if !isCompleted {
                    Button { beginCompletion() } label: { Label("Mark project complete", systemImage: "checkmark.circle") }
                        .disabled(isCompleting)
                        .accessibilityIdentifier("complete-project")
                }
                if isCompleting { LoadingBanner(message: "Marking this project complete and updating your library…") }
            } header: {
                if isExploreProject { Text("Make from the result") }
            }
            Section("Saved notes") {
                if isLoading && detail == nil { LoadingBanner(message: "Loading project details and saved notes…") }
                else if let notes = detail?.notes, !notes.isEmpty {
                    ForEach(notes) { note in VStack(alignment: .leading, spacing: 6) { if let position = note.instructionPosition { Text("Step \(position)").font(.caption.weight(.semibold)).foregroundStyle(Color.ink) }; Text(note.body); Text(note.createdAt, style: .date).font(.caption).foregroundStyle(.secondary) }.padding(.vertical, 4) }
                } else { Text("No saved notes yet.").foregroundStyle(.secondary) }
            }
        }
        .navigationTitle("Project overview").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showOriginal) { OriginalPDFView(patternID: project.patternId, title: project.patternName ?? "Original pattern") }
        .task { await load() }.refreshable { await load() }
        .confirmationDialog("Mark \(project.name) complete?", isPresented: $confirmCompletion, titleVisibility: .visible) { Button("Mark complete") { Task { await complete() } }; Button("Cancel", role: .cancel) {} } message: { Text("Your project and notes will stay available for review.") }
        .alert("Couldn’t update project", isPresented: .init(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("Try again") { Task { await load() } } } message: { Text(error ?? "") }
    }
    private func load() async {
        if auth.isGuest || auth.token == "demo" { isLoading = true; defer { isLoading = false }; detail = ProjectResponse(project: project, instructions: DemoData.instructions(for: project.patternId), notes: DemoData.notes); return }
        guard let userID = auth.user?.id else { return }
        let cached = await AppDataCache.shared.cachedProjectDetail(for: userID, projectID: project.id)
        if detail == nil, let cached { detail = cached.value }
        if let cached, cached.isFresh() { isLoading = false; return }
        isLoading = detail == nil
        defer { isLoading = false }
        do { detail = try await AppDataCache.shared.refreshProjectDetail(for: userID, projectID: project.id, client: auth.client) }
        catch { if detail == nil { self.error = error.localizedDescription } }
    }
    private func toggleMaterial(_ id: String) {
        if checkedMaterials.contains(id) { checkedMaterials.remove(id) } else { checkedMaterials.insert(id) }
        ProjectMaterials.saveChecks(checkedMaterials, projectID: project.id)
    }
    private func complete() async {
        guard !isCompleting, !isCompleted else { return }
        isCompleting = true; defer { isCompleting = false }
        if auth.token == "demo" { isCompleted = true; onUpdated(); return }
        struct Body: Encodable { let status = "completed" }
        do {
            let _: EmptyResponse = try await auth.client.request("/api/projects/\(project.id)", method: "PATCH", body: Body())
            if let userID = auth.user?.id { await AppDataCache.shared.invalidateProject(for: userID, projectID: project.id) }
            isCompleted = true; onUpdated()
        } catch { self.error = error.localizedDescription }
    }
    private func beginCompletion() {
        guard !auth.isGuest else {
            auth.requireAuthentication(title: "Create an account to complete projects", message: "Sign in to save completion, progress, and notes to your maker space.")
            return
        }
        confirmCompletion = true
    }
}

private struct ExploreTransformationStep: View {
    let number: Int
    let icon: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(Color.white)
                .frame(width: 26, height: 26)
                .background(number == 3 ? Color.brandPink : Color.ink, in: .circle)
                .accessibilityHidden(true)
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(number == 3 ? Color.brandPink : Color.ink)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundStyle(Color.ink)
                Text(message).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number), \(title). \(message)")
    }
}

struct ReaderView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title3) private var repeatBadgeFontSize: CGFloat = 20
    let project: Project
    @State private var instructions: [Instruction] = []
    @State private var position: Int
    @State private var note = ""
    @State private var showNotes = false
    @State private var showSections = false
    @State private var showOriginal = false
    @State private var isLoading = true
    @State private var isSavingProgress = false
    @State private var isSavingNote = false
    @State private var isCompletingProject = false
    @State private var showCompletion = false
    @State private var hasCompletedProject: Bool
    @State private var shouldExitAfterSave = false
    @State private var readerError: String?
    @State private var selectedGlossaryTerm: PatternGlossaryTerm?
    @State private var stepPhotos: [ProjectStepPhoto] = []
    @State private var selectedPhoto: ProjectStepPhoto?
    @State private var showStepPhotos = false
    @State private var presentedPhotoSource: ProjectPhotoSource?
    @State private var isSavingPhoto = false
    @State private var isDeletingPhoto = false
    let exitTitle: String
    let onCompleted: () -> Void
    init(project: Project, showSectionsInitially: Bool = false, exitTitle: String = "Projects", onCompleted: @escaping () -> Void = {}) {
        self.project = project
        self.exitTitle = exitTitle
        self.onCompleted = onCompleted
        _position = State(initialValue: project.currentInstruction)
        _showSections = State(initialValue: showSectionsInitially)
        _hasCompletedProject = State(initialValue: project.status == "completed")
    }
    var steps: [ReaderStep] { instructions.readerSteps }
    var currentStepIndex: Int { steps.firstIndex { position >= $0.firstPosition && position <= $0.lastPosition } ?? 0 }
    var currentStep: ReaderStep? { steps.indices.contains(currentStepIndex) ? steps[currentStepIndex] : nil }
    var current: Instruction? { currentStep?.instruction }
    var isAtLastStep: Bool { !steps.isEmpty && currentStepIndex == steps.count - 1 }
    private var isGuestDemo: Bool { (auth.isGuest || auth.token == "demo") && DemoData.isDemoProject(project.id) }
    var body: some View {
        ZStack {
            LinearGradient(colors: [.cream.opacity(0.65), .white], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 0) {
                readerHeader.padding()
                ProgressView(value: Double(currentStepIndex + 1), total: Double(max(steps.count, 1))).tint(.brandOrange).padding(.horizontal).accessibilityHidden(true)
                if isGuestDemo {
                    DemoProjectCallout(compact: true)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .accessibilityIdentifier("guest-local-progress")
                }
                if isLoading {
                    LoadingStateView(title: "Opening your project", message: "Loading pattern sections, your current step, and saved notes.")
                } else { ScrollView {
                    LazyVStack(spacing: 18) {
                        Text(current?.sourceLabel ?? "Step \(position)").font(.title3.weight(.semibold)).foregroundStyle(Color.brandPink)
                        Button { showStepPhotos = true } label: {
                            Label(stepPhotos.isEmpty ? "Add a private step photo" : "Step photos (\(stepPhotos.count))", systemImage: "camera.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.ink)
                        .controlSize(.large)
                        .accessibilityIdentifier("reader-step-photos")
                        if let notes = current?.notes {
                            Text(notes)
                                .font(.body)
                                .foregroundStyle(Color.ink)
                                .padding()
                                .background(Color.cream, in: .rect(cornerRadius: 16))
                        }
                        GlossaryInstructionText(text: current?.instructions ?? "Loading your next step…") { selectedGlossaryTerm = $0 }
                            .font(.system(.title, design: .rounded, weight: .semibold))
                            .foregroundStyle(Color.ink)
                            .multilineTextAlignment(.center)
                            .lineSpacing(8)
                            .padding(20)
                            .background(Color.white, in: .rect(cornerRadius: 20))
                        if let repeatCount = currentStep?.repeatCount {
                            HStack(spacing: 8) {
                                Image(systemName: "repeat").accessibilityHidden(true)
                                Text("×\(repeatCount) repeats").accessibilityHidden(true)
                            }
                                .font(.system(size: repeatBadgeFontSize, weight: .bold))
                                .foregroundStyle(Color.ink)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 12)
                                .background(Color.brandOrange.opacity(0.2), in: .capsule)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("Repeat \(repeatCount) times")
                                .accessibilityIdentifier("reader-repeat-count")
                        }
                        if let stitchCount = current?.stitchCount { Label("\(stitchCount) stitches", systemImage: "number").font(.headline).foregroundStyle(Color.ink) }
                    }.frame(maxWidth: .infinity).padding(28)
                }.defaultScrollAnchor(isGuestDemo ? .top : .center) }
                readerControls.padding()
            }
        }.navigationTitle(project.name).navigationBarTitleDisplayMode(.inline).navigationBarBackButtonHidden(true).toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { exitReader() } label: { Label(exitTitle, systemImage: "chevron.left") }
                    .accessibilityLabel(isSavingProgress ? "Saving your place, then return to \(exitTitle)" : "Return to \(exitTitle)")
                    .accessibilityIdentifier("reader-exit")
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Sections", systemImage: "list.bullet.rectangle") { showSections = true }
                        .accessibilityIdentifier("reader-sections")
                    Button("View original PDF", systemImage: "doc.richtext") { showOriginal = true }
                        .accessibilityIdentifier("reader-original-pdf")
                    Button("Add note", systemImage: "square.and.pencil") {
                        if auth.isGuest {
                            auth.requireAuthentication(title: "Create an account to add notes", message: "Notes are private and stay attached to your saved project step.")
                        } else { showNotes = true }
                    }
                } label: {
                    Label("Reader actions", systemImage: "ellipsis.circle")
                }
                .disabled(isLoading)
                .accessibilityIdentifier("reader-actions")
            }
        }.toolbar(.hidden, for: .tabBar)
            .fullScreenCover(isPresented: $showSections) { sectionNavigator }
            .sheet(isPresented: $showOriginal) { OriginalPDFView(patternID: project.patternId, title: project.patternName ?? "Original pattern") }
            .sheet(isPresented: $showCompletion) { completionView }
            .sheet(item: $selectedGlossaryTerm) { GlossaryTermSheet(term: $0) }
            .sheet(isPresented: $showStepPhotos) { stepPhotoJournalSheet }
            .sheet(isPresented: $showNotes) { NavigationStack { Form { TextEditor(text: $note).frame(minHeight: 160); if isSavingNote { Section { LoadingBanner(message: "Saving this note to step \(position)…").frame(maxWidth: .infinity) } } }.navigationTitle("Step note").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showNotes = false }.disabled(isSavingNote) }; ToolbarItem(placement: .confirmationAction) { Button { Task { await saveNote() } } label: { if isSavingNote { ProgressView().accessibilityLabel("Saving note") } else { Text("Save") } }.disabled(isSavingNote || note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } } } }
            .task { await loadReader() }
            .task(id: position) { loadStepPhotos() }
            .onChange(of: isSavingProgress) { _, saving in
                if !saving && shouldExitAfterSave {
                    shouldExitAfterSave = false
                    dismiss()
                }
            }
            .overlay(alignment: .top) {
                if isCompletingProject { LoadingBanner(message: "Finishing your project and marking it complete…").padding(.top, 8) }
                else if isSavingProgress { LoadingBanner(message: "Saving your place at step \(position)…").padding(.top, 8) }
            }
            .alert("Couldn’t update your project", isPresented: .init(get: { readerError != nil }, set: { if !$0 { readerError = nil } })) { Button("OK") {} } message: { Text(readerError ?? "") }
    }
    private var stepPhotoJournalSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Label("Private · only on this device", systemImage: "lock.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.ink)
                    Text("Capture what step \(position) looks like when it is done, so you can compare your work when you return.")
                        .foregroundStyle(Color.ink)
                    Button { presentedPhotoSource = .camera } label: {
                        Label(isSavingPhoto ? "Saving photo…" : "Take photo", systemImage: "camera")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.brandPink)
                    .controlSize(.large)
                    .disabled(isSavingPhoto)
                    .accessibilityIdentifier("reader-photo-camera")
                    Button { presentedPhotoSource = .photoLibrary } label: {
                        Label("Choose from library", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.ink)
                    .controlSize(.large)
                    .disabled(isSavingPhoto)
                    .accessibilityIdentifier("reader-photo-library")
                    if stepPhotos.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundStyle(Color.ink)
                                .accessibilityHidden(true)
                            Text("No photos for this step")
                                .font(.headline)
                                .foregroundStyle(Color.ink)
                            Text("Your first photo will appear here.")
                                .font(.subheadline)
                                .foregroundStyle(Color.ink)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 14) {
                            ForEach(stepPhotos) { photo in
                                Button { selectedPhoto = photo } label: { ProjectPhotoThumbnail(photo: photo) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(24)
            }
            .navigationTitle("Step \(position) photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { showStepPhotos = false } label: { Image(systemName: "xmark") }
                        .tint(.ink)
                        .accessibilityLabel("Close step photos")
                }
            }
            .fullScreenCover(item: $presentedPhotoSource) { source in
                if ProcessInfo.processInfo.arguments.contains("-mockPhotoPickerForUITests") {
                    ProjectPhotoPickerTestView(source: source)
                } else {
                    ProjectPhotoPicker(source: source, onImage: savePhoto)
                }
            }
            .sheet(item: $selectedPhoto) { photo in ProjectPhotoDetailSheet(photo: photo, isDeleting: isDeletingPhoto) { deletePhoto(photo) } }
        }
    }
    @ViewBuilder private var readerHeader: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    readerArtwork
                    Spacer()
                    readerStepBadge
                }
                sectionSwitcher
            }
        } else {
            HStack(spacing: 12) {
                readerArtwork
                sectionSwitcher
                Spacer(minLength: 0)
                readerStepBadge
            }
        }
    }
    private var readerArtwork: some View {
        AuthenticatedCoverImage(path: project.coverUrl, fallbackAsset: "ProjectFallback")
            .frame(width: 46, height: 46)
    }
    private var sectionSwitcher: some View {
        Button { showSections = true } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("SECTION")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.ink)
                    Text(current?.section ?? project.patternName ?? "Pattern")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.ink)
                        .lineLimit(2)
                }
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.brandOrange)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white, in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(isLoading || instructions.patternSections.isEmpty)
        .accessibilityLabel("Current section, \(current?.section ?? project.patternName ?? "Pattern")")
        .accessibilityHint("Shows all pattern sections")
        .accessibilityIdentifier("reader-section-switcher")
    }
    private var readerStepBadge: some View {
        Text("Step \(currentStepIndex + 1) of \(max(steps.count, 1))")
            .font(.subheadline.bold())
            .monospacedDigit()
            .foregroundStyle(.black)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white, in: .capsule)
    }
    @ViewBuilder private var readerControls: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 12) { readerButtons }
        } else {
            HStack(spacing: 18) { readerButtons }
        }
    }
    @ViewBuilder private var readerButtons: some View {
        if currentStepIndex > 0 {
            Button { move(-1) } label: {
                Label("Previous", systemImage: "chevron.left")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).tint(.ink).controlSize(.large)
            .disabled(isLoading || isSavingProgress || isCompletingProject)
        }
        Button { advance() } label: {
            Label(isAtLastStep ? (hasCompletedProject ? "Done" : "Finish project") : "Next", systemImage: isAtLastStep ? "checkmark.circle.fill" : "chevron.right")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent).tint(isAtLastStep ? .brandPink : .ink).controlSize(.large)
        .disabled(isLoading || isSavingProgress || isCompletingProject || steps.isEmpty)
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
                            Text("Steps \(section.firstPosition)–\(section.lastPosition) · \(section.instructions.readerSteps.count) reader steps").font(.subheadline).foregroundStyle(Color.ink)
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
    private func move(_ delta: Int) {
        let destination = min(max(currentStepIndex + delta, 0), max(steps.count - 1, 0))
        guard steps.indices.contains(destination) else { return }
        position = steps[destination].firstPosition
        Task { await persistProgress() }
    }
    private func advance() {
        guard isAtLastStep else { move(1); return }
        if hasCompletedProject { showCompletion = true }
        else { Task { await completeProject() } }
    }
    private func loadReader() async {
        Telemetry.shared.track("reader_opened")
        if auth.isGuest || auth.token == "demo" {
            isLoading = true; defer { isLoading = false }
            if ProcessInfo.processInfo.arguments.contains("-simulateSlowLoading") { try? await Task.sleep(for: .seconds(4)) }
            if ProcessInfo.processInfo.arguments.contains("-readerRepeatDemo") { instructions = DemoData.repeatInstructions; position = DemoData.repeatProject.currentInstruction; return }
            instructions = DemoData.instructions(for: project.patternId)
            let savedPosition = UserDefaults.standard.integer(forKey: DemoData.readerPositionKey(for: project.id))
            position = instructions.contains(where: { $0.position == savedPosition }) ? savedPosition : project.currentInstruction
            return
        }
        guard let userID = auth.user?.id else { return }
        let cached = await AppDataCache.shared.cachedProjectDetail(for: userID, projectID: project.id)
        if instructions.isEmpty, let cached { instructions = cached.value.instructions }
        if let cached, cached.isFresh() { isLoading = false; return }
        isLoading = instructions.isEmpty
        defer { isLoading = false }
        do { instructions = try await AppDataCache.shared.refreshProjectDetail(for: userID, projectID: project.id, client: auth.client).instructions }
        catch { if instructions.isEmpty { readerError = error.localizedDescription } }
    }
    private func persistProgress() async {
        guard !auth.isGuest else {
            UserDefaults.standard.set(position, forKey: DemoData.readerPositionKey(for: project.id))
            return
        }
        if auth.token == "demo" { UserDefaults.standard.set(position, forKey: DemoData.readerPositionKey(for: project.id)); return }
        isSavingProgress = true; defer { isSavingProgress = false }
        struct Body: Encodable { let currentInstruction: Int }
        do {
            let _: EmptyResponse = try await auth.client.request("/api/projects/\(project.id)", method: "PATCH", body: Body(currentInstruction: position))
            if let userID = auth.user?.id { await AppDataCache.shared.invalidateProject(for: userID, projectID: project.id) }
            Telemetry.shared.track("reader_progressed")
        } catch { readerError = error.localizedDescription }
    }
    private func loadStepPhotos() {
        do { stepPhotos = try ProjectPhotoJournal.load(projectID: project.id, instructionPosition: position) }
        catch { readerError = "Private step photos could not load." }
    }
    private func savePhoto(_ image: UIImage) {
        guard !isSavingPhoto, let data = image.jpegData(compressionQuality: 0.82) else { return }
        isSavingPhoto = true
        Task { @MainActor in
            defer { isSavingPhoto = false }
            do {
                _ = try ProjectPhotoJournal.save(data, projectID: project.id, instructionPosition: position, section: current?.section ?? "Pattern")
                loadStepPhotos()
            } catch { readerError = "This photo could not be saved on your device." }
        }
    }
    private func deletePhoto(_ photo: ProjectStepPhoto) {
        guard !isDeletingPhoto else { return }
        isDeletingPhoto = true
        Task { @MainActor in
            defer { isDeletingPhoto = false }
            do { try ProjectPhotoJournal.delete(photo); selectedPhoto = nil; loadStepPhotos() }
            catch { readerError = "This photo could not be deleted." }
        }
    }
    private func completeProject() async {
        guard !isCompletingProject, isAtLastStep, !hasCompletedProject else { return }
        guard !auth.isGuest else {
            auth.requireAuthentication(title: "Create an account to complete projects", message: "Sign in to save completion, progress, and notes to your maker space.")
            return
        }
        isCompletingProject = true
        defer { isCompletingProject = false }
        if let lastPosition = currentStep?.lastPosition { position = lastPosition }
        if auth.token != "demo" {
            struct Body: Encodable { let currentInstruction: Int; let status = "completed" }
            do {
                let _: EmptyResponse = try await auth.client.request("/api/projects/\(project.id)", method: "PATCH", body: Body(currentInstruction: position))
                if let userID = auth.user?.id { await AppDataCache.shared.invalidateProject(for: userID, projectID: project.id) }
            } catch {
                readerError = error.localizedDescription
                return
            }
        } else {
            UserDefaults.standard.set(position, forKey: DemoData.readerPositionKey(for: project.id))
        }
        hasCompletedProject = true
        Telemetry.shared.track("project_completed_in_reader")
        onCompleted()
        showCompletion = true
    }
    private func saveNote() async {
        guard !auth.isGuest else {
            showNotes = false
            auth.requireAuthentication(title: "Create an account to add notes", message: "Notes are private and stay attached to your saved project step.")
            return
        }
        guard auth.token != "demo" else { note = ""; showNotes = false; return }
        isSavingNote = true; defer { isSavingNote = false }
        struct Body: Encodable { let instructionPosition: Int; let body: String }
        do {
            let _: EmptyResponse = try await auth.client.request("/api/projects/\(project.id)/notes", method: "POST", body: Body(instructionPosition: position, body: note))
            if let userID = auth.user?.id { await AppDataCache.shared.invalidateProject(for: userID, projectID: project.id) }
            note = ""; showNotes = false
        } catch { readerError = error.localizedDescription }
    }

    private var completionView: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    ZStack(alignment: .bottomTrailing) {
                        AuthenticatedCoverImage(path: project.coverUrl, fallbackAsset: "ProjectFallback")
                            .frame(width: 150, height: 150)
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.brandPink)
                            .background(Color(.systemBackground), in: .circle)
                            .accessibilityHidden(true)
                    }
                    Text("You finished \(project.name)!")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.ink)
                    Text("Congratulations — your project is marked complete and stays available with its instructions and notes.")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Button {
                        showCompletion = false
                        dismiss()
                    } label: {
                        Label("Done", systemImage: "checkmark").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.ink)
                    .controlSize(.large)
                    .accessibilityIdentifier("completion-done")
                }
                .padding(28)
            }
            .navigationTitle("Project complete")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled()
    }
}

private struct DemoProjectCallout: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var compact = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.brandPink)
                .frame(width: 28, height: 28)
                .background(Color.white, in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(compact ? "Demo project" : "You’re exploring a demo project")
                    .font((compact ? Font.caption : .headline).weight(.bold))
                    .foregroundStyle(Color.white)
                    .fixedSize(horizontal: false, vertical: true)
                if !compact || !dynamicTypeSize.isAccessibilitySize {
                    Text(compact ? "Try every step · saved only on this device" : "Tap through every step to experience the reader. Your place is saved only on this device.")
                        .font(.caption)
                        .foregroundStyle(Color.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(compact ? 10 : 14)
        .background(Color.ink, in: .rect(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(compact ? "Demo project. Try every step. Progress is saved only on this device." : "You’re exploring a demo project. Tap through every step to experience the reader. Your place is saved only on this device.")
    }
}

struct CreateProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @EnvironmentObject private var auth: AuthManager
    let onCreated: (Project?) -> Void
    let initialPattern: Pattern?
    @State private var patterns: [Pattern] = []; @State private var selected = ""; @State private var name = ""; @State private var yarn = ""; @State private var notes = ""; @State private var isLoadingPatterns = true; @State private var isCreating = false; @State private var error: String?
    init(initialPattern: Pattern? = nil, onCreated: @escaping (Project?) -> Void) { self.initialPattern = initialPattern; self.onCreated = onCreated; _selected = State(initialValue: initialPattern?.id ?? ""); _name = State(initialValue: initialPattern.map { "\($0.name) project" } ?? "") }
    private var selectedPattern: Pattern? { patterns.first(where: { $0.id == selected }) ?? initialPattern }
    var body: some View {
        NavigationStack {
            Form {
                Section("Pattern") {
                    if isLoadingPatterns {
                        LoadingBanner(message: "Loading patterns from your library…").frame(maxWidth: .infinity)
                    } else {
                        Picker("Pattern", selection: $selected) {
                            Text("Choose a pattern").tag("")
                            ForEach(patterns) { Text($0.name).tag($0.id) }
                        }
                        if let pattern = selectedPattern {
                            HStack(spacing: 14) {
                                AuthenticatedCoverImage(path: pattern.coverUrl, fallbackAsset: "PatternFallback")
                                    .frame(width: 78, height: 78)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(pattern.name).font(.headline)
                                    Text([pattern.designer, pattern.craft.capitalized].compactMap { $0 }.joined(separator: " · "))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                Section("Project") {
                    TextField("Project name", text: $name)
                    TextField("Yarn", text: $yarn)
                    TextField("Notes", text: $notes, axis: .vertical)
                }
                if isCreating { Section { LoadingBanner(message: "Creating your project and preparing its first step…").frame(maxWidth: .infinity) } }
            }
            .disabled(isCreating)
            .navigationTitle("New project")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(isCreating) }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { await create() } } label: {
                        if isCreating { ProgressView().accessibilityLabel("Creating project") } else { Text("Create") }
                    }
                    .disabled(isLoadingPatterns || isCreating || selected.isEmpty || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .task { await loadPatterns() }
            .alert("Couldn’t create project", isPresented: .init(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") {} } message: { Text(error ?? "") }
        }
    }
    private func loadPatterns() async {
        if auth.isGuest || auth.token == "demo" {
            isLoadingPatterns = true; defer { isLoadingPatterns = false }
            if ProcessInfo.processInfo.arguments.contains("-simulateSlowLoading") { try? await Task.sleep(for: .seconds(4)) }
            patterns = DemoData.patterns; selected = initialPattern?.id ?? DemoData.pattern.id
            return
        }
        guard let userID = auth.user?.id else { return }
        let cached = await AppDataCache.shared.cachedPatterns(for: userID)
        if let cached {
            patterns = cached.value
            selected = initialPattern.flatMap { initial in patterns.first(where: { $0.id == initial.id })?.id } ?? patterns.first?.id ?? ""
        }
        if let cached, cached.isFresh() { isLoadingPatterns = false; return }
        isLoadingPatterns = cached == nil
        defer { isLoadingPatterns = false }
        do {
            patterns = try await AppDataCache.shared.refreshPatterns(for: userID, client: auth.client)
            selected = initialPattern.flatMap { initial in patterns.first(where: { $0.id == initial.id })?.id } ?? patterns.first?.id ?? ""
        } catch { if cached == nil { self.error = error.localizedDescription } }
    }
    private func create() async {
        guard !isCreating else { return }
        isCreating = true
        defer { isCreating = false }
        var shouldRequestReview = false
        var createdProject: Project? = auth.token == "demo" ? DemoData.project : nil
        if auth.token != "demo" {
            struct Body: Encodable { let patternId: String; let name: String; let yarn: String; let notes: String }
            do {
                let response: ProjectCreationResponse = try await auth.client.request("/api/projects", method: "POST", body: Body(patternId: selected, name: name, yarn: yarn, notes: notes))
                createdProject = response.project
                if let userID = auth.user?.id { await AppDataCache.shared.invalidateProject(for: userID, projectID: response.project.id) }
                shouldRequestReview = ReviewPromptPolicy().claimRequest(isFirstProject: response.isFirstProject)
                Telemetry.shared.track("project_created")
            } catch {
                self.error = error.localizedDescription
                return
            }
        }
        dismiss()
        onCreated(createdProject)
        if shouldRequestReview {
            try? await Task.sleep(for: .seconds(1))
            requestReview()
        }
    }
}

struct ProjectCreatedView: View {
    @Environment(\.dismiss) private var dismiss
    let project: Project
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    AuthenticatedCoverImage(path: project.coverUrl, fallbackAsset: "ProjectFallback")
                        .frame(width: 180, height: 180)
                    Label("Project ready", systemImage: "checkmark.seal.fill")
                        .font(.title.bold())
                        .foregroundStyle(Color.ink)
                    Text("\(project.name) is ready at your first saved step.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    NavigationLink { ReaderView(project: project, exitTitle: "Next step") } label: { Label("Start making", systemImage: "play.fill") }
                        .buttonStyle(.borderedProminent).tint(.ink).controlSize(.large)
                        .accessibilityIdentifier("created-start-making")
                    NavigationLink { ProjectOverviewView(project: project) {} } label: { Label("View project overview", systemImage: "square.stack.3d.up") }
                        .buttonStyle(.bordered).tint(.ink).controlSize(.large)
                }
                .padding(28)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Next step")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
    }
}
