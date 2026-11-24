import XCTest
@testable import VexelCore

final class SceneEvaluatorTests: XCTestCase {
    func testEvaluatesInterpolatedTransformKeyframesDeterministically() {
        var document = ProjectDocument.starter()
        document.fields["layers"] = .array([
            .object([
                "id": .string("shape-1"), "type": .string("shape"), "name": .string("Animated shape"),
                "start": .number(0), "duration": .number(10),
                "shape": .object(["kind": .string("rectangle"), "size": .array([.number(100), .number(80)]), "fill": .object(["color": .string("#FFFFFF")])]),
                "transform": .object(["position": .object(["keyframes": .array([
                    .object(["time": .number(0), "value": .array([.number(0), .number(0)])]),
                    .object(["time": .number(10), "value": .array([.number(100), .number(50)])])
                ])])])
            ])
        ])

        let first = SceneEvaluator.evaluate(document, at: 5)
        let second = SceneEvaluator.evaluate(document, at: 5)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.layers.count, 1)
        XCTAssertEqual(first.layers[0].position.x, 50, accuracy: 0.0001)
        XCTAssertEqual(first.layers[0].position.y, 25, accuracy: 0.0001)
        XCTAssertEqual(first.layers[0].localTime, 5, accuracy: 0.0001)
    }

    func testCycleAndPingPongLoopsSampleExpectedLocalTimes() {
        func makeDocument(loop: String) -> ProjectDocument {
            var document = ProjectDocument.starter()
            var composition = document.fields["composition"]?.objectValue ?? [:]
            composition["duration"] = .number(30)
            document.fields["composition"] = .object(composition)
            document.fields["layers"] = .array([
                .object([
                    "id": .string("looped"), "type": .string("shape"), "start": .number(0), "duration": .number(30),
                    "transform": .object(["position": .object([
                        "loop": .string(loop),
                        "keyframes": .array([
                            .object(["time": .number(0), "value": .array([.number(0), .number(0)])]),
                            .object(["time": .number(10), "value": .array([.number(100), .number(0)])])
                        ])
                    ])])
                ])
            ])
            return document
        }

        let cycle = SceneEvaluator.evaluate(makeDocument(loop: "cycle"), at: 12)
        let pingPong = SceneEvaluator.evaluate(makeDocument(loop: "pingpong"), at: 12)

        XCTAssertEqual(cycle.layers.first?.position.x ?? -1, 20, accuracy: 0.0001)
        XCTAssertEqual(pingPong.layers.first?.position.x ?? -1, 80, accuracy: 0.0001)
    }

    func testNegativeLayerAndGroupStartsRetainContainerLocalTiming() {
        var document = ProjectDocument.starter()
        document.fields["layers"] = .array([
            .object([
                "id": .string("group-negative"), "type": .string("group"),
                "start": .number(-2), "duration": .number(8),
                "transform": .object(["position": .array([.number(10), .number(20)])]),
                "layers": .array([
                    .object([
                        "id": .string("child-negative"), "type": .string("shape"),
                        "start": .number(-1), "duration": .number(4),
                        "shape": .object(["kind": .string("rectangle")]),
                        "transform": .object(["position": .array([.number(5), .number(6)])])
                    ])
                ])
            ])
        ])

        let scene = SceneEvaluator.evaluate(document, at: 0)

        XCTAssertEqual(scene.layers.count, 1)
        XCTAssertEqual(scene.layers[0].id, "child-negative")
        XCTAssertEqual(scene.layers[0].localTime, 3, accuracy: 0.0001)
        XCTAssertEqual(scene.layers[0].position.x, 15, accuracy: 0.0001)
        XCTAssertEqual(scene.layers[0].position.y, 26, accuracy: 0.0001)
    }

    func testNestedGroupTransformsAndTimingAreApplied() {
        var document = ProjectDocument.starter()
        document.fields["layers"] = .array([
            .object([
                "id": .string("group-1"), "type": .string("group"), "start": .number(2), "duration": .number(8),
                "transform": .object(["position": .array([.number(10), .number(20)])]),
                "layers": .array([
                    .object([
                        "id": .string("child-1"), "type": .string("shape"), "start": .number(1), "duration": .number(4),
                        "shape": .object(["size": .array([.number(20), .number(20)])]),
                        "transform": .object(["position": .array([.number(5), .number(6)])])
                    ])
                ])
            ])
        ])

        let before = SceneEvaluator.evaluate(document, at: 2.5)
        let active = SceneEvaluator.evaluate(document, at: 4)

        XCTAssertTrue(before.layers.isEmpty)
        XCTAssertEqual(active.layers.count, 1)
        XCTAssertEqual(active.layers[0].id, "child-1")
        XCTAssertEqual(active.layers[0].position.x, 15, accuracy: 0.0001)
        XCTAssertEqual(active.layers[0].position.y, 26, accuracy: 0.0001)
        XCTAssertEqual(active.layers[0].localTime, 1, accuracy: 0.0001)
    }
}
