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

    func testAndroidProjectArchiveImportsAsNativeVexelProject() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let jsonURL = directory.appendingPathComponent("project.json")
        var fields = ProjectDocument.starter(title: "Android import").fields
        fields["format"] = .string(VexelProjectImporter.legacyAndroidFormatIdentifier)
        fields["formatVersion"] = .number(12)
        try ProjectDocument(fields: fields).encoded().write(to: jsonURL)
        let archiveURL = directory.appendingPathComponent("android-source.zip")
        let archive = try XCTUnwrap(Archive(url: archiveURL, accessMode: .create))
        try archive.addEntry(with: ZIPProjectArchive.legacyProjectEntry, fileURL: jsonURL, compressionMethod: .deflate)

        let result = try ZIPProjectArchive().read(from: archiveURL)
        XCTAssertEqual(result.project.fields["format"], .string(ProjectDocument.format))
        XCTAssertEqual(result.project.fields["formatVersion"], .number(Double(ProjectDocument.currentVersion)))
        XCTAssertEqual(result.project.fields["compatibility"]?.objectValue?["source"], .string("android-reference"))
        XCTAssertEqual(result.project.fields["compatibility"]?.objectValue?["sourceVersion"], .number(12))
        XCTAssertEqual(result.project.title, "Android import")
    }



    func testAndroidReferenceArchiveImportsExportsAndRoundTripsWithAssetPaths() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let fixtureURL = try XCTUnwrap(Bundle.module.url(
            forResource: "android-v2-video-audio",
            withExtension: "json",
            subdirectory: "Fixtures"
        ))
        let projectJSON = directory.appendingPathComponent("project.json")
        try Data(contentsOf: fixtureURL).write(to: projectJSON)

        let clip = directory.appendingPathComponent("clip.mp4")
        let music = directory.appendingPathComponent("music.m4a")
        let clipBytes = Data([0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70])
        let musicBytes = Data([0x4D, 0x34, 0x41, 0x20])
        try clipBytes.write(to: clip)
        try musicBytes.write(to: music)

        let androidArchiveURL = directory.appendingPathComponent("android-reference.zip")
        let androidArchive = try XCTUnwrap(Archive(url: androidArchiveURL, accessMode: .create))
        try androidArchive.addEntry(
            with: ZIPProjectArchive.legacyProjectEntry,
            fileURL: projectJSON,
            compressionMethod: .deflate
        )
        try androidArchive.addEntry(with: "assets/clip.mp4", fileURL: clip, compressionMethod: .none)
        try androidArchive.addEntry(with: "assets/music.m4a", fileURL: music, compressionMethod: .none)

        let extractedAssets = directory.appendingPathComponent("imported-assets", isDirectory: true)
        let imported = try ZIPProjectArchive().read(from: androidArchiveURL, extractingAssetsTo: extractedAssets)
        XCTAssertEqual(imported.project.fields["format"]?.stringValue, ProjectDocument.format)
        XCTAssertEqual(imported.project.fields["compatibility"]?.objectValue?["sourceVersion"]?.numberValue, 2)
        XCTAssertEqual(try Data(contentsOf: extractedAssets.appendingPathComponent("assets/clip.mp4")), clipBytes)
        XCTAssertEqual(try Data(contentsOf: extractedAssets.appendingPathComponent("assets/music.m4a")), musicBytes)

        let vexelArchiveURL = directory.appendingPathComponent("converted.vexelproj")
        try ZIPProjectArchive().write(
            imported.project,
            assetsDirectory: imported.extractedAssetsDirectory,
            to: vexelArchiveURL
        )
        let reopened = try ZIPProjectArchive().read(from: vexelArchiveURL)
        XCTAssertEqual(reopened.project, imported.project)
        let nativeArchive = try XCTUnwrap(Archive(url: vexelArchiveURL, accessMode: .read))
        let paths = Set(nativeArchive.map(\\.path))
        XCTAssertTrue(paths.contains("vexel.json"))
        XCTAssertTrue(paths.contains("assets/clip.mp4"))
        XCTAssertTrue(paths.contains("assets/music.m4a"))
        XCTAssertFalse(paths.contains("project.json"))
    }


    func testSourceAndroidV12KotlinFixtureMigratesToNativeVexel() throws {
        let fixtureURL = try XCTUnwrap(Bundle.module.url(
            forResource: "android-v12-kotlin-reference",
            withExtension: "json",
            subdirectory: "Fixtures"
        ))
        let data = try Data(contentsOf: fixtureURL)
        let imported = try VexelProjectImporter.importDocument(from: data)

        XCTAssertEqual(imported.fields["format"]?.stringValue, ProjectDocument.format)
        XCTAssertEqual(imported.fields["formatVersion"]?.numberValue, Double(ProjectDocument.currentVersion))
        XCTAssertEqual(imported.fields["compatibility"]?.objectValue?["sourceVersion"]?.numberValue, 12)
        XCTAssertEqual(imported.title, "Everything")
        XCTAssertEqual(imported.fields["assets"]?.arrayValue?.count, 5)
        XCTAssertEqual(imported.fields["layers"]?.arrayValue?.count, 17)
        XCTAssertEqual(imported.fields["composition"]?.objectValue?["fps"]?.numberValue, 30)

        let layers = imported.fields["layers"]?.arrayValue ?? []
        let star = try XCTUnwrap(layers.first { $0.objectValue?["id"]?.stringValue == "star" }?.objectValue)
        XCTAssertEqual(star["effects"]?.arrayValue?.count, 7)
        XCTAssertNotNil(star["transform"]?.objectValue?["position"]?.objectValue?["keyframes"])
        XCTAssertNotNil(star["transitionIn"])
    }

    func testImporterRejectsUnknownExternalFormat() throws {
        let fields: [String: JSONValue] = [
            "format": .string("unrelated-project"),
            "formatVersion": .number(1),
            "composition": .object([
                "width": .number(1080),
                "height": .number(1920),
                "fps": .number(30),
                "duration": .number(5)
            ]),
            "layers": .array([])
        ]
        let data = try ProjectDocument(fields: fields).encoded()
        XCTAssertThrowsError(try VexelProjectImporter.importDocument(from: data))
    }

    func testImporterRejectsUnsupportedAndroidSourceVersion() throws {
        var fields = ProjectDocument.starter(title: "Unsupported").fields
        fields["format"] = .string(VexelProjectImporter.legacyAndroidFormatIdentifier)
        fields["formatVersion"] = .number(13)
        let data = try ProjectDocument(fields: fields).encoded()
        XCTAssertThrowsError(try VexelProjectImporter.importDocument(from: data))
    }

    func testNonVexelFormatCannotBeExported() throws {
        var fields = ProjectDocument.starter(title: "Android").fields
        fields["format"] = .string("android-project")
        fields["formatVersion"] = .number(12)
        let externalProject = ProjectDocument(fields: fields)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".vexelproj")
        XCTAssertThrowsError(try ZIPProjectArchive().write(externalProject, to: url)) { error in
            XCTAssertEqual(error as? ZIPProjectArchiveError, .unsupportedProjectFormat)
        }
    }

    func testNativeExportUsesVexelDocumentEntry() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let archiveURL = directory.appendingPathComponent("native.vexelproj")
        try ZIPProjectArchive().write(ProjectDocument.starter(), to: archiveURL)
        let archive = try XCTUnwrap(Archive(url: archiveURL, accessMode: .read))
        let paths = Set(archive.map(\\.path))
        XCTAssertTrue(paths.contains("vexel.json"))
        XCTAssertFalse(paths.contains("project.json"))
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

    func testActualDecompressedAssetBytesAreBoundedIndependentlyOfZIPMetadata() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let assetsRoot = directory.appendingPathComponent("assets-root", isDirectory: true)
        let assetURL = assetsRoot.appendingPathComponent("assets/payload.bin")
        try FileManager.default.createDirectory(at: assetURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 0x41, count: 256).write(to: assetURL)

        var fields = ProjectDocument.starter(title: "Bounded extraction").fields
        fields["assets"] = .array([
            .object(["id": .string("payload"), "type": .string("image"), "path": .string("assets/payload.bin")])
        ])
        let project = ProjectDocument(fields: fields)
        let archiveURL = directory.appendingPathComponent("bounded.vexelproj")
        try ZIPProjectArchive().write(project, assetsDirectory: assetsRoot, to: archiveURL)

        let projectBytes = UInt64(try project.encoded().count)
        let archive = ZIPProjectArchive(maximumExtractedBytes: projectBytes + 32)
        XCTAssertThrowsError(try archive.read(from: archiveURL)) { error in
            XCTAssertEqual(error as? ZIPProjectArchiveError, .archiveTooLarge)
        }
    }

    func testFailedDestinationPromotionRestoresPreviousAssetsDirectory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let archiveURL = directory.appendingPathComponent("project.vexelproj")
        try ZIPProjectArchive().write(ProjectDocument.starter(title: "Promotion failure"), to: archiveURL)

        let destination = directory.appendingPathComponent("assets", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let sentinel = destination.appendingPathComponent("existing.txt")
        try Data("preserve-me".utf8).write(to: sentinel)

        let archive = ZIPProjectArchive(
            maximumExtractedBytes: ZIPProjectArchive.maximumUncompressedBytes,
            moveItemAction: { source, target in
                if source.lastPathComponent.contains(".staging-") {
                    throw CocoaError(.fileWriteNoPermission)
                }
                try FileManager.default.moveItem(at: source, to: target)
            }
        )
        XCTAssertThrowsError(try archive.read(from: archiveURL, extractingAssetsTo: destination)) { error in
            guard let archiveError = error as? ZIPProjectArchiveError,
                  case .destinationReplacementFailed = archiveError else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: sentinel), Data("preserve-me".utf8))
    }

    func testInvalidImportDoesNotModifyExistingAssetsDirectory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let projectJSON = directory.appendingPathComponent("project.json")
        var fields = ProjectDocument.starter(title: "Rollback").fields
        fields["assets"] = .array([
            .object(["id": .string("missing"), "type": .string("image"), "path": .string("assets/missing.png")])
        ])
        try ProjectDocument(fields: fields).encoded().write(to: projectJSON)
        let archiveURL = directory.appendingPathComponent("missing-asset.zip")
        let zip = try XCTUnwrap(Archive(url: archiveURL, accessMode: .create))
        try zip.addEntry(with: ZIPProjectArchive.legacyProjectEntry, fileURL: projectJSON, compressionMethod: .deflate)

        let destination = directory.appendingPathComponent("existing-assets", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let sentinel = destination.appendingPathComponent("keep.txt")
        try Data("untouched".utf8).write(to: sentinel)

        XCTAssertThrowsError(try ZIPProjectArchive().read(from: archiveURL, extractingAssetsTo: destination))
        XCTAssertEqual(try Data(contentsOf: sentinel), Data("untouched".utf8))
    }

    func testArchiveImportReturnsUnsupportedFeatureReport() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        var fields = ProjectDocument.starter(title: "Feature report").fields
        fields["layers"] = .array([
            .object([
                "id": .string("video"), "type": .string("video"), "duration": .number(3),
                "video": .object(["asset": .string("unused")]),
                "effects": .array([.object(["type": .string("gaussianBlur")])]),
                "transform": .object(["position": .object([
                    "expression": .string("time * 2"),
                    "keyframes": .array([])
                ])])
            ]),
            .object(["id": .string("future-layer"), "type": .string("future-layer"), "blendMode": .string("futureBlend"), "duration": .number(1)])
        ])
        fields["assets"] = .array([
            .object(["id": .string("unused"), "type": .string("video"), "path": .string("assets/video.mov")])
        ])
        let source = directory.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: source.appendingPathComponent("assets"), withIntermediateDirectories: true)
        try Data([0x01, 0x02]).write(to: source.appendingPathComponent("assets/video.mov"))
        let archiveURL = directory.appendingPathComponent("report.vexelproj")
        try ZIPProjectArchive().write(ProjectDocument(fields: fields), assetsDirectory: source, to: archiveURL)

        let imported = try ZIPProjectArchive().read(from: archiveURL)
        XCTAssertTrue(imported.compatibilityReport.contains { $0.feature == "video" })
        XCTAssertTrue(imported.compatibilityReport.contains { $0.feature == "effect:gaussianBlur" })
        XCTAssertTrue(imported.compatibilityReport.contains { $0.feature == "expression" })
        XCTAssertTrue(imported.compatibilityReport.contains { $0.feature == "unknown-layer:future-layer" })
        XCTAssertTrue(imported.compatibilityReport.contains { $0.feature == "blend-mode:futureBlend" })
    }


    func testAndroidReferenceArchiveImportsRealVideoAndAudioPayloads() throws {
        let archiveURL = try XCTUnwrap(Bundle.module.url(
            forResource: "android-video-audio-reference",
            withExtension: "knsproj",
            subdirectory: "Fixtures"
        ))
        let imported = try ZIPProjectArchive().read(from: archiveURL)
        defer {
            if let directory = imported.extractedAssetsDirectory {
                try? FileManager.default.removeItem(at: directory)
            }
        }

        XCTAssertEqual(imported.project.fields["compatibility"]?.objectValue?["sourceVersion"]?.numberValue, 2)
        XCTAssertEqual(imported.project.fields["assets"]?.arrayValue?.count, 2)
        XCTAssertTrue(imported.compatibilityReport.contains { $0.feature == "video" })
        XCTAssertTrue(imported.compatibilityReport.contains { $0.feature == "audio" })

        let assets = try XCTUnwrap(imported.extractedAssetsDirectory)
        XCTAssertEqual(try Data(contentsOf: assets.appendingPathComponent("assets/clip.mp4")).count, 73_048)
        XCTAssertEqual(try Data(contentsOf: assets.appendingPathComponent("assets/music.m4a")).count, 38_439)
    }


    func testFailedRollbackReportsRecoverableBackupLocation() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let archiveURL = directory.appendingPathComponent("project.vexelproj")
        try ZIPProjectArchive().write(ProjectDocument.starter(title: "Rollback failure"), to: archiveURL)
        let destination = directory.appendingPathComponent("assets", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let sentinel = destination.appendingPathComponent("existing.txt")
        try Data("recoverable".utf8).write(to: sentinel)

        let archive = ZIPProjectArchive(
            maximumExtractedBytes: ZIPProjectArchive.maximumUncompressedBytes,
            moveItemAction: { source, target in
                if source.lastPathComponent.contains(".staging-") ||
                    source.lastPathComponent.contains(".backup-") {
                    throw CocoaError(.fileWriteNoPermission)
                }
                try FileManager.default.moveItem(at: source, to: target)
            }
        )

        XCTAssertThrowsError(try archive.read(from: archiveURL, extractingAssetsTo: destination)) { error in
            guard let archiveError = error as? ZIPProjectArchiveError,
                  case .destinationRollbackFailed(let backupPath, _) = archiveError else {
                return XCTFail("Unexpected error: \\(error)")
            }
            let backup = URL(fileURLWithPath: backupPath)
            XCTAssertTrue(FileManager.default.fileExists(atPath: backup.appendingPathComponent("existing.txt").path))
            XCTAssertEqual(try Data(contentsOf: backup.appendingPathComponent("existing.txt")), Data("recoverable".utf8))
        }
    }

}
