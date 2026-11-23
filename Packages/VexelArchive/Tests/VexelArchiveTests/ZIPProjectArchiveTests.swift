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

    func testLegacyAndroidArchiveIsConvertedToNativeVexelProject() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let jsonURL = directory.appendingPathComponent("project.json")
        var fields = ProjectDocument.starter(title: "Legacy import").fields
        fields["format"] = .string("knsproj")
        fields["formatVersion"] = .number(12)
        try ProjectDocument(fields: fields).encoded().write(to: jsonURL)
        let archiveURL = directory.appendingPathComponent("legacy-source.zip")
        let archive = try XCTUnwrap(Archive(url: archiveURL, accessMode: .create))
        try archive.addEntry(with: ZIPProjectArchive.projectEntry, fileURL: jsonURL, compressionMethod: .deflate)

        let result = try ZIPProjectArchive().read(from: archiveURL)
        XCTAssertEqual(result.project.fields["format"], .string(ProjectDocument.format))
        XCTAssertEqual(result.project.fields["formatVersion"], .number(Double(ProjectDocument.currentVersion)))
        XCTAssertEqual(result.project.fields["compatibility"]?.objectValue?["source"], .string("legacy-android"))
        XCTAssertEqual(result.project.fields["compatibility"]?.objectValue?["sourceVersion"], .number(12))
        XCTAssertEqual(result.project.title, "Legacy import")
    }

    func testLegacyAndroidProjectCannotBeExported() throws {
        var fields = ProjectDocument.starter(title: "Legacy").fields
        fields["format"] = .string("knsproj")
        fields["formatVersion"] = .number(12)
        let legacy = ProjectDocument(fields: fields)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".vexelproj")
        XCTAssertThrowsError(try ZIPProjectArchive().write(legacy, to: url)) { error in
            XCTAssertEqual(error as? ZIPProjectArchiveError, .legacyFormatExportNotSupported)
        }
    }

    func testMissingAssetPayloadFailsImport() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        var fields = ProjectDocument.starter(title: "Missing asset").fields
        fields["assets"] = .array([.object(["id": .string("a"), "path": .string("assets/missing.png")])])
        let jsonURL = directory.appendingPathComponent("project.json")
        try ProjectDocument(fields: fields).encoded().write(to: jsonURL)
        let url = directory.appendingPathComponent("missing-asset.zip")
        let archive = try XCTUnwrap(Archive(url: url, accessMode: .create))
        try archive.addEntry(with: ZIPProjectArchive.projectEntry, fileURL: jsonURL, compressionMethod: .deflate)
        XCTAssertThrowsError(try ZIPProjectArchive().read(from: url))
    }

    func testRejectsUnexpectedRootPayload() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let jsonURL = directory.appendingPathComponent("project.json")
        try ProjectDocument.starter().encoded().write(to: jsonURL)
        let extraURL = directory.appendingPathComponent("unexpected.bin")
        try Data([0x01]).write(to: extraURL)
        let url = directory.appendingPathComponent("unexpected.zip")
        let archive = try XCTUnwrap(Archive(url: url, accessMode: .create))
        try archive.addEntry(with: ZIPProjectArchive.projectEntry, fileURL: jsonURL, compressionMethod: .deflate)
        try archive.addEntry(with: "unexpected.bin", fileURL: extraURL, compressionMethod: .deflate)
        XCTAssertThrowsError(try ZIPProjectArchive().read(from: url))
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

    func testAssetArchiveRoundTripPreservesAssetDirectoryLayout() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let assetsRoot = directory.appendingPathComponent("source-assets", isDirectory: true)
        let assetFile = assetsRoot.appendingPathComponent("assets/image.bin")
        try FileManager.default.createDirectory(at: assetFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([0x56, 0x45, 0x58, 0x45, 0x4C]).write(to: assetFile)

        var fields = ProjectDocument.starter(title: "Asset round trip").fields
        fields["assets"] = .array([
            .object(["id": .string("image-1"), "path": .string("assets/image.bin")])
        ])
        let project = ProjectDocument(fields: fields)
        let firstArchive = directory.appendingPathComponent("first.vexelproj")
        try ZIPProjectArchive().write(project, assetsDirectory: assetsRoot, to: firstArchive)

        let extracted = directory.appendingPathComponent("extracted", isDirectory: true)
        let imported = try ZIPProjectArchive().read(from: firstArchive, extractingAssetsTo: extracted)
        let extractedAsset = extracted.appendingPathComponent("assets/image.bin")
        XCTAssertEqual(try Data(contentsOf: extractedAsset), Data([0x56, 0x45, 0x58, 0x45, 0x4C]))

        let secondArchive = directory.appendingPathComponent("second.vexelproj")
        try ZIPProjectArchive().write(imported.project, assetsDirectory: imported.extractedAssetsDirectory, to: secondArchive)
        let roundTrip = try ZIPProjectArchive().read(from: secondArchive)
        XCTAssertEqual(roundTrip.project, project)
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
