import Foundation
import XCTest
import ZIPFoundation
@testable import VexelCore

final class KnsprojArchiveImporterTests: XCTestCase {
    func testImportsProjectAndCopiesAssets() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let archiveURL = root.appendingPathComponent("sample.knsproj")
        let projectJSON = """
        {
          "format": "knsproj",
          "formatVersion": 12,
          "meta": {"title": "Imported Edit"},
          "composition": {"width": 1920, "height": 1080, "fps": 60, "duration": 8},
          "assets": [{"id": "image-1", "type": "image", "path": "assets/title.png"}],
          "markers": [{"id": "marker-1", "time": 2, "name": "Beat"}],
          "layers": [{"id": "layer-1", "type": "image", "image": {"asset": "image-1"}}],
          "futureRootField": {"preserve": true}
        }
        """.data(using: .utf8)!
        let image = Data([0x89, 0x50, 0x4E, 0x47])

        try createArchive(at: archiveURL, entries: [
            ("project.json", projectJSON),
            ("assets/title.png", image),
            ("thumbnail.jpg", Data([0xFF, 0xD8, 0xFF]))
        ])

        let result = try KnsprojArchiveImporter().importProject(from: archiveURL, into: root)

        XCTAssertEqual(result.project.title, "Imported Edit")
        XCTAssertEqual(result.project.compositionSize.width, 1920)
        XCTAssertEqual(result.project.layerCount, 1)
        XCTAssertEqual(result.sourceVersion, 12)
        XCTAssertEqual(result.importedAssetCount, 1)
        XCTAssertEqual(try Data(contentsOf: result.projectDirectory.appendingPathComponent("assets/title.png")), image)

        let compatibility = result.project.fields["compatibility"]?.objectValue
        let sourceDocument = compatibility?["sourceDocument"]?.objectValue
        XCTAssertEqual(sourceDocument?["futureRootField"]?.objectValue?["preserve"], .bool(true))
    }

    func testMigratesVersionElevenRotoRecipeToCutout() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let archiveURL = root.appendingPathComponent("legacy.knsproj")
        let projectJSON = """
        {
          "format": "knsproj",
          "formatVersion": 11,
          "meta": {"title": "Legacy"},
          "composition": {"width": 1080, "height": 1920, "fps": 30, "duration": 5},
          "assets": [],
          "layers": [{"id": "clip", "type": "video", "video": {"asset": "video-1", "roto": {"strokes": []}}}]
        }
        """.data(using: .utf8)!
        try createArchive(at: archiveURL, entries: [("project.json", projectJSON)])

        let result = try KnsprojArchiveImporter().importProject(from: archiveURL, into: root)
        let layers = result.project.fields["layers"]?.arrayValue
        let video = layers?.first?.objectValue?["video"]?.objectValue

        XCTAssertEqual(result.sourceVersion, 11)
        XCTAssertNotNil(video?["cutout"])
        XCTAssertNil(video?["roto"])
    }

    func testRejectsPathTraversalBeforeExtracting() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let archiveURL = root.appendingPathComponent("unsafe.knsproj")
        let projectJSON = validProjectJSON()
        try createArchive(at: archiveURL, entries: [
            ("project.json", projectJSON),
            ("../escape.txt", Data("no".utf8))
        ])

        XCTAssertThrowsError(try KnsprojArchiveImporter().importProject(from: archiveURL, into: root)) { error in
            XCTAssertEqual(error as? KnsprojImportError, .unsafeEntryPath("../escape.txt"))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("escape.txt").path))
    }

    func testRejectsDuplicateArchiveEntries() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let archiveURL = root.appendingPathComponent("duplicate.knsproj")
        try createArchive(at: archiveURL, entries: [
            ("project.json", validProjectJSON()),
            ("assets/item.bin", Data([1])),
            ("assets/item.bin", Data([2]))
        ])

        XCTAssertThrowsError(try KnsprojArchiveImporter().importProject(from: archiveURL, into: root)) { error in
            XCTAssertEqual(error as? KnsprojImportError, .duplicateEntry("assets/item.bin"))
        }
    }

    func testRejectsUnsupportedFutureVersion() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let archiveURL = root.appendingPathComponent("future.knsproj")
        let json = """
        {"format":"knsproj","formatVersion":13,"composition":{},"layers":[]}
        """.data(using: .utf8)!
        try createArchive(at: archiveURL, entries: [("project.json", json)])

        XCTAssertThrowsError(try KnsprojArchiveImporter().importProject(from: archiveURL, into: root)) { error in
            XCTAssertEqual(error as? KnsprojImportError, .unsupportedVersion(13))
        }
    }

    private func validProjectJSON() -> Data {
        """
        {
          "format": "knsproj",
          "formatVersion": 12,
          "meta": {"title": "Test"},
          "composition": {"width": 1080, "height": 1920, "fps": 30, "duration": 5},
          "assets": [],
          "layers": []
        }
        """.data(using: .utf8)!
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func createArchive(at url: URL, entries: [(String, Data)]) throws {
        let archive = try Archive(url: url, accessMode: .create, pathEncoding: .utf8)
        for (path, data) in entries {
            try archive.addEntry(
                with: path,
                type: .file,
                uncompressedSize: Int64(data.count),
                compressionMethod: .deflate,
                provider: { position, size in
                    let start = Int(position)
                    guard start < data.count else { return Data() }
                    let end = min(start + size, data.count)
                    return data.subdata(in: start..<end)
                }
            )
        }
    }
}
