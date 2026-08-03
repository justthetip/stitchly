import Testing
import Foundation
@testable import Stitchly

struct StitchlyTests {
    @Test func demoProgressIsValid() { #expect(DemoData.project.currentInstruction <= DemoData.pattern.totalInstructions) }
    @Test func productionAPIUsesTLS() { #expect(APIClient.baseURL.scheme == "https") }
    @Test func firstLaunchSplashHasThreeSecondMinimum() { #expect(BrandedSplashView.minimumDuration == .seconds(3)) }
    @Test func instructionsAreGroupedIntoOrderedSections() {
        let sections = DemoData.instructions.patternSections
        #expect(sections.map(\.title) == ["Back panel", "Left front", "Sleeves"])
        #expect(sections.map(\.firstPosition) == [1, 4, 6])
        #expect(sections[0].lastPosition == 3)
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

    @Test func reviewPromptIsClaimedOnlyForTheFirstProjectAndOnlyOnce() {
        let suiteName = "ReviewPromptPolicyTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let policy = ReviewPromptPolicy(defaults: defaults)

        #expect(policy.claimRequest(isFirstProject: false) == false)
        #expect(policy.claimRequest(isFirstProject: true) == true)
        #expect(policy.claimRequest(isFirstProject: true) == false)
    }
}
