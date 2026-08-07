import CryptoKit
import Foundation
import Network
import SwiftUI

struct OfflineMutation: Codable, Identifiable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case projectProgress
        case projectCompletion
        case projectNote
    }

    let id: UUID
    let kind: Kind
    let projectID: String
    let currentInstruction: Int?
    let instructionPosition: Int?
    let noteBody: String?
    let createdAt: Date
}

actor OfflineMutationStore {
    static let shared = OfflineMutationStore()
    private static let schemaVersion = 1

    private struct QueueFile: Codable {
        let schemaVersion: Int
        let userID: String
        var mutations: [OfflineMutation]
    }

    private let storageDirectory: URL
    private var queues: [String: [OfflineMutation]] = [:]
    private var loadedUsers: Set<String> = []

    init(storageDirectory: URL? = nil) {
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.storageDirectory = storageDirectory ?? applicationSupport.appending(path: "StitchlyPendingSync", directoryHint: .isDirectory)
    }

    @discardableResult
    func enqueueProgress(userID: String, projectID: String, currentInstruction: Int, at date: Date = Date()) throws -> OfflineMutation? {
        ensureLoaded(userID)
        if queues[userID, default: []].contains(where: { $0.projectID == projectID && $0.kind == .projectCompletion }) {
            return nil
        }
        queues[userID, default: []].removeAll { $0.projectID == projectID && $0.kind == .projectProgress }
        let mutation = OfflineMutation(id: UUID(), kind: .projectProgress, projectID: projectID, currentInstruction: currentInstruction, instructionPosition: nil, noteBody: nil, createdAt: date)
        queues[userID, default: []].append(mutation)
        try persist(userID)
        return mutation
    }

    @discardableResult
    func enqueueCompletion(userID: String, projectID: String, currentInstruction: Int?, at date: Date = Date()) throws -> OfflineMutation {
        ensureLoaded(userID)
        queues[userID, default: []].removeAll {
            $0.projectID == projectID && ($0.kind == .projectProgress || $0.kind == .projectCompletion)
        }
        let mutation = OfflineMutation(id: UUID(), kind: .projectCompletion, projectID: projectID, currentInstruction: currentInstruction, instructionPosition: nil, noteBody: nil, createdAt: date)
        queues[userID, default: []].append(mutation)
        try persist(userID)
        return mutation
    }

    @discardableResult
    func enqueueNote(userID: String, projectID: String, instructionPosition: Int, body: String, at date: Date = Date()) throws -> OfflineMutation {
        ensureLoaded(userID)
        let mutation = OfflineMutation(id: UUID(), kind: .projectNote, projectID: projectID, currentInstruction: nil, instructionPosition: instructionPosition, noteBody: body, createdAt: date)
        queues[userID, default: []].append(mutation)
        try persist(userID)
        return mutation
    }

    func pending(for userID: String) -> [OfflineMutation] {
        ensureLoaded(userID)
        return queues[userID, default: []]
    }

    func remove(_ mutationID: UUID, for userID: String) throws {
        ensureLoaded(userID)
        queues[userID, default: []].removeAll { $0.id == mutationID }
        try persist(userID)
    }

    func clear(for userID: String) {
        queues.removeValue(forKey: userID)
        loadedUsers.remove(userID)
        try? FileManager.default.removeItem(at: queueURL(for: userID))
    }

    private func ensureLoaded(_ userID: String) {
        guard !loadedUsers.contains(userID) else { return }
        loadedUsers.insert(userID)
        guard let data = try? Data(contentsOf: queueURL(for: userID)),
              let file = try? JSONDecoder.offlineSync.decode(QueueFile.self, from: data),
              file.schemaVersion == Self.schemaVersion,
              file.userID == userID else {
            queues[userID] = []
            return
        }
        queues[userID] = file.mutations
    }

    private func persist(_ userID: String) throws {
        try FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var directory = storageDirectory
        try? directory.setResourceValues(values)
        let file = QueueFile(schemaVersion: Self.schemaVersion, userID: userID, mutations: queues[userID, default: []])
        let data = try JSONEncoder.offlineSync.encode(file)
        let url = queueURL(for: userID)
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: url.path)
    }

    private func queueURL(for userID: String) -> URL {
        let digest = SHA256.hash(data: Data(userID.utf8)).prefix(12).map { String(format: "%02x", $0) }.joined()
        return storageDirectory.appending(path: "account-\(digest).json")
    }
}

@MainActor final class ConnectivityObserver: ObservableObject, @unchecked Sendable {
    @Published private(set) var isOnline = true
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "app.stitchly.connectivity")

    init() {
        if ProcessInfo.processInfo.arguments.contains("-simulateOfflineForUITests") {
            isOnline = false
            return
        }
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in self?.isOnline = path.status == .satisfied }
        }
        monitor.start(queue: queue)
    }

    deinit { monitor.cancel() }
}

@MainActor final class OfflineSyncCoordinator: ObservableObject {
    @Published private(set) var pendingCount = 0
    @Published private(set) var isSyncing = false
    @Published private(set) var lastError: String?

    private let store: OfflineMutationStore
    private let cache: AppDataCache
    private var userID: String?
    private var client: APIClient?

    init(store: OfflineMutationStore = .shared, cache: AppDataCache = .shared) {
        self.store = store
        self.cache = cache
    }

    func activate(userID: String?, client: APIClient) async {
        self.userID = userID
        self.client = userID == nil ? nil : client
        guard let userID else { pendingCount = 0; lastError = nil; return }
        pendingCount = await store.pending(for: userID).count
        await syncNow()
    }

    func queueProgress(projectID: String, currentInstruction: Int) async throws {
        guard let userID else { return }
        let date = Date()
        _ = try await store.enqueueProgress(userID: userID, projectID: projectID, currentInstruction: currentInstruction, at: date)
        await cache.applyProjectChange(for: userID, projectID: projectID, currentInstruction: currentInstruction, at: date)
        pendingCount = await store.pending(for: userID).count
        Task { await syncNow() }
    }

    func queueCompletion(projectID: String, currentInstruction: Int? = nil) async throws {
        guard let userID else { return }
        let date = Date()
        _ = try await store.enqueueCompletion(userID: userID, projectID: projectID, currentInstruction: currentInstruction, at: date)
        await cache.applyProjectChange(for: userID, projectID: projectID, currentInstruction: currentInstruction, status: "completed", at: date)
        pendingCount = await store.pending(for: userID).count
        Task { await syncNow() }
    }

    func queueNote(projectID: String, instructionPosition: Int, body: String) async throws {
        guard let userID else { return }
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let mutation = try await store.enqueueNote(userID: userID, projectID: projectID, instructionPosition: instructionPosition, body: trimmedBody)
        let note = ProjectNote(id: mutation.id.uuidString, instructionPosition: instructionPosition, body: trimmedBody, createdAt: mutation.createdAt)
        await cache.applyProjectNote(for: userID, projectID: projectID, note: note, at: mutation.createdAt)
        pendingCount = await store.pending(for: userID).count
        Task { await syncNow() }
    }

    func syncNow() async {
        guard !isSyncing, let userID, let client else { return }
        let initial = await store.pending(for: userID)
        pendingCount = initial.count
        guard !initial.isEmpty else { lastError = nil; return }
        isSyncing = true
        lastError = nil
        var touchedProjects = Set<String>()

        while let mutation = await store.pending(for: userID).first {
            do {
                try await send(mutation, client: client)
                try await store.remove(mutation.id, for: userID)
                touchedProjects.insert(mutation.projectID)
                pendingCount = await store.pending(for: userID).count
            } catch {
                lastError = error.localizedDescription
                pendingCount = await store.pending(for: userID).count
                isSyncing = false
                return
            }
        }

        if await store.pending(for: userID).isEmpty {
            _ = try? await cache.refreshProjects(for: userID, client: client)
            for projectID in touchedProjects {
                _ = try? await cache.refreshProjectDetail(for: userID, projectID: projectID, client: client)
            }
        }
        isSyncing = false
        pendingCount = await store.pending(for: userID).count
        if pendingCount > 0 { await syncNow() }
    }

    func clear(userID: String) async {
        await store.clear(for: userID)
        if self.userID == userID {
            self.userID = nil
            client = nil
            pendingCount = 0
            lastError = nil
        }
    }

    private func send(_ mutation: OfflineMutation, client: APIClient) async throws {
        switch mutation.kind {
        case .projectProgress:
            struct Body: Encodable { let currentInstruction: Int }
            guard let position = mutation.currentInstruction else { return }
            let _: EmptyResponse = try await client.request("/api/projects/\(mutation.projectID)", method: "PATCH", body: Body(currentInstruction: position))
        case .projectCompletion:
            struct Body: Encodable { let currentInstruction: Int?; let status = "completed" }
            let _: EmptyResponse = try await client.request("/api/projects/\(mutation.projectID)", method: "PATCH", body: Body(currentInstruction: mutation.currentInstruction))
        case .projectNote:
            struct Body: Encodable { let instructionPosition: Int; let body: String; let clientMutationId: String }
            guard let position = mutation.instructionPosition, let body = mutation.noteBody else { return }
            let payload = Body(instructionPosition: position, body: body, clientMutationId: mutation.id.uuidString)
            let _: EmptyResponse = try await client.request("/api/projects/\(mutation.projectID)/notes", method: "POST", body: payload)
        }
    }
}

struct SyncStatusBanner: View {
    @EnvironmentObject private var sync: OfflineSyncCoordinator
    @EnvironmentObject private var connectivity: ConnectivityObserver

    var body: some View {
        if sync.isSyncing {
            status(icon: nil, message: "Syncing \(sync.pendingCount) saved \(sync.pendingCount == 1 ? "change" : "changes")…", showsRetry: false)
        } else if !connectivity.isOnline {
            status(icon: "wifi.slash", message: sync.pendingCount == 0 ? "Offline · saved projects are available" : "Offline · \(sync.pendingCount) \(sync.pendingCount == 1 ? "change" : "changes") saved on this iPhone", showsRetry: false)
        } else if sync.pendingCount > 0 {
            status(icon: "arrow.triangle.2.circlepath", message: "\(sync.pendingCount) saved \(sync.pendingCount == 1 ? "change is" : "changes are") waiting to sync", showsRetry: true)
        }
    }

    private func status(icon: String?, message: String, showsRetry: Bool) -> some View {
        HStack(spacing: 10) {
            if sync.isSyncing { ProgressView().controlSize(.small).accessibilityHidden(true) }
            else if let icon { Image(systemName: icon).accessibilityHidden(true) }
            Text(message)
                .font(.footnote.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            if showsRetry {
                Button("Retry") { Task { await sync.syncNow() } }
                    .font(.footnote.bold())
                    .disabled(sync.isSyncing)
            }
        }
        .foregroundStyle(Color.ink)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(Color.ink.opacity(0.12)) }
        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
        .padding(.horizontal, 12)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("offline-sync-status")
    }
}

private extension JSONEncoder {
    static var offlineSync: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var offlineSync: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
