import Foundation

struct ProjectMaterial: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let detail: String?
}

enum ProjectMaterials {
    static func derive(project: Project, pattern: Pattern?, instructions: [Instruction]) -> [ProjectMaterial] {
        var result: [ProjectMaterial] = []
        let yarn = project.yarn?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let yarn, !yarn.isEmpty { result.append(.init(id: "yarn", name: "Yarn", detail: yarn)) }
        let tool = pattern?.tool?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let tool, !tool.isEmpty { result.append(.init(id: "tool", name: "Needles or hook", detail: tool)) }
        let source = instructions.map(\.instructions).joined(separator: " ").lowercased()
        if source.range(of: #"safety eyes?"#, options: .regularExpression) != nil {
            result.append(.init(id: "safety-eyes", name: "Toy safety eyes", detail: "Size and quantity are given in the pattern steps"))
        }
        if source.range(of: #"\b(stuff|stuffing|filling|fiberfill)\b"#, options: .regularExpression) != nil {
            result.append(.init(id: "stuffing", name: "Toy stuffing", detail: "For filling the finished pieces"))
        }
        if source.range(of: #"\b(sew|sewing|weave in)\b"#, options: .regularExpression) != nil {
            result.append(.init(id: "yarn-needle", name: "Yarn needle", detail: "For sewing pieces and finishing ends"))
        }
        if source.range(of: #"stitch markers?"#, options: .regularExpression) != nil {
            result.append(.init(id: "stitch-markers", name: "Stitch markers", detail: nil))
        }
        return result
    }

    static func loadChecks(projectID: String, defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: storageKey(projectID)) ?? [])
    }

    static func saveChecks(_ checks: Set<String>, projectID: String, defaults: UserDefaults = .standard) {
        defaults.set(Array(checks).sorted(), forKey: storageKey(projectID))
    }

    private static func storageKey(_ projectID: String) -> String { "projectMaterials-\(projectID)" }
}
