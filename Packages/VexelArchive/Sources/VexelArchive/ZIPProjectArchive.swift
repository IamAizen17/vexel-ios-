import Foundation
import ZIPFoundation
import VexelCore

public struct ProjectArchivePayload: Sendable {
    public let project: ProjectDocument
    public let extractedAssetsDirectory: URL?

    public init(project: ProjectDocument, extractedAssetsDirectory: URL?) {
        self.project = project
        self.extractedAssetsDirectory = extractedAssetsDirectory
    }
}

public enum ZIPProjectArchiveError: Error, Equatable {
    case invalidArchive
    case unsafePath(String)
    case duplicateEntry(String)
    case unsupportedEntryType(String)
    case tooManyEntries
    case projectDocumentTooLarge
    case archiveTooLarge
    case missingProjectDocument
    case missingAsset(String)
    case legacyFormatExportNotSupported
}

public struct ZIPProjectArchive: Sendable {
    public static let projectEntry = "project.json"
    public static let maximumEntries = 10_000
    public static let maximumProjectBytes: UInt64 = 64 * 1024 * 1024
    public static let maximumUncompressedBytes: UInt64 = 8 * 1024 * 1024 * 1024

    public init() {}

    public func read(from archiveURL: URL, extractingAssetsTo destination: URL? = nil) throws -> ProjectArchivePayload {
        guard let archive = Archive(url: archiveURL, accessMode: .read) else {
            throw ZIPProjectArchiveError.invalidArchive
        }
        let temporary = destination ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("VexelImport-\(UUID().uuidString)", isDirectory: true)
        let shouldRemove = destination == nil
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)

        var seen = Set<String>()
        var total: UInt64 = 0
        var projectData: Data?
        var entryCount = 0

        do {
            for entry in archive {
                entryCount += 1
                guard entryCount <= Self.maximumEntries else { throw ZIPProjectArchiveError.tooManyEntries }
                let path = try Self.normalizedPath(entry.path, isDirectory: entry.type == .directory)
                guard seen.insert(path).inserted else { throw ZIPProjectArchiveError.duplicateEntry(path) }
                guard entry.type != .symlink else { throw ZIPProjectArchiveError.unsupportedEntryType(path) }
                if entry.type == .directory { continue }
                total = total.addingReportingOverflow(entry.uncompressedSize).partialValue
                guard total <= Self.maximumUncompressedBytes else { throw ZIPProjectArchiveError.archiveTooLarge }
                if path == Self.projectEntry {
                    guard entry.uncompressedSize <= Self.maximumProjectBytes else { throw ZIPProjectArchiveError.projectDocumentTooLarge }
                    var data = Data()
                    _ = try archive.extract(entry, consumer: { chunk in data.append(chunk) })
                    projectData = data
                } else {
                    let target = temporary.appendingPathComponent(path)
                    let root = temporary.standardizedFileURL.path + "/"
                    let standardized = target.standardizedFileURL.path
                    guard standardized.hasPrefix(root) else { throw ZIPProjectArchiveError.unsafePath(path) }
                    try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                    _ = try archive.extract(entry, to: target)
                }
            }
            guard let projectData else { throw ZIPProjectArchiveError.missingProjectDocument }
            let project = try ProjectDocument(data: projectData)
            let issues = project.validate().filter { $0.severity == .error }
            guard issues.isEmpty else {
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: issues.map { "\($0.path): \($0.message)" }.joined(separator: "\n")))
            }
            return ProjectArchivePayload(project: project, extractedAssetsDirectory: destination == nil ? temporary : destination)
        } catch {
            if shouldRemove { try? FileManager.default.removeItem(at: temporary) }
            throw error
        }
    }

    public func write(_ project: ProjectDocument, assetsDirectory: URL? = nil, to archiveURL: URL) throws {
        guard project.fields["format"]?.stringValue == ProjectDocument.format else {
            throw ZIPProjectArchiveError.legacyFormatExportNotSupported
        }
        let issues = project.validate().filter { $0.severity == .error }
        guard issues.isEmpty else {
            throw EncodingError.invalidValue(project, .init(codingPath: [], debugDescription: issues.map { "\($0.path): \($0.message)" }.joined(separator: "\n")))
        }
        let data = try project.encoded()
        guard data.count <= Int(Self.maximumProjectBytes) else { throw ZIPProjectArchiveError.projectDocumentTooLarge }
        let manager = FileManager.default
        let staging = manager.temporaryDirectory.appendingPathComponent("VexelArchive-\(UUID().uuidString)", isDirectory: true)
        try manager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: staging) }
        let jsonURL = staging.appendingPathComponent(Self.projectEntry)
        try data.write(to: jsonURL, options: .atomic)

        let partialURL = archiveURL.deletingLastPathComponent().appendingPathComponent(".\(UUID().uuidString).tmp")
        defer { try? manager.removeItem(at: partialURL) }
        guard let archive = Archive(url: partialURL, accessMode: .create) else { throw ZIPProjectArchiveError.invalidArchive }
        try archive.addEntry(with: Self.projectEntry, fileURL: jsonURL, compressionMethod: .deflate)

        let assetPaths = project.fields["assets"]?.arrayValue?.compactMap { $0.objectValue?["path"]?.stringValue } ?? []
        var written = Set<String>()
        for rawPath in assetPaths {
            let path = try Self.normalizedPath(rawPath)
            guard path.hasPrefix("assets/") else { throw ZIPProjectArchiveError.unsafePath(path) }
            guard written.insert(path).inserted else { continue }
            guard let assetsDirectory else { throw ZIPProjectArchiveError.missingAsset(path) }
            let source = assetsDirectory.appendingPathComponent(String(path.dropFirst("assets/".count)))
            let root = assetsDirectory.standardizedFileURL.path + "/"
            guard source.standardizedFileURL.path.hasPrefix(root),
                  manager.fileExists(atPath: source.path) else { throw ZIPProjectArchiveError.missingAsset(path) }
            try archive.addEntry(with: path, fileURL: source, compressionMethod: .none)
        }
        try manager.createDirectory(at: archiveURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if manager.fileExists(atPath: archiveURL.path) { try manager.removeItem(at: archiveURL) }
        try manager.moveItem(at: partialURL, to: archiveURL)
    }

    private static func normalizedPath(_ raw: String, isDirectory: Bool = false) throws -> String {
        var path = raw.replacingOccurrences(of: "\\", with: "/")
        if isDirectory { while path.hasSuffix("/") { path.removeLast() } }
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        guard !path.isEmpty, !path.hasPrefix("/"), !path.contains(":"),
              !components.isEmpty,
              !components.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else {
            throw ZIPProjectArchiveError.unsafePath(raw)
        }
        return components.joined(separator: "/")
    }
}
