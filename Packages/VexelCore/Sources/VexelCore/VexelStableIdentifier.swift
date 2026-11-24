import Foundation
import CryptoKit

/// Stable mapping from external project identifiers to Vexel's UUID-backed editor identity.
public enum VexelStableIdentifier {
    private static let namespace = UUID(uuidString: "8A9E5B2C-42D7-5F61-9B36-2D7F1A5C903E")!

    /// Preserves UUID-shaped source IDs and maps every other source ID with UUID version 5 semantics.
    public static func uuid(forSourceID sourceID: String) -> UUID {
        if let uuid = UUID(uuidString: sourceID) {
            return uuid
        }

        var namespaceBytes = namespace.uuid
        var input = Data(bytes: &namespaceBytes, count: MemoryLayout.size(ofValue: namespaceBytes))
        input.append(contentsOf: sourceID.utf8)

        var digest = Array(Insecure.SHA1.hash(data: input).prefix(16))
        digest[6] = (digest[6] & 0x0F) | 0x50
        digest[8] = (digest[8] & 0x3F) | 0x80

        let bytes: uuid_t = (
            digest[0], digest[1], digest[2], digest[3],
            digest[4], digest[5], digest[6], digest[7],
            digest[8], digest[9], digest[10], digest[11],
            digest[12], digest[13], digest[14], digest[15]
        )
        return UUID(uuid: bytes)
    }
}
