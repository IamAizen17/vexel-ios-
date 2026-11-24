import Foundation
import ZIPFoundation
import VexelCore

public struct ProjectArchivePayload: Sendable {
    public let project: ProjectDocument
    public let extractedAssetsDirectory: URL?
    public let compatibilityReport: [VexelUnsupportedFeature]

    public init(
        project: ProjectDocument,
        extractedAssetsDirectory: URL?,
        compatibilityReport: [VexelUnsupportedFeature] = []
    ) {
        self.project = project
        self.extractedAssetsDirectory = extractedAssetsDirectory
        self.compatibilityReport = compatibilityReport
    }
}

public enum ZIPProjectArchiveError: Error, Equatable {
    case invalidArchive
    case unsafePath(String)
    case duplicateEntry(String)
    case unsupportedEntryType(String)
    case unsupportedProjectFormat
    case tooManyEntries
    case projectDocumentTooLarge
    case archiveTooLarge
    case missingProjectDocument
    case missingAsset(String)
    case destinationReplacementFailed(String)
    case destinationRollbackFailed(String, String)
}

public struct ZIPProjectArchive: Sendable {
    private let maximumExtractedBytes: UInt64
    private let moveItemAction: @Sendable (URL, URL) throws -> Void
    public static let projectEntry = "vexel.json"
    public static let legacyProjectEntry = "project.json"
    public static let maximumEntries = 10_000
    public static let maximumProjectBytes: UInt64 = 64 * 1024 * 1024
    public static let maximumEntryUncompressedBytes: UInt64 = 2 * 1024 * 1024 * 1024
    public static let maximumUncompressedBytes: UInt64 = 8 * 1024 * 1024 * 1024
    public static let maximumCompressionRatio = 500.0

    public init() {
        maximumExtractedBytes = Self.maximumUncompressedBytes
        moveItemAction = { try FileManager.default.moveItem(at: $0, to: $1) }
    }

    init(
        maximumExtractedBytes: UInt64,
        moveItemAction: @escaping @Sendable (URL, URL) throws -> Void = { try FileManager.default.moveItem(at: $0, to: $1) }
    ) {
        self.maximumExtractedBytes = min(maximumExtractedBytes, Self.maximumUncompressedBytes)
        self.moveItemAction = moveItemAction
    }

    public func read(from archiveURL: URL, extractingAssetsTo destination: URL? = nil) throws -> ProjectArchivePayload {
        guard let archive = Archive(url: archiveURL, accessMode: .read) else {
            throw ZIPProjectArchiveError.invalidArchive
        }
        let manager = FileManager.default
        let staging = destination.map {
            $0.deletingLastPathComponent().appendingPathComponent(".\($0.lastPathComponent).staging-\(UUID().uuidString)", isDirectory: true)
        } ?? manager.temporaryDirectory.appendingPathComponent("VexelImport-\(UUID().uuidString)", isDirectory: true)
        var keepStaging = false
        defer { if !keepStaging { try? manager.removeItem(at: staging) } }
        try manager.createDirectory(at: staging, withIntermediateDirectories: true)

        var seen = Set<String>()
        var total: UInt64 = 0
        var actualTotal: UInt64 = 0
        var project: ProjectDocument?
        var entryCount = 0

        do {
            for entry in archive {
                entryCount += 1
                guard entryCount <= Self.maximumEntries else { throw ZIPProjectArchiveError.tooManyEntries }
                let path = try Self.normalizedPath(entry.path, isDirectory: entry.type == .directory)
                guard seen.insert(path).inserted else { throw ZIPProjectArchiveError.duplicateEntry(path) }
                guard entry.type != .symlink else { throw ZIPProjectArchiveError.unsupportedEntryType(path) }
                if entry.type == .directory {
                    guard path == "assets" || path.hasPrefix("assets/") else {
                        throw ZIPProjectArchiveError.unsupportedEntryType(path)
                    }
                    continue
                }
                guard entry.type == .file else { throw ZIPProjectArchiveError.unsupportedEntryType(path) }

                let (nextTotal, overflow) = total.addingReportingOverflow(entry.uncompressedSize)
                guard !overflow, nextTotal <= Self.maximumUncompressedBytes else {
                    throw ZIPProjectArchiveError.archiveTooLarge
                }
                total = nextTotal
                guard entry.uncompressedSize <= Self.maximumEntryUncompressedBytes else {
                    throw ZIPProjectArchiveError.archiveTooLarge
                }
                if entry.uncompressedSize > 0 {
                    guard entry.compressedSize > 0 else { throw ZIPProjectArchiveError.archiveTooLarge }
                    let ratio = Double(entry.uncompressedSize) / Double(entry.compressedSize)
                    guard ratio.isFinite, ratio <= Self.maximumCompressionRatio else {
                        throw ZIPProjectArchiveError.archiveTooLarge
                    }
                }

                if path == Self.projectEntry || path == Self.legacyProjectEntry {
                    guard project == nil else { throw ZIPProjectArchiveError.duplicateEntry(path) }
                    guard entry.uncompressedSize <= Self.maximumProjectBytes else {
                        throw ZIPProjectArchiveError.projectDocumentTooLarge
                    }
                    var data = Data()
                    let remaining = maximumExtractedBytes - actualTotal
                    let extracted = try Self.extract(
                        entry,
                        from: archive,
                        maximumBytes: min(Self.maximumProjectBytes, remaining)
                    ) { chunk in
                        data.append(chunk)
                    }
                    actualTotal += extracted
                    project = try VexelProjectImporter.importDocument(from: data)
                    continue
                }

                let isAssetFile = path.hasPrefix("assets/") && entry.type == .file
                let isThumbnail = (path == "thumbnail.png" || path == "thumbnail.jpg") && entry.type == .file
                guard isAssetFile || isThumbnail else {
                    throw ZIPProjectArchiveError.unsupportedEntryType(path)
                }
                let target = staging.appendingPathComponent(path)
                let root = staging.standardizedFileURL.path + "/"
                let standardized = target.standardizedFileURL.path
                guard standardized.hasPrefix(root) else { throw ZIPProjectArchiveError.unsafePath(path) }
                try manager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                guard manager.createFile(atPath: target.path, contents: nil) else {
                    throw ZIPProjectArchiveError.invalidArchive
                }
                do {
                    let handle = try FileHandle(forWritingTo: target)
                    defer { try? handle.close() }
                    let remaining = maximumExtractedBytes - actualTotal
                    let extracted = try Self.extract(
                        entry,
                        from: archive,
                        maximumBytes: min(Self.maximumEntryUncompressedBytes, remaining)
                    ) { chunk in
                        try handle.write(contentsOf: chunk)
                    }
                    actualTotal += extracted
                } catch {
                    try? manager.removeItem(at: target)
                    throw error
                }
            }

            guard let project else { throw ZIPProjectArchiveError.missingProjectDocument }
            let issues = project.validate().filter { $0.severity == .error }
            guard issues.isEmpty else {
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: issues.map { "\($0.path): \($0.message)" }.joined(separator: "\n")))
            }
            let archivedAssets = Set(seen)
            for asset in project.fields["assets"]?.arrayValue ?? [] {
                guard let path = asset.objectValue?["path"]?.stringValue else { continue }
                guard archivedAssets.contains(path) else { throw ZIPProjectArchiveError.missingAsset(path) }
            }
            if let destination {
                try manager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                let backup = destination.deletingLastPathComponent()
                    .appendingPathComponent(".\(destination.lastPathComponent).backup-\(UUID().uuidString)", isDirectory: true)
                let hadDestination = manager.fileExists(atPath: destination.path)
                if hadDestination { try moveItemAction(destination, backup) }
                do {
                    try moveItemAction(staging, destination)
                    if hadDestination { try? manager.removeItem(at: backup) }
                } catch {
                    if hadDestination, manager.fileExists(atPath: backup.path) {
                        do {
                            try moveItemAction(backup, destination)
                        } catch {
                            throw ZIPProjectArchiveError.destinationRollbackFailed(backup.path, error.localizedDescription)
                        }
                    }
                    throw ZIPProjectArchiveError.destinationReplacementFailed(error.localizedDescription)
                }
                return ProjectArchivePayload(project: project, extractedAssetsDirectory: destination, compatibilityReport: VexelProjectImporter.compatibilityReport(for: project))
            }
            keepStaging = true
            return ProjectArchivePayload(project: project, extractedAssetsDirectory: staging, compatibilityReport: VexelProjectImporter.compatibilityReport(for: project))
        } catch {
            throw error
        }
    }

    public func write(_ project: ProjectDocument, assetsDirectory: URL? = nil, to archiveURL: URL) throws {
        guard project.fields["format"]?.stringValue == ProjectDocument.format else {
            throw ZIPProjectArchiveError.unsupportedProjectFormat
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
        guard let archive = Archive(url: partialURL, accessMode: .create) else {
            throw ZIPProjectArchiveError.invalidArchive
        }
        try archive.addEntry(with: Self.projectEntry, fileURL: jsonURL, compressionMethod: .deflate)

        let assetPaths = project.fields["assets"]?.arrayValue?.compactMap { $0.objectValue?["path"]?.stringValue } ?? []
        var written = Set<String>()
        for rawPath in assetPaths {
            let path = try Self.normalizedPath(rawPath)
            guard path.hasPrefix("assets/") else { throw ZIPProjectArchiveError.unsafePath(path) }
            guard written.insert(path).inserted else { continue }
            guard let assetsDirectory else { throw ZIPProjectArchiveError.missingAsset(path) }
            let source = assetsDirectory.appendingPathComponent(path)
            let rootURL = assetsDirectory.resolvingSymlinksInPath().standardizedFileURL
            let sourceURL = source.resolvingSymlinksInPath().standardizedFileURL
            let root = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"
            let values = try? sourceURL.resourceValues(forKeys: [.isRegularFileKey])
            guard sourceURL.path.hasPrefix(root), values?.isRegularFile == true else {
                throw ZIPProjectArchiveError.missingAsset(path)
            }
            try archive.addEntry(with: path, fileURL: sourceURL, compressionMethod: .none)
        }

        try manager.createDirectory(at: archiveURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if manager.fileExists(atPath: archiveURL.path) {
            _ = try manager.replaceItemAt(archiveURL, withItemAt: partialURL, backupItemName: nil, options: [])
        } else {
            try manager.moveItem(at: partialURL, to: archiveURL)
        }
    }

    private static func extract(
        _ entry: Archive.Entry,
        from archive: Archive,
        maximumBytes: UInt64,
        consume: (Data) throws -> Void
    ) throws -> UInt64 {
        var extractedBytes: UInt64 = 0
        _ = try archive.extract(entry, consumer: { chunk in
            let (next, overflow) = extractedBytes.addingReportingOverflow(UInt64(chunk.count))
            guard !overflow, next <= maximumBytes else {
                throw ZIPProjectArchiveError.archiveTooLarge
            }
            try consume(chunk)
            extractedBytes = next
        })
        guard extractedBytes == entry.uncompressedSize else {
            throw ZIPProjectArchiveError.invalidArchive
        }
        return extractedBytes
    }

    private static func normalizedPath(_ raw: String, isDirectory: Bool = false) throws -> String {
        var path = raw.replacingOccurrences(of: "\\", with: "/")
        if isDirectory {
            while path.hasSuffix("/") { path.removeLast() }
        }
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        guard !path.isEmpty,
              path.utf8.count <= 1024,
              !path.hasPrefix("/"),
              !path.contains(":"),
              components.count <= 32,
              !components.isEmpty,
              !components.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else {
            throw ZIPProjectArchiveError.unsafePath(raw)
        }
        return components.joined(separator: "/")
    }
}
