import XCTest
@testable import VexelArchive
import VexelCore

final class VexelProjectImporterTests: XCTestCase {
    func testVersionOneColorAdjustEffectExpandsIntoNativeEffectStack() throws {
        let project = legacyProject(version: 1, layers: [
            .object([
                "id": .string("layer-1"),
                "type": .string("shape"),
                "duration": .number(5),
                "effects": .array([
                    .object([
                        "type": .string("colorAdjust"),
                        "hue": .number(12),
                        "brightness": .number(0.1),
                        "contrast": .number(1.2),
                        "saturation": .number(1.1)
                    ])
                ])
            ])
        ])

        let imported = try VexelProjectImporter.importDocument(from: project.encoded())
        let effects = try XCTUnwrap(imported.fields["layers"]?.arrayValue?.first?.objectValue?["effects"]?.arrayValue)
        XCTAssertEqual(effects.compactMap { $0.objectValue?["type"]?.stringValue }, [
            "hueShift", "brightnessContrast", "saturation"
        ])
        XCTAssertEqual(imported.fields["format"]?.stringValue, ProjectDocument.format)
        XCTAssertEqual(imported.fields["formatVersion"]?.numberValue, Double(ProjectDocument.currentVersion))
        XCTAssertEqual(imported.fields["compatibility"]?.objectValue?["sourceVersion"]?.numberValue, 1)
    }

    func testVersionSixCyclicEasingOffsetMigratesToPhase() throws {
        let project = legacyProject(version: 6, layers: [
            .object([
                "id": .string("layer-1"),
                "type": .string("shape"),
                "duration": .number(5),
                "transform": .object([
                    "position": .object([
                        "keyframes": .array([
                            .object([
                                "time": .number(0),
                                "value": .array([.number(0), .number(0)]),
                                "easing": .object([
                                    "cyclic": .object([
                                        "offset": .number(0.25),
                                        "cycles": .number(3.5)
                                    ])
                                ])
                            ])
                        ])
                    ])
                ])
            ])
        ])

        let imported = try VexelProjectImporter.importDocument(from: project.encoded())
        let easing = imported.fields["layers"]?.arrayValue?.first?.objectValue?["transform"]?
            .objectValue?["position"]?.objectValue?["keyframes"]?.arrayValue?.first?
            .objectValue?["easing"]?.objectValue?["cyclic"]?.objectValue
        XCTAssertEqual(easing?["phase"]?.numberValue, 0.25)
        XCTAssertNil(easing?["offset"])
        XCTAssertEqual(easing?["cycles"]?.numberValue, 3.5)
    }

    func testVersionElevenMediaRotoRecipeMigratesToCutout() throws {
        let project = legacyProject(version: 11, layers: [
            .object([
                "id": .string("video-1"),
                "type": .string("video"),
                "duration": .number(5),
                "video": .object([
                    "asset": .string("asset-1"),
                    "roto": .object([
                        "source": .string("asset-1"),
                        "duration": .number(5),
                        "frames": .array([])
                    ])
                ])
            ])
        ])

        let imported = try VexelProjectImporter.importDocument(from: project.encoded())
        let video = imported.fields["layers"]?.arrayValue?.first?.objectValue?["video"]?.objectValue
        XCTAssertNotNil(video?["cutout"])
        XCTAssertNil(video?["roto"])
    }

    func testVersionTwelveUnknownFieldsArePreserved() throws {
        let project = legacyProject(version: 12, layers: [
            .object([
                "id": .string("layer-1"),
                "type": .string("shape"),
                "duration": .number(5),
                "futureField": .object(["preserve": .bool(true)])
            ])
        ])

        let imported = try VexelProjectImporter.importDocument(from: project.encoded())
        XCTAssertEqual(
            imported.fields["layers"]?.arrayValue?.first?.objectValue?["futureField"]?.objectValue?["preserve"]?.boolValue,
            true
        )
    }

    func testFutureKNSVersionIsRejected() throws {
        let project = legacyProject(version: 13)
        XCTAssertThrowsError(try VexelProjectImporter.importDocument(from: project.encoded()))
    }

    private func legacyProject(version: Int, layers: [JSONValue] = []) -> ProjectDocument {
        var fields = ProjectDocument.starter(title: "Legacy fixture").fields
        fields["format"] = .string("knsproj")
        fields["formatVersion"] = .number(Double(version))
        fields["layers"] = .array(layers)
        return ProjectDocument(fields: fields)
    }
}

private extension JSONValue {
    var boolValue: Bool? {
        guard case .bool(let value) = self else { return nil }
        return value
    }
}
