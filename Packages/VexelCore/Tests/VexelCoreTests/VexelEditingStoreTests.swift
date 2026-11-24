import XCTest
@testable import VexelCore

final class VexelEditingStoreTests: XCTestCase {
    func testSnapshotReplacementParticipatesInUndoAndRedo() async throws {
        let store = try makeStore()
        let original = await store.snapshot()
        var replacement = original
        replacement.meta["title"] = .string("Replacement")

        try await store.execute(.replaceSnapshot(replacement))
        var snapshot = await store.snapshot()
        XCTAssertEqual(snapshot.meta["title"], .string("Replacement"))

        let didUndo = await store.undo()
        XCTAssertTrue(didUndo)
        snapshot = await store.snapshot()
        XCTAssertEqual(snapshot.meta["title"], original.meta["title"])

        let didRedo = await store.redo()
        XCTAssertTrue(didRedo)
        snapshot = await store.snapshot()
        XCTAssertEqual(snapshot.meta["title"], .string("Replacement"))
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

    func testTypedKeyframeCommandsPreserveAnimationMetadataAndUndo() async throws {
        let layer = VexelLayer(
            id: "shape",
            type: .shape,
            start: 0,
            duration: 6,
            transform: VexelTransform(properties: [
                "position": .animated(VexelAnimationTrack(
                    keyframes: [VexelKeyframe(time: 0, value: .array([.number(0), .number(0)]))],
                    loop: .cycle,
                    expression: "time",
                    expressionEnabled: false,
                    unknownFields: ["futureTrackFlag": .bool(true)]
                ))
            ]),
            content: .object(["kind": .string("rectangle")])
        )
        let store = try makeStore(layers: [layer])
        let keyframe = VexelKeyframe(
            time: 2,
            value: .array([.number(100), .number(50)]),
            easing: .preset("easeIn")
        )

        try await store.execute(.setKeyframe(layerID: "shape", property: "position", keyframe: keyframe, is3D: false))
        var snapshot = await store.snapshot()
        guard case .animated(let animation)? = snapshot.layers[0].transform?.properties["position"] else {
            return XCTFail("Expected an animated position property.")
        }
        XCTAssertEqual(animation.keyframes.count, 2)
        XCTAssertEqual(animation.loop, .cycle)
        XCTAssertEqual(animation.expression, "time")
        XCTAssertEqual(animation.unknownFields["futureTrackFlag"], .bool(true))

        try await store.execute(.removeKeyframe(layerID: "shape", property: "position", time: 2, is3D: false))
        snapshot = await store.snapshot()
        guard case .animated(let restored)? = snapshot.layers[0].transform?.properties["position"] else {
            return XCTFail("Expected the original animation to remain.")
        }
        XCTAssertEqual(restored.keyframes.count, 1)

        let didUndoKeyframe = await store.undo()
        XCTAssertTrue(didUndoKeyframe)
        snapshot = await store.snapshot()
        guard case .animated(let undone)? = snapshot.layers[0].transform?.properties["position"] else {
            return XCTFail("Expected keyframe undo to restore the previous track.")
        }
        XCTAssertEqual(undone.keyframes.count, 2)
    }

    func testMarkerUpsertUpdatesExistingMarkerWithoutDuplicatingIt() async throws {
        let store = try makeStore()
        try await store.execute(.upsertMarker(VexelMarkerData(id: "marker", time: 1, name: "Original")))
        try await store.execute(.upsertMarker(VexelMarkerData(
            id: "marker",
            time: 2,
            name: "Updated",
            unknownFields: ["extension": .bool(true)]
        )))
        let snapshot = await store.snapshot()
        XCTAssertEqual(snapshot.markers.count, 1)
        XCTAssertEqual(snapshot.markers[0].name, "Updated")
        XCTAssertEqual(snapshot.markers[0].unknownFields["extension"], .bool(true))
    }

    func testKeyframeCommandRejectsTimeOutsideLayerWithoutMutatingHistory() async throws {
        let layer = VexelLayer(id: "shape", type: .shape, start: 0, duration: 2, content: .object(["kind": .string("rectangle")]))
        let store = try makeStore(layers: [layer])
        let before = await store.snapshot()
        do {
            try await store.execute(.setKeyframe(
                layerID: "shape",
                property: "position",
                keyframe: VexelKeyframe(time: 3, value: .array([.number(1), .number(2)])),
                is3D: false
            ))
            XCTFail("Out-of-range keyframes must be rejected.")
        } catch let error as VexelEditingStoreError {
            guard case .invalidOperation = error else { return XCTFail("Unexpected error: \(error)") }
        }
        let after = await store.snapshot()
        let canUndo = await store.canUndo
        XCTAssertEqual(after, before)
        XCTAssertFalse(canUndo)
    }

    func testMarkerCommandsUpsertSortRemoveAndUndo() async throws {
        let store = try makeStore()
        let marker = VexelMarkerData(
            id: "marker-a",
            time: 3,
            name: "Beat",
            color: "#00D6C8",
            unknownFields: ["futureMarkerData": .string("preserve")]
        )
        try await store.execute(.upsertMarker(marker))
        try await store.execute(.upsertMarker(VexelMarkerData(id: "marker-b", time: 1, name: "Intro")))
        var snapshot = await store.snapshot()
        XCTAssertEqual(snapshot.markers.map(\.id), ["marker-b", "marker-a"])
        XCTAssertEqual(snapshot.markers[1].unknownFields["futureMarkerData"], .string("preserve"))

        try await store.execute(.removeMarker(id: "marker-a"))
        snapshot = await store.snapshot()
        XCTAssertEqual(snapshot.markers.map(\.id), ["marker-b"])
        let didUndoRemoval = await store.undo()
        XCTAssertTrue(didUndoRemoval)
        snapshot = await store.snapshot()
        XCTAssertEqual(snapshot.markers.map(\.id), ["marker-b", "marker-a"])
    }

    func testTypedTextPropertyCommandsPreserveNestedFieldsAndAnimationMetadata() async throws {
        let layer = VexelLayer(
            id: "title",
            type: .text,
            start: 0,
            duration: 8,
            content: .object([
                "content": .string("Original"),
                "font": .object([
                    "family": .string("sans-serif"),
                    "weight": .number(700),
                    "italic": .bool(false),
                    "futureFontField": .string("preserve")
                ]),
                "fontSize": .object([
                    "keyframes": .array([
                        .object(["time": .number(0), "value": .number(80)]),
                        .object(["time": .number(3), "value": .number(120)])
                    ]),
                    "value": .number(96),
                    "loop": .string("cycle"),
                    "expression": .string("time"),
                    "expressionEnabled": .bool(false),
                    "futureAnimationFlag": .bool(true)
                ]),
                "futureTextField": .string("preserve")
            ])
        )
        let store = try makeStore(layers: [layer])

        try await store.execute(.setTextProperty(id: "title", property: .content, value: .string("Updated title")))
        try await store.execute(.setTextProperty(id: "title", property: .fontFamily, value: .string("serif")))
        try await store.execute(.setTextProperty(id: "title", property: .fontWeight, value: .number(500)))
        try await store.execute(.setTextProperty(id: "title", property: .fontItalic, value: .bool(true)))
        try await store.execute(.setTextProperty(id: "title", property: .fontSize, value: .number(144)))
        try await store.execute(.setTextProperty(id: "title", property: .lineHeight, value: .number(1.4)))
        try await store.execute(.setTextProperty(id: "title", property: .letterSpacing, value: .number(0.08)))
        try await store.execute(.setTextProperty(id: "title", property: .alignment, value: .string("left")))

        let snapshot = await store.snapshot()
        let fields = VexelObjectFields(snapshot.layers[0].content?.objectValue ?? [:])
        let text = VexelTextContent(fields: fields)
        XCTAssertEqual(text.content, "Updated title")
        XCTAssertEqual(text.font?.family, "serif")
        XCTAssertEqual(text.font?.weight, 500)
        XCTAssertEqual(text.font?.italic, true)
        XCTAssertEqual(text.lineHeight, 1.4)
        XCTAssertEqual(text.letterSpacing, .constant(.number(0.08)))
        XCTAssertEqual(text.align, "left")
        XCTAssertEqual(fields["futureTextField"], .string("preserve"))
        XCTAssertEqual(text.font?.fields["futureFontField"], .string("preserve"))
        guard case .animated(let updatedFontSize)? = text.fontSize else {
            return XCTFail("Editing font size must preserve its animation track.")
        }
        XCTAssertEqual(updatedFontSize.value, .number(144))
        XCTAssertEqual(updatedFontSize.keyframes.count, 2)
        XCTAssertEqual(updatedFontSize.loop, .cycle)
        XCTAssertEqual(updatedFontSize.expression, "time")
        XCTAssertEqual(updatedFontSize.expressionEnabled, false)
        XCTAssertEqual(updatedFontSize.unknownFields["futureAnimationFlag"], .bool(true))
    }

    func testTransformInspectorPropertiesPersistAndUndoForTwoDimensionalLayers() async throws {
        let layer = VexelLayer(
            id: "shape",
            type: .shape,
            start: 0,
            duration: 8,
            content: .object(["kind": .string("rectangle")])
        )
        let store = try makeStore(layers: [layer])

        try await store.execute(.setTransformValue(
            id: "shape", property: "anchor",
            value: .constant(.array([.number(12), .number(-8)])), is3D: false
        ))
        try await store.execute(.setTransformValue(
            id: "shape", property: "scale",
            value: .constant(.array([.number(1.25), .number(0.75)])), is3D: false
        ))
        try await store.execute(.setTransformValue(
            id: "shape", property: "rotation",
            value: .constant(.number(37.5)), is3D: false
        ))
        try await store.execute(.setTransformValue(
            id: "shape", property: "opacity",
            value: .constant(.number(0.65)), is3D: false
        ))

        var snapshot = await store.snapshot()
        XCTAssertEqual(snapshot.layers[0].transform?.properties["anchor"], .constant(.array([.number(12), .number(-8)])))
        XCTAssertEqual(snapshot.layers[0].transform?.properties["scale"], .constant(.array([.number(1.25), .number(0.75)])))
        XCTAssertEqual(snapshot.layers[0].transform?.properties["rotation"], .constant(.number(37.5)))
        XCTAssertEqual(snapshot.layers[0].transform?.properties["opacity"], .constant(.number(0.65)))

        let didUndo = await store.undo()
        XCTAssertTrue(didUndo)
        snapshot = await store.snapshot()
        XCTAssertNil(snapshot.layers[0].transform?.properties["opacity"])

        let didRedo = await store.redo()
        XCTAssertTrue(didRedo)
        snapshot = await store.snapshot()
        XCTAssertEqual(snapshot.layers[0].transform?.properties["opacity"], .constant(.number(0.65)))
    }

    func testTransformValueEditPreservesExistingAnimationTrackMetadata() async throws {
        let animation = VexelAnimationTrack(
            keyframes: [
                VexelKeyframe(time: 0, value: .array([.number(0), .number(0)])),
                VexelKeyframe(time: 4, value: .array([.number(40), .number(20)]))
            ],
            value: .array([.number(0), .number(0)]),
            loop: .pingpong,
            expression: "time",
            expressionEnabled: false,
            unknownFields: ["futureTrackFlag": .bool(true)]
        )
        let layer = VexelLayer(
            id: "shape",
            type: .shape,
            start: 0,
            duration: 8,
            transform: VexelTransform(properties: ["position": .animated(animation)]),
            content: .object(["kind": .string("rectangle")])
        )
        let store = try makeStore(layers: [layer])

        try await store.execute(.setTransformValue(
            id: "shape",
            property: "position",
            value: .constant(.array([.number(100), .number(50)])),
            is3D: false
        ))

        let snapshot = await store.snapshot()
        guard case .animated(let updated)? = snapshot.layers[0].transform?.properties["position"] else {
            return XCTFail("Editing the base value must not replace an animated property.")
        }
        XCTAssertEqual(updated.value, .array([.number(100), .number(50)]))
        XCTAssertEqual(updated.keyframes, animation.keyframes)
        XCTAssertEqual(updated.loop, .pingpong)
        XCTAssertEqual(updated.expression, "time")
        XCTAssertEqual(updated.expressionEnabled, false)
        XCTAssertEqual(updated.unknownFields["futureTrackFlag"], .bool(true))
    }

    func testTransformInspectorPreservesThreeDimensionalComponents() async throws {
        let layer = VexelLayer(
            id: "object",
            type: .object3D,
            start: 0,
            duration: 8,
            content: .object(["primitive": .string("cube")])
        )
        let store = try makeStore(layers: [layer])

        try await store.execute(.setTransformValue(
            id: "object", property: "anchor",
            value: .constant(.array([.number(1), .number(2), .number(3)])), is3D: true
        ))
        try await store.execute(.setTransformValue(
            id: "object", property: "scale",
            value: .constant(.array([.number(1.5), .number(0.75), .number(2)])), is3D: true
        ))
        try await store.execute(.setTransformValue(
            id: "object", property: "rotation",
            value: .constant(.array([.number(10), .number(20), .number(30)])), is3D: true
        ))
        try await store.execute(.setTransformValue(
            id: "object", property: "opacity",
            value: .constant(.number(0.8)), is3D: true
        ))

        let snapshot = await store.snapshot()
        XCTAssertEqual(snapshot.layers[0].transform3D?.properties["anchor"], .constant(.array([.number(1), .number(2), .number(3)])))
        XCTAssertEqual(snapshot.layers[0].transform3D?.properties["scale"], .constant(.array([.number(1.5), .number(0.75), .number(2)])))
        XCTAssertEqual(snapshot.layers[0].transform3D?.properties["rotation"], .constant(.array([.number(10), .number(20), .number(30)])))
        XCTAssertEqual(snapshot.layers[0].transform3D?.properties["opacity"], .constant(.number(0.8)))
    }

    private func makeStore(layers: [VexelLayer] = []) throws -> VexelEditingStore {
        let document = ProjectDocument.starter(title: "Editing store")
        var native = try VexelNativeProject(document: document)
        native.layers = layers
        return try VexelEditingStore(project: native)
    }
}
