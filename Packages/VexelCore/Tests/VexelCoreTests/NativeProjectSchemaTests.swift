import XCTest
@testable import VexelCore

final class NativeProjectSchemaTests: XCTestCase {
    func testTypedSchemaDecodesEveryAndroidLayerDiscriminator() throws {
        let layers: [JSONValue] = VexelLayerType.allCases.map { type in
            var value: [String: JSONValue] = [
                "id": .string(type.rawValue),
                "type": .string(type.rawValue),
                "start": .number(0),
                "duration": .number(2)
            ]
            if let key = type.contentKey { value[key] = .object(["fixture": .string(type.rawValue)]) }
            if type == .group { value["layers"] = .array([]) }
            return .object(value)
        }
        var fields = ProjectDocument.starter(title: "Layer matrix").fields
        fields["layers"] = .array(layers)
        let schema = try VexelNativeProject(document: ProjectDocument(fields: fields))

        XCTAssertEqual(schema.layers.map(\.type), VexelLayerType.allCases)
        for layer in schema.layers where layer.type.contentKey != nil {
            XCTAssertEqual(layer.content?.objectValue?["fixture"]?.stringValue, layer.type.rawValue)
        }
    }

    func testTypedSchemaRoundTripsNestedGroupsAnimatedPropertiesAndUnknownFields() throws {
        let source = """
        {
          "format": "vexelproj",
          "formatVersion": 1,
          "generator": "Vexel",
          "meta": {"title": "Nested"},
          "composition": {
            "width": 1920, "height": 1080, "fps": 29.97, "duration": 12,
            "motionBlur": {"enabled": true, "samples": 8},
            "futureComposition": {"retained": [1, 2, 3]}
          },
          "assets": [{"id": "img", "type": "image", "path": "assets/img.png", "futureAsset": true}],
          "markers": [{"id": "m1", "time": 2, "name": "Beat", "futureMarker": "kept"}],
          "layers": [{
            "id": "group", "type": "group", "start": 0, "duration": 10,
            "futureGroup": {"deep": {"keep": true}},
            "layers": [{
              "id": "shape", "type": "shape", "start": 0, "duration": 5,
              "transform": {
                "position": {
                  "keyframes": [
                    {"time": 0, "value": [0, 0], "easing": "easeInOut"},
                    {"time": 2, "value": [100, 50], "easing": {"cubicBezier": [0.2, 0.1, 0.8, 0.9]}}
                  ],
                  "loop": "cycle",
                  "expression": "time * 2",
                  "futureAnimation": {"kept": 1}
                },
                "opacity": 1
              },
              "shape": {"kind": "rectangle", "futureShape": "kept"},
              "effects": [{"type": "blur", "enabled": true, "radius": 12, "futureEffect": [1, 2]}],
              "masks": [{"type": "path", "futureMask": true}],
              "matte": {"layer": "matte-layer", "mode": "alpha"},
              "transitionIn": {"type": "fade", "duration": 0.5},
              "transitionOut": {"type": "wipe", "duration": 0.5},
              "futureLayer": {"nested": ["survives"]}
            }]
          }],
          "futureRoot": {"feature": {"enabled": true}}
        }
        """.data(using: .utf8)!

        let original = try ProjectDocument(data: source)
        let typed = try VexelNativeProject(document: original)
        XCTAssertEqual(typed.composition.fps, 29.97, accuracy: 0.0001)
        XCTAssertEqual(typed.assets.first?.unknownFields["futureAsset"], .bool(true))
        XCTAssertEqual(typed.markers.first?.unknownFields["futureMarker"], .string("kept"))
        XCTAssertEqual(typed.layers.first?.unknownFields["futureGroup"]?.objectValue?["deep"]?.objectValue?["keep"], .bool(true))
        XCTAssertEqual(typed.layers.first?.layers.first?.content?.objectValue?["futureShape"], .string("kept"))
        XCTAssertEqual(typed.layers.first?.layers.first?.effects.first?.parameters["futureEffect"],
                       .array([.number(1), .number(2)]))
        XCTAssertEqual(typed.layers.first?.layers.first?.transform?.properties["position"], .animated(
            VexelAnimationTrack(
                keyframes: [
                    VexelKeyframe(time: 0, value: .array([.number(0), .number(0)]), easing: .preset("easeInOut")),
                    VexelKeyframe(time: 2, value: .array([.number(100), .number(50)]), easing: .cubicBezier(x1: 0.2, y1: 0.1, x2: 0.8, y2: 0.9))
                ],
                loop: .cycle,
                expression: "time * 2",
                unknownFields: ["futureAnimation": .object(["kept": .number(1)])]
            )
        ))

        let reopened = try typed.projectDocument()
        XCTAssertEqual(reopened.fields["futureRoot"], original.fields["futureRoot"])
        XCTAssertEqual(reopened.fields["composition"]?.objectValue?["futureComposition"], original.fields["composition"]?.objectValue?["futureComposition"])
        XCTAssertEqual(reopened.fields["layers"]?.arrayValue?.first?.objectValue?["layers"]?.arrayValue?.first?.objectValue?["futureLayer"],
                       original.fields["layers"]?.arrayValue?.first?.objectValue?["layers"]?.arrayValue?.first?.objectValue?["futureLayer"])
        XCTAssertEqual(reopened.fields["layers"]?.arrayValue?.first?.objectValue?["layers"]?.arrayValue?.first?.objectValue?["effects"],
                       original.fields["layers"]?.arrayValue?.first?.objectValue?["layers"]?.arrayValue?.first?.objectValue?["effects"])
    }

    func testUnknownLayerDiscriminatorFailsInsteadOfSilentlyDroppingContent() throws {
        let data = """
        {"format":"vexelproj","formatVersion":1,
         "composition":{"width":1080,"height":1920,"fps":30,"duration":5},
         "layers":[{"id":"future","type":"futureLayer","payload":{"keep":true}}]}
        """.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(VexelNativeProject.self, from: data))
    }

    func testTypedAnimationSupportsAndroidLoopModesCyclicEasingAndDisabledExpressions() throws {
        let source = """
        {
          "format": "vexelproj", "formatVersion": 1,
          "composition": {"width": 1080, "height": 1920, "fps": 30, "duration": 5},
          "layers": [{
            "id": "shape", "type": "shape", "duration": 5,
            "transform": {
              "rotation": {
                "keyframes": [{
                  "time": 0, "value": 0,
                  "easing": {"cyclic": {"offset": 0.2, "cycles": 3.5, "phase": 0.1}}
                }],
                "loop": "pingpong",
                "expression": "time",
                "expressionEnabled": false
              }
            }
          }]
        }
        """.data(using: .utf8)!

        let schema = try JSONDecoder().decode(VexelNativeProject.self, from: source)
        guard case .animated(let track)? = schema.layers.first?.transform?.properties["rotation"] else {
            return XCTFail("Expected a typed animated rotation.")
        }
        XCTAssertEqual(track.loop, .pingpong)
        XCTAssertEqual(track.expression, "time")
        XCTAssertEqual(track.expressionEnabled, false)
        XCTAssertEqual(track.keyframes.first?.easing, .cyclic(offset: 0.2, cycles: 3.5, phase: 0.1))

        let roundTrip = try JSONDecoder().decode(
            VexelNativeProject.self,
            from: JSONEncoder().encode(schema)
        )
        XCTAssertEqual(roundTrip, schema)
    }


    func testTypedPayloadAccessorsCoverAllAndroidLayerContentAndAdvancedFields() throws {
        let source = """
        {
          "format": "vexelproj", "formatVersion": 1,
          "meta": {"title": "Payload matrix", "author": "Vexel"},
          "composition": {
            "width": 1080, "height": 1920, "fps": 30, "duration": 8,
            "motionBlur": {"enabled": true, "shutterAngle": 180, "samples": 8},
            "environment": {"asset": "hdr", "intensity": 1.5, "rotation": 30}
          },
          "editorView": {"mode": "editor", "target": [0, 0, 0], "yaw": 20, "pitch": 10, "distance": 2500, "fov": 40},
          "assets": [
            {"id": "img", "type": "image", "path": "assets/image.png"},
            {"id": "video", "type": "video", "path": "assets/video.mp4"},
            {"id": "audio", "type": "audio", "path": "assets/audio.m4a"},
            {"id": "model", "type": "model", "path": "assets/model.glb"},
            {"id": "font", "type": "font", "path": "assets/font.ttf"},
            {"id": "hdr", "type": "image", "path": "assets/hdr.png"}
          ],
          "layers": [
            {"id":"text","type":"text","duration":8,"text":{"content":"Title","font":{"family":"sans-serif","weight":700,"asset":"font"},"fontSize":48,"color":"#FFFFFF","align":"center","lineHeight":1.2,"letterSpacing":0,"maxWidth":800,"animators":[],"propertyAnimators":[]}},
            {"id":"shape","type":"shape","duration":8,"shape":{"kind":"star","size":[300,300],"roundness":4,"sides":5,"innerRatio":0.5,"fill":{"enabled":true}}},
            {"id":"image","type":"image","duration":8,"image":{"asset":"img"}},
            {"id":"video","type":"video","duration":8,"video":{"asset":"video","sourceStart":0.5,"speed":1.25,"volume":1,"muted":false,"fadeIn":0.2,"fadeOut":0.3,"alphaPacked":true,"eq":[],"cutout":{"source":"video","duration":4},"futureMedia":"kept"}},
            {"id":"audio","type":"audio","duration":8,"audio":{"asset":"audio","sourceStart":1,"speed":1,"volume":0.8}},
            {"id":"group","type":"group","duration":8,"layers":[]},
            {"id":"object","type":"object3d","duration":8,"object3d":{"primitive":"cube","size":300,"material":{"metallic":0.5}}},
            {"id":"model","type":"model3d","duration":8,"model3d":{"asset":"model","size":400}},
            {"id":"camera","type":"camera","duration":8,"camera":{"aim":"target","fov":40,"dof":{"enabled":true}}},
            {"id":"light","type":"light","duration":8,"light":{"kind":"directional","intensity":1,"castShadows":true}},
            {"id":"null","type":"null","duration":8,"null":{"threeD":true}}
          ]
        }
        """.data(using: .utf8)!

        let schema = try JSONDecoder().decode(VexelNativeProject.self, from: source)
        XCTAssertEqual(schema.typedMetadata.title, "Payload matrix")
        XCTAssertEqual(schema.typedMetadata.author, "Vexel")
        XCTAssertEqual(schema.composition.typedMotionBlur?.samples, 8)
        XCTAssertEqual(schema.composition.typedEnvironment?.asset, "hdr")
        XCTAssertEqual(schema.typedEditorView?.mode, .editor)
        XCTAssertEqual(schema.layers.count, 11)
        XCTAssertTrue(schema.layers.allSatisfy { $0.typedContent != nil })

        guard case .text(let text)? = schema.layers[0].typedContent else { return XCTFail("Expected typed text content.") }
        XCTAssertEqual(text.content, "Title")
        XCTAssertEqual(text.font?.asset, "font")
        guard case .shape(let shape)? = schema.layers[1].typedContent else { return XCTFail("Expected typed shape content.") }
        XCTAssertEqual(shape.kind, "star")
        guard case .image(let image)? = schema.layers[2].typedContent else { return XCTFail("Expected typed image content.") }
        XCTAssertEqual(image.asset, "img")
        guard case .video(let video)? = schema.layers[3].typedContent else { return XCTFail("Expected typed video content.") }
        XCTAssertEqual(video.sourceStart, 0.5)
        XCTAssertEqual(video.speed, 1.25)
        XCTAssertEqual(video.cutout?.string("source"), "video")
        XCTAssertEqual(video.fields.string("futureMedia"), "kept")
        guard case .audio(let audio)? = schema.layers[4].typedContent else { return XCTFail("Expected typed audio content.") }
        XCTAssertEqual(audio.asset, "audio")
        guard case .group? = schema.layers[5].typedContent else { return XCTFail("Expected typed group content.") }
        guard case .object3D(let object)? = schema.layers[6].typedContent else { return XCTFail("Expected typed object3d content.") }
        XCTAssertEqual(object.primitive, "cube")
        guard case .model3D(let model)? = schema.layers[7].typedContent else { return XCTFail("Expected typed model3d content.") }
        XCTAssertEqual(model.asset, "model")
        guard case .camera(let camera)? = schema.layers[8].typedContent else { return XCTFail("Expected typed camera content.") }
        XCTAssertEqual(camera.aim, "target")
        guard case .light(let light)? = schema.layers[9].typedContent else { return XCTFail("Expected typed light content.") }
        XCTAssertEqual(light.kind, "directional")
        guard case .null(let null)? = schema.layers[10].typedContent else { return XCTFail("Expected typed null content.") }
        XCTAssertEqual(null.is3D, true)

        var maskedLayer = schema.layers[1]
        maskedLayer.masks = [.object(["shape": .string("ellipse"), "mode": .string("subtract"), "enabled": .bool(true)])]
        maskedLayer.matte = .object(["layer": .string("image"), "mode": .string("alpha")])
        maskedLayer.transitionIn = .object(["type": .string("fade"), "duration": .number(0.5)])
        XCTAssertEqual(maskedLayer.typedMasks.first?.shape, "ellipse")
        XCTAssertEqual(maskedLayer.typedMatte?.layerID, "image")
        XCTAssertEqual(maskedLayer.typedTransitionIn?.type, "fade")

        var updatedVideo = schema.layers[3]
        guard case .video(var updatedPayload)? = updatedVideo.typedContent else { return XCTFail("Expected typed video payload.") }
        updatedPayload.fields["sourceStart"] = .number(1.25)
        updatedVideo.typedContent = .video(updatedPayload)
        XCTAssertEqual(updatedVideo.content?.objectValue?["sourceStart"]?.numberValue, 1.25)
        XCTAssertEqual(updatedVideo.content?.objectValue?["futureMedia"]?.stringValue, "kept")
    }

}
