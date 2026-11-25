import XCTest
import UIKit

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
        XCTAssertTrue(app.descendants(matching: .any)["editor.inspector.sheet"].waitForExistence(timeout: 5))
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
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCTAssertLessThan(preview.frame.midY, timeline.frame.midY)
        } else {
            XCTAssertLessThan(preview.frame.midX, timeline.frame.midX)
        }
        XCTAssertTrue(app.buttons["timeline.zoom.in"].exists)
        XCTAssertTrue(app.buttons["editor.playback.toggle"].exists)
    }

    func testInEditorCompositionSettingsBecomeTheNextProjectDefaults() {
        let app = launchApp()

        XCTAssertTrue(app.staticTexts["Your workspace"].waitForExistence(timeout: 10))
        app.buttons["home.createProject"].tap()
        XCTAssertTrue(app.textFields["newProject.name"].waitForExistence(timeout: 5))
        app.buttons["newProject.create"].tap()

        app.buttons["editor.composition.settings"].tap()
        let frameRate = app.steppers["compositionSettings.fps"]
        XCTAssertTrue(frameRate.waitForExistence(timeout: 5))
        frameRate.buttons["Increment"].tap()
        app.buttons["compositionSettings.save"].tap()
        XCTAssertTrue(app.staticTexts["1080 × 1920 · 31 FPS"].waitForExistence(timeout: 5))

        app.buttons["chevron.left"].tap()
        app.buttons["home.createProject"].tap()
        XCTAssertTrue(app.buttons["newProject.fps.31"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["31 frames per second"].exists)
        app.buttons["newProject.resetDefaults"].tap()
        app.buttons["Cancel"].tap()
    }

    func testTappingTimelineClipSelectsItsLayer() {
        let app = launchApp()

        XCTAssertTrue(app.staticTexts["Your workspace"].waitForExistence(timeout: 10))
        app.buttons["home.createProject"].tap()
        XCTAssertTrue(app.textFields["newProject.name"].waitForExistence(timeout: 5))
        app.buttons["newProject.create"].tap()
        app.buttons["Shapes"].tap()
        let rectangle = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Rectangle")).firstMatch
        XCTAssertTrue(rectangle.waitForExistence(timeout: 5))
        rectangle.tap()

        let clip = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "timeline.clip."))
            .firstMatch
        XCTAssertTrue(clip.waitForExistence(timeout: 5))
        clip.tap()
        XCTAssertEqual(clip.value as? String, "Selected")
    }

    func testPresetLibrarySelectionPersistsCompositionDefaults() {
        let app = launchApp()

        XCTAssertTrue(app.staticTexts["Your workspace"].waitForExistence(timeout: 10))
        app.buttons["home.tab.presets"].tap()
        app.buttons["preset.high-frame-rate"].tap()
        XCTAssertTrue(app.staticTexts["High frame rate"].waitForExistence(timeout: 10))
        app.buttons["chevron.left"].tap()
        app.buttons["home.createProject"].tap()
        XCTAssertTrue(app.textFields["newProject.width"].waitForExistence(timeout: 5))

        XCTAssertEqual(Int(String((app.textFields["newProject.width"].value as? String ?? "").filter { $0.isNumber })), 1920)
        XCTAssertEqual(Int(String((app.textFields["newProject.height"].value as? String ?? "").filter { $0.isNumber })), 1080)
        XCTAssertTrue(app.staticTexts["60 frames per second"].exists)
        app.buttons["newProject.resetDefaults"].tap()
        app.buttons["Cancel"].tap()
    }


    func testLayerPanelVisibilityAndLockControlsCommitToTheProject() {
        let app = launchApp()

        XCTAssertTrue(app.staticTexts["Your workspace"].waitForExistence(timeout: 10))
        app.buttons["home.createProject"].tap()
        XCTAssertTrue(app.textFields["newProject.name"].waitForExistence(timeout: 5))
        app.buttons["newProject.create"].tap()
        app.buttons["Shapes"].tap()
        let rectangle = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Rectangle")).firstMatch
        XCTAssertTrue(rectangle.waitForExistence(timeout: 5))
        rectangle.tap()

        XCTAssertTrue(app.buttons["Select Rectangle Layer"].waitForExistence(timeout: 5))
        app.buttons["editor.tool.layers"].tap()
        let visibility = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "layers.visibility.")).firstMatch
        XCTAssertTrue(visibility.waitForExistence(timeout: 5))
        visibility.tap()
        XCTAssertTrue(app.buttons["Show Rectangle Layer"].waitForExistence(timeout: 5))

        let lock = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "layers.lock.")).firstMatch
        XCTAssertTrue(lock.waitForExistence(timeout: 5))
        lock.tap()
        XCTAssertTrue(app.buttons["Unlock Rectangle Layer"].waitForExistence(timeout: 5))
    }


    func testPreviewTimecodeReflectsTransportPosition() {
        let app = launchApp()

        XCTAssertTrue(app.staticTexts["Your workspace"].waitForExistence(timeout: 10))
        app.buttons["home.createProject"].tap()
        XCTAssertTrue(app.textFields["newProject.name"].waitForExistence(timeout: 5))
        app.buttons["newProject.create"].tap()

        let timecode = app.staticTexts["editor.timecode"]
        XCTAssertTrue(timecode.waitForExistence(timeout: 5))
        XCTAssertEqual(timecode.label, "00:00:00:00")
        app.buttons["editor.time.forwardFive"].tap()
        XCTAssertEqual(timecode.label, "00:00:05:00")
    }

    func testIPadEditorKeepsTheInspectorVisibleBesideTheWorkspace() {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return }

        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Your workspace"].waitForExistence(timeout: 10))
        app.buttons["home.createProject"].tap()
        XCTAssertTrue(app.textFields["newProject.name"].waitForExistence(timeout: 5))
        app.buttons["newProject.create"].tap()

        let inspector = app.descendants(matching: .any)["editor.inspector"]
        XCTAssertTrue(inspector.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["editor.preview"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["editor.timeline"].exists)
    }


    func testTimelineRulerScrubbingUpdatesFrameTimecode() {
        let app = launchApp()

        XCTAssertTrue(app.staticTexts["Your workspace"].waitForExistence(timeout: 10))
        app.buttons["home.createProject"].tap()
        XCTAssertTrue(app.textFields["newProject.name"].waitForExistence(timeout: 5))
        app.buttons["newProject.create"].tap()

        let timecode = app.staticTexts["editor.timecode"]
        XCTAssertTrue(timecode.waitForExistence(timeout: 5))
        let ruler = app.descendants(matching: .any)["timeline.ruler"]
        XCTAssertTrue(ruler.waitForExistence(timeout: 5))
        ruler.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.5)).tap()
        XCTAssertNotEqual(timecode.label, "00:00:00:00")
    }

    func testTimelineTrimHandleChangesClipDuration() {
        let app = launchApp()

        XCTAssertTrue(app.staticTexts["Your workspace"].waitForExistence(timeout: 10))
        app.buttons["home.createProject"].tap()
        XCTAssertTrue(app.textFields["newProject.name"].waitForExistence(timeout: 5))
        app.buttons["newProject.create"].tap()
        app.buttons["Shapes"].tap()
        let rectangle = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Rectangle")).firstMatch
        XCTAssertTrue(rectangle.waitForExistence(timeout: 5))
        rectangle.tap()

        let zoomOut = app.buttons["timeline.zoom.out"]
        XCTAssertTrue(zoomOut.waitForExistence(timeout: 5))
        for _ in 0..<5 { zoomOut.tap() }

        let clip = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "timeline.clip."))
            .firstMatch
        XCTAssertTrue(clip.waitForExistence(timeout: 5))
        let initialWidth = clip.frame.width
        let trimHandle = clip.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5))
        let trimTarget = clip.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5))
        trimHandle.press(forDuration: 0.2, thenDragTo: trimTarget)
        XCTAssertLessThan(clip.frame.width, initialWidth - 10)
    }


}
