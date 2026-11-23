import Foundation
import XCTest
import ZIPFoundation
@testable import VexelCore

final class VexelProjectArchiveTests: XCTestCase {
    func testSavesAndReopensProjectWithAssetsAndUnknownFields() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let assetsDirectory = root.appendingPathComponent("working", isDirectory: true)
        let assetDirectory = assetsDirectory.appendingPathComponent("assets", isDirectory: true)
        try FileManager.default.createDirectory(at: assetDirectory, withIntermediateDirectories: true)
        let assetData = Data([0x10, 0x20, 0x30, 0x40])
        try assetData.write(to: assetDirectory.appendingPathComponent("clip.bin"))

        var project = ProjectDocument.starter(title: "Native Vexel")
        project.fields["assets"] = .array([
            .object([
                "id": .string("asset-1"),
                "type": .string("image"),
                "path": .string("assets/clip.bin")
            ])
        ])
        project.fields["futureField"] = .object(["enabled": .bool(true)])

        let archiveURL = root.appendingPathComponent("Native.vexelproj")
        try VexelProjectArchive().save(project, assetsDirectory: assetsDirectory, to: archiveURL)
        let savedArchive = try Archive(url: archiveURL, accessMode: .read, pathEncoding: .utf8)
        let savedEntries = Array(savedArchive).map { "\($0.path):\($0.type)" }
        XCTAssertTrue(savedEntries.contains { $0.hasPrefix("assets/clip.bin:") }, "Saved entries: \(savedEntries)")

        let loaded = try VexelProjectArchive().open(from: archiveURL, into: root)
        let copiedAsset = loaded.projectDirectory.appendingPathComponent("assets/clip.bin")

        XCTAssertEqual(loaded.project.title, "Native Vexel")
        XCTAssertEqual(loaded.project.fields["futureField"], .object(["enabled": .bool(true)]))
        XCTAssertEqual(try Data(contentsOf: copiedAsset), assetData)
        XCTAssertEqual(loaded.importedFileCount, 1)
    }

    func testSaveRejectsMissingReferencedAsset() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let assetsDirectory = root.appendingPathComponent("working", isDirectory: true)
        try FileManager.default.createDirectory(at: assetsDirectory, withIntermediateDirectories: true)

        var project = ProjectDocument.starter()
        project.fields["assets"] = .array([
            .object([
                "id": .string("missing"),
                "type": .string("image"),
                "path": .string("assets/missing.png")
            ])
        ])

        XCTAssertThrowsError(
            try VexelProjectArchive().save(
                project,
                assetsDirectory: assetsDirectory,
                to: root.appendingPathComponent("broken.vexelproj")
            )
        ) { error in
            XCTAssertEqual(error as? VexelProjectArchiveError, .missingAsset("assets/missing.png"))
        }
    }

    func testOpenRejectsArchiveWithWrongFormat() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let archiveURL = root.appendingPathComponent("wrong.vexelproj")
        try makeArchive(at: archiveURL, projectJSON: """
        {"format":"knsproj","formatVersion":12,"composition":{},"layers":[]}
        """)

        XCTAssertThrowsError(try VexelProjectArchive().open(from: archiveURL, into: root)) { error in
            XCTAssertEqual(error as? VexelProjectArchiveError, .invalidProjectFormat)
        }
    }

    private func makeArchive(at url: URL, projectJSON: String) throws {
        let archive = try Archive(url: url, accessMode: .create, pathEncoding: .utf8)
        let data = Data(projectJSON.utf8)
        try archive.addEntry(
            with: "project.json",
            type: .file,
            uncompressedSize: Int64(data.count),
            provider: { position, size in
                let start = Int(position)
                guard start < data.count else { return Data() }
                return data.subdata(in: start..<min(start + size, data.count))
            }
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
