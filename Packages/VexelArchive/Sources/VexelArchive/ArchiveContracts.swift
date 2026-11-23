import Foundation
import VexelCore

public struct ArchiveLimits: Sendable, Equatable {
    public let maximumEntries: Int
    public let maximumProjectJSONBytes: Int
    public let maximumUncompressedBytes: Int

    public init(maximumEntries: Int = 10_000, maximumProjectJSONBytes: Int = 64 * 1024 * 1024, maximumUncompressedBytes: Int = 8 * 1024 * 1024 * 1024) {
        self.maximumEntries = maximumEntries
        self.maximumProjectJSONBytes = maximumProjectJSONBytes
        self.maximumUncompressedBytes = maximumUncompressedBytes
    }
}

public protocol ProjectArchiveReading: Sendable {
    func readProject(from url: URL, limits: ArchiveLimits) async throws -> ProjectDocument
}

public protocol ProjectArchiveWriting: Sendable {
    func writeProject(_ project: ProjectDocument, to url: URL) async throws
}

public enum ArchiveError: Error, Equatable {
    case invalidContainer
    case unsafeEntryPath(String)
    case duplicateEntry(String)
    case resourceLimitExceeded(String)
    case missingProjectDocument
    case checksumMismatch(String)
}
