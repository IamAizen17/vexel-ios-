import XCTest
@testable import VexelCore

final class TimelineEngineTests: XCTestCase {
    func testTimebaseSnapsAndFormatsFrames() throws {
        let timebase = try TimelineTimebase(framesPerSecond: 30, duration: 10)

        XCTAssertEqual(timebase.frameCount, 300)
        XCTAssertEqual(timebase.snap(1.011), 1, accuracy: 0.0001)
        XCTAssertEqual(timebase.timecode(1.5), "00:00:01:15")
        XCTAssertEqual(timebase.clamped(-2), 0)
        XCTAssertEqual(timebase.clamped(12), 10)
    }

    func testMoveSupportsUndoAndRedo() async throws {
        let engine = TimelineEngine(project: project(with: [
            layer("a", start: 0, duration: 2)
        ]))

        _ = try await engine.moveLayer("a", to: 4)
        var current = await engine.snapshot()
        XCTAssertEqual(layer("a", in: current)?["start"]?.numberValue, 4)
        XCTAssertTrue(await engine.canUndo)

        _ = await engine.undo()
        current = await engine.snapshot()
        XCTAssertEqual(layer("a", in: current)?["start"]?.numberValue, 0)
        XCTAssertTrue(await engine.canRedo)

        _ = await engine.redo()
        current = await engine.snapshot()
        XCTAssertEqual(layer("a", in: current)?["start"]?.numberValue, 4)
    }

    func testGroupAndUngroupPreserveAbsoluteTiming() async throws {
        let engine = TimelineEngine(project: project(with: [
            layer("a", start: 1, duration: 2),
            layer("b", start: 2, duration: 3)
        ]))

        let grouped = try await engine.groupLayers(["a", "b"], id: "group-1")
        let group = layer("group-1", in: grouped)
        XCTAssertEqual(group?["start"]?.numberValue, 1)
        XCTAssertEqual(group?["duration"]?.numberValue, 4)
        XCTAssertEqual(group?["layers"]?.arrayValue?.first?.objectValue?["start"]?.numberValue, 0)
        XCTAssertEqual(group?["layers"]?.arrayValue?.last?.objectValue?["start"]?.numberValue, 1)

        let ungrouped = try await engine.ungroup("group-1")
        XCTAssertEqual(layer("a", in: ungrouped)?["start"]?.numberValue, 1)
        XCTAssertEqual(layer("b", in: ungrouped)?["start"]?.numberValue, 2)
    }

    func testDeleteClearsParentAndMatteReferences() async throws {
        var child = layer("child", start: 0, duration: 2).objectValue!
        child["parent"] = .string("parent")
        child["matte"] = .object(["layer": .string("parent"), "type": .string("alpha")])
        let engine = TimelineEngine(project: project(with: [
            layer("parent", start: 0, duration: 2),
            .object(child)
        ]))

        let result = try await engine.deleteLayers(["parent"])
        let remaining = layer("child", in: result)
        XCTAssertNil(remaining?["parent"])
        XCTAssertNil(remaining?["matte"])
    }

    func testDuplicateGroupRemapsNestedIDsAndReferences() async throws {
        let child = layer("child", start: 0, duration: 2).objectValue!
        var parent = layer("group", start: 0, duration: 2).objectValue!
        parent["type"] = .string("group")
        parent["layers"] = .array([
            .object(child),
            .object([
                "id": .string("child-2"),
                "type": .string("null"),
                "parent": .string("child")
            ])
        ])
        let engine = TimelineEngine(project: project(with: [.object(parent)]))

        let result = try await engine.duplicateLayer("group")
        let layers = result.fields["layers"]?.arrayValue ?? []
        XCTAssertEqual(layers.count, 2)
        let originalIDs = Set(["group", "child", "child-2"])
        let duplicate = layers[1].objectValue!
        let duplicateID = duplicate["id"]?.stringValue
        let duplicateChildren = duplicate["layers"]?.arrayValue ?? []
        let duplicateChildIDs = Set(duplicateChildren.compactMap { $0.objectValue?["id"]?.stringValue })

        XCTAssertNotNil(duplicateID)
        XCTAssertFalse(originalIDs.contains(duplicateID ?? ""))
        XCTAssertEqual(duplicateChildren.count, 2)
        XCTAssertTrue(duplicateChildIDs.isDisjoint(with: originalIDs))
        XCTAssertEqual(
            duplicateChildren[1].objectValue?["parent"]?.stringValue,
            duplicateChildren[0].objectValue?["id"]?.stringValue
        )
    }

    func testRejectsGroupingLayersFromDifferentContainers() async throws {
        let group = JSONValue.object([
            "id": .string("container"),
            "type": .string("group"),
            "layers": .array([layer("nested", start: 0, duration: 1)])
        ])
        let engine = TimelineEngine(project: project(with: [
            layer("top", start: 0, duration: 1),
            group
        ]))

        do {
            _ = try await engine.groupLayers(["top", "nested"], id: "invalid-group")
            XCTFail("Expected sibling constraint to be enforced")
        } catch {
            XCTAssertEqual(error as? TimelineError, .layersMustBeSiblings)
        }
    }

    private func project(with layers: [JSONValue]) -> ProjectDocument {
        var project = ProjectDocument.starter()
        project.fields["layers"] = .array(layers)
        return project
    }

    private func layer(_ id: String, start: Double, duration: Double) -> JSONValue {
        .object([
            "id": .string(id),
            "type": .string("shape"),
            "start": .number(start),
            "duration": .number(duration)
        ])
    }

    private func layer(_ id: String, in project: ProjectDocument) -> [String: JSONValue]? {
        func find(_ layers: [JSONValue]) -> [String: JSONValue]? {
            for item in layers {
                guard let object = item.objectValue else { continue }
                if object["id"]?.stringValue == id { return object }
                if let nested = find(object["layers"]?.arrayValue ?? []) { return nested }
            }
            return nil
        }
        return find(project.fields["layers"]?.arrayValue ?? [])
    }
}
