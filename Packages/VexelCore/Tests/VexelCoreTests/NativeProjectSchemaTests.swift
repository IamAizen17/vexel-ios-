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

}
