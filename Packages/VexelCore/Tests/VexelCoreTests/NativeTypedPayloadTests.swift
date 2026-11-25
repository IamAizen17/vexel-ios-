import XCTest
@testable import VexelCore

final class NativeTypedPayloadTests: XCTestCase {
    func testVectorTuplesDecodeEncodeAndRejectMalformedCoordinates() throws {
        let vector2 = try JSONDecoder().decode(VexelVector2.self, from: Data("[12.5,-4]".utf8))
        XCTAssertEqual(vector2, VexelVector2(x: 12.5, y: -4))
        XCTAssertEqual(String(data: try JSONEncoder().encode(vector2), encoding: .utf8), "[12.5,-4]")

        let vector3 = try JSONDecoder().decode(VexelVector3.self, from: Data("[1,2,3]".utf8))
        XCTAssertEqual(vector3, VexelVector3(x: 1, y: 2, z: 3))
        XCTAssertThrowsError(try JSONDecoder().decode(VexelVector2.self, from: Data("[1]".utf8)))
        XCTAssertThrowsError(try JSONDecoder().decode(VexelVector3.self, from: Data("[1,2,3,4]".utf8)))
    }

    func testGradientAndPathExposeTypedCoordinateTuplesWithoutDroppingRawFields() {
        let gradient = VexelGradientContent(fields: VexelObjectFields([
            "start": .array([.number(-100), .number(20)]),
            "end": .array([.number(100), .number(240)]),
            "futureGradient": .string("keep")
        ]))
        XCTAssertEqual(gradient.startPoint, VexelVector2(x: -100, y: 20))
        XCTAssertEqual(gradient.endPoint, VexelVector2(x: 100, y: 240))
        XCTAssertEqual(gradient.fields.string("futureGradient"), "keep")

        let pathPoint = VexelPathPointContent(fields: VexelObjectFields([
            "point": .array([.number(1), .number(2)]),
            "in": .array([.number(-1), .number(0)]),
            "out": .array([.number(3), .number(4)])
        ]))
        XCTAssertEqual(pathPoint.typedPoint, VexelVector2(x: 1, y: 2))
        XCTAssertEqual(pathPoint.typedInTangent, VexelVector2(x: -1, y: 0))
        XCTAssertEqual(pathPoint.typedOutTangent, VexelVector2(x: 3, y: 4))
    }

    func testCutoutFrameAndStrokePayloadsMatchSourceRecipeShape() throws {
        let cutout = VexelCutoutBrushContent(fields: VexelObjectFields([
            "source": .string("source-video"),
            "sourceStart": .number(0.5),
            "duration": .number(2),
            "frames": .array([
                .object([
                    "time": .number(0.25),
                    "strokes": .array([
                        .object([
                            "mode": .string("add"),
                            "size": .number(0.06),
                            "points": .array([
                                .array([.number(0.2), .number(0.3)]),
                                .array([.number(0.4), .number(0.5)])
                            ]),
                            "futureStrokeField": .bool(true)
                        ])
                    ]),
                    "futureFrameField": .string("keep")
                ])
            ])
        ]))

        let frame = try XCTUnwrap(cutout.typedFrames?.first)
        XCTAssertEqual(frame.time, 0.25)
        XCTAssertEqual(frame.fields.string("futureFrameField"), "keep")
        let stroke = try XCTUnwrap(frame.strokes?.first)
        XCTAssertEqual(stroke.mode, .add)
        XCTAssertEqual(stroke.size, 0.06)
        XCTAssertEqual(stroke.points, [VexelVector2(x: 0.2, y: 0.3), VexelVector2(x: 0.4, y: 0.5)])
        XCTAssertEqual(stroke.fields.bool("futureStrokeField"), true)
        let unknownMode = VexelCutoutStrokeContent(fields: VexelObjectFields(["mode": .string("erase")]))
        XCTAssertEqual(unknownMode.mode, .unknown("erase"))
    }

    func testEffectCatalogDecodesEveryParameterKindAndPreservesUnknownKinds() throws {
        let json = """
        {
          "version": 1,
          "categories": [{"id":"colorLight","pt":"Cor e luz","en":"Color & light"}],
          "effects": [{
            "id":"typed",
            "category":"colorLight",
            "pt":"Typed",
            "en":"Typed",
            "target":"any",
            "needsBackdrop":false,
            "params":[
              {"name":"amount","type":"number","default":1,"min":0,"max":2},
              {"name":"count","type":"integer","default":2,"min":1,"max":8},
              {"name":"enabled","type":"boolean","default":true},
              {"name":"color","type":"color","default":"#FFFFFF"},
              {"name":"mode","type":"choice","default":"a","choices":["a","b"]},
              {"name":"center","type":"point","default":[0,0]},
              {"name":"stops","type":"stops","default":[{"offset":0,"color":"#000000"}]},
              {"name":"future","type":"vector4","default":[0,0,0,1]}
            ]
          }]
        }
        """
        let catalog = try JSONDecoder().decode(VexelEffectCatalog.self, from: Data(json.utf8))
        XCTAssertEqual(catalog.effects.count, 1)
        XCTAssertEqual(catalog.effect(id: "typed")?.parameters.map(\.type), [
            .number, .integer, .boolean, .color, .choice, .point, .stops, VexelEffectParameterType(rawValue: "vector4")
        ])
        XCTAssertEqual(catalog.effect(id: "typed")?.parameters[4].choices, ["a", "b"])

        let roundTrip = try JSONDecoder().decode(VexelEffectCatalog.self, from: JSONEncoder().encode(catalog))
        XCTAssertEqual(roundTrip, catalog)
    }

    func testEffectChoiceAndNumericBoundsAreValidated() {
        let missingChoices = #"{"name":"mode","type":"choice","default":"a"}"#
        XCTAssertThrowsError(try JSONDecoder().decode(VexelEffectParameterDefinition.self, from: Data(missingChoices.utf8)))

        let invalidBounds = #"{"name":"amount","type":"number","min":5,"max":1}"#
        XCTAssertThrowsError(try JSONDecoder().decode(VexelEffectParameterDefinition.self, from: Data(invalidBounds.utf8)))
    }
}
