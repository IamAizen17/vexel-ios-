import Foundation

enum VexelProjectStore {
    enum StoreError: Error {
        case invalidAssetDirectory
        case invalidSourceFile
        case assetTooLarge
    }

    struct ImportedAsset {
        let id: String
        let type: String
        let path: String
        let name: String
        let mimeType: String?
        let fileURL: URL
    }

    private static let directoryName = "Projects"
    private static let fileName = "index.json"
    private static let encoder: JSONEncoder = {
        let value = JSONEncoder()
        value.outputFormatting = [.prettyPrinted, .sortedKeys]
        value.dateEncodingStrategy = .iso8601
        return value
    }()
    private static let decoder: JSONDecoder = {
        let value = JSONDecoder()
        value.dateDecodingStrategy = .iso8601
        return value
    }()

    static func load() throws -> [VexelProjectItem] {
        let directory = try projectDirectory()
        let url = directory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        var projects = try decoder.decode([VexelProjectItem].self, from: data)
        for index in projects.indices {
            projects[index].synchronizeDocument()
        }
        return projects
    }

    static func save(_ projects: [VexelProjectItem]) throws {
        let directory = try projectDirectory()
        var snapshots = projects
        for index in snapshots.indices {
            snapshots[index].synchronizeDocument()
        }
        let data = try encoder.encode(snapshots)
        try data.write(to: directory.appendingPathComponent(fileName), options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    static func assetsDirectory(for projectID: UUID) throws -> URL {
        let directory = try assetsRoot().appendingPathComponent(projectID.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func duplicate(_ project: VexelProjectItem) throws -> VexelProjectItem {
        var copy = project
        copy.id = UUID()
        copy.title = project.title + " Copy"
        copy.modified = Date()

        let destination = try assetsRoot().appendingPathComponent(copy.id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let sourcePath = project.assetsDirectory {
            let source = URL(fileURLWithPath: sourcePath).resolvingSymlinksInPath().standardizedFileURL
            let root = try assetsRoot().resolvingSymlinksInPath().standardizedFileURL
            let rootPrefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
            guard source.path.hasPrefix(rootPrefix), source != root else { throw StoreError.invalidAssetDirectory }
            if FileManager.default.fileExists(atPath: source.path) {
                try FileManager.default.copyItem(at: source, to: destination)
            } else {
                try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            }
        } else {
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        }
        copy.assetsDirectory = destination.path
        copy.synchronizeDocument()
        return copy
    }

    static func importAsset(from source: URL, projectID: UUID, type: String, mimeType: String?) throws -> ImportedAsset {
        let sourceURL = source.resolvingSymlinksInPath().standardizedFileURL
        let values = try? sourceURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values?.isRegularFile == true, (values?.fileSize ?? 0) > 0 else {
            throw StoreError.invalidSourceFile
        }
        guard UInt64(values?.fileSize ?? 0) <= 4 * 1024 * 1024 * 1024 else {
            throw StoreError.assetTooLarge
        }
        let id = UUID().uuidString.lowercased()
        let ext = sourceURL.pathExtension.lowercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
        let fileName = ext.isEmpty ? id : "\(id).\(ext)"
        let root = try assetsDirectory(for: projectID)
        let folder = root.appendingPathComponent("assets", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appendingPathComponent(fileName)
        let temporary = folder.appendingPathComponent(".\(fileName).partial")
        do {
            try FileManager.default.copyItem(at: sourceURL, to: temporary)
            try FileManager.default.moveItem(at: temporary, to: destination)
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            throw error
        }
        return ImportedAsset(
            id: id,
            type: type,
            path: "assets/\(fileName)",
            name: sourceURL.lastPathComponent,
            mimeType: mimeType,
            fileURL: destination
        )
    }

    static func deleteAssets(for project: VexelProjectItem) throws {
        guard let path = project.assetsDirectory else { return }
        let source = URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL
        let root = try assetsRoot().resolvingSymlinksInPath().standardizedFileURL
        let prefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard source.path.hasPrefix(prefix), source != root else { throw StoreError.invalidAssetDirectory }
        if FileManager.default.fileExists(atPath: source.path) {
            try FileManager.default.removeItem(at: source)
        }
    }

    private static func assetsRoot() throws -> URL {
        let root = try projectDirectory().appendingPathComponent("Assets", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private static func projectDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent(directoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = false
        var mutable = directory
        try? mutable.setResourceValues(values)
        return directory
    }
}
