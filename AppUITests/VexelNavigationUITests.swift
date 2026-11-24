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

    func testTransformInspectorCommitsAnchorAndScaleEdits() {
        let app = launchApp()

        XCTAssertTrue(app.staticTexts["Your workspace"].waitForExistence(timeout: 10))
        app.buttons["home.createProject"].tap()
        XCTAssertTrue(app.textFields["newProject.name"].waitForExistence(timeout: 5))
        app.buttons["newProject.create"].tap()
        XCTAssertTrue(app.staticTexts["Your canvas is empty"].waitForExistence(timeout: 10))

        app.buttons["Shapes"].tap()
        let rectangle = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Rectangle")).firstMatch
        XCTAssertTrue(rectangle.waitForExistence(timeout: 5))
        rectangle.tap()

        let properties = app.buttons["Properties"]
        XCTAssertTrue(properties.waitForExistence(timeout: 5))
        properties.tap()

        let anchorX = app.textFields["inspector.anchor.x"]
        XCTAssertTrue(anchorX.waitForExistence(timeout: 5))
        anchorX.tap()
        anchorX.press(forDuration: 1.1)
        if app.menuItems["Select All"].waitForExistence(timeout: 1) {
            app.menuItems["Select All"].tap()
        }
        anchorX.typeText("42")
        anchorX.typeText("\\n")
        XCTAssertEqual(anchorX.value as? String, "42")

        let scaleX = app.textFields["inspector.scale.x"]
        XCTAssertTrue(scaleX.waitForExistence(timeout: 5))
        scaleX.tap()
        scaleX.press(forDuration: 1.1)
        if app.menuItems["Select All"].waitForExistence(timeout: 1) {
            app.menuItems["Select All"].tap()
        }
        scaleX.typeText("125")
        scaleX.typeText("\\n")
        XCTAssertEqual(scaleX.value as? String, "125")
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
