import Testing
@testable import Stitchly

struct StitchlyTests {
    @Test func demoProgressIsValid() { #expect(DemoData.project.currentInstruction <= DemoData.pattern.totalInstructions) }
    @Test func productionAPIUsesTLS() { #expect(APIClient.baseURL.scheme == "https") }
    @Test func instructionsAreGroupedIntoOrderedSections() {
        let sections = DemoData.instructions.patternSections
        #expect(sections.map(\.title) == ["Back panel", "Left front", "Sleeves"])
        #expect(sections.map(\.firstPosition) == [1, 4, 6])
        #expect(sections[0].lastPosition == 3)
    }
}
