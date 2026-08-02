import SwiftUI

@MainActor final class ProjectsStore: ObservableObject {
    @Published var projects: [Project] = []; @Published var loading = false; @Published var error: String?
    func load(client: APIClient) async { if client.token == "demo" { projects = [DemoData.project]; return }; loading = true; defer { loading = false }; do { let response: ProjectListResponse = try await client.request("/api/projects"); projects = response.projects } catch { self.error = error.localizedDescription } }
}

struct ProjectsView: View {
    @EnvironmentObject private var auth: AuthManager
    @StateObject private var store = ProjectsStore()
    @State private var createProject = false
    var body: some View {
        NavigationStack {
            Group {
                if store.loading && store.projects.isEmpty { ProgressView("Loading projects…") }
                else if store.projects.isEmpty { EmptyState(icon: "square.stack.3d.up", title: "Start your first project", message: "Choose a pattern, add your yarn, and always return to the right step.") }
                else { List(store.projects) { project in NavigationLink(value: project) { ProjectRow(project: project) } }.listStyle(.insetGrouped) }
            }.navigationTitle("Projects")
                .toolbar { ToolbarItem(placement: .primaryAction) { Button("New project", systemImage: "plus") { createProject = true } } }
                .navigationDestination(for: Project.self) { ReaderView(project: $0) }
                .sheet(isPresented: $createProject) { CreateProjectView { Task { await store.load(client: auth.client) } } }
                .task { await store.load(client: auth.client) }.refreshable { await store.load(client: auth.client) }
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
    init(project: Project) { self.project = project; _position = State(initialValue: project.currentInstruction) }
    var current: Instruction? { instructions.first { $0.position == position } ?? instructions.first }
    var body: some View {
        ZStack {
            LinearGradient(colors: [.cream.opacity(0.65), .white], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 0) {
                HStack { Text(current?.section ?? project.patternName ?? "Pattern").font(.subheadline.weight(.semibold)).foregroundStyle(Color.ink); Spacer(); Text("\(position) / \(max(instructions.count, project.totalInstructions ?? 1))").monospacedDigit().foregroundStyle(Color.ink) }.padding()
                ProgressView(value: Double(position), total: Double(max(instructions.count, project.totalInstructions ?? 1))).tint(.brandOrange).padding(.horizontal).accessibilityHidden(true)
                ScrollView {
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
                }.defaultScrollAnchor(.center)
                HStack(spacing: 18) {
                    Button { move(-1) } label: { Label("Previous", systemImage: "chevron.left").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).tint(.ink).controlSize(.large).disabled(position <= 1)
                    Button { move(1) } label: { Label("Next", systemImage: "chevron.right").labelStyle(.titleAndIcon).frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).tint(.ink).controlSize(.large).disabled(position >= max(instructions.count, project.totalInstructions ?? 1))
                }.padding()
            }
        }.navigationTitle(project.name).navigationBarTitleDisplayMode(.inline).toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Sections", systemImage: "list.bullet.rectangle") { showSections = true }
                    .accessibilityIdentifier("reader-sections")
                Button("Note", systemImage: "square.and.pencil") { showNotes = true }
            }
        }.toolbar(.hidden, for: .tabBar)
            .sheet(isPresented: $showSections) { sectionNavigator }
            .sheet(isPresented: $showNotes) { NavigationStack { Form { TextEditor(text: $note).frame(minHeight: 160) }.navigationTitle("Step note").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showNotes = false } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await saveNote() } }.disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } } } }
            .task { Telemetry.shared.track("reader_opened"); if auth.token == "demo" { instructions = DemoData.instructions } else if let response: ProjectResponse = try? await auth.client.request("/api/projects/\(project.id)") { instructions = response.instructions } }
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
                            Text("Steps \(section.firstPosition)–\(section.lastPosition) · \(section.instructions.count) instructions").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                    }.padding(.vertical, 5)
                }
                .accessibilityLabel("\(section.title), steps \(section.firstPosition) to \(section.lastPosition)")
            }
            .navigationTitle("Pattern sections")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { showSections = false } } }
        }.presentationDetents([.medium, .large])
    }
    private func move(_ delta: Int) { position = min(max(position + delta, 1), max(instructions.count, project.totalInstructions ?? 1)); Task { await persistProgress() } }
    private func persistProgress() async { guard auth.token != "demo" else { return }; struct Body: Encodable { let currentInstruction: Int }; let _: EmptyResponse? = try? await auth.client.request("/api/projects/\(project.id)", method: "PATCH", body: Body(currentInstruction: position)); Telemetry.shared.track("reader_progressed") }
    private func saveNote() async { guard auth.token != "demo" else { note = ""; showNotes = false; return }; struct Body: Encodable { let instructionPosition: Int; let body: String }; let _: EmptyResponse? = try? await auth.client.request("/api/projects/\(project.id)/notes", method: "POST", body: Body(instructionPosition: position, body: note)); note = ""; showNotes = false }
}

struct CreateProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthManager
    let onCreated: () -> Void
    @State private var patterns: [Pattern] = []; @State private var selected = ""; @State private var name = ""; @State private var yarn = ""; @State private var notes = ""
    var body: some View { NavigationStack { Form { Section("Pattern") { Picker("Pattern", selection: $selected) { Text("Choose a pattern").tag(""); ForEach(patterns) { Text($0.name).tag($0.id) } } }; Section("Project") { TextField("Project name", text: $name); TextField("Yarn", text: $yarn); TextField("Notes", text: $notes, axis: .vertical) } }.navigationTitle("New project").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Create") { Task { await create() } }.disabled(selected.isEmpty || name.trimmingCharacters(in: .whitespaces).isEmpty) } }.task { if auth.token == "demo" { patterns = [DemoData.pattern]; selected = DemoData.pattern.id } else if let response: PatternListResponse = try? await auth.client.request("/api/patterns") { patterns = response.patterns; selected = response.patterns.first?.id ?? "" } } } }
    private func create() async { if auth.token != "demo" { struct Body: Encodable { let patternId: String; let name: String; let yarn: String; let notes: String }; let _: EmptyResponse? = try? await auth.client.request("/api/projects", method: "POST", body: Body(patternId: selected, name: name, yarn: yarn, notes: notes)); Telemetry.shared.track("project_created") }; dismiss(); onCreated() }
}
