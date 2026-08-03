import Foundation

struct ReviewPromptPolicy {
    static let requestedKey = "hasRequestedReviewAfterFirstProject"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func claimRequest(isFirstProject: Bool) -> Bool {
        guard isFirstProject, !defaults.bool(forKey: Self.requestedKey) else { return false }
        defaults.set(true, forKey: Self.requestedKey)
        return true
    }
}
