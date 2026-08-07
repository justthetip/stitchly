import Testing
import Foundation
@testable import Stitchly

struct StitchlyTests {
    @Test func demoProgressIsValid() { #expect(DemoData.project.currentInstruction <= DemoData.pattern.totalInstructions) }
    @Test func productionAPIUsesTLS() { #expect(APIClient.baseURL.scheme == "https") }
    @Test func firebaseConfigurationIsBundled() {
        #expect(Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil)
    }
    @Test func glossaryMatchingPreservesSourceAndPrefersLongerTerms() {
        let source = "K1, k2tog, then sc while scanning the row."
        let segments = PatternGlossary.segments(in: source)
        #expect(segments.map(\.text).joined() == source)
        #expect(segments.compactMap(\.term?.id) == ["k", "k2tog", "sc"])
    }
    @Test func compactMagicRingCountUsesMagicRingDefinition() {
        #expect(PatternGlossary.segments(in: "mr6, sc around").first?.term?.id == "mr")
    }
    @Test func projectMaterialsUseKnownDataAndExplicitInstructionEvidence() {
        let materials = ProjectMaterials.derive(project: DemoData.completedProject, pattern: DemoData.patterns.first { $0.id == DemoData.completedProject.patternId }, instructions: DemoData.instructions(for: DemoData.completedProject.patternId))
        #expect(materials.map(\.id) == ["yarn", "tool", "stuffing", "yarn-needle"])
    }
    @Test func materialChecksPersistPerProject() {
        let suite = "ProjectMaterialsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        ProjectMaterials.saveChecks(["yarn", "tool"], projectID: "one", defaults: defaults)
        #expect(ProjectMaterials.loadChecks(projectID: "one", defaults: defaults) == ["yarn", "tool"])
        #expect(ProjectMaterials.loadChecks(projectID: "two", defaults: defaults).isEmpty)
    }
    @Test func privatePhotoJournalKeepsProjectsAndStepsSeparate() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "PhotoJournalTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        _ = try ProjectPhotoJournal.save(Data("one".utf8), projectID: "project-a", instructionPosition: 2, section: "Body", directory: directory)
        _ = try ProjectPhotoJournal.save(Data("two".utf8), projectID: "project-a", instructionPosition: 3, section: "Body", directory: directory)
        _ = try ProjectPhotoJournal.save(Data("three".utf8), projectID: "project-b", instructionPosition: 2, section: "Body", directory: directory)
        #expect(try ProjectPhotoJournal.load(projectID: "project-a", instructionPosition: 2, directory: directory).count == 1)
        #expect(try ProjectPhotoJournal.load(projectID: "project-a", instructionPosition: 3, directory: directory).count == 1)
        #expect(try ProjectPhotoJournal.load(projectID: "project-b", instructionPosition: 2, directory: directory).count == 1)
    }
    @MainActor @Test func photoSourcesMapToDistinctPersistentPickerRequests() {
        #expect(ProjectPhotoSource.allCases == [.camera, .photoLibrary])
        #expect(ProjectPhotoSource.camera.id != ProjectPhotoSource.photoLibrary.id)
        #expect(ProjectPhotoSource.camera.uiKitSourceType == .camera)
        #expect(ProjectPhotoSource.photoLibrary.uiKitSourceType == .photoLibrary)
    }
    @Test func firstLaunchSplashHasThreeSecondMinimum() { #expect(BrandedSplashView.minimumDuration == .seconds(3)) }
    @Test func instructionsAreGroupedIntoOrderedSections() {
        let sections = DemoData.instructions.patternSections
        #expect(sections.count == 22)
        #expect(sections.first?.title == "APPLE")
        #expect(sections.first?.firstPosition == 1)
        #expect(sections.first?.lastPosition == 6)
        #expect(sections.last?.title == "TO MAKE UP")
        #expect(sections.last?.lastPosition == DemoData.instructions.count)
        #expect(sections.flatMap(\.instructions).map(\.position) == Array(1...DemoData.instructions.count))
    }
    @Test func repeatedRowRangesBecomeOneReaderStepWithTheWorkedRepeatCount() {
        let repeatedRows = (9...72).map { row in
            Instruction(
                id: "row-\(row)", position: row, section: "Headband", instructionKind: "row",
                sourceLabel: "Rows 9–72", instructions: "Repeat Rows 7–8 thirty-two times, or until the work comfortably wraps around your head.",
                notes: nil, stitchCount: 18, optional: false, instructionNumber: row,
                instructionNumberEnd: 72, sourceGroup: "row:9-72"
            )
        }
        let steps = repeatedRows.readerSteps
        #expect(steps.count == 1)
        #expect(steps[0].firstPosition == 9)
        #expect(steps[0].lastPosition == 72)
        #expect(steps[0].repeatCount == 32)
    }
    @Test func patternLibrarySearchAndCraftFiltersCompose() {
        let knit = Pattern(id: "knit", name: "Coastal Cardigan", designer: "Mina Moss", craft: "knit", difficulty: nil, yarn: nil, tool: nil, totalInstructions: 10, source: "PDF", pageCount: 4)
        let crochet = Pattern(id: "crochet", name: "Garden Wrap", designer: "Coastal Studio", craft: "crochet", difficulty: nil, yarn: nil, tool: nil, totalInstructions: 8, source: "PDF", pageCount: 3)
        let patterns = [knit, crochet]
        #expect(PatternLibraryFiltering.apply(patterns, searchText: "coastal", craft: .all).map(\.id) == ["knit", "crochet"])
        #expect(PatternLibraryFiltering.apply(patterns, searchText: "COASTAL", craft: .crochet).map(\.id) == ["crochet"])
        #expect(PatternLibraryFiltering.apply(patterns, searchText: "missing", craft: .all).isEmpty)
        #expect(PatternLibraryFiltering.apply(patterns, searchText: "", craft: .all).count == 2)
    }

    @MainActor @Test func authenticationSwapRemovesDemoContentAndSignOutRestoresIt() async {
        let userID = "empty-maker-\(UUID().uuidString)"
        let emptyClient = APIClient(token: "authenticated-test") { request in
            let path = request.url?.path ?? ""
            let data: Data
            if path == "/api/patterns" {
                data = try JSONEncoder().encode(PatternListResponse(patterns: []))
            } else if path == "/api/projects" {
                data = try JSONEncoder().encode(ProjectListResponse(projects: []))
            } else {
                Issue.record("Unexpected empty-account request: \(path)")
                data = Data("{}".utf8)
            }
            return (data, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }

        let library = LibraryStore()
        let projects = ProjectsStore()

        await library.load(client: APIClient(token: "demo"), userID: nil)
        await projects.load(client: APIClient(token: "demo"), userID: nil)
        #expect(library.patterns.count == DemoData.patterns.count)
        #expect(projects.projects.map(\.id) == [DemoData.project.id, DemoData.completedProject.id])

        await library.load(client: emptyClient, userID: userID)
        await projects.load(client: emptyClient, userID: userID)
        #expect(library.patterns.isEmpty)
        #expect(projects.projects.isEmpty)

        await library.load(client: APIClient(token: "demo"), userID: nil)
        await projects.load(client: APIClient(token: "demo"), userID: nil)
        #expect(library.patterns.count == DemoData.patterns.count)
        #expect(projects.projects.map(\.id) == [DemoData.project.id, DemoData.completedProject.id])
    }

    @Test func reviewPromptIsClaimedOnlyForTheFirstProjectAndOnlyOnce() {
        let suiteName = "ReviewPromptPolicyTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let policy = ReviewPromptPolicy(defaults: defaults)

        #expect(policy.claimRequest(isFirstProject: false) == false)
        #expect(policy.claimRequest(isFirstProject: true) == true)
        #expect(policy.claimRequest(isFirstProject: true) == false)
    }

    @Test func cacheEntriesUseTheSharedFreshnessWindow() {
        let now = Date()
        let fresh = CacheEntry(value: [DemoData.pattern], updatedAt: now.addingTimeInterval(-AppDataCache.freshnessDuration + 1))
        let stale = CacheEntry(value: [DemoData.pattern], updatedAt: now.addingTimeInterval(-AppDataCache.freshnessDuration - 1))
        #expect(fresh.isFresh(at: now))
        #expect(!stale.isFresh(at: now))
    }

    @Test func accountCachePersistsSeparatelyAndClearsOnInvalidation() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "StitchlyCacheTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = AppDataCache(storageDirectory: directory)
        let otherPattern = Pattern(id: "other", name: "Other pattern", designer: nil, craft: "knit", difficulty: nil, yarn: nil, tool: nil, totalInstructions: 2, source: "PDF", pageCount: 1)

        await cache.store(patterns: [DemoData.pattern], for: "maker-a")
        await cache.store(patterns: [otherPattern], for: "maker-b")

        let reloaded = AppDataCache(storageDirectory: directory)
        #expect(await reloaded.cachedPatterns(for: "maker-a")?.value.map(\.id) == [DemoData.pattern.id])
        #expect(await reloaded.cachedPatterns(for: "maker-b")?.value.map(\.id) == [otherPattern.id])

        await reloaded.invalidatePattern(for: "maker-a", patternID: DemoData.pattern.id)
        #expect(await reloaded.cachedPatterns(for: "maker-a") == nil)
        #expect(await reloaded.cachedPatterns(for: "maker-b")?.value.count == 1)

        await reloaded.clear(for: "maker-b")
        #expect(await reloaded.cachedPatterns(for: "maker-b") == nil)
    }

    @Test func duplicatePatternRefreshesShareOneRequest() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "StitchlyCacheTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = AppDataCache(storageDirectory: directory)
        let counter = CacheRequestCounter()
        let client = APIClient(token: "test") { request in try await counter.patternResponse(for: request) }

        async let first = cache.refreshPatterns(for: "maker", client: client)
        async let second = cache.refreshPatterns(for: "maker", client: client)
        let results = try await (first, second)

        #expect(results.0.map(\.id) == [DemoData.pattern.id])
        #expect(results.1.map(\.id) == [DemoData.pattern.id])
        #expect(await counter.requestCount == 1)
    }

    @Test func failedRevalidationKeepsTheLastGoodSnapshot() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "StitchlyCacheTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = AppDataCache(storageDirectory: directory)
        await cache.store(patterns: [DemoData.pattern], for: "maker")
        let client = APIClient(token: "test") { _ in throw URLError(.notConnectedToInternet) }

        do {
            _ = try await cache.refreshPatterns(for: "maker", client: client)
            Issue.record("Expected refresh to fail")
        } catch {
            #expect(await cache.cachedPatterns(for: "maker")?.value.map(\.id) == [DemoData.pattern.id])
        }
    }

    @Test func coverImagesPersistLocallyAndStayAccountScoped() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "StitchlyImageCacheTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let counter = CacheRequestCounter()
        let client = APIClient(token: "test") { request in try await counter.assetResponse(for: request) }
        let expected = Data("cached-cover".utf8)

        let firstCache = AppDataCache(storageDirectory: directory)
        #expect(try await firstCache.imageData(for: "maker-a", path: "/cover.png", client: client) == expected)

        let reloadedCache = AppDataCache(storageDirectory: directory)
        #expect(try await reloadedCache.imageData(for: "maker-a", path: "/cover.png", client: client) == expected)
        #expect(await counter.requestCount == 1)

        #expect(try await reloadedCache.imageData(for: "maker-b", path: "/cover.png", client: client) == expected)
        #expect(await counter.requestCount == 2)
    }

    @Test func originalPDFsPersistLocallyAndStayAccountScoped() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "StitchlyPDFCacheTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let counter = CacheRequestCounter()
        let client = APIClient(token: "test") { request in try await counter.assetResponse(for: request) }
        let expected = Data("cached-cover".utf8)

        let firstCache = AppDataCache(storageDirectory: directory)
        #expect(try await firstCache.pdfData(for: "maker-a", path: "/original.pdf", client: client) == expected)

        let reloadedCache = AppDataCache(storageDirectory: directory)
        #expect(try await reloadedCache.pdfData(for: "maker-a", path: "/original.pdf", client: client) == expected)
        #expect(await counter.requestCount == 1)

        #expect(try await reloadedCache.pdfData(for: "maker-b", path: "/original.pdf", client: client) == expected)
        #expect(await counter.requestCount == 2)
    }

    @Test func offlineQueuePersistsSeparatelyAndCoalescesProjectProgress() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "OfflineMutationTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = OfflineMutationStore(storageDirectory: directory)

        _ = try await store.enqueueProgress(userID: "maker-a", projectID: "project", currentInstruction: 2)
        _ = try await store.enqueueProgress(userID: "maker-a", projectID: "project", currentInstruction: 7)
        _ = try await store.enqueueNote(userID: "maker-a", projectID: "project", instructionPosition: 7, body: "Use the blue marker")
        _ = try await store.enqueueProgress(userID: "maker-b", projectID: "project", currentInstruction: 3)

        let reloaded = OfflineMutationStore(storageDirectory: directory)
        let makerA = await reloaded.pending(for: "maker-a")
        #expect(makerA.count == 2)
        #expect(makerA.first?.kind == .projectProgress)
        #expect(makerA.first?.currentInstruction == 7)
        #expect(makerA.last?.kind == .projectNote)
        #expect(await reloaded.pending(for: "maker-b").first?.currentInstruction == 3)
    }

    @Test func completionSupersedesUnsyncedProgressWithoutDroppingNotes() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "OfflineMutationTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = OfflineMutationStore(storageDirectory: directory)

        _ = try await store.enqueueProgress(userID: "maker", projectID: "project", currentInstruction: 8)
        let note = try await store.enqueueNote(userID: "maker", projectID: "project", instructionPosition: 8, body: "Changed yarn")
        _ = try await store.enqueueCompletion(userID: "maker", projectID: "project", currentInstruction: 12)

        let pending = await store.pending(for: "maker")
        #expect(pending.map(\.kind) == [.projectNote, .projectCompletion])
        #expect(pending.first?.id == note.id)
        #expect(pending.last?.currentInstruction == 12)
    }

    @MainActor @Test func syncReplaysDurableMutationsAndUsesAnIdempotentNoteKey() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "OfflineReplayTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OfflineMutationStore(storageDirectory: root.appending(path: "queue"))
        let cache = AppDataCache(storageDirectory: root.appending(path: "cache"))
        let note = try await store.enqueueNote(userID: "maker", projectID: DemoData.project.id, instructionPosition: 4, body: "Count twice")
        _ = try await store.enqueueCompletion(userID: "maker", projectID: DemoData.project.id, currentInstruction: 80)
        let recorder = SyncRequestRecorder()
        let client = APIClient(token: "test") { request in try await recorder.response(for: request) }
        let coordinator = OfflineSyncCoordinator(store: store, cache: cache)

        await coordinator.activate(userID: "maker", client: client)

        #expect(coordinator.pendingCount == 0)
        let requests = await recorder.requests
        #expect(requests.prefix(2).map(\.path) == ["/api/projects/\(DemoData.project.id)/notes", "/api/projects/\(DemoData.project.id)"])
        let noteBody = try #require(requests.first?.body)
        let object = try #require(JSONSerialization.jsonObject(with: noteBody) as? [String: Any])
        #expect(object["clientMutationId"] as? String == note.id.uuidString)
    }

    @Test func optimisticProjectChangesPersistForTheNextOfflineLaunch() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "OptimisticCacheTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = AppDataCache(storageDirectory: directory)
        await cache.store(projects: [DemoData.project], for: "maker")
        await cache.applyProjectChange(for: "maker", projectID: DemoData.project.id, currentInstruction: 42, status: "completed")

        let reloaded = AppDataCache(storageDirectory: directory)
        let project = await reloaded.cachedProjects(for: "maker")?.value.first
        #expect(project?.currentInstruction == 42)
        #expect(project?.status == "completed")
    }
}

private actor CacheRequestCounter {
    private(set) var requestCount = 0

    func patternResponse(for request: URLRequest) async throws -> (Data, URLResponse) {
        requestCount += 1
        try await Task.sleep(for: .milliseconds(100))
        let data = try JSONEncoder().encode(PatternListResponse(patterns: [DemoData.pattern]))
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (data, response)
    }

    func assetResponse(for request: URLRequest) async throws -> (Data, URLResponse) {
        requestCount += 1
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "image/png"])!
        return (Data("cached-cover".utf8), response)
    }
}

private actor SyncRequestRecorder {
    struct RecordedRequest: Sendable {
        let path: String
        let method: String
        let body: Data?
    }

    private(set) var requests: [RecordedRequest] = []

    func response(for request: URLRequest) async throws -> (Data, URLResponse) {
        let path = request.url?.path ?? ""
        requests.append(RecordedRequest(path: path, method: request.httpMethod ?? "GET", body: request.httpBody))
        let data: Data
        let status: Int
        if request.httpMethod == "GET", path == "/api/projects" {
            data = try encoder.encode(ProjectListResponse(projects: [DemoData.completedProject]))
            status = 200
        } else if request.httpMethod == "GET", path == "/api/projects/\(DemoData.project.id)" {
            data = try encoder.encode(ProjectResponse(project: DemoData.completedProject, instructions: DemoData.instructions, notes: []))
            status = 200
        } else {
            data = Data("{}".utf8)
            status = path.hasSuffix("/notes") ? 201 : 200
        }
        return (data, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
