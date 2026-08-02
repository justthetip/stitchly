import XCTest

@MainActor final class StitchlyUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testProjectReaderJourney() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Projects"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["My coral cardigan"].exists)
        app.staticTexts["My coral cardigan"].tap()
        XCTAssertTrue(app.staticTexts["Row 1"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Next"].isHittable)
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Row 2"].waitForExistence(timeout: 3))
    }

    func testLibraryJourneyAtLargestDynamicType() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-libraryDemo", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Wildflower Cardigan"].exists)
        XCTAssertTrue(app.buttons["Import"].isHittable)
    }

    func testNativeAuthenticationScreenIsAccessible() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-resetAuthForUITests"]
        app.launch()
        XCTAssertTrue(app.textFields["Email address"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.secureTextFields["Password"].exists)
        XCTAssertTrue(app.buttons["Sign in"].exists)
        XCTAssertTrue(app.buttons["Continue with Apple"].exists)
        try app.performAccessibilityAudit(for: [.contrast, .dynamicType, .hitRegion, .textClipped])
    }

    func testReaderPassesAccessibilityAudit() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-readerDemo"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Row 1"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(for: [.contrast, .dynamicType, .hitRegion, .textClipped])
    }
}
