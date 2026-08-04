import XCTest

@MainActor final class StitchlyUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testProjectReaderJourney() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-projectsDemo", "-resetDemoReaderProgressForUITests", "-skipFirstLaunchSplashForUITests"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Projects"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["My coral cardigan"].exists)
        app.staticTexts["My coral cardigan"].tap()
        XCTAssertTrue(app.navigationBars["Project overview"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Used the coral marker at the side seam."].exists)
        app.buttons["continue-project"].tap()
        XCTAssertTrue(app.staticTexts["Row 1"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["reader-actions"].exists)
        XCTAssertTrue(app.buttons["Next"].isHittable)
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Row 2"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["reader-exit"].isHittable)
        app.buttons["reader-exit"].tap()
        XCTAssertTrue(app.navigationBars["Project overview"].waitForExistence(timeout: 3))
        app.buttons["continue-project"].tap()
        XCTAssertTrue(app.staticTexts["Row 2"].waitForExistence(timeout: 3))
        app.buttons["reader-actions"].tap()
        XCTAssertTrue(app.buttons["reader-original-pdf"].exists)
        app.buttons["reader-sections"].tap()
        XCTAssertTrue(app.navigationBars["Pattern sections"].waitForExistence(timeout: 3))
        try app.performAccessibilityAudit(for: [.contrast, .dynamicType, .hitRegion, .textClipped])
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Sleeves'")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Cuff"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Finish project"].isHittable)
        app.buttons["Finish project"].tap()
        XCTAssertTrue(app.staticTexts["You finished My coral cardigan!"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Congratulations — your project is marked complete and stays available with its instructions and notes."].exists)
        app.buttons["completion-done"].tap()
        XCTAssertTrue(app.navigationBars["Project overview"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Completed"].exists)
    }

    func testLibraryJourneyAtLargestDynamicType() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-libraryDemo", "-skipFirstLaunchSplashForUITests", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Wildflower Cardigan"].exists)
        XCTAssertTrue(app.buttons["Import"].isHittable)
        app.staticTexts["Wildflower Cardigan"].tap()
        XCTAssertTrue(app.navigationBars["Pattern overview"].waitForExistence(timeout: 3))
        for _ in 0..<2 where !app.staticTexts["Back panel"].exists { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["Back panel"].waitForExistence(timeout: 3))
        for _ in 0..<4 { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["Left front"].waitForExistence(timeout: 3))
    }

    func testNativeAuthenticationScreenIsAccessible() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-resetAuthForUITests", "-skipOnboardingForUITests", "-skipFirstLaunchSplashForUITests"]
        app.launch()
        let email = app.textFields["Email address"]
        let password = app.secureTextFields["Password"]
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        XCTAssertTrue(password.exists)
        XCTAssertTrue(email.isHittable)
        XCTAssertTrue(password.isHittable)
        XCTAssertGreaterThanOrEqual(app.buttons["toggle-password-visibility"].frame.height, 44)
        XCTAssertTrue(app.buttons["Sign in"].exists)
        XCTAssertTrue(app.buttons["Continue with Apple"].exists)
        try app.performAccessibilityAudit(for: [.contrast, .dynamicType, .hitRegion, .textClipped])
    }

    func testAuthenticationFieldsSupportEdgeTapsKeyboardProgressionAndModeSwitching() {
        let app = XCUIApplication()
        app.launchArguments = ["-resetAuthForUITests", "-skipOnboardingForUITests", "-skipFirstLaunchSplashForUITests"]
        app.launch()

        let email = app.textFields["Email address"]
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        app.buttons["Sign in"].tap()
        XCTAssertTrue(app.staticTexts["auth-validation-message"].exists)

        email.coordinate(withNormalizedOffset: CGVector(dx: -0.15, dy: 0.5)).tap()
        email.typeText("maker@example.com")
        email.typeText("\n")

        let password = app.secureTextFields["Password"]
        XCTAssertTrue(password.exists)
        password.typeText("stitchly-demo")
        let visibility = app.buttons["toggle-password-visibility"]
        XCTAssertTrue(visibility.isHittable)
        visibility.tap()

        let keyboardDone = app.buttons["auth-keyboard-done"]
        if keyboardDone.waitForExistence(timeout: 1) { keyboardDone.tap() }
        let modeSwitch = app.buttons["New here? Create an account"]
        for _ in 0..<3 where !modeSwitch.isHittable { app.swipeDown() }
        XCTAssertTrue(modeSwitch.isHittable)
        modeSwitch.tap()
        let name = app.textFields["Your name"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        XCTAssertTrue(name.isHittable)
        XCTAssertEqual(email.value as? String, "maker@example.com")
    }

    func testFirstRunOnboardingCompletesBeforeAuthentication() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-resetAuthForUITests", "-resetOnboardingForUITests", "-onboardingDemo", "-skipFirstLaunchSplashForUITests"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Bring patterns together"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Skip"].isHittable)
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Turn patterns into clear steps"].waitForExistence(timeout: 3))
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Make without losing your place"].waitForExistence(timeout: 3))
        try app.performAccessibilityAudit(for: [.contrast, .dynamicType, .hitRegion, .textClipped])
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.textFields["Email address"].waitForExistence(timeout: 3))
    }

    func testFirstInstallSplashHoldsBeforeOnboarding() {
        let app = XCUIApplication()
        app.launchArguments = ["-resetAuthForUITests", "-resetOnboardingForUITests", "-resetFirstLaunchSplashForUITests"]
        app.launch()
        let splash = app.descendants(matching: .any)["branded-splash"]
        XCTAssertTrue(splash.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Bring patterns together"].waitForExistence(timeout: 3))
    }

    func testOnboardingCanBeSkipped() {
        let app = XCUIApplication()
        app.launchArguments = ["-resetAuthForUITests", "-resetOnboardingForUITests", "-onboardingDemo", "-skipFirstLaunchSplashForUITests"]
        app.launch()
        XCTAssertTrue(app.buttons["Skip"].waitForExistence(timeout: 5))
        app.buttons["Skip"].tap()
        XCTAssertTrue(app.textFields["Email address"].waitForExistence(timeout: 3))
    }

    func testReaderPassesAccessibilityAudit() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-readerDemo", "-resetDemoReaderProgressForUITests", "-skipFirstLaunchSplashForUITests"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Row 1"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(for: [.contrast, .dynamicType, .hitRegion, .textClipped])
    }

    func testReaderExplainsItsLoadingState() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-readerDemo", "-resetDemoReaderProgressForUITests", "-simulateSlowLoading", "-skipFirstLaunchSplashForUITests"]
        app.launch()
        let loading = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Opening your project'")).firstMatch
        XCTAssertTrue(loading.waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["branded-loading-state"].exists)
        XCTAssertTrue(loading.label.contains("Loading pattern sections, your current step, and saved notes."))
        XCTAssertTrue(app.staticTexts["Row 1"].waitForExistence(timeout: 8))
    }

    func testReaderGroupsRepeatedRowsAndShowsTheWorkedRepeatCount() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-readerRepeatDemo", "-skipFirstLaunchSplashForUITests"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Rows 9–72"].waitForExistence(timeout: 5))
        let repeatBadge = app.descendants(matching: .any)["reader-repeat-count"]
        XCTAssertTrue(repeatBadge.exists)
        XCTAssertEqual(repeatBadge.label, "Repeat 32 times")
        XCTAssertTrue(app.buttons["Finish project"].isHittable)
        XCTAssertFalse(app.buttons["Next"].exists)
        try app.performAccessibilityAudit(for: [.contrast, .dynamicType, .hitRegion, .textClipped])
    }

    func testLibraryExplainsItsLoadingState() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-libraryDemo", "-simulateSlowLoading", "-skipFirstLaunchSplashForUITests"]
        app.launch()
        let loading = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Loading your library'")).firstMatch
        XCTAssertTrue(loading.waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["branded-loading-state"].exists)
        XCTAssertTrue(loading.label.contains("Loading your pattern library…"))
        XCTAssertTrue(app.staticTexts["Wildflower Cardigan"].waitForExistence(timeout: 3))
    }

    func testProjectsEmptyStatePresentsOneCreationFlow() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-projectsDemo", "-emptyProjectsDemo", "-skipFirstLaunchSplashForUITests"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Start your first project"].waitForExistence(timeout: 5))
        let action = app.buttons["empty-state-primary-action"]
        XCTAssertTrue(action.isHittable)
        action.tap()
        XCTAssertTrue(app.navigationBars["New project"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.navigationBars.matching(identifier: "New project").count, 1)
    }

    func testLibraryEmptyStateShowsProminentImportAction() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-libraryDemo", "-emptyLibraryDemo", "-skipFirstLaunchSplashForUITests"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Try your first pattern"].waitForExistence(timeout: 5))
        let example = app.buttons["empty-state-primary-action"]
        let importer = app.buttons["empty-state-secondary-action"]
        XCTAssertTrue(example.isHittable)
        XCTAssertEqual(example.label, "Try an example pattern")
        XCTAssertTrue(importer.isHittable)
        XCTAssertEqual(importer.label, "Import my PDF")
        importer.tap()
        XCTAssertTrue(app.navigationBars["Import a pattern"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["PDF to pocket-sized steps"].exists)
        XCTAssertTrue(app.buttons["choose-private-pdf"].isHittable)
    }

    func testEmptyLibraryCanTryExampleAndReviewIt() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-libraryDemo", "-emptyLibraryDemo", "-skipFirstLaunchSplashForUITests"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Try your first pattern"].waitForExistence(timeout: 5))
        app.buttons["empty-state-primary-action"].tap()
        XCTAssertTrue(app.navigationBars["Review import"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Confidence is a prompt to verify—not a guarantee. Preserve the PDF’s own row, round, setup, finishing, and size terminology."].exists)
        XCTAssertTrue(app.buttons["review-original-pdf"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["review-instruction-1"].exists)
        app.buttons["save-import-review"].tap()
        XCTAssertTrue(app.staticTexts["Pattern ready"].waitForExistence(timeout: 3))
        app.buttons["Review pattern"].tap()
        XCTAssertTrue(app.navigationBars["Pattern overview"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["pattern-original-pdf"].exists)
        app.buttons["start-pattern-project"].tap()
        XCTAssertTrue(app.navigationBars["New project"].waitForExistence(timeout: 3))
        app.buttons["Create"].tap()
        XCTAssertTrue(app.staticTexts["Project ready"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["created-start-making"].isHittable)
    }

    func testHomeResumesCurrentProjectInOneAction() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-resetDemoReaderProgressForUITests", "-skipFirstLaunchSplashForUITests"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["My coral cardigan"].exists)
        XCTAssertTrue(app.staticTexts["Row 1"].exists)
        app.buttons["resume-current-project"].tap()
        XCTAssertTrue(app.staticTexts["Row 1"].waitForExistence(timeout: 3))
    }

    func testHomeExplainsLoadingCurrentProject() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-simulateSlowLoading", "-skipFirstLaunchSplashForUITests"]
        app.launch()
        let loading = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Finding your current project'")).firstMatch
        XCTAssertTrue(loading.waitForExistence(timeout: 3))
        XCTAssertTrue(loading.label.contains("Loading your most recently worked project and saved step"))
    }

    func testHomeEmptyStateOpensProjects() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-emptyProjectsDemo", "-skipFirstLaunchSplashForUITests"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Choose what to make next"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["getting-started-guide"].exists)
        app.buttons["empty-state-primary-action"].tap()
        XCTAssertTrue(app.navigationBars["Projects"].waitForExistence(timeout: 3))
    }

    func testProjectOverviewCanCompleteProject() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-projectsDemo", "-skipFirstLaunchSplashForUITests"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Projects"].waitForExistence(timeout: 5))
        app.staticTexts["My coral cardigan"].tap()
        XCTAssertTrue(app.navigationBars["Project overview"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["project-original-pdf"].exists)
        app.buttons["complete-project"].tap()
        XCTAssertTrue(app.buttons["Mark complete"].waitForExistence(timeout: 3))
        app.buttons["Mark complete"].tap()
        XCTAssertTrue(app.staticTexts["Completed"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["complete-project"].exists)
    }

    func testProjectCanBeDeletedFromProjectsList() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-projectsDemo", "-skipFirstLaunchSplashForUITests"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Projects"].waitForExistence(timeout: 5))
        let project = app.staticTexts["My coral cardigan"]
        XCTAssertTrue(project.exists)
        project.swipeLeft()
        app.buttons["Delete My coral cardigan"].tap()
        XCTAssertTrue(app.buttons["Delete My coral cardigan"].waitForExistence(timeout: 3))
        app.buttons["Delete My coral cardigan"].tap()
        XCTAssertTrue(app.staticTexts["Start your first project"].waitForExistence(timeout: 3))
    }

    func testPatternCanBeDeletedFromLibrary() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-libraryDemo", "-skipFirstLaunchSplashForUITests"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 5))
        let pattern = app.staticTexts["Wildflower Cardigan"]
        XCTAssertTrue(pattern.exists)
        pattern.swipeLeft()
        app.buttons["Delete Wildflower Cardigan"].tap()
        XCTAssertTrue(app.buttons["Delete Wildflower Cardigan"].waitForExistence(timeout: 3))
        app.buttons["Delete Wildflower Cardigan"].tap()
        XCTAssertTrue(app.staticTexts["Try your first pattern"].waitForExistence(timeout: 3))
    }

    func testImportedPatternCanBeReviewedEditedAndSaved() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-libraryDemo", "-importReviewDemo", "-skipFirstLaunchSplashForUITests"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Review import"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["review-confidence-1"].exists)
        let instruction = app.descendants(matching: .any)["review-instruction-1"]
        XCTAssertTrue(instruction.exists)
        instruction.tap()
        instruction.typeText(" Checked")
        app.buttons["save-import-review"].tap()
        XCTAssertTrue(app.staticTexts["Pattern ready"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 3))
    }
}
