import XCTest
@testable import VexelCore

final class ProjectDocumentTests: XCTestCase {
    func testStableSourceIdentifierMappingIsDeterministicAndPreservesUUIDs() {
        let sourceID = "android-layer-α-42"
        let first = VexelStableIdentifier.uuid(forSourceID: sourceID)
        let second = VexelStableIdentifier.uuid(forSourceID: sourceID)
        XCTAssertEqual(first, second)
        XCTAssertNotEqual(first, VexelStableIdentifier.uuid(forSourceID: "android-layer-α-43"))

        let existing = UUID()
        XCTAssertEqual(VexelStableIdentifier.uuid(forSourceID: existing.uuidString), existing)
    }

    func testStarterProjectIsValid() {
        let project = ProjectDocument.starter(title: "First Cut")
        XCTAssertTrue(project.validate().isEmpty)
        XCTAssertEqual(project.title, "First Cut")
        XCTAssertEqual(project.compositionSize.width, 1080)
        XCTAssertEqual(project.compositionSize.height, 1920)
    }

    func testUnknownFieldsSurviveDecodeAndEncode() throws {
        let source = """
        {
          "format": "vexelproj",
          "formatVersion": 1,
          "meta": {"title": "Preserved"},
          "composition": {"width": 1920, "height": 1080, "fps": 60, "duration": 5},
          "layers": [],
          "futureFeature": {"custom": [1, true, null, "kept"]}
        }
        """.data(using: .utf8)!

        let project = try ProjectDocument(data: source)
        let roundTrip = try ProjectDocument(data: project.encoded())
        XCTAssertEqual(roundTrip.fields["futureFeature"], project.fields["futureFeature"])
        XCTAssertEqual(roundTrip.title, "Preserved")
    }

    func testRejectsUnsafeAssetPaths() {
        var project = ProjectDocument.starter()
        project.fields["assets"] = .array([
            .object(["id": .string("bad"), "path": .string("assets/../../secret.png")])
        ])
        XCTAssertTrue(project.validate().contains { $0.path == "assets[0].path" })
    }

    func testRejectsDuplicateLayerIdentifiersIncludingGroups() {
        var project = ProjectDocument.starter()
        project.fields["layers"] = .array([
            .object([
                "id": .string("same"),
                "type": .string("group"),
                "layers": .array([.object(["id": .string("same"), "type": .string("text")])])
            ])
        ])
        XCTAssertTrue(project.validate().contains { $0.message.contains("unique") })
    }

    func testRejectsUnsupportedVersion() {
        var project = ProjectDocument.starter()
        project.fields["formatVersion"] = .number(99)
        XCTAssertEqual(project.validate().first?.path, "formatVersion")
    }


    func testRejectsNonFiniteNumbersRecursively() {
        var project = ProjectDocument.starter()
        project.fields["layers"] = .array([
            .object([
                "id": .string("numeric"),
                "type": .string("shape"),
                "duration": .number(5),
                "transform": .object([
                    "position": .array([.number(.nan), .number(0)])
                ]),
                "futureNested": .object(["value": .number(.infinity)])
            ])
        ])

        let issues = project.validate()
        XCTAssertTrue(issues.contains { $0.path == "$.layers[0].transform.position[0]" })
        XCTAssertTrue(issues.contains { $0.path == "$.layers[0].futureNested.value" })
    }

    func testCompositionSizeUsesSafeFallbackForNonFiniteAndOutOfRangeValues() {
        var project = ProjectDocument.starter()
        var composition = project.fields["composition"]?.objectValue ?? [:]
        composition["width"] = .number(.infinity)
        composition["height"] = .number(1e100)
        project.fields["composition"] = .object(composition)

        XCTAssertEqual(project.compositionSize.width, 1080)
        XCTAssertEqual(project.compositionSize.height, 1920)
        XCTAssertTrue(project.validate().contains { $0.path == "$.composition.width" })
    }


    func testValidatesAssetReferencesAndExpectedAssetTypesRecursively() {
        var project = ProjectDocument.starter()
        project.fields["assets"] = .array([
            .object(["id": .string("photo"), "type": .string("image"), "path": .string("assets/photo.png")]),
            .object(["id": .string("font"), "type": .string("font"), "path": .string("assets/font.ttf")])
        ])
        project.fields["layers"] = .array([
            .object([
                "id": .string("group"),
                "type": .string("group"),
                "layers": .array([
                    .object([
                        "id": .string("text"),
                        "type": .string("text"),
                        "text": .object(["font": .object(["asset": .string("photo")])])
                    ]),
                    .object([
                        "id": .string("image"),
                        "type": .string("image"),
                        "image": .object(["asset": .string("missing")])
                    ])
                ])
            ])
        ])

        let issues = project.validate()
        XCTAssertTrue(issues.contains { $0.path == "layers[0].layers[0].text.font.asset" && $0.message.contains("font") })
        XCTAssertTrue(issues.contains { $0.path == "layers[0].layers[1].image.asset" && $0.message.contains("does not exist") })
    }

    func testSceneEvaluatorProducesVisibleShapeLayers() {
        var project = ProjectDocument.starter(title: "Scene")
        project.fields["layers"] = .array([
            .object([
                "id": .string("shape-1"),
                "type": .string("shape"),
                "name": .string("Rectangle"),
                "start": .number(0),
                "duration": .number(5),
                "visible": .bool(true),
                "transform": .object([
                    "position": .array([.number(20), .number(-10)]),
                    "scale": .array([.number(1), .number(1)]),
                    "rotation": .number(0),
                    "opacity": .number(1)
                ]),
                "shape": .object([
                    "kind": .string("rectangle"),
                    "size": .array([.number(300), .number(120)]),
                    "fill": .object(["color": .string("#55CDBE")])
                ])
            ])
        ])

        let scene = SceneEvaluator.evaluate(project, at: 1)
        XCTAssertEqual(scene.layers.count, 1)
        XCTAssertEqual(scene.layers[0].id, "shape-1")
        XCTAssertEqual(scene.layers[0].position, ScenePoint(x: 20, y: -10))
        XCTAssertEqual(scene.layers[0].size, ScenePoint(x: 300, y: 120))
        XCTAssertEqual(scene.layers[0].fillColor, "#55CDBE")
    }

    func testSceneEvaluatorInterpolatesAnimatedTransformValues() {
        var project = ProjectDocument.starter(title: "Animated scene")
        project.fields["layers"] = .array([
            .object([
                "id": .string("animated"),
                "type": .string("shape"),
                "start": .number(0),
                "duration": .number(4),
                "transform": .object([
                    "position": .object([
                        "keyframes": .array([
                            .object(["time": .number(0), "value": .array([.number(0), .number(0)])]),
                            .object(["time": .number(2), "value": .array([.number(100), .number(40)])])
                        ])
                    ]),
                    "opacity": .object([
                        "keyframes": .array([
                            .object(["time": .number(0), "value": .number(0)]),
                            .object(["time": .number(2), "value": .number(1)])
                        ])
                    ])
                ]),
                "shape": .object(["kind": .string("ellipse"), "size": .array([.number(80), .number(80)])])
            ])
        ])

        let scene = SceneEvaluator.evaluate(project, at: 1)
        XCTAssertEqual(scene.layers.first?.position, ScenePoint(x: 50, y: 20))
        XCTAssertEqual(scene.layers.first?.opacity ?? -1, 0.5, accuracy: 0.0001)
    }

    func testSceneEvaluatorComposesNestedGroupTransformsAndOffsets() {
        var project = ProjectDocument.starter(title: "Nested scene")
        project.fields["layers"] = .array([
            .object([
                "id": .string("group"),
                "type": .string("group"),
                "start": .number(1),
                "duration": .number(5),
                "transform": .object(["position": .array([.number(10), .number(5)])]),
                "layers": .array([
                    .object([
                        "id": .string("child"),
                        "type": .string("shape"),
                        "start": .number(0),
                        "duration": .number(3),
                        "transform": .object(["position": .array([.number(5), .number(2)])]),
                        "shape": .object(["kind": .string("rectangle")])
                    ])
                ])
            ])
        ])

        let scene = SceneEvaluator.evaluate(project, at: 2)
        XCTAssertEqual(scene.layers.first?.position, ScenePoint(x: 15, y: 7))
        XCTAssertTrue(SceneEvaluator.evaluate(project, at: 0.5).layers.isEmpty)
    }

    func testSceneEvaluatorResolvesParentTransforms() {
        var project = ProjectDocument.starter(title: "Parent transforms")
        project.fields["layers"] = .array([
            .object([
                "id": .string("null-parent"),
                "type": .string("null"),
                "start": .number(0),
                "duration": .number(5),
                "transform": .object(["position": .array([.number(20), .number(10)])])
            ]),
            .object([
                "id": .string("child"),
                "type": .string("shape"),
                "parent": .string("null-parent"),
                "start": .number(0),
                "duration": .number(5),
                "transform": .object(["position": .array([.number(5), .number(3)])]),
                "shape": .object(["kind": .string("rectangle")])
            ])
        ])

        let scene = SceneEvaluator.evaluate(project, at: 1)
        XCTAssertEqual(scene.layers.count, 1)
        XCTAssertEqual(scene.layers.first?.position, ScenePoint(x: 25, y: 13))
    }

    func testSceneEvaluatorAppliesKeyframeLoopAndPresetEasing() {
        var project = ProjectDocument.starter(title: "Looped animation")
        project.fields["layers"] = .array([
            .object([
                "id": .string("looped"),
                "type": .string("shape"),
                "start": .number(0),
                "duration": .number(5),
                "transform": .object([
                    "position": .object([
                        "loop": .string("cycle"),
                        "keyframes": .array([
                            .object([
                                "time": .number(0),
                                "value": .array([.number(0), .number(0)]),
                                "easing": .string("easeInOut")
                            ]),
                            .object([
                                "time": .number(1),
                                "value": .array([.number(100), .number(0)])
                            ])
                        ])
                    ])
                ]),
                "shape": .object(["kind": .string("rectangle")])
            ])
        ])

        let scene = SceneEvaluator.evaluate(project, at: 1.5)
        XCTAssertEqual(scene.layers.first?.position.x ?? -1, 50, accuracy: 0.1)
    }

    func testNativeDocumentRejectsForeignFormatIdentifiers() {
        let project = ProjectDocument(fields: [
            "format": .string("foreign-format"),
            "formatVersion": .number(1)
        ])
        XCTAssertEqual(project.validate().first?.path, "format")
    }
}
