import CryptoKit
import Foundation

struct CacheEntry<Value: Codable & Sendable>: Codable, Sendable {
    let value: Value
    let updatedAt: Date

    func isFresh(at date: Date = Date(), maxAge: TimeInterval = AppDataCache.freshnessDuration) -> Bool {
        date.timeIntervalSince(updatedAt) < maxAge
    }
}

actor AppDataCache {
    static let shared = AppDataCache()
    static let freshnessDuration: TimeInterval = 120
    private static let schemaVersion = 1

    private struct UserSnapshot: Codable, Sendable {
        let schemaVersion: Int
        let userID: String
        var patterns: CacheEntry<[Pattern]>?
        var projects: CacheEntry<[Project]>?
        var patternDetails: [String: CacheEntry<PatternResponse>]
        var projectDetails: [String: CacheEntry<ProjectResponse>]

        init(userID: String) {
            schemaVersion = AppDataCache.schemaVersion
            self.userID = userID
            patterns = nil
            projects = nil
            patternDetails = [:]
            projectDetails = [:]
        }
    }

    private let storageDirectory: URL
    private var snapshots: [String: UserSnapshot] = [:]
    private var loadedUsers: Set<String> = []
    private var patternTasks: [String: Task<[Pattern], Error>] = [:]
    private var projectTasks: [String: Task<[Project], Error>] = [:]
    private var patternDetailTasks: [String: Task<PatternResponse, Error>] = [:]
    private var projectDetailTasks: [String: Task<ProjectResponse, Error>] = [:]
    private var imageTasks: [String: Task<Data, Error>] = [:]
    private var pdfTasks: [String: Task<Data, Error>] = [:]
    private var assetKeysByUser: [String: Set<String>] = [:]
    private let imageCache = NSCache<NSString, NSData>()
    private let pdfCache = NSCache<NSString, NSData>()

    init(storageDirectory: URL? = nil) {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.storageDirectory = storageDirectory ?? caches.appending(path: "StitchlyAccountCache", directoryHint: .isDirectory)
        imageCache.totalCostLimit = 24 * 1_024 * 1_024
        pdfCache.totalCostLimit = 32 * 1_024 * 1_024
    }

    func cachedPatterns(for userID: String) -> CacheEntry<[Pattern]>? {
        ensureLoaded(userID)
        return snapshots[userID]?.patterns
    }

    func cachedProjects(for userID: String) -> CacheEntry<[Project]>? {
        ensureLoaded(userID)
        return snapshots[userID]?.projects
    }

    func cachedPatternDetail(for userID: String, patternID: String) -> CacheEntry<PatternResponse>? {
        ensureLoaded(userID)
        return snapshots[userID]?.patternDetails[patternID]
    }

    func cachedProjectDetail(for userID: String, projectID: String) -> CacheEntry<ProjectResponse>? {
        ensureLoaded(userID)
        return snapshots[userID]?.projectDetails[projectID]
    }

    func refreshPatterns(for userID: String, client: APIClient) async throws -> [Pattern] {
        if let task = patternTasks[userID] { return try await task.value }
        let task = Task<[Pattern], Error> {
            let response: PatternListResponse = try await client.request("/api/patterns")
            return response.patterns
        }
        patternTasks[userID] = task
        do {
            let patterns = try await task.value
            patternTasks[userID] = nil
            ensureLoaded(userID)
            snapshots[userID]?.patterns = CacheEntry(value: patterns, updatedAt: Date())
            persist(userID)
            return patterns
        } catch {
            patternTasks[userID] = nil
            throw error
        }
    }

    func refreshProjects(for userID: String, client: APIClient) async throws -> [Project] {
        if let task = projectTasks[userID] { return try await task.value }
        let task = Task<[Project], Error> {
            let response: ProjectListResponse = try await client.request("/api/projects")
            return response.projects
        }
        projectTasks[userID] = task
        do {
            let projects = try await task.value
            projectTasks[userID] = nil
            ensureLoaded(userID)
            snapshots[userID]?.projects = CacheEntry(value: projects, updatedAt: Date())
            persist(userID)
            return projects
        } catch {
            projectTasks[userID] = nil
            throw error
        }
    }

    func refreshPatternDetail(for userID: String, patternID: String, client: APIClient) async throws -> PatternResponse {
        let key = "\(userID):\(patternID)"
        if let task = patternDetailTasks[key] { return try await task.value }
        let task = Task<PatternResponse, Error> { try await client.request("/api/patterns/\(patternID)") }
        patternDetailTasks[key] = task
        do {
            let detail = try await task.value
            patternDetailTasks[key] = nil
            ensureLoaded(userID)
            snapshots[userID]?.patternDetails[patternID] = CacheEntry(value: detail, updatedAt: Date())
            persist(userID)
            return detail
        } catch {
            patternDetailTasks[key] = nil
            throw error
        }
    }

    func refreshProjectDetail(for userID: String, projectID: String, client: APIClient) async throws -> ProjectResponse {
        let key = "\(userID):\(projectID)"
        if let task = projectDetailTasks[key] { return try await task.value }
        let task = Task<ProjectResponse, Error> { try await client.request("/api/projects/\(projectID)") }
        projectDetailTasks[key] = task
        do {
            let detail = try await task.value
            projectDetailTasks[key] = nil
            ensureLoaded(userID)
            snapshots[userID]?.projectDetails[projectID] = CacheEntry(value: detail, updatedAt: Date())
            persist(userID)
            return detail
        } catch {
            projectDetailTasks[key] = nil
            throw error
        }
    }

    func imageData(for userID: String, path: String, client: APIClient) async throws -> Data {
        let key = assetKey(userID: userID, path: path)
        if let data = imageCache.object(forKey: key as NSString) { return data as Data }
        let diskURL = imageURL(userID: userID, path: path)
        if let data = try? Data(contentsOf: diskURL), !data.isEmpty {
            imageCache.setObject(data as NSData, forKey: key as NSString, cost: data.count)
            assetKeysByUser[userID, default: []].insert(key)
            return data
        }
        if let task = imageTasks[key] { return try await task.value }
        let task = Task<Data, Error> { try await client.imageData(path) }
        imageTasks[key] = task
        do {
            let data = try await task.value
            imageTasks[key] = nil
            imageCache.setObject(data as NSData, forKey: key as NSString, cost: data.count)
            assetKeysByUser[userID, default: []].insert(key)
            persistImage(data, to: diskURL)
            return data
        } catch {
            imageTasks[key] = nil
            throw error
        }
    }

    func pdfData(for userID: String, path: String, client: APIClient) async throws -> Data {
        let key = assetKey(userID: userID, path: path)
        if let data = pdfCache.object(forKey: key as NSString) { return data as Data }
        if let task = pdfTasks[key] { return try await task.value }
        let task = Task<Data, Error> { try await client.pdfData(path) }
        pdfTasks[key] = task
        do {
            let data = try await task.value
            pdfTasks[key] = nil
            pdfCache.setObject(data as NSData, forKey: key as NSString, cost: data.count)
            assetKeysByUser[userID, default: []].insert(key)
            return data
        } catch {
            pdfTasks[key] = nil
            throw error
        }
    }

    func store(patterns: [Pattern], for userID: String) {
        ensureLoaded(userID)
        snapshots[userID]?.patterns = CacheEntry(value: patterns, updatedAt: Date())
        persist(userID)
    }

    func store(projects: [Project], for userID: String) {
        ensureLoaded(userID)
        snapshots[userID]?.projects = CacheEntry(value: projects, updatedAt: Date())
        persist(userID)
    }

    func invalidatePattern(for userID: String, patternID: String) {
        ensureLoaded(userID)
        snapshots[userID]?.patternDetails.removeValue(forKey: patternID)
        snapshots[userID]?.patterns = nil
        persist(userID)
    }

    func invalidateProject(for userID: String, projectID: String) {
        ensureLoaded(userID)
        snapshots[userID]?.projectDetails.removeValue(forKey: projectID)
        snapshots[userID]?.projects = nil
        persist(userID)
    }

    func clear(for userID: String) {
        snapshots.removeValue(forKey: userID)
        loadedUsers.remove(userID)
        patternTasks[userID]?.cancel()
        projectTasks[userID]?.cancel()
        patternTasks.removeValue(forKey: userID)
        projectTasks.removeValue(forKey: userID)
        let prefix = "\(userID):"
        patternDetailTasks.keys.filter { $0.hasPrefix(prefix) }.forEach { patternDetailTasks[$0]?.cancel(); patternDetailTasks.removeValue(forKey: $0) }
        projectDetailTasks.keys.filter { $0.hasPrefix(prefix) }.forEach { projectDetailTasks[$0]?.cancel(); projectDetailTasks.removeValue(forKey: $0) }
        for key in assetKeysByUser.removeValue(forKey: userID) ?? [] {
            imageTasks[key]?.cancel(); imageTasks.removeValue(forKey: key)
            pdfTasks[key]?.cancel(); pdfTasks.removeValue(forKey: key)
            imageCache.removeObject(forKey: key as NSString)
            pdfCache.removeObject(forKey: key as NSString)
        }
        try? FileManager.default.removeItem(at: snapshotURL(for: userID))
        try? FileManager.default.removeItem(at: imageDirectory(for: userID))
    }

    private func ensureLoaded(_ userID: String) {
        guard !loadedUsers.contains(userID) else { return }
        loadedUsers.insert(userID)
        let url = snapshotURL(for: userID)
        if let data = try? Data(contentsOf: url),
           let snapshot = try? JSONDecoder.stitchlyCache.decode(UserSnapshot.self, from: data),
           snapshot.schemaVersion == Self.schemaVersion, snapshot.userID == userID {
            snapshots[userID] = snapshot
        } else {
            snapshots[userID] = UserSnapshot(userID: userID)
        }
    }

    private func persist(_ userID: String) {
        guard let snapshot = snapshots[userID], let data = try? JSONEncoder.stitchlyCache.encode(snapshot) else { return }
        try? FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var directory = storageDirectory
        try? directory.setResourceValues(values)
        let url = snapshotURL(for: userID)
        try? data.write(to: url, options: .atomic)
        try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: url.path)
    }

    private func snapshotURL(for userID: String) -> URL {
        let digest = digest(userID, byteCount: 12)
        return storageDirectory.appending(path: "account-\(digest).json")
    }

    private func imageDirectory(for userID: String) -> URL {
        storageDirectory.appending(path: "images", directoryHint: .isDirectory)
            .appending(path: digest(userID, byteCount: 12), directoryHint: .isDirectory)
    }

    private func imageURL(userID: String, path: String) -> URL {
        imageDirectory(for: userID).appending(path: "\(digest(path)).image")
    }

    private func persistImage(_ data: Data, to url: URL) {
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var excludedDirectory = directory
        try? excludedDirectory.setResourceValues(values)
        try? data.write(to: url, options: .atomic)
        try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: url.path)
    }

    private func digest(_ value: String, byteCount: Int = 32) -> String {
        SHA256.hash(data: Data(value.utf8)).prefix(byteCount).map { String(format: "%02x", $0) }.joined()
    }

    private func assetKey(userID: String, path: String) -> String { "\(userID):\(path)" }
}

private extension JSONEncoder {
    static var stitchlyCache: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var stitchlyCache: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
