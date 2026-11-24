import XCTest
@testable import VexelCore

final class ProjectDocumentTests: XCTestCase {
    func testSourceValidatorParityForMissingPayloadAndIgnoredLayerFeatures() {
        var project = ProjectDocument.starter()
        project.fields["compatibility"] = .object(["source": .string("android-reference")])
        project.fields["layers"] = .array([
            .object([
                "id": .string("missing-text"),
                "type": .string("text"),
                "name": .string("Missing payload"),
                "start": .number(0),
                "duration": .number(4),
                "effects": .array([.object(["type": .string("blur")])]),
                "masks": .array([.object(["id": .string("mask-1")])])
            ]),
            .object([
                "id": .string("ambient"),
                "type": .string("light"),
                "start": .number(0),
                "duration": .number(4),
                "light": .object(["kind": .string("ambient"), "castShadows": .bool(true)])
            ])
        ])

        let issues = project.validate()
        XCTAssertTrue(issues.contains { $0.severity == .warning && $0.path == "layers[0].text" })
        XCTAssertFalse(issues.contains { $0.severity == .error && $0.path == "layers[0].text" })
        XCTAssertTrue(issues.contains { $0.severity == .warning && $0.path == "layers[0].effects" })
        XCTAssertTrue(issues.contains { $0.severity == .warning && $0.path == "layers[0].masks" })
        XCTAssertTrue(issues.contains { $0.severity == .warning && $0.path == "layers[1].light.castShadows" })
    }

    func testSourceValidatorParityFor3DTextRangesAndTextAnimatorTiming() {
        var project = ProjectDocument.starter()
        project.fields["layers"] = .array([
            .object([
                "id": .string("text3d"),
                "type": .string("object3d"),
                "start": .number(0),
                "duration": .number(4),
                "object3d": .object([
                    "primitive": .string("text"),
                    "text": .object([
                        "fontSize": .number(3000),
                        "depth": .number(2),
                        "bevel": .number(2),
                        "lineHeight": .number(0)
                    ])
                ])
            ]),
            .object([
                "id": .string("text"),
                "type": .string("text"),
                "start": .number(0),
                "duration": .number(4),
                "text": .object([
                    "content": .string("A"),
                    "animators": .array([
                        .object(["unitDuration": .number(0), "stagger": .number(-1)])
                    ])
                ])
            ])
        ])

        let errors = Set(project.validate().filter { $0.severity == .error }.map(\.path))
        XCTAssertTrue(errors.contains("layers[0].object3d.text.fontSize"))
        XCTAssertTrue(errors.contains("layers[0].object3d.text.bevel"))
        XCTAssertTrue(errors.contains("layers[0].object3d.text.lineHeight"))
        XCTAssertTrue(errors.contains("layers[1].text.animators[0].unitDuration"))
        XCTAssertTrue(errors.contains("layers[1].text.animators[0].stagger"))
    }

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

    func testNativeV1MigrationAddsV2DefaultsAndPreservesUnknownFields() throws {
        let source = ProjectDocument(fields: [
            "format": .string(ProjectDocument.format),
            "formatVersion": .number(1),
            "composition": .object([
                "width": .number(1080),
                "height": .number(1920),
                "fps": .number(29.97),
                "duration": .number(8)
            ]),
            "futureRoot": .object(["keep": .bool(true)])
        ])

        let migrated = try source.migratedToCurrentVersion()
        XCTAssertEqual(migrated.fields["formatVersion"], .number(Double(ProjectDocument.currentVersion)))
        XCTAssertEqual(migrated.fields["generator"], .string("Vexel"))
        XCTAssertEqual(migrated.title, "Untitled")
        XCTAssertEqual(migrated.fields["assets"], .array([]))
        XCTAssertEqual(migrated.fields["markers"], .array([]))
        XCTAssertEqual(migrated.fields["layers"], .array([]))
        XCTAssertEqual(migrated.fields["composition"]?.objectValue?["background"], .string("#0D0F12"))
        XCTAssertEqual(migrated.fields["composition"]?.objectValue?["fps"], .number(29.97))
        XCTAssertEqual(migrated.fields["futureRoot"], .object(["keep": .bool(true)]))
        XCTAssertTrue(migrated.validate().isEmpty)
    }

    func testNativeMigrationRejectsFutureVersions() throws {
        var source = ProjectDocument.starter()
        source.fields["formatVersion"] = .number(Double(ProjectDocument.currentVersion + 1))
        XCTAssertThrowsError(try source.migratedToCurrentVersion())
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

    func testValidatesCutoutFramesStrokesAndMediaRanges() {
        var project = ProjectDocument.starter(title: "Cutout validation")
        project.fields["assets"] = .array([
            .object(["id": .string("video"), "type": .string("video"), "path": .string("assets/video.mp4")])
        ])
        project.fields["layers"] = .array([
            .object([
                "id": .string("clip"),
                "type": .string("video"),
                "duration": .number(3),
                "video": .object([
                    "asset": .string("video"),
                    "speed": .number(0),
                    "sourceStart": .number(-1),
                    "cutout": .object([
                        "source": .string("video"),
                        "sourceStart": .number(0),
                        "duration": .number(1),
                        "frames": .array([
                            .object([
                                "time": .number(2),
                                "strokes": .array([
                                    .object([
                                        "mode": .string("paint"),
                                        "size": .number(0.8),
                                        "points": .array([.array([.number(1.2), .number(0.5)])])
                                    ])
                                ])
                            ])
                        ])
                    ])
                ])
            ])
        ])

        let paths = Set(project.validate().map(\.path))
        XCTAssertTrue(paths.contains("layers[0].video.speed"))
        XCTAssertTrue(paths.contains("layers[0].video.sourceStart"))
        XCTAssertTrue(paths.contains("layers[0].video.cutout.frames[0].time"))
        XCTAssertTrue(paths.contains("layers[0].video.cutout.frames[0].strokes[0].mode"))
        XCTAssertTrue(paths.contains("layers[0].video.cutout.frames[0].strokes[0].size"))
        XCTAssertTrue(paths.contains("layers[0].video.cutout.frames[0].strokes[0].points[0]"))
    }

    func testValidatesMotionBlurMarkersAndParentCycles() {
        var project = ProjectDocument.starter(title: "Semantic validation")
        var composition = project.fields["composition"]?.objectValue ?? [:]
        composition["motionBlur"] = .object([
            "enabled": .bool(true),
            "samples": .number(65),
            "shutterAngle": .number(721)
        ])
        project.fields["composition"] = .object(composition)
        project.fields["markers"] = .array([
            .object(["id": .string("marker"), "time": .number(1)]),
            .object(["id": .string("marker"), "time": .number(4000)])
        ])
        project.fields["layers"] = .array([
            .object(["id": .string("first"), "type": .string("shape"), "duration": .number(2), "parent": .string("second")]),
            .object(["id": .string("second"), "type": .string("shape"), "duration": .number(2), "parent": .string("first")])
        ])

        let paths = Set(project.validate().map(\.path))
        XCTAssertTrue(paths.contains("composition.motionBlur.samples"))
        XCTAssertTrue(paths.contains("composition.motionBlur.shutterAngle"))
        XCTAssertTrue(paths.contains("markers[1].id"))
        XCTAssertTrue(paths.contains("markers[1].time"))
        XCTAssertTrue(paths.contains("layers.first.parent"))
        XCTAssertTrue(project.validate().contains { $0.message.contains("cycle") })
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
    func testAnimatedNumericEffectParametersValidateBaseAndEveryKeyframe() {
        let catalog = VexelEffectCatalog(version: 1, categories: [], effects: [
            VexelEffectDefinition(id: "exposure", category: "color", englishName: "Exposure",
                target: "any", needsBackdrop: false, parameters: [
                    VexelEffectParameterDefinition(name: "amount", type: .number, minimum: -1, maximum: 1)
                ])
        ])
        var project = ProjectDocument.starter()
        project.fields["layers"] = .array([.object([
            "id": .string("shape"), "type": .string("shape"),
            "shape": .object(["kind": .string("rectangle")]),
            "effects": .array([.object([
                "type": .string("exposure"),
                "amount": .object([
                    "value": .number(0.25),
                    "keyframes": .array([
                        .object(["time": .number(0), "value": .number(0)]),
                        .object(["time": .number(1), "value": .number(1.5)])
                    ])
                ])
            ])])
        ])])

        let issues = project.validate(effectCatalog: catalog)
        XCTAssertTrue(issues.contains {
            $0.severity == .error && $0.path == "layers[0].effects[0].amount.keyframes[1].value"
        })
        XCTAssertFalse(issues.contains { $0.path == "layers[0].effects[0].amount" && $0.severity == .error })
    }

    func testValidatesEditorViewAndSourceShapeLimits() {
        var project = ProjectDocument.starter()
        project.fields["editorView"] = .object([
            "mode": .string("invalid"),
            "target": .array([.number(0), .number(1)]),
            "distance": .number(10),
            "pitch": .number(90),
            "fov": .number(180)
        ])
        project.fields["layers"] = .array([
            .object([
                "id": .string("path"), "type": .string("shape"),
                "shape": .object([
                    "kind": .string("path"),
                    "path": .object(["points": .array([.object(["point": .array([.number(0), .number(0)])])])]),
                    "fill": .object(["gradient": .object(["stops": .array([.object(["offset": .number(0), "color": .string("#000000")])])])])
                ]),
                "masks": .array((0..<5).map { _ in .object([:]) })
            ])
        ])

        let issues = project.validate()
        let errors = Set(issues.filter { $0.severity == .error }.map(\.path))
        XCTAssertTrue(errors.contains("editorView.mode"))
        XCTAssertTrue(errors.contains("editorView.target"))
        XCTAssertTrue(errors.contains("editorView.distance"))
        XCTAssertTrue(errors.contains("editorView.pitch"))
        XCTAssertTrue(errors.contains("editorView.fov"))
        XCTAssertTrue(errors.contains("layers[0].shape.path"))
        XCTAssertTrue(errors.contains("layers[0].shape.fill.gradient.stops"))
        XCTAssertTrue(issues.contains { $0.severity == .warning && $0.path == "layers[0].masks" })
    }

    func testWarnsForLayersEndingBeforeZeroAndKeyframesOutsideLayerTime() {
        var project = ProjectDocument.starter()
        project.fields["layers"] = .array([
            .object([
                "id": .string("offscreen"),
                "type": .string("shape"),
                "start": .number(-8),
                "duration": .number(4),
                "transform": .object([
                    "position": .object([
                        "keyframes": .array([
                            .object(["time": .number(5), "value": .array([.number(0), .number(0)])]),
                            .object(["time": .number(7), "value": .array([.number(10), .number(10)])])
                        ])
                    ])
                ])
            ])
        ])

        let warnings = project.validate().filter { $0.severity == .warning }
        XCTAssertTrue(warnings.contains { $0.path == "layers[0].start" })
        XCTAssertTrue(warnings.contains { $0.path == "layers[0].transform.position.keyframes" })
    }

    func testValidatesSourceLayerContentAndMediaSemantics() {
        var project = ProjectDocument.starter()
        project.fields["layers"] = .array([
            .object(["id": .string("missing-shape"), "type": .string("shape")]),
            .object([
                "id": .string("video-1"), "type": .string("video"),
                "video": .object([
                    "asset": .string("missing-video"),
                    "speed": .number(0),
                    "sourceStart": .number(-1),
                    "eq": .array([.object([
                        "frequency": .number(10), "gain": .number(30), "q": .number(20)
                    ])])
                ])
            ]),
            .object([
                "id": .string("object-3d"), "type": .string("object3d"),
                "object3d": .object([
                    "primitive": .string("cube"),
                    "text": .object([
                        "fontSize": .number(2), "depth": .number(4),
                        "bevel": .number(3), "lineHeight": .number(0)
                    ])
                ])
            ])
        ])

        let issues = project.validate()
        let errors = Set(issues.filter { $0.severity == .error }.map(\.path))
        XCTAssertTrue(errors.contains("layers[0].shape"))
        XCTAssertTrue(errors.contains("layers[1].video.speed"))
        XCTAssertTrue(errors.contains("layers[1].video.sourceStart"))
        XCTAssertTrue(errors.contains("layers[1].video.eq[0]"))
        XCTAssertTrue(errors.contains("layers[2].object3d.text.fontSize"))
        XCTAssertTrue(errors.contains("layers[2].object3d.text.bevel"))
        XCTAssertTrue(errors.contains("layers[2].object3d.text.lineHeight"))
        XCTAssertTrue(issues.contains { $0.severity == .warning && $0.path == "layers[2].object3d.text" })
    }

    func testWarnsForUnsupportedSourceSemantics() {
        var project = ProjectDocument.starter()
        project.fields["layers"] = .array([
            .object([
                "id": .string("ambient"), "type": .string("light"),
                "light": .object(["kind": .string("ambient"), "castShadows": .bool(true)])
            ]),
            .object([
                "id": .string("expression-layer"), "type": .string("null"),
                "expression": .string("time * 2")
            ])
        ])
        let warnings = project.validate().filter { $0.severity == .warning }
        XCTAssertTrue(warnings.contains { $0.path == "layers[0].light.castShadows" })
        XCTAssertTrue(warnings.contains { $0.path == "layers[1].expression" })
    }

    func testWarnsWhenSourceSceneLimitsAreExceeded() {
        var project = ProjectDocument.starter()
        project.fields["layers"] = .array([
            .object(["id": .string("camera-1"), "type": .string("camera")]),
            .object(["id": .string("camera-2"), "type": .string("camera")]),
            .object(["id": .string("light-1"), "type": .string("light")]),
            .object(["id": .string("light-2"), "type": .string("light")]),
            .object(["id": .string("light-3"), "type": .string("light")]),
            .object(["id": .string("light-4"), "type": .string("light")]),
            .object(["id": .string("light-5"), "type": .string("light")])
        ])
        let issues = project.validate()
        XCTAssertTrue(issues.contains { $0.severity == .warning && $0.message.contains("Multiple camera") })
        XCTAssertTrue(issues.contains { $0.severity == .warning && $0.message.contains("four lights") })
    }

    func testEffectInstanceParametersAreValidatedAgainstCanonicalDefinitions() {
        let catalog = VexelEffectCatalog(version: 1, categories: [], effects: [
            VexelEffectDefinition(id: "brightness", category: "color", englishName: "Brightness", target: "any",
                needsBackdrop: false, parameters: [
                    VexelEffectParameterDefinition(name: "amount", type: .number, minimum: 0, maximum: 1),
                    VexelEffectParameterDefinition(name: "enabled", type: .boolean),
                    VexelEffectParameterDefinition(name: "mode", type: .choice, choices: ["soft", "hard"]),
                    VexelEffectParameterDefinition(name: "center", type: .point),
                    VexelEffectParameterDefinition(name: "stops", type: .stops)
                ])
        ])
        var project = ProjectDocument.starter()
        project.fields["layers"] = .array([.object([
            "id": .string("shape"), "type": .string("shape"),
            "shape": .object(["kind": .string("rectangle")]),
            "effects": .array([
                .object(["type": .string("brightness"), "amount": .number(1.5), "enabled": .string("yes"),
                    "mode": .string("invalid"), "center": .array([.number(0)]),
                    "stops": .array([.object(["offset": .number(2), "color": .string("#FFFFFF")])]),
                    "futureParameter": .number(1)]),
                .object(["type": .string("futureEffect"), "opaque": .bool(true)])
            ])
        ])])

        let issues = project.validate(effectCatalog: catalog)
        XCTAssertEqual(Set(issues.filter { $0.severity == .error }.map(\.path)), Set([
            "layers[0].effects[0].amount", "layers[0].effects[0].enabled",
            "layers[0].effects[0].mode", "layers[0].effects[0].center", "layers[0].effects[0].stops"
        ]))
        XCTAssertTrue(issues.contains { $0.severity == .warning && $0.path == "layers[0].effects[0].futureParameter" })
        XCTAssertTrue(issues.contains { $0.severity == .warning && $0.path == "layers[0].effects[1].type" })
    }

    func testValidEffectInstanceParametersPassCanonicalValidation() {
        let catalog = VexelEffectCatalog(version: 1, categories: [], effects: [
            VexelEffectDefinition(id: "gradientMap", category: "color", englishName: "Gradient Map",
                target: "any", needsBackdrop: false, parameters: [
                    VexelEffectParameterDefinition(name: "amount", type: .number, minimum: 0, maximum: 1),
                    VexelEffectParameterDefinition(name: "stops", type: .stops)
                ])
        ])
        var project = ProjectDocument.starter()
        project.fields["layers"] = .array([.object([
            "id": .string("shape"), "type": .string("shape"),
            "shape": .object(["kind": .string("rectangle")]),
            "effects": .array([.object([
                "type": .string("gradientMap"), "amount": .number(0.75),
                "stops": .array([
                    .object(["offset": .number(0), "color": .string("#000000")]),
                    .object(["offset": .number(1), "color": .string("#FFFFFF")])
                ])
            ])])
        ])])
        XCTAssertTrue(project.validate(effectCatalog: catalog).isEmpty)
    }
    func testIntegerEffectParametersRequireWholeNumbersAndRemainAnimatable() {
        let catalog = VexelEffectCatalog(version: 1, categories: [], effects: [
            VexelEffectDefinition(id: "depthMap", category: "utility", englishName: "Depth Map",
                target: "layer_3d", needsBackdrop: false, parameters: [
                    VexelEffectParameterDefinition(name: "samples", type: .integer, minimum: 1, maximum: 16)
                ])
        ])
        func project(value: JSONValue) -> ProjectDocument {
            var document = ProjectDocument.starter()
            document.fields["layers"] = .array([.object([
                "id": .string("shape"), "type": .string("object3d"),
                "object3d": .object(["primitive": .string("cube")]),
                "effects": .array([.object([
                    "type": .string("depthMap"),
                    "samples": value
                ])])
            ])])
            return document
        }

        let valid = project(value: .object([
            "keyframes": .array([
                .object(["time": .number(0), "value": .number(2)]),
                .object(["time": .number(1), "value": .number(4)])
            ])
        ]))
        XCTAssertFalse(valid.validate(effectCatalog: catalog).contains { $0.severity == .error })

        let invalidStatic = project(value: .number(2.5))
        XCTAssertTrue(invalidStatic.validate(effectCatalog: catalog).contains {
            $0.severity == .error && $0.path == "layers[0].effects[0].samples"
        })

        let invalidAnimated = project(value: .object([
            "keyframes": .array([
                .object(["time": .number(0), "value": .number(2.5)]),
                .object(["time": .number(1), "value": .number(4)])
            ])
        ]))
        XCTAssertTrue(invalidAnimated.validate(effectCatalog: catalog).contains {
            $0.severity == .error && $0.path == "layers[0].effects[0].samples.keyframes[0].value"
        })
        XCTAssertTrue(invalidStatic.validate(effectCatalog: catalog).contains {
            $0.severity == .warning && $0.path == "layers[0].effects[0].type"
        })
    }

}
