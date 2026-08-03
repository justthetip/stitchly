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

struct ProjectNote: Codable, Identifiable, Sendable {
    let id: String
    let instructionPosition: Int?
    let body: String
    let createdAt: Date
}

struct PatternListResponse: Codable { let patterns: [Pattern] }
struct PatternResponse: Codable { let pattern: Pattern; let instructions: [Instruction]; var alreadyAdded: Bool? = nil }
struct ProjectListResponse: Codable { let projects: [Project] }
struct ProjectResponse: Codable { let project: Project; let instructions: [Instruction]; let notes: [ProjectNote] }
struct ProjectCreationResponse: Codable { let project: Project; let isFirstProject: Bool }
struct UploadTokenResponse: Codable { let clientToken: String }
struct BlobResponse: Codable { let url: URL }

enum DemoData {
    static let pattern = Pattern(id: "pattern-demo", name: "Wildflower Cardigan", designer: "Stitchly Studio", craft: "crochet", difficulty: "Intermediate", yarn: "DK cotton", tool: "4 mm hook", totalInstructions: 18, source: "PDF", pageCount: 8)
    static let instructions = [
        Instruction(id: "i1", position: 1, section: "Back panel", instructionKind: "setup", sourceLabel: "Foundation", instructions: "Chain 72 loosely. Turn, working into the back bumps for a neat lower edge.", notes: "Keep the foundation chain relaxed.", stitchCount: 72, optional: false),
        Instruction(id: "i2", position: 2, section: "Back panel", instructionKind: "row", sourceLabel: "Row 1", instructions: "Double crochet in the fourth chain from the hook and in every chain across. Turn.", notes: nil, stitchCount: 70, optional: false),
        Instruction(id: "i3", position: 3, section: "Back panel", instructionKind: "row", sourceLabel: "Row 2", instructions: "Chain 3, skip the first stitch, double crochet across. Turn.", notes: "Repeat this row until the panel measures 38 cm.", stitchCount: 70, optional: false),
        Instruction(id: "i4", position: 4, section: "Left front", instructionKind: "setup", sourceLabel: "Foundation", instructions: "Chain 38 loosely for the left front panel.", notes: nil, stitchCount: 38, optional: false),
        Instruction(id: "i5", position: 5, section: "Left front", instructionKind: "row", sourceLabel: "Row 1", instructions: "Double crochet across, keeping the front edge relaxed.", notes: nil, stitchCount: 36, optional: false),
        Instruction(id: "i6", position: 6, section: "Sleeves", instructionKind: "setup", sourceLabel: "Cuff", instructions: "Work the cuff ribbing to the required wrist measurement.", notes: "Make two matching sleeves.", stitchCount: nil, optional: false)
    ]
    static let project = Project(id: "project-demo", patternId: pattern.id, name: "My coral cardigan", status: "active", yarn: "Coral merino blend", currentInstruction: 2, patternName: pattern.name, totalInstructions: 18, craft: "crochet")
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
