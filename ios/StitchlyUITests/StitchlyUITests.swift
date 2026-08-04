import XCTest

@MainActor final class StitchlyUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testProjectReaderJourney() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-projectsDemo", "-resetDemoReaderProgressForUITests", "-skipFirstLaunchSplashForUITests"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Projects"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["DEMO PROJECT"].exists)
        XCTAssertTrue(app.staticTexts["My Fruity Friends"].exists)
        app.staticTexts["My Fruity Friends"].tap()
        XCTAssertTrue(app.navigationBars["Project overview"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["You’re exploring a demo project"].exists)
        app.buttons["continue-project"].tap()
        XCTAssertTrue(app.staticTexts["Row 11"].waitForExistence(timeout: 3))
        let sectionSwitcher = app.buttons["reader-section-switcher"]
        XCTAssertTrue(sectionSwitcher.isHittable)
        XCTAssertTrue(sectionSwitcher.label.contains("APPLE"))
        sectionSwitcher.tap()
        XCTAssertTrue(app.navigationBars["Pattern sections"].waitForExistence(timeout: 3))
        app.buttons["Close sections"].tap()
        XCTAssertTrue(app.buttons["reader-actions"].exists)
        XCTAssertTrue(app.buttons["Next"].isHittable)
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Row 35"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["reader-exit"].isHittable)
        app.buttons["reader-exit"].tap()
        XCTAssertTrue(app.navigationBars["Project overview"].waitForExistence(timeout: 3))
        app.buttons["continue-project"].tap()
        XCTAssertTrue(app.staticTexts["Row 35"].waitForExistence(timeout: 3))
        app.buttons["reader-actions"].tap()
        XCTAssertTrue(app.buttons["reader-original-pdf"].exists)
        app.buttons["reader-sections"].tap()
        XCTAssertTrue(app.navigationBars["Pattern sections"].waitForExistence(timeout: 3))
        try app.performAccessibilityAudit(for: [.contrast, .dynamicType, .hitRegion, .textClipped])
        let finishingSection = app.buttons.matching(NSPredicate(format: "label CONTAINS 'TO MAKE UP'")).firstMatch
        for _ in 0..<12 where !finishingSection.isHittable { app.swipeUp() }
        XCTAssertTrue(finishingSection.isHittable)
        finishingSection.tap()
        XCTAssertTrue(app.staticTexts["Step 80"].waitForExistence(timeout: 3))
        app.buttons["Next"].tap()
        XCTAssertTrue(app.buttons["Finish project"].isHittable)
        app.buttons["Finish project"].tap()
        XCTAssertTrue(app.staticTexts["You finished My Fruity Friends!"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Congratulations — your project is marked complete and stays available with its instructions and notes."].exists)
        app.buttons["completion-done"].tap()
        XCTAssertTrue(app.navigationBars["Project overview"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Completed"].exists)
    }

    func testLibraryJourneyAtLargestDynamicType() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-libraryDemo", "-skipFirstLaunchSplashForUITests", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Fruity Friends"].exists)
        XCTAssertTrue(app.buttons["Import"].isHittable)
        app.staticTexts["Fruity Friends"].tap()
        XCTAssertTrue(app.navigationBars["Pattern overview"].waitForExistence(timeout: 3))
        for _ in 0..<2 where !app.staticTexts["APPLE"].exists { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["APPLE"].waitForExistence(timeout: 3))
    }

    func testNativeAuthenticationScreenIsAccessible() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-resetAuthForUITests", "-skipOnboardingForUITests", "-showAuthForUITests", "-skipFirstLaunchSplashForUITests"]
        app.launch()
        XCTAssertTrue(app.buttons["Continue with Apple"].waitForExistence(timeout: 5))
        let emailChoice = app.buttons["continue-with-email"]
        XCTAssertTrue(emailChoice.isHittable)
        emailChoice.tap()
        let name = app.textFields["Your name"]
        let email = app.textFields["Email address"]
        let password = app.secureTextFields["Password"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        XCTAssertTrue(email.waitForExistence(timeout: 3))
        XCTAssertTrue(password.exists)
        XCTAssertTrue(name.isHittable)
        XCTAssertTrue(email.isHittable)
        XCTAssertTrue(password.isHittable)
        XCTAssertGreaterThanOrEqual(app.buttons["toggle-password-visibility"].frame.height, 44)
        XCTAssertTrue(app.buttons["Create account"].exists)
        let back = app.buttons["back-to-sign-in-options"]
        XCTAssertTrue(back.isHittable)
        XCTAssertGreaterThanOrEqual(back.frame.height, 44)
        try app.performAccessibilityAudit(for: [.contrast, .dynamicType, .hitRegion, .textClipped])
    }

    func testAuthSubmitLoadingStateKeepsTheLargeButtonGeometry() {
        let app = XCUIApplication()
        app.launchArguments = ["-resetAuthForUITests", "-skipOnboardingForUITests", "-showAuthForUITests", "-authSubmittingDemo", "-skipFirstLaunchSplashForUITests"]
        app.launch()
        let submit = app.buttons["auth-submit-button"]
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(submit.frame.height, 44)
        XCTAssertTrue(submit.label.contains("Creating your account"))
    }

    func testAuthenticationFieldsSupportEdgeTapsKeyboardProgressionAndModeSwitching() {
        let app = XCUIApplication()
        app.launchArguments = ["-resetAuthForUITests", "-skipOnboardingForUITests", "-showAuthForUITests", "-skipFirstLaunchSplashForUITests"]
        app.launch()

        let emailChoice = app.buttons["continue-with-email"]
        XCTAssertTrue(emailChoice.waitForExistence(timeout: 5))
        emailChoice.tap()
        let name = app.textFields["Your name"]
        let email = app.textFields["Email address"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        XCTAssertTrue(email.waitForExistence(timeout: 3))
        let modeSwitch = app.buttons["Already have an account? Sign in"]
        XCTAssertTrue(modeSwitch.isHittable)
        modeSwitch.tap()
        XCTAssertTrue(app.buttons["Sign in"].waitForExistence(timeout: 3))
        XCTAssertFalse(name.exists)
        XCTAssertTrue(email.waitForExistence(timeout: 3))
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
        app.buttons["Explore"].tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 3))
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
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 3))
    }

    func testGuestCanBrowseLibraryAndGetsAContextualAccountGate() {
        let app = XCUIApplication()
        app.launchArguments = ["-resetAuthForUITests", "-skipOnboardingForUITests", "-skipFirstLaunchSplashForUITests"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Library"].tap()
        XCTAssertTrue(app.staticTexts["Fruity Friends"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Mini Whale"].exists)
        XCTAssertTrue(app.staticTexts["The Perfect Granny Square"].exists)
        app.staticTexts["Fruity Friends"].tap()
        XCTAssertTrue(app.navigationBars["Pattern overview"].waitForExistence(timeout: 3))
        app.buttons["pattern-original-pdf"].tap()
        XCTAssertTrue(app.navigationBars["Fruity Friends"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()
        app.buttons["start-pattern-project"].tap()
        XCTAssertTrue(app.staticTexts["Create an account to start a project"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Continue with Apple"].exists)
        XCTAssertTrue(app.buttons["continue-with-email"].exists)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Pattern overview"].waitForExistence(timeout: 3))
    }

    func testGuestReaderProgressesAndPersistsLocallyWithoutAuthentication() {
        let app = XCUIApplication()
        app.launchArguments = ["-resetAuthForUITests", "-skipOnboardingForUITests", "-readerDemo", "-resetDemoReaderProgressForUITests", "-skipFirstLaunchSplashForUITests"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Row 11"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Demo project"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["guest-local-progress"].exists)
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Row 35"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Continue with Apple"].exists)

        app.terminate()
        app.launchArguments = ["-resetAuthForUITests", "-skipOnboardingForUITests", "-readerDemo", "-skipFirstLaunchSplashForUITests"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Row 35"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["guest-local-progress"].exists)
    }

    func testReaderPassesAccessibilityAudit() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-readerDemo", "-resetDemoReaderProgressForUITests", "-skipFirstLaunchSplashForUITests"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Row 11"].waitForExistence(timeout: 5))
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
        XCTAssertTrue(app.staticTexts["Row 11"].waitForExistence(timeout: 8))
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
        XCTAssertTrue(app.staticTexts["Fruity Friends"].waitForExistence(timeout: 3))
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
        XCTAssertTrue(app.descendants(matching: .any)["home-feature-strip"].exists)
        XCTAssertTrue(app.staticTexts["DEMO PROJECT"].exists)
        XCTAssertTrue(app.staticTexts["My Fruity Friends"].exists)
        XCTAssertTrue(app.staticTexts["Row 11"].exists)
        app.buttons["resume-current-project"].tap()
        XCTAssertTrue(app.staticTexts["Row 11"].waitForExistence(timeout: 5))
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
        app.buttons["empty-state-primary-action"].tap()
        XCTAssertTrue(app.navigationBars["Projects"].waitForExistence(timeout: 3))
    }

    func testProjectOverviewCanCompleteProject() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-projectsDemo", "-skipFirstLaunchSplashForUITests"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Projects"].waitForExistence(timeout: 5))
        app.staticTexts["My Fruity Friends"].tap()
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
        let project = app.staticTexts["My Fruity Friends"]
        XCTAssertTrue(project.exists)
        project.swipeLeft()
        app.buttons["Delete My Fruity Friends"].tap()
        XCTAssertTrue(app.buttons["Delete My Fruity Friends"].waitForExistence(timeout: 3))
        app.buttons["Delete My Fruity Friends"].tap()
        XCTAssertTrue(app.staticTexts["Start your first project"].waitForExistence(timeout: 3))
    }

    func testPatternCanBeDeletedFromLibrary() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-libraryDemo", "-skipFirstLaunchSplashForUITests"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 5))
        let pattern = app.staticTexts["Fruity Friends"]
        XCTAssertTrue(pattern.exists)
        pattern.swipeLeft()
        app.buttons["Delete Fruity Friends"].tap()
        XCTAssertTrue(app.buttons["Delete Fruity Friends"].waitForExistence(timeout: 3))
        app.buttons["Delete Fruity Friends"].tap()
        XCTAssertTrue(app.staticTexts["Fruity Friends"].waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Mini Whale"].exists)
        XCTAssertTrue(app.staticTexts["The Perfect Granny Square"].exists)
    }

    func testImportedPatternCanBeReviewedEditedAndSaved() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-libraryDemo", "-importReviewDemo", "-skipFirstLaunchSplashForUITests"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Review import"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["review-confidence-1"].exists)
        let instruction = app.descendants(matching: .any)["review-instruction-1"]
        XCTAssertTrue(instruction.exists)
        app.swipeUp()
        for _ in 0..<3 where !instruction.isHittable { app.swipeUp() }
        XCTAssertTrue(instruction.isHittable)
        instruction.tap()
        instruction.typeText(" Checked")
        XCTAssertTrue(String(describing: instruction.value).contains("Checked"))
        app.buttons["save-import-review"].tap()
        XCTAssertTrue(app.staticTexts["Pattern ready"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 3))
    }
}
