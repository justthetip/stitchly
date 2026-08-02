import Testing
@testable import Stitchly

struct StitchlyTests {
    @Test func demoProgressIsValid() { #expect(DemoData.project.currentInstruction <= DemoData.pattern.totalInstructions) }
    @Test func productionAPIUsesTLS() { #expect(APIClient.baseURL.scheme == "https") }
}
