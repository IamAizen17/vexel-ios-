import XCTest
@testable import VexelCore

final class VexelEditingStoreTests: XCTestCase {
    func testSnapshotReplacementParticipatesInUndoAndRedo() async throws {
        let store = try makeStore()
        let original = await store.snapshot()
        var replacement = original
        replacement.meta["title"] = .string("Replacement")

        try await store.execute(.replaceSnapshot(replacement))
        XCTAssertEqual((await store.snapshot()).meta["title"], .string("Replacement"))

        let didUndo = await store.undo()
        XCTAssertTrue(didUndo)
        XCTAssertEqual((await store.snapshot()).meta["title"], original.meta["title"])

        let didRedo = await store.redo()
        XCTAssertTrue(didRedo)
        XCTAssertEqual((await store.snapshot()).meta["title"], .string("Replacement"))
    }

    func testAddUndoRedoAndCoalescedEdits() async throws {
        let store = try makeStore()
        let shape = VexelLayer(
            id: "shape",
            type: .shape,
            name: "Rectangle",
            start: 0,
            duration: 4,
            content: .object(["kind": .string("rectangle")])
        )

        try await store.execute(.addLayer(shape, containerID: nil, index: nil))
        try await store.execute(.renameLayer(id: "shape", name: "First"), coalescingKey: "rename:shape")
        try await store.execute(.renameLayer(id: "shape", name: "Final"), coalescingKey: "rename:shape")

        var snapshot = await store.snapshot()
        XCTAssertEqual(snapshot.layers.first?.name, "Final")
        let canUndo = await store.canUndo
        XCTAssertTrue(canUndo)
        let didUndo = await store.undo()
        XCTAssertTrue(didUndo)
        snapshot = await store.snapshot()
        XCTAssertEqual(snapshot.layers.first?.name, "Rectangle")

        let didRedo = await store.redo()
        XCTAssertTrue(didRedo)
        snapshot = await store.snapshot()
        XCTAssertEqual(snapshot.layers.first?.name, "Final")

        _ = await store.undo()
        try await store.execute(.renameLayer(id: "shape", name: "Replacement"))
        let canRedo = await store.canRedo
        XCTAssertFalse(canRedo)
        snapshot = await store.snapshot()
        XCTAssertEqual(snapshot.layers.first?.name, "Replacement")
    }

    func testDuplicateAndSplitUseCoreLayerEditingSemantics() async throws {
        let source = VexelLayer(
            id: "clip",
            type: .video,
            name: "Clip",
            start: 1,
            duration: 8,
            content: .object([
                "asset": .string("video-asset"),
                "sourceStart": .number(0),
                "speed": .number(1)
            ])
        )
        var document = ProjectDocument.starter(title: "Media editing")
        document.fields["assets"] = .array([
            .object([
                "id": .string("video-asset"),
                "type": .string("video"),
                "path": .string("assets/video.mp4")
            ])
        ])
        var native = try VexelNativeProject(document: document)
        native.layers = [source]
        let store = try VexelEditingStore(project: native)
        try await store.execute(.duplicateLayer(id: "clip", newID: "clip-copy"))
        try await store.execute(.splitLayer(id: "clip", localTime: 2, newID: "clip-second"))

        let layers = (await store.snapshot()).layers
        XCTAssertEqual(layers.map(\.id), ["clip", "clip-second", "clip-copy"])
        XCTAssertEqual(layers[0].duration, 2)
        XCTAssertEqual(layers[1].start, 3)
        XCTAssertEqual(layers[1].duration, 6)
        XCTAssertEqual(layers[2].name, "Clip copy")
    }

    func testEffectCommandsPreserveParametersAndUndo() async throws {
        let layer = VexelLayer(id: "shape", type: .shape, start: 0, duration: 4, content: .object(["kind": .string("rectangle")]))
        let store = try makeStore(layers: [layer])
        let glow = VexelEffect(type: "glow", parameters: ["radius": .number(12)])
        let blur = VexelEffect(type: "blur", parameters: ["amount": .number(4)])

        try await store.execute(.addEffect(layerID: "shape", effect: glow))
        try await store.execute(.addEffect(layerID: "shape", effect: blur))
        try await store.execute(.removeEffect(layerID: "shape", type: "blur"))

        var snapshot = await store.snapshot()
        XCTAssertEqual(snapshot.layers[0].effects, [glow])

        let didUndo = await store.undo()
        XCTAssertTrue(didUndo)
        snapshot = await store.snapshot()
        XCTAssertEqual(snapshot.layers[0].effects, [glow, blur])
    }

    func testNestedInsertionAndParentCycleProtection() async throws {
        let group = VexelLayer(
            id: "group",
            type: .group,
            name: "Scene",
            start: 0,
            duration: 8,
            layers: [
                VexelLayer(id: "first", type: .shape, start: 0, duration: 8, content: .object(["kind": .string("rectangle")])),
                VexelLayer(id: "second", type: .shape, start: 0, duration: 8, content: .object(["kind": .string("rectangle")]))
            ]
        )
        let store = try makeStore(layers: [group])

        try await store.execute(.setParent(id: "first", parentID: "second"))
        do {
            try await store.execute(.setParent(id: "second", parentID: "first"))
            XCTFail("A parent cycle must be rejected.")
        } catch let error as VexelEditingStoreError {
            guard case .invalidOperation = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        let snapshot = await store.snapshot()
        XCTAssertEqual(snapshot.layers[0].layers[0].parent, "second")
        XCTAssertNil(snapshot.layers[0].layers[1].parent)
    }

    func testGroupAndUngroupPreserveSiblingTimingAndOrder() async throws {
        let first = VexelLayer(id: "first", type: .shape, name: "First", start: 0, duration: 4, content: .object(["kind": .string("rectangle")]))
        let second = VexelLayer(id: "second", type: .shape, name: "Second", start: 2, duration: 5, content: .object(["kind": .string("rectangle")]))
        let store = try makeStore(layers: [first, second])

        try await store.execute(.groupLayers(firstID: "first", secondID: "second", groupID: "group", name: "Scene"))
        var snapshot = await store.snapshot()
        XCTAssertEqual(snapshot.layers.map(\.id), ["group"])
        XCTAssertEqual(snapshot.layers[0].start, 0)
        XCTAssertEqual(snapshot.layers[0].duration, 7)
        XCTAssertEqual(snapshot.layers[0].layers.map(\.id), ["first", "second"])
        XCTAssertEqual(snapshot.layers[0].layers[1].start, 2)

        try await store.execute(.ungroupLayer(id: "group"))
        snapshot = await store.snapshot()
        XCTAssertEqual(snapshot.layers.map(\.id), ["first", "second"])
        XCTAssertEqual(snapshot.layers[1].start, 2)
        XCTAssertEqual(snapshot.layers[1].duration, 5)
    }

    func testUngroupRejectsGroupLevelPropertiesThatWouldBeLost() async throws {
        let group = VexelLayer(
            id: "group",
            type: .group,
            start: 0,
            duration: 4,
            transform: VexelTransform(properties: ["opacity": .constant(.number(0.5))]),
            layers: [VexelLayer(id: "child", type: .shape, start: 0, duration: 4, content: .object(["kind": .string("rectangle")]))]
        )
        let store = try makeStore(layers: [group])

        do {
            try await store.execute(.ungroupLayer(id: "group"))
            XCTFail("Ungrouping must not discard a group transform.")
        } catch let error as VexelEditingStoreError {
            guard case .invalidOperation = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        let snapshot = await store.snapshot()
        XCTAssertEqual(snapshot.layers.first?.id, "group")
    }

    func testThreeDimensionalNullLayerCanParentThreeDimensionalLayers() async throws {
        let parent = VexelLayer(
            id: "null-3d",
            type: .null,
            start: 0,
            duration: 8,
            content: .object(["threeD": .bool(true)])
        )
        let child = VexelLayer(id: "object", type: .object3D, start: 0, duration: 8, content: .object(["primitive": .string("cube")]))
        let store = try makeStore(layers: [parent, child])

        try await store.execute(.setParent(id: "object", parentID: "null-3d"))
        try await store.execute(.setTransformValue(
            id: "null-3d",
            property: "position",
            value: .constant(.array([.number(1), .number(2), .number(3)])),
            is3D: true
        ))

        let snapshot = await store.snapshot()
        XCTAssertEqual(snapshot.layers[1].parent, "null-3d")
        XCTAssertNotNil(snapshot.layers[0].transform3D)
    }

    func testGroupCannotMoveIntoItsOwnDescendant() async throws {
        let group = VexelLayer(
            id: "group",
            type: .group,
            start: 0,
            duration: 8,
            layers: [VexelLayer(id: "child", type: .shape, start: 0, duration: 8, content: .object(["kind": .string("rectangle")]))]
        )
        let store = try makeStore(layers: [group])

        do {
            try await store.execute(.moveLayer(id: "group", toContainerID: "child", index: nil))
            XCTFail("A group cannot move inside one of its descendants.")
        } catch let error as VexelEditingStoreError {
            guard case .invalidOperation = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        let snapshot = await store.snapshot()
        XCTAssertEqual(snapshot.layers.first?.id, "group")
    }

    func testFailedCommandDoesNotMutateProjectOrCreateUndoEntry() async throws {
        let store = try makeStore()
        let before = await store.snapshot()

        do {
            try await store.execute(.setComposition(width: 0, height: 1920, fps: 30, duration: 10))
            XCTFail("Invalid composition settings must be rejected.")
        } catch let error as VexelEditingStoreError {
            guard case .invalidOperation = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        let after = await store.snapshot()
        let canUndo = await store.canUndo
        XCTAssertEqual(after, before)
        XCTAssertFalse(canUndo)
    }

    private func makeStore(layers: [VexelLayer] = []) throws -> VexelEditingStore {
        let document = ProjectDocument.starter(title: "Editing store")
        var native = try VexelNativeProject(document: document)
        native.layers = layers
        return try VexelEditingStore(project: native)
    }
}
