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
        anchorX.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 12) + "42" + XCUIKeyboardKey.return.rawValue)
        XCTAssertEqual(Double(anchorX.value as? String ?? "") ?? .nan, 42, accuracy: 0.01)

        let positionX = app.textFields["inspector.position.x"]
        XCTAssertTrue(positionX.waitForExistence(timeout: 5))
        positionX.tap()
        positionX.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 12) + "64" + XCUIKeyboardKey.return.rawValue)
        XCTAssertEqual(Double(positionX.value as? String ?? "") ?? .nan, 64, accuracy: 0.01)

        let scaleX = app.textFields["inspector.scale.x"]
        XCTAssertTrue(scaleX.waitForExistence(timeout: 5))
        scaleX.tap()
        scaleX.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 12) + "125" + XCUIKeyboardKey.return.rawValue)
        XCTAssertEqual(Double(scaleX.value as? String ?? "") ?? .nan, 125, accuracy: 0.01)

        let rotation = app.textFields["inspector.rotation"]
        XCTAssertTrue(rotation.waitForExistence(timeout: 5))
        rotation.tap()
        rotation.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 12) + "45" + XCUIKeyboardKey.return.rawValue)
        XCTAssertEqual(Double(rotation.value as? String ?? "") ?? .nan, 45, accuracy: 0.01)

        let opacity = app.textFields["inspector.opacity"]
        XCTAssertTrue(opacity.waitForExistence(timeout: 5))
        opacity.tap()
        opacity.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 12) + "75" + XCUIKeyboardKey.return.rawValue)
        XCTAssertEqual(Double(opacity.value as? String ?? "") ?? .nan, 75, accuracy: 0.01)
    }

    func testGraphEditorAddsAndRemovesKeyframeForSelectedProperty() {
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

        app.buttons["Motion"].tap()
        let graph = app.buttons["Graph editor"]
        XCTAssertTrue(graph.waitForExistence(timeout: 5))
        graph.tap()

        let add = app.buttons["keyframe.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        XCTAssertTrue(app.staticTexts["keyframe.time.0.000"].waitForExistence(timeout: 5))

        let remove = app.buttons["keyframe.remove"]
        let enabled = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: remove)
        wait(for: [enabled], timeout: 5)
        remove.tap()
        XCTAssertTrue(app.staticTexts["No keyframes on this property yet."].waitForExistence(timeout: 5))
    }

    func testNewCompositionRestoresLastUsedPresetAndCanResetDefaults() {
        let app = launchApp()

        XCTAssertTrue(app.staticTexts["Your workspace"].waitForExistence(timeout: 10))
        app.buttons["home.createProject"].tap()
        let highFrameRatePreset = app.buttons["preset.high-frame-rate"]
        XCTAssertTrue(highFrameRatePreset.waitForExistence(timeout: 5))
        highFrameRatePreset.tap()
        app.buttons["newProject.create"].tap()

        XCTAssertTrue(app.staticTexts["Your canvas is empty"].waitForExistence(timeout: 10))
        app.buttons["chevron.left"].tap()
        app.buttons["home.createProject"].tap()

        let width = app.textFields["newProject.width"]
        let height = app.textFields["newProject.height"]
        XCTAssertTrue(width.waitForExistence(timeout: 5))
        XCTAssertTrue(height.exists)
        XCTAssertEqual(Int(String((width.value as? String ?? "").filter { $0.isNumber })), 1920)
        XCTAssertEqual(Int(String((height.value as? String ?? "").filter { $0.isNumber })), 1080)
        XCTAssertTrue(app.staticTexts["60 frames per second"].exists)

        app.buttons["newProject.resetDefaults"].tap()
        XCTAssertEqual(Int(String((width.value as? String ?? "").filter { $0.isNumber })), 1080)
        XCTAssertEqual(Int(String((height.value as? String ?? "").filter { $0.isNumber })), 1920)
        XCTAssertTrue(app.staticTexts["30 frames per second"].exists)
    }

    func testSelectingPortraitPresetOpensMatchingComposition() {
        let app = launchApp()

        XCTAssertTrue(app.staticTexts["Your workspace"].waitForExistence(timeout: 10))
        app.buttons["home.tab.presets"].tap()
        app.buttons["preset.portrait-video"].tap()
        XCTAssertTrue(app.staticTexts["Portrait video"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Your canvas is empty"].exists)
    }
    func testTimelineLayerSelectionAndVisibilityControlsAreAccessible() {
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

        XCTAssertTrue(app.descendants(matching: .any)["editor.timeline"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["timeline.snap.toggle"].exists)
        XCTAssertTrue(app.buttons["timeline.zoom.in"].exists)
        XCTAssertTrue(app.buttons["timeline.zoom.out"].exists)
        let layerSelection = app.buttons["Select Rectangle Layer"]
        XCTAssertTrue(layerSelection.waitForExistence(timeout: 5))
        layerSelection.tap()

        let hideLayer = app.buttons["Hide Rectangle Layer"]
        XCTAssertTrue(hideLayer.waitForExistence(timeout: 5))
        hideLayer.tap()
        XCTAssertTrue(app.buttons["Show Rectangle Layer"].waitForExistence(timeout: 5))
    }

    func testInspectorAndPlaybackControlsArePresentInEditor() {
        let app = launchApp()

        XCTAssertTrue(app.staticTexts["Your workspace"].waitForExistence(timeout: 10))
        app.buttons["home.createProject"].tap()
        XCTAssertTrue(app.textFields["newProject.name"].waitForExistence(timeout: 5))
        app.buttons["newProject.create"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["editor.preview"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["editor.playback.toggle"].waitForExistence(timeout: 5))
        app.buttons["Shapes"].tap()
        let rectangle = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Rectangle")).firstMatch
        XCTAssertTrue(rectangle.waitForExistence(timeout: 5))
        rectangle.tap()
        XCTAssertTrue(app.buttons["editor.action.properties"].waitForExistence(timeout: 5))
        app.buttons["editor.action.properties"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["editor.inspector"].waitForExistence(timeout: 5))
    }

    func testLandscapeEditorPlacesPreviewBesideTimeline() {
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }

        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Your workspace"].waitForExistence(timeout: 10))
        app.buttons["home.createProject"].tap()
        XCTAssertTrue(app.textFields["newProject.name"].waitForExistence(timeout: 5))
        app.buttons["newProject.create"].tap()

        let preview = app.descendants(matching: .any)["editor.preview"]
        let timeline = app.descendants(matching: .any)["editor.timeline"]
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        XCTAssertTrue(timeline.waitForExistence(timeout: 5))
        XCTAssertLessThan(preview.frame.midX, timeline.frame.midX)
        XCTAssertTrue(app.buttons["timeline.zoom.in"].exists)
        XCTAssertTrue(app.buttons["editor.playback.toggle"].exists)
    }

}
