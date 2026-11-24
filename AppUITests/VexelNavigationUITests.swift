import XCTest

final class VexelNavigationUITests: XCTestCase {
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-vexel.onboarding.complete", "YES"]
        app.launch()
        return app
    }

    func testHomeTabsNavigateBetweenProjectsPresetsAndSettings() {
        let app = launchApp()

        XCTAssertTrue(app.staticTexts["Your workspace"].waitForExistence(timeout: 10))
        app.buttons["home.tab.presets"].tap()
        XCTAssertTrue(app.staticTexts["Start with a preset"].waitForExistence(timeout: 5))
        app.buttons["home.tab.settings"].tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))
        app.buttons["home.tab.projects"].tap()
        XCTAssertTrue(app.staticTexts["Your workspace"].waitForExistence(timeout: 5))
    }

    func testCreatingBlankProjectOpensEditor() {
        let app = launchApp()

        XCTAssertTrue(app.staticTexts["Your workspace"].waitForExistence(timeout: 10))
        app.buttons["home.createProject"].tap()
        XCTAssertTrue(app.textFields["newProject.name"].waitForExistence(timeout: 5))
        app.buttons["newProject.create"].tap()
        XCTAssertTrue(app.staticTexts["Untitled Composition"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Your canvas is empty"].exists)
    }

    func testSelectingPortraitPresetOpensMatchingComposition() {
        let app = launchApp()

        XCTAssertTrue(app.staticTexts["Your workspace"].waitForExistence(timeout: 10))
        app.buttons["home.tab.presets"].tap()
        app.buttons["preset.portrait-video"].tap()
        XCTAssertTrue(app.staticTexts["Portrait video"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Your canvas is empty"].exists)
    }
}
