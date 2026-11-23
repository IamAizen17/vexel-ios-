import XCTest
@testable import VexelCore

final class ProjectDocumentTests: XCTestCase {
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
    func testKNSVersion12DocumentsAreAcceptedAndRoundTripUnknownFields() throws {
        let source = """
        {
          "format": "knsproj",
          "formatVersion": 12,
          "meta": {"title": "Imported", "customMeta": "keep"},
          "composition": {"width": 1080, "height": 1920, "fps": 30, "duration": 8},
          "layers": [{"id": "layer-1", "type": "shape", "shape": {"kind": "rectangle"}, "futureLayerField": 42}],
          "futureRootField": {"enabled": true}
        }
        """.data(using: .utf8)!
        let project = try ProjectDocument(data: source)
        XCTAssertTrue(project.validate().filter { $0.severity == .error }.isEmpty)
        let decoded = try ProjectDocument(data: project.encoded())
        XCTAssertEqual(decoded.fields["format"], .string("knsproj"))
        XCTAssertEqual(decoded.fields["formatVersion"], .number(12))
        XCTAssertEqual(decoded.fields["futureRootField"], project.fields["futureRootField"])
        XCTAssertEqual(decoded.layerCount, 1)
    }

    func testRejectsKNSVersionsNewerThanReference() {
        var project = ProjectDocument(fields: [
            "format": .string("knsproj"),
            "formatVersion": .number(13),
            "composition": .object(["width": .number(1080), "height": .number(1920), "fps": .number(30), "duration": .number(5)]),
            "layers": .array([])
        ])
        XCTAssertEqual(project.validate().first?.path, "formatVersion")
        project.fields["formatVersion"] = .number(12)
        XCTAssertTrue(project.validate().isEmpty)
    }

}
