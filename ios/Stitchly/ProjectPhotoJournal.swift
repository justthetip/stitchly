import Foundation
import SwiftUI
@preconcurrency import UIKit

struct ProjectStepPhoto: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let projectID: String
    let instructionPosition: Int
    let section: String
    let capturedAt: Date
    let filename: String
}

enum ProjectPhotoSource: String, Identifiable, CaseIterable, Sendable {
    case camera
    case photoLibrary

    var id: String { rawValue }
    var accessibilityName: String { self == .camera ? "camera" : "photo library" }

    @MainActor var uiKitSourceType: UIImagePickerController.SourceType {
        self == .camera ? .camera : .photoLibrary
    }
}

enum ProjectPhotoJournal {
    static func load(projectID: String, instructionPosition: Int, directory: URL? = nil) throws -> [ProjectStepPhoto] {
        try loadAll(projectID: projectID, directory: directory)
            .filter { $0.instructionPosition == instructionPosition }
            .sorted { $0.capturedAt > $1.capturedAt }
    }

    @discardableResult static func save(_ data: Data, projectID: String, instructionPosition: Int, section: String, directory: URL? = nil) throws -> ProjectStepPhoto {
        let folder = try projectDirectory(projectID, root: directory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let photo = ProjectStepPhoto(id: UUID(), projectID: projectID, instructionPosition: instructionPosition, section: section, capturedAt: Date(), filename: "\(UUID().uuidString).jpg")
        try data.write(to: folder.appending(path: photo.filename), options: .atomic)
        var metadata = try loadAll(projectID: projectID, directory: directory)
        metadata.append(photo)
        try JSONEncoder().encode(metadata).write(to: folder.appending(path: "journal.json"), options: .atomic)
        return photo
    }

    static func delete(_ photo: ProjectStepPhoto, directory: URL? = nil) throws {
        let folder = try projectDirectory(photo.projectID, root: directory)
        try? FileManager.default.removeItem(at: folder.appending(path: photo.filename))
        let metadata = try loadAll(projectID: photo.projectID, directory: directory).filter { $0.id != photo.id }
        try JSONEncoder().encode(metadata).write(to: folder.appending(path: "journal.json"), options: .atomic)
    }

    static func imageURL(for photo: ProjectStepPhoto, directory: URL? = nil) throws -> URL {
        try projectDirectory(photo.projectID, root: directory).appending(path: photo.filename)
    }

    private static func loadAll(projectID: String, directory: URL?) throws -> [ProjectStepPhoto] {
        let file = try projectDirectory(projectID, root: directory).appending(path: "journal.json")
        guard FileManager.default.fileExists(atPath: file.path) else { return [] }
        return try JSONDecoder().decode([ProjectStepPhoto].self, from: Data(contentsOf: file))
    }

    private static func projectDirectory(_ projectID: String, root: URL?) throws -> URL {
        let base = try root ?? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appending(path: "StitchlyPrivateJournal")
        let safeID = projectID.map { $0.isLetter || $0.isNumber || $0 == "-" ? $0 : "-" }
        return base.appending(path: String(safeID), directoryHint: .isDirectory)
    }
}

@MainActor struct ProjectPhotoPicker: UIViewControllerRepresentable {
    let source: ProjectPhotoSource
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        let requestedSource = source.uiKitSourceType
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(requestedSource) ? requestedSource : .photoLibrary
        picker.allowsEditing = false
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ProjectPhotoPicker
        init(parent: ProjectPhotoPicker) { self.parent = parent }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onImage(image) }
            parent.dismiss()
        }
    }
}

struct ProjectPhotoPickerTestView: View {
    @Environment(\.dismiss) private var dismiss
    let source: ProjectPhotoSource

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: source == .camera ? "camera.fill" : "photo.on.rectangle")
                    .font(.largeTitle)
                    .accessibilityHidden(true)
                Text("Mock \(source.accessibilityName) picker")
                    .accessibilityIdentifier("mock-photo-picker-\(source.rawValue)")
                Button("Cancel photo picker") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(24)
            .navigationTitle("Photo picker")
        }
    }
}

struct ProjectPhotoThumbnail: View {
    let photo: ProjectStepPhoto
    var body: some View {
        Group {
            if let url = try? ProjectPhotoJournal.imageURL(for: photo), let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image).resizable().scaledToFill()
            } else { Image(systemName: "photo").foregroundStyle(.secondary) }
        }
        .frame(width: 82, height: 82).background(Color.cream).clipShape(.rect(cornerRadius: 14)).clipped()
        .accessibilityLabel("Private project photo from \(photo.section), step \(photo.instructionPosition)")
    }
}

struct ProjectPhotoDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let photo: ProjectStepPhoto
    let isDeleting: Bool
    let delete: () -> Void
    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                if let url = try? ProjectPhotoJournal.imageURL(for: photo), let image = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: image).resizable().scaledToFit().clipShape(.rect(cornerRadius: 20))
                }
                Label("Private · only on this device", systemImage: "lock.fill").font(.subheadline).foregroundStyle(.secondary)
                Text("\(photo.section) · step \(photo.instructionPosition)").font(.headline)
                Text(photo.capturedAt, style: .date).font(.subheadline).foregroundStyle(.secondary)
                Button(role: .destructive, action: delete) { Label(isDeleting ? "Deleting photo…" : "Delete photo", systemImage: "trash").frame(maxWidth: .infinity) }
                    .buttonStyle(.bordered).disabled(isDeleting)
                Spacer()
            }.padding(24).navigationTitle("Step photo").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.disabled(isDeleting) } }
        }.presentationDetents([.large])
    }
}
