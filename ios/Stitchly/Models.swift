import Foundation

struct User: Codable, Sendable { let id: String; let name: String?; let email: String? }
struct SessionResponse: Codable, Sendable { let user: User; let token: String?; let expiresAt: Date? }

struct Pattern: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let designer: String?
    let craft: String
    let difficulty: String?
    let yarn: String?
    let tool: String?
    let totalInstructions: Int
    let source: String
    let pageCount: Int?
    var coverUrl: String? = nil
}

struct Instruction: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let position: Int
    let section: String
    let instructionKind: String
    let sourceLabel: String?
    let instructions: String
    let notes: String?
    let stitchCount: Int?
    let optional: Bool
    let confidence: String?
    let instructionNumber: Int?
    let instructionNumberEnd: Int?
    let sourceGroup: String?

    init(id: String, position: Int, section: String, instructionKind: String, sourceLabel: String?, instructions: String, notes: String?, stitchCount: Int?, optional: Bool, confidence: String? = nil, instructionNumber: Int? = nil, instructionNumberEnd: Int? = nil, sourceGroup: String? = nil) {
        self.id = id; self.position = position; self.section = section; self.instructionKind = instructionKind; self.sourceLabel = sourceLabel; self.instructions = instructions; self.notes = notes; self.stitchCount = stitchCount; self.optional = optional; self.confidence = confidence; self.instructionNumber = instructionNumber; self.instructionNumberEnd = instructionNumberEnd; self.sourceGroup = sourceGroup
    }
}

struct ReaderStep: Identifiable, Hashable, Sendable {
    let instructions: [Instruction]
    var id: String { instructions.first?.id ?? "reader-step" }
    var firstPosition: Int { instructions.first?.position ?? 1 }
    var lastPosition: Int { instructions.last?.position ?? firstPosition }
    var section: String { instructions.first?.section ?? "Pattern" }
    var sourceLabel: String? { instructions.first?.sourceLabel }
    var instruction: Instruction? { instructions.first }

    var repeatCount: Int? {
        guard instructions.count > 1 else { return nil }
        let repeatedUnitWidth = referencedRangeWidth(in: instruction?.instructions ?? "") ?? 1
        let count = instructions.count / max(repeatedUnitWidth, 1)
        return count > 1 ? count : nil
    }

    private func referencedRangeWidth(in text: String) -> Int? {
        let pattern = #"(?i)repeat\s+(?:rows?|rounds?)\s+(\d+)\s*[-–—]\s*(\d+)"#
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let startRange = Range(match.range(at: 1), in: text),
              let endRange = Range(match.range(at: 2), in: text),
              let start = Int(text[startRange]), let end = Int(text[endRange]), end >= start else { return nil }
        return end - start + 1
    }
}

struct PatternSection: Identifiable, Hashable, Sendable {
    let title: String
    let instructions: [Instruction]
    var id: String { "\(instructions.first?.position ?? 0)-\(title)" }
    var firstPosition: Int { instructions.first?.position ?? 1 }
    var lastPosition: Int { instructions.last?.position ?? firstPosition }
}

extension Array where Element == Instruction {
    var readerSteps: [ReaderStep] {
        let ordered = sorted { $0.position < $1.position }
        var steps: [ReaderStep] = []
        for instruction in ordered {
            if let group = instruction.sourceGroup,
               let last = steps.last,
               last.instructions.last?.sourceGroup == group,
               last.section == instruction.section {
                steps[steps.count - 1] = ReaderStep(instructions: last.instructions + [instruction])
            } else {
                steps.append(ReaderStep(instructions: [instruction]))
            }
        }
        return steps
    }

    var patternSections: [PatternSection] {
        let ordered = sorted { $0.position < $1.position }
        var sections: [PatternSection] = []
        for instruction in ordered {
            if let last = sections.last, last.title == instruction.section {
                sections[sections.count - 1] = PatternSection(title: last.title, instructions: last.instructions + [instruction])
            } else {
                sections.append(PatternSection(title: instruction.section, instructions: [instruction]))
            }
        }
        return sections
    }
}

struct Project: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let patternId: String
    let name: String
    let status: String
    let yarn: String?
    let currentInstruction: Int
    let patternName: String?
    let totalInstructions: Int?
    let craft: String?
    let startedAt: Date?
    let lastWorkedAt: Date?
    let completedAt: Date?
    let coverUrl: String?

    init(id: String, patternId: String, name: String, status: String, yarn: String?, currentInstruction: Int, patternName: String?, totalInstructions: Int?, craft: String?, startedAt: Date? = nil, lastWorkedAt: Date? = nil, completedAt: Date? = nil, coverUrl: String? = nil) {
        self.id = id; self.patternId = patternId; self.name = name; self.status = status; self.yarn = yarn; self.currentInstruction = currentInstruction; self.patternName = patternName; self.totalInstructions = totalInstructions; self.craft = craft; self.startedAt = startedAt; self.lastWorkedAt = lastWorkedAt; self.completedAt = completedAt; self.coverUrl = coverUrl
    }
}

extension Project {
    func updating(currentInstruction: Int? = nil, status: String? = nil, at date: Date = Date()) -> Project {
        let nextStatus = status ?? self.status
        return Project(
            id: id,
            patternId: patternId,
            name: name,
            status: nextStatus,
            yarn: yarn,
            currentInstruction: currentInstruction ?? self.currentInstruction,
            patternName: patternName,
            totalInstructions: totalInstructions,
            craft: craft,
            startedAt: startedAt,
            lastWorkedAt: date,
            completedAt: nextStatus == "completed" ? (completedAt ?? date) : completedAt,
            coverUrl: coverUrl
        )
    }
}

struct ProjectNote: Codable, Identifiable, Sendable {
    let id: String
    let instructionPosition: Int?
    let body: String
    let createdAt: Date
}

struct PatternListResponse: Codable, Sendable { let patterns: [Pattern] }
struct PatternResponse: Codable, Sendable { let pattern: Pattern; let instructions: [Instruction]; var alreadyAdded: Bool? = nil }
struct ProjectListResponse: Codable, Sendable { let projects: [Project] }
struct ProjectResponse: Codable, Sendable { let project: Project; let instructions: [Instruction]; let notes: [ProjectNote] }
struct ProjectCreationResponse: Codable, Sendable { let project: Project; let isFirstProject: Bool }
struct UploadTokenResponse: Codable { let clientToken: String }
struct BlobResponse: Codable { let url: URL }

enum DemoData {
    struct Catalog: Decodable {
        let patterns: [Pattern]
        let instructions: [String: [Instruction]]
        let project: Project
    }

    private static let catalog: Catalog = {
        guard let url = Bundle.main.url(forResource: "demo-catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            fatalError("The bundled demo catalog is missing.")
        }
        guard let catalog = try? decodeCatalog(from: data) else {
            fatalError("The bundled demo catalog could not be decoded.")
        }
        return catalog
    }()

    static func decodeCatalog(from data: Data) throws -> Catalog {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            let fractionalFormatter = ISO8601DateFormatter()
            fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let standardFormatter = ISO8601DateFormatter()
            standardFormatter.formatOptions = [.withInternetDateTime]

            guard let date = fractionalFormatter.date(from: value) ?? standardFormatter.date(from: value) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Expected an ISO-8601 date with optional fractional seconds."
                )
            }
            return date
        }
        return try decoder.decode(Catalog.self, from: data)
    }

    static let patterns = catalog.patterns
    static let pattern = patterns[0]
    static let project = catalog.project
    static let completedProject = Project(
        id: "demo-completed-mini-whale", patternId: "demo-mini-whale", name: "My Mini Whale",
        status: "completed", yarn: "Worsted weight yarn", currentInstruction: 12,
        patternName: "Mini Whale", totalInstructions: 12, craft: "crochet",
        startedAt: Date(timeIntervalSince1970: 1_752_317_200),
        lastWorkedAt: Date(timeIntervalSince1970: 1_752_858_600),
        completedAt: Date(timeIntervalSince1970: 1_752_858_600),
        coverUrl: "/demo/mini-whale-cover.png"
    )
    static let instructions = instructions(for: pattern.id)

    static var projectWithLocalProgress: Project {
        let savedPosition = UserDefaults.standard.integer(forKey: "demoReaderPosition")
        guard savedPosition > 0,
              savedPosition <= (project.totalInstructions ?? pattern.totalInstructions),
              savedPosition != project.currentInstruction else { return project }
        return Project(
            id: project.id, patternId: project.patternId, name: project.name, status: project.status,
            yarn: project.yarn, currentInstruction: savedPosition, patternName: project.patternName,
            totalInstructions: project.totalInstructions, craft: project.craft, startedAt: project.startedAt,
            lastWorkedAt: project.lastWorkedAt, completedAt: project.completedAt, coverUrl: project.coverUrl
        )
    }

    static var projectsWithLocalProgress: [Project] {
        [projectWithLocalProgress, completedProject]
    }

    static func instructions(for patternID: String) -> [Instruction] {
        catalog.instructions[patternID] ?? []
    }

    static func pdfResource(for patternID: String) -> String? {
        switch patternID {
        case "demo-fruity-friends": "fruity-friends"
        case "demo-mini-whale": "mini-whale"
        case "demo-perfect-granny-square": "perfect-granny-square"
        default: nil
        }
    }

    static func isDemoPattern(_ patternID: String) -> Bool {
        pdfResource(for: patternID) != nil
    }

    static func isDemoProject(_ projectID: String) -> Bool {
        projectID == project.id || projectID == completedProject.id || projectID.hasPrefix("demo-marketplace-project-")
    }

    static func readerPositionKey(for projectID: String) -> String {
        projectID == project.id ? "demoReaderPosition" : "demoReaderPosition-\(projectID)"
    }
    static let repeatInstructions = (9...72).map { row in
        Instruction(
            id: "headband-row-\(row)", position: row, section: "Headband", instructionKind: "row",
            sourceLabel: "Rows 9–72", instructions: "Repeat Rows 7–8 thirty-two times, or until the work comfortably wraps around your head.",
            notes: "Add a note if you change the length for your preferred fit.", stitchCount: 18, optional: false,
            instructionNumber: row, instructionNumberEnd: 72, sourceGroup: "row:9-72"
        )
    }
    static let repeatProject = Project(id: "headband-demo", patternId: "headband-pattern-demo", name: "Stitchly starter headband", status: "active", yarn: "Aran yarn", currentInstruction: 9, patternName: "Stitchly Starter Headband", totalInstructions: 64, craft: "knit")
    static let notes = [ProjectNote(id: "note-demo", instructionPosition: 2, body: "Used the coral marker at the side seam.", createdAt: Date(timeIntervalSince1970: 1_753_084_800))]
}
