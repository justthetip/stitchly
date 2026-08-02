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
}

struct PatternSection: Identifiable, Hashable, Sendable {
    let title: String
    let instructions: [Instruction]
    var id: String { "\(instructions.first?.position ?? 0)-\(title)" }
    var firstPosition: Int { instructions.first?.position ?? 1 }
    var lastPosition: Int { instructions.last?.position ?? firstPosition }
}

extension Array where Element == Instruction {
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
}

struct ProjectNote: Codable, Identifiable, Sendable {
    let id: String
    let instructionPosition: Int?
    let body: String
    let createdAt: Date
}

struct PatternListResponse: Codable { let patterns: [Pattern] }
struct PatternResponse: Codable { let pattern: Pattern; let instructions: [Instruction] }
struct ProjectListResponse: Codable { let projects: [Project] }
struct ProjectResponse: Codable { let project: Project; let instructions: [Instruction]; let notes: [ProjectNote] }
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
}
