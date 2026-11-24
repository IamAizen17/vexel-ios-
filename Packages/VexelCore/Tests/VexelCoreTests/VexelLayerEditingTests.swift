import XCTest
@testable import VexelCore

final class VexelLayerEditingTests: XCTestCase {
    func testDuplicateAssignsFreshNestedIDsAndRemapsInternalReferencesOnly() throws {
        let source = VexelLayer(
            id: "group",
            type: .group,
            name: "Scene",
            start: 1,
            duration: 8,
            parent: "external-parent",
            layers: [
                VexelLayer(id: "child-a", type: .shape, name: "A", start: 0, duration: 4),
                VexelLayer(
                    id: "child-b",
                    type: .text,
                    name: "B",
                    start: 1,
                    duration: 3,
                    parent: "child-a",
                    matte: .object(["layer": .string("child-a"), "mode": .string("alpha")])
                )
            ]
        )

        let copy = VexelLayerEditing.duplicate(
            source,
            takenIDs: ["group", "child-a", "child-b", "external-parent"],
            newID: "group-copy",
            idFactory: { type in "\(type.rawValue)-copy" }
        )

        XCTAssertEqual(copy.id, "group-copy")
        XCTAssertEqual(copy.name, "Scene copy")
        XCTAssertEqual(copy.parent, "external-parent")
        XCTAssertEqual(copy.layers.map(\.id), ["shape-copy", "text-copy"])
        XCTAssertEqual(copy.layers[1].parent, "shape-copy")
        XCTAssertEqual(copy.layers[1].matte?.objectValue?["layer"]?.stringValue, "shape-copy")
        XCTAssertEqual(copy.layers[1].matte?.objectValue?["mode"]?.stringValue, "alpha")
        XCTAssertEqual(source.layers[1].parent, "child-a")
        XCTAssertEqual(source.layers[1].matte?.objectValue?["layer"]?.stringValue, "child-a")
    }

    func testSplitMatchesAndroidTimingTransitionsAndMediaInPointSemantics() throws {
        let source = VexelLayer(
            id: "video",
            type: .video,
            name: "Clip",
            start: 1,
            duration: 8,
            transform: VexelTransform(properties: [
                "position": .animated(VexelAnimationTrack(keyframes: [
                    VexelKeyframe(time: 0, value: .array([.number(0), .number(0)])),
                    VexelKeyframe(time: 4, value: .array([.number(100), .number(0)]))
                ]))
            ]),
            transitionIn: .object(["type": .string("fade")]),
            transitionOut: .object(["type": .string("wipe")]),
            content: .object([
                "asset": .string("video-asset"),
                "sourceStart": .number(1),
                "speed": .number(2),
                "volume": .object(["keyframes": .array([
                    .object(["time": .number(0), "value": .number(1)]),
                    .object(["time": .number(4), "value": .number(0)])
                ])])
            ])
        )

        let result = try XCTUnwrap(VexelLayerEditing.split(
            source,
            at: 2,
            takenIDs: ["video", "external"],
            newID: "video-second",
            idFactory: { _ in "nested-\(UUID().uuidString)" }
        ))

        XCTAssertEqual(result.first.id, "video")
        XCTAssertEqual(result.first.start, 1)
        XCTAssertEqual(result.first.duration, 2)
        XCTAssertNotNil(result.first.transitionIn)
        XCTAssertNil(result.first.transitionOut)

        XCTAssertEqual(result.second.id, "video-second")
        XCTAssertEqual(result.second.name, "Clip")
        XCTAssertEqual(result.second.start, 3)
        XCTAssertEqual(result.second.duration, 6)
        XCTAssertNil(result.second.transitionIn)
        XCTAssertNotNil(result.second.transitionOut)
        XCTAssertEqual(result.second.content?.objectValue?["sourceStart"]?.numberValue, 5)

        guard case .animated(let position)? = result.second.transform?.properties["position"] else {
            return XCTFail("The split layer must retain its animated transform.")
        }
        XCTAssertEqual(position.keyframes.map(\.time), [-2, 2])
        XCTAssertEqual(
            result.second.content?.objectValue?["volume"]?.objectValue?["keyframes"]?.arrayValue?.compactMap { $0.objectValue?["time"]?.numberValue },
            [-2, 2]
        )
    }

    func testSplitRejectsBoundaryAndNonFiniteTimes() {
        let source = VexelLayer(id: "shape", type: .shape, start: 0, duration: 2)
        let ids = Set(["shape"])
        let factory: (VexelLayerType) -> String = { _ in UUID().uuidString }
        XCTAssertNil(VexelLayerEditing.split(source, at: 0, takenIDs: ids, newID: "second", idFactory: factory))
        XCTAssertNil(VexelLayerEditing.split(source, at: 2, takenIDs: ids, newID: "second", idFactory: factory))
        XCTAssertNil(VexelLayerEditing.split(source, at: .nan, takenIDs: ids, newID: "second", idFactory: factory))
    }

    func testSplittingGroupShiftsImmediateChildStartsAndRemapsNestedReferences() throws {
        let source = VexelLayer(
            id: "group",
            type: .group,
            name: "Nested",
            start: 0,
            duration: 10,
            layers: [
                VexelLayer(id: "child-a", type: .shape, start: 1, duration: 8),
                VexelLayer(
                    id: "child-b",
                    type: .shape,
                    start: 2,
                    duration: 6,
                    parent: "child-a",
                    matte: .object(["layer": .string("child-a"), "mode": .string("alpha")])
                )
            ]
        )
        var nextID = 0
        let split = try XCTUnwrap(VexelLayerEditing.split(
            source,
            at: 5,
            takenIDs: ["group", "child-a", "child-b"],
            newID: "group-second",
            idFactory: { _ in
                nextID += 1
                return "nested-copy-\(nextID)"
            }
        ))

        XCTAssertEqual(split.first.duration, 5)
        XCTAssertEqual(split.second.start, 5)
        XCTAssertEqual(split.second.duration, 5)
        XCTAssertEqual(split.second.layers.map(\.start), [-4, -3])
        XCTAssertEqual(split.second.layers[1].parent, split.second.layers[0].id)
        XCTAssertEqual(split.second.layers[1].matte?.objectValue?["layer"]?.stringValue, split.second.layers[0].id)
        XCTAssertEqual(source.layers.map(\.start), [1, 2])
    }

}
