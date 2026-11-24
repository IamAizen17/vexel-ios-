import XCTest
import VexelCore
@testable import Vexel

final class VexelProjectPersistenceTests: XCTestCase {
    private enum Failure: Error {
        case indexWrite
        case rollback
    }

    func testDuplicateCommitRollsBackCopiedAssetsWhenIndexSaveFails() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VexelDuplicateRollback-\(UUID().uuidString)", isDirectory: true)
        let copiedAssets = directory.appendingPathComponent("Assets/duplicate", isDirectory: true)
        try FileManager.default.createDirectory(at: copiedAssets, withIntermediateDirectories: true)
        let media = copiedAssets.appendingPathComponent("media.bin")
        try Data([1, 2, 3]).write(to: media)
        defer { try? FileManager.default.removeItem(at: directory) }
        var rollbackCount = 0

        XCTAssertThrowsError(try VexelProjectStore.commitDuplicate(
            persist: { throw Failure.indexWrite },
            rollback: {
                rollbackCount += 1
                try FileManager.default.removeItem(at: copiedAssets)
            }
        )) { error in
            guard case Failure.indexWrite = error else {
                return XCTFail("Expected the original index-write error, got \(error)")
            }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: copiedAssets.path))
        XCTAssertEqual(rollbackCount, 1)
    }

    func testDuplicateCommitKeepsAssetsAfterSuccessfulIndexSave() throws {
        var persisted = false
        var rolledBack = false

        try VexelProjectStore.commitDuplicate(
            persist: { persisted = true },
            rollback: { rolledBack = true }
        )

        XCTAssertTrue(persisted)
        XCTAssertFalse(rolledBack)
    }

    func testDuplicateCommitReportsRollbackFailureWithoutHidingPersistenceFailure() {
        XCTAssertThrowsError(try VexelProjectStore.commitDuplicate(
            persist: { throw Failure.indexWrite },
            rollback: { throw Failure.rollback }
        )) { error in
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            XCTAssertTrue(message.contains("could not be saved"))
            XCTAssertTrue(message.contains("could not be rolled back"))
        }
    }

    func testBridgePreservesUnknownNestedFieldsAfterMetadataEdit() throws {
        var document = ProjectDocument.starter(title: "Before")
        document.fields["layers"] = .array([
            .object([
                "id": .string("shape-1"),
                "type": .string("shape"),
                "name": .string("Shape"),
                "start": .number(0),
                "duration": .number(5),
                "shape": .object([
                    "kind": .string("rectangle"),
                    "size": .array([.number(100), .number(100)]),
                    "fill": .object(["color": .string("#FFFFFF")]),
                    "futureShapeData": .object([
                        "revision": .number(3),
                        "samples": .array([.number(1), .number(2), .number(3)])
                    ])
                ]),
                "futureLayerData": .object(["retain": .bool(true)])
            ])
        ])

        var item = VexelProjectItem(document: document)
        item.title = "Edited"
        item.synchronizeDocument()
        let reopened = try item.makeProjectDocument()
        let layer = try XCTUnwrap(reopened.fields["layers"]?.arrayValue?.first?.objectValue)
        let shape = try XCTUnwrap(layer["shape"]?.objectValue)

        XCTAssertEqual(reopened.title, "Edited")
        XCTAssertEqual(layer["futureLayerData"]?.objectValue?["retain"], .bool(true))
        XCTAssertEqual(shape["futureShapeData"]?.objectValue?["revision"], .number(3))
        XCTAssertEqual(shape["futureShapeData"]?.objectValue?["samples"]?.arrayValue?.count, 3)
    }
}
