import Foundation
import XCTest
import VexelCore
@testable import VexelArchive

final class ZIPProjectArchiveTests: XCTestCase {
    func testVexelProjectArchiveRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let archiveURL = directory.appendingPathComponent("roundtrip.vexelproj")
        let project = ProjectDocument.starter(title: "Round trip")
        try ZIPProjectArchive().write(project, to: archiveURL)
        let result = try ZIPProjectArchive().read(from: archiveURL)
        XCTAssertEqual(result.project, project)
        XCTAssertNotNil(result.extractedAssetsDirectory)
    }

    func testKNSProjectFormatIsPreserved() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let archiveURL = directory.appendingPathComponent("legacy.knsproj")
        var fields = ProjectDocument.starter(title: "KNS import").fields
        fields["format"] = .string("knsproj")
        fields["formatVersion"] = .number(12)
        let source = ProjectDocument(fields: fields)
        try ZIPProjectArchive().write(source, to: archiveURL)
        let result = try ZIPProjectArchive().read(from: archiveURL)
        XCTAssertEqual(result.project.fields["format"], .string("knsproj"))
        XCTAssertEqual(result.project.title, "KNS import")
    }

    func testRejectsTraversalEntry() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let outside = directory.appendingPathComponent("evil.txt")
        try Data("evil".utf8).write(to: outside)
        let archiveURL = directory.appendingPathComponent("malicious.zip")
        let archive = try XCTUnwrap(Archive(url: archiveURL, accessMode: .create))
        try archive.addEntry(with: "../evil.txt", fileURL: outside, compressionMethod: .deflate)
        XCTAssertThrowsError(try ZIPProjectArchive().read(from: archiveURL))
    }

    func testMissingAssetPayloadFailsExport() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        var project = ProjectDocument.starter()
        project.fields["assets"] = .array([
            .object(["id": .string("asset"), "path": .string("assets/missing.png")])
        ])
        XCTAssertThrowsError(try ZIPProjectArchive().write(project, to: directory.appendingPathComponent("missing.vexelproj")))
    }
}
