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

    func testNativeV1DocumentMigratesBeforeImportValidation() throws {
        var fields = ProjectDocument.starter(title: "").fields
        fields["formatVersion"] = .number(1)
        fields.removeValue(forKey: "generator")
        fields.removeValue(forKey: "assets")
        fields.removeValue(forKey: "markers")
        fields.removeValue(forKey: "layers")
        var composition = fields["composition"]?.objectValue ?? [:]
        composition.removeValue(forKey: "background")
        fields["composition"] = .object(composition)

        let imported = try VexelProjectImporter.importDocument(from: ProjectDocument(fields: fields).encoded())
        XCTAssertEqual(imported.fields["formatVersion"], .number(Double(ProjectDocument.currentVersion)))
        XCTAssertEqual(imported.fields["generator"], .string("Vexel"))
        XCTAssertEqual(imported.fields["assets"], .array([]))
        XCTAssertEqual(imported.fields["markers"], .array([]))
        XCTAssertEqual(imported.fields["layers"], .array([]))
        XCTAssertEqual(imported.fields["composition"]?.objectValue?["background"], .string("#0D0F12"))
        XCTAssertTrue(imported.validate().isEmpty)
    }

    func testLegacyProjectsWithOmittedDefaultArraysAreNormalized() throws {
        var fields = ProjectDocument.starter(title: "Legacy defaults").fields
        fields["format"] = .string("knsproj")
        fields["formatVersion"] = .number(2)
        fields.removeValue(forKey: "assets")
        fields.removeValue(forKey: "markers")
        fields.removeValue(forKey: "layers")

        let imported = try VexelProjectImporter.importDocument(from: ProjectDocument(fields: fields).encoded())
        XCTAssertEqual(imported.fields["assets"], .array([]))
        XCTAssertEqual(imported.fields["markers"], .array([]))
        XCTAssertEqual(imported.fields["layers"], .array([]))
        XCTAssertTrue(imported.validate().isEmpty)
    }

    func testFutureKNSVersionIsRejected() throws {
        let project = legacyProject(version: 13)
        XCTAssertThrowsError(try VexelProjectImporter.importDocument(from: project.encoded()))
    }


    func testAndroidReferenceFixturesImportAndRoundTripPreservesNestedData() throws {
        for name in ["android-v2-group", "android-v2-video-audio", "android-v2-track-matte-transitions"] {
            let imported = try VexelProjectImporter.importDocument(from: androidFixture(name))
            XCTAssertEqual(imported.fields["format"]?.stringValue, ProjectDocument.format, name)
            XCTAssertEqual(imported.fields["compatibility"]?.objectValue?["sourceVersion"]?.numberValue, 2, name)

            let exported = try imported.encoded()
            let reopened = try ProjectDocument(data: exported)
            XCTAssertEqual(reopened, imported, name)
        }
    }

    func testAndroidGroupFixturePreservesUnknownFieldsRecursively() throws {
        let imported = try VexelProjectImporter.importDocument(from: androidFixture("android-v2-group"))
        let group = try XCTUnwrap(imported.fields["layers"]?.arrayValue?.first?.objectValue)
        XCTAssertEqual(group["futureGroupField"]?.objectValue?["revision"]?.numberValue, 7)

        let child = try XCTUnwrap(group["layers"]?.arrayValue?.first?.objectValue)
        let nested = try XCTUnwrap(group["layers"]?.arrayValue?[1].objectValue)
        XCTAssertEqual(nested["futureNestedField"]?.objectValue?["mustSurvive"]?.arrayValue?.count, 2)
        XCTAssertEqual(child["id"]?.stringValue, "plate")
    }

    func testAndroidAudioLayerWithoutPayloadKeepsAudioDiscriminator() throws {
        let imported = try VexelProjectImporter.importDocument(from: androidFixture("android-v2-video-audio"))
        let layers = try XCTUnwrap(imported.fields["layers"]?.arrayValue)
        let audio = try XCTUnwrap(layers.first { $0.objectValue?["id"]?.stringValue == "audio-without-payload" }?.objectValue)
        XCTAssertEqual(audio["type"]?.stringValue, "audio")
        XCTAssertNil(audio["audio"])
    }

    private func androidFixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
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
