import Foundation
import CoreTransferable
import UniformTypeIdentifiers

struct VexelImportedFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .item) { received in
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("vexel-import-\(UUID().uuidString)")
            try FileManager.default.copyItem(at: received.file, to: destination)
            return VexelImportedFile(url: destination)
        }
    }
}
