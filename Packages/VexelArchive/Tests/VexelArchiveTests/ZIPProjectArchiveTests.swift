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

    func testLegacyAndroidProjectArchiveCanBeImported() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let jsonURL = directory.appendingPathComponent("project.json")
        var fields = ProjectDocument.starter(title: "Legacy import").fields
        fields["format"] = .string("knsproj")
        fields["formatVersion"] = .number(12)
        try ProjectDocument(fields: fields).encoded().write(to: jsonURL)
        let archiveURL = directory.appendingPathComponent("legacy.knsproj")
        let archive = try XCTUnwrap(Archive(url: archiveURL, accessMode: .create))
        try archive.addEntry(with: ZIPProjectArchive.projectEntry, fileURL: jsonURL, compressionMethod: .deflate)

        let result = try ZIPProjectArchive().read(from: archiveURL)
        XCTAssertEqual(result.project.fields["format"], .string("knsproj"))
        XCTAssertEqual(result.project.title, "Legacy import")
    }

    func testLegacyAndroidProjectCannotBeExported() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        var fields = ProjectDocument.starter(title: "Legacy import").fields
        fields["format"] = .string("knsproj")
        fields["formatVersion"] = .number(12)
        let legacy = ProjectDocument(fields: fields)
        XCTAssertThrowsError(try ZIPProjectArchive().write(legacy, to: directory.appendingPathComponent("legacy.knsproj"))) { error in
            XCTAssertEqual(error as? ZIPProjectArchiveError, .legacyFormatExportNotSupported)
        }
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
