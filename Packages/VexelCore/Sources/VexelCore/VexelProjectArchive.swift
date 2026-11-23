import Foundation
import ZIPFoundation

public struct VexelProjectLoadResult: Sendable {
    public let project: ProjectDocument
    public let projectDirectory: URL
    public let importedFileCount: Int
}

public enum VexelProjectArchiveError: Error, Equatable, LocalizedError {
    case archiveCannotOpen
    case invalidProjectFormat
    case unsupportedProjectVersion
    case missingProjectJSON
    case projectJSONTooLarge
    case archiveTooLarge
    case tooManyEntries
    case unsafePath(String)
    case duplicateEntry(String)
    case symbolicLinkNotAllowed(String)
    case missingAsset(String)
    case invalidProject(String)
    case cannotWriteArchive

    public var errorDescription: String? {
        switch self {
        case .archiveCannotOpen: return "The selected file is not a readable Vexel project archive."
        case .invalidProjectFormat: return "The archive does not contain a valid .vexelproj document."
        case .unsupportedProjectVersion: return "This Vexel project version is not supported by this app."
        case .missingProjectJSON: return "The archive does not contain project.json."
        case .projectJSONTooLarge: return "project.json exceeds the 64 MiB size limit."
        case .archiveTooLarge: return "The archive exceeds the 8 GiB uncompressed size limit."
        case .tooManyEntries: return "The archive contains more than 10,000 entries."
        case .unsafePath(let path): return "The archive contains an unsafe path: \(path)."
        case .duplicateEntry(let path): return "The archive contains a duplicate entry: \(path)."
        case .symbolicLinkNotAllowed(let path): return "Symbolic links are not allowed in Vexel projects: \(path)."
        case .missingAsset(let path): return "A referenced project asset is missing: \(path)."
        case .invalidProject(let reason): return "The Vexel project is invalid: \(reason)"
        case .cannotWriteArchive: return "The project archive could not be written."
        }
    }
}

public struct VexelProjectArchive {
    public static let maximumProjectJSONBytes: UInt64 = 64 * 1024 * 1024
    public static let maximumUncompressedBytes: UInt64 = 8 * 1024 * 1024 * 1024
    public static let maximumEntryCount = 10_000

    public init() {}

    public func save(
        _ project: ProjectDocument,
        assetsDirectory: URL,
        to destinationURL: URL,
        thumbnailJPEG: Data? = nil
    ) throws {
        if let issue = project.validate().first(where: { $0.severity == .error }) {
            throw VexelProjectArchiveError.invalidProject(issue.message)
        }
        let json = try project.encoded()
        guard UInt64(json.count) <= Self.maximumProjectJSONBytes else {
            throw VexelProjectArchiveError.projectJSONTooLarge
        }

        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let temporaryURL = destinationURL.deletingLastPathComponent()
            .appendingPathComponent(".vexel-\(UUID().uuidString).tmp")

        do {
            try writeArchive(
                projectData: json,
                assetsDirectory: assetsDirectory,
                destination: temporaryURL,
                thumbnailJPEG: thumbnailJPEG
            )
            if fileManager.fileExists(atPath: destinationURL.path) {
                _ = try fileManager.replaceItemAt(
                    destinationURL,
                    withItemAt: temporaryURL,
                    backupItemName: nil,
                    options: .usingNewMetadataOnly
                )
            } else {
                try fileManager.moveItem(at: temporaryURL, to: destinationURL)
            }
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw error
        }
    }

    public func open(from archiveURL: URL, into destination: URL) throws -> VexelProjectLoadResult {
        let archive: Archive
        do {
            archive = try Archive(url: archiveURL, accessMode: .read, pathEncoding: .utf8)
        } catch {
            throw VexelProjectArchiveError.archiveCannotOpen
        }

        let entries = Array(archive)
        guard entries.count <= Self.maximumEntryCount else {
            throw VexelProjectArchiveError.tooManyEntries
        }

        var seen = Set<String>()
        var total: UInt64 = 0
        var projectEntry: Entry?
        var files: [(Entry, String)] = []

        for entry in entries {
            let rawPath = entry.path
            let candidate = entry.type == .directory && rawPath.hasSuffix("/") ? String(rawPath.dropLast()) : rawPath
            guard let path = KnsprojArchiveImporter.normalizedPath(candidate), path == candidate else {
                throw VexelProjectArchiveError.unsafePath(rawPath)
            }
            guard seen.insert(path).inserted else {
                throw VexelProjectArchiveError.duplicateEntry(path)
            }
            if entry.type == .symlink {
                throw VexelProjectArchiveError.symbolicLinkNotAllowed(rawPath)
            }
            if entry.type == .directory { continue }
            guard entry.type == .file else {
                throw VexelProjectArchiveError.symbolicLinkNotAllowed(rawPath)
            }

            let (next, overflow) = total.addingReportingOverflow(entry.uncompressedSize)
            guard !overflow, next <= Self.maximumUncompressedBytes else {
                throw VexelProjectArchiveError.archiveTooLarge
            }
            total = next

            if path == "project.json" {
                guard entry.uncompressedSize <= Self.maximumProjectJSONBytes else {
                    throw VexelProjectArchiveError.projectJSONTooLarge
                }
                projectEntry = entry
            } else {
                files.append((entry, path))
            }
        }

        guard let projectEntry else { throw VexelProjectArchiveError.missingProjectJSON }

        var projectData = Data()
        do {
            _ = try archive.extract(projectEntry, bufferSize: 64 * 1024) { chunk in
                guard UInt64(projectData.count) + UInt64(chunk.count) <= Self.maximumProjectJSONBytes else {
                    throw VexelProjectArchiveError.projectJSONTooLarge
                }
                projectData.append(chunk)
            }
        } catch let error as VexelProjectArchiveError {
            throw error
        } catch {
            throw VexelProjectArchiveError.invalidProject(error.localizedDescription)
        }

        let project: ProjectDocument
        do {
            project = try ProjectDocument(data: projectData)
        } catch {
            throw VexelProjectArchiveError.invalidProject(error.localizedDescription)
        }
        guard project.fields["format"]?.stringValue == ProjectDocument.format else {
            throw VexelProjectArchiveError.invalidProjectFormat
        }
        guard project.fields["formatVersion"]?.numberValue == Double(ProjectDocument.currentVersion) else {
            throw VexelProjectArchiveError.unsupportedProjectVersion
        }
        if let issue = project.validate().first(where: { $0.severity == .error }) {
            throw VexelProjectArchiveError.invalidProject(issue.message)
        }

        let entryPaths = Set(files.map(\.1))
        for asset in project.fields["assets"]?.arrayValue ?? [] {
            guard let path = asset.objectValue?["path"]?.stringValue,
                  entryPaths.contains(path) else {
                throw VexelProjectArchiveError.missingAsset(asset.objectValue?["path"]?.stringValue ?? "unknown")
            }
        }

        let projectDirectory = destination.appendingPathComponent("Project-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
            for (entry, path) in files {
                let target = path.split(separator: "/").reduce(projectDirectory) {
                    $0.appendingPathComponent(String($1), isDirectory: false)
                }
                _ = try archive.extract(entry, to: target, bufferSize: 64 * 1024, symlinksValidWithin: projectDirectory)
            }
        } catch {
            try? FileManager.default.removeItem(at: projectDirectory)
            throw error
        }

        return VexelProjectLoadResult(
            project: project,
            projectDirectory: projectDirectory,
            importedFileCount: files.count
        )
    }

    private func writeArchive(
        projectData: Data,
        assetsDirectory: URL,
        destination: URL,
        thumbnailJPEG: Data?
    ) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: assetsDirectory, withIntermediateDirectories: true)

        var files: [(String, URL)] = []
        var totalBytes = UInt64(projectData.count)
        let referencedAssets = Set((try JSONDecoder().decode(JSONValue.self, from: projectData))
            .objectValue?["assets"]?.arrayValue?.compactMap { $0.objectValue?["path"]?.stringValue } ?? [])

        for relativePath in try fileManager.subpathsOfDirectory(atPath: assetsDirectory.path) {
            guard let safePath = KnsprojArchiveImporter.normalizedPath(relativePath), safePath == relativePath else {
                throw VexelProjectArchiveError.unsafePath(relativePath)
            }
            if safePath == "project.json" { continue }
            if safePath == "thumbnail.jpg", thumbnailJPEG != nil { continue }

            let fileURL = assetsDirectory.appendingPathComponent(relativePath)
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            let type = attributes[.type] as? FileAttributeType
            if type == .typeSymbolicLink {
                throw VexelProjectArchiveError.symbolicLinkNotAllowed(relativePath)
            }
            guard type == .typeRegular else { continue }

            let size = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
            let (next, overflow) = totalBytes.addingReportingOverflow(size)
            guard !overflow, next <= Self.maximumUncompressedBytes else {
                throw VexelProjectArchiveError.archiveTooLarge
            }
            totalBytes = next
            files.append((safePath, fileURL))
        }

        let available = Set(files.map(\.0))
        for path in referencedAssets where !available.contains(path) {
            throw VexelProjectArchiveError.missingAsset(path)
        }
        guard files.count + (thumbnailJPEG == nil ? 1 : 2) <= Self.maximumEntryCount else {
            throw VexelProjectArchiveError.tooManyEntries
        }

        let archive = try Archive(url: destination, accessMode: .create, pathEncoding: .utf8)
        try archive.addEntry(
            with: "project.json",
            type: .file,
            uncompressedSize: Int64(projectData.count),
            compressionMethod: .deflate,
            provider: { position, size in
                let start = Int(position)
                guard start < projectData.count else { return Data() }
                return projectData.subdata(in: start..<min(start + size, projectData.count))
            }
        )
        for (path, fileURL) in files.sorted(by: { $0.0 < $1.0 }) {
            try archive.addEntry(with: path, fileURL: fileURL, compressionMethod: .none)
        }
        if let thumbnailJPEG {
            let (totalWithThumbnail, overflow) = totalBytes.addingReportingOverflow(UInt64(thumbnailJPEG.count))
            guard !overflow, totalWithThumbnail <= Self.maximumUncompressedBytes else {
                throw VexelProjectArchiveError.archiveTooLarge
            }
            try archive.addEntry(
                with: "thumbnail.jpg",
                type: .file,
                uncompressedSize: Int64(thumbnailJPEG.count),
                compressionMethod: .none,
                provider: { position, size in
                    let start = Int(position)
                    guard start < thumbnailJPEG.count else { return Data() }
                    return thumbnailJPEG.subdata(in: start..<min(start + size, thumbnailJPEG.count))
                }
            )
        }
    }
}
