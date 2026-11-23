import Foundation
import ZIPFoundation

public struct KnsprojImportResult: Sendable {
    public let project: ProjectDocument
    public let projectDirectory: URL
    public let sourceVersion: Int
    public let importedAssetCount: Int
    public let importedEntryCount: Int
}

public enum KnsprojImportError: Error, Equatable, LocalizedError {
    case archiveCannotOpen
    case tooManyEntries
    case archiveTooLarge
    case projectJSONTooLarge
    case missingProjectJSON
    case duplicateEntry(String)
    case unsafeEntryPath(String)
    case unsupportedEntryType(String)
    case missingOrInvalidFormat
    case unsupportedVersion(Int)
    case invalidProjectJSON(String)
    case invalidDestination

    public var errorDescription: String? {
        switch self {
        case .archiveCannotOpen: return "The selected file is not a readable ZIP project archive."
        case .tooManyEntries: return "The project contains more than 10,000 archive entries."
        case .archiveTooLarge: return "The project exceeds the 8 GiB uncompressed import limit."
        case .projectJSONTooLarge: return "project.json exceeds the 64 MiB size limit."
        case .missingProjectJSON: return "The archive does not contain project.json."
        case .duplicateEntry(let path): return "The archive contains a duplicate entry: \(path)."
        case .unsafeEntryPath(let path): return "The archive contains an unsafe path: \(path)."
        case .unsupportedEntryType(let path): return "The archive contains an unsupported symbolic link: \(path)."
        case .missingOrInvalidFormat: return "project.json is not a Kinesis .knsproj document."
        case .unsupportedVersion(let version): return "Kinesis project version \(version) is not supported. Vexel currently imports versions 1 through 12."
        case .invalidProjectJSON(let reason): return "project.json could not be decoded: \(reason)"
        case .invalidDestination: return "The import destination could not be created."
        }
    }
}

public struct KnsprojArchiveImporter {
    public static let maximumProjectJSONBytes: UInt64 = 64 * 1024 * 1024
    public static let maximumUncompressedBytes: UInt64 = 8 * 1024 * 1024 * 1024
    public static let maximumEntryCount = 10_000
    public static let currentSourceVersion = 12

    public init() {}

    public func importProject(from archiveURL: URL, into destination: URL) throws -> KnsprojImportResult {
        let archive: Archive
        do {
            archive = try Archive(url: archiveURL, accessMode: .read)
        } catch {
            throw KnsprojImportError.archiveCannotOpen
        }

        let entries = Array(archive)
        guard entries.count <= Self.maximumEntryCount else {
            throw KnsprojImportError.tooManyEntries
        }

        var seenPaths = Set<String>()
        var totalBytes: UInt64 = 0
        var projectEntry: Entry?
        var filesToExtract: [(Entry, String)] = []

        for entry in entries {
            let path = entry.path
            let candidate = entry.type == .directory && path.hasSuffix("/") ? String(path.dropLast()) : path
            guard let normalized = Self.normalizedPath(candidate), normalized == candidate else {
                throw KnsprojImportError.unsafeEntryPath(path)
            }
            guard seenPaths.insert(normalized).inserted else {
                throw KnsprojImportError.duplicateEntry(normalized)
            }
            if entry.type == .symlink {
                throw KnsprojImportError.unsupportedEntryType(path)
            }
            if entry.type == .directory {
                continue
            }
            guard entry.type == .file else {
                throw KnsprojImportError.unsupportedEntryType(path)
            }

            let size = entry.uncompressedSize
            let (nextTotal, overflow) = totalBytes.addingReportingOverflow(size)
            guard !overflow, nextTotal <= Self.maximumUncompressedBytes else {
                throw KnsprojImportError.archiveTooLarge
            }
            totalBytes = nextTotal

            if normalized == "project.json" {
                guard size <= Self.maximumProjectJSONBytes else {
                    throw KnsprojImportError.projectJSONTooLarge
                }
                projectEntry = entry
            } else {
                filesToExtract.append((entry, normalized))
            }
        }

        guard let projectEntry else {
            throw KnsprojImportError.missingProjectJSON
        }

        var projectData = Data()
        do {
            _ = try archive.extract(projectEntry, bufferSize: 64 * 1024) { chunk in
                guard UInt64(projectData.count) + UInt64(chunk.count) <= Self.maximumProjectJSONBytes else {
                    throw KnsprojImportError.projectJSONTooLarge
                }
                projectData.append(chunk)
            }
        } catch let error as KnsprojImportError {
            throw error
        } catch {
            throw KnsprojImportError.invalidProjectJSON(error.localizedDescription)
        }

        let originalRoot: JSONValue
        do {
            originalRoot = try JSONDecoder().decode(JSONValue.self, from: projectData)
        } catch {
            throw KnsprojImportError.invalidProjectJSON(error.localizedDescription)
        }
        guard case .object(let originalFields) = originalRoot,
              originalFields["format"]?.stringValue == "knsproj" else {
            throw KnsprojImportError.missingOrInvalidFormat
        }

        guard let versionNumber = originalFields["formatVersion"]?.numberValue,
              versionNumber.isFinite,
              versionNumber.rounded(.towardZero) == versionNumber,
              versionNumber >= 1,
              versionNumber <= Double(Self.currentSourceVersion) else {
            let rawVersion = originalFields["formatVersion"]?.numberValue ?? 0
            if rawVersion > Double(Self.currentSourceVersion) {
                let safeVersion = rawVersion >= Double(Int.max) ? Int.max : Int(rawVersion)
                throw KnsprojImportError.unsupportedVersion(safeVersion)
            }
            throw KnsprojImportError.missingOrInvalidFormat
        }
        let sourceVersion = Int(versionNumber)
        let migratedFields = Self.migrate(originalFields, from: sourceVersion)

        let projectDirectory = destination.appendingPathComponent("Imported-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
            for (entry, path) in filesToExtract {
                let target = path.split(separator: "/").reduce(projectDirectory) {
                    $0.appendingPathComponent(String($1), isDirectory: false)
                }
                _ = try archive.extract(entry, to: target, bufferSize: 64 * 1024, symlinksValidWithin: projectDirectory)
            }
        } catch {
            try? FileManager.default.removeItem(at: projectDirectory)
            throw error
        }

        var vexelFields: [String: JSONValue] = [
            "format": .string(ProjectDocument.format),
            "formatVersion": .number(Double(ProjectDocument.currentVersion)),
            "generator": .string("Vexel iOS"),
            "compatibility": .object([
                "sourceFormat": .string("knsproj"),
                "sourceFormatVersion": .number(Double(sourceVersion)),
                "migratedSourceVersion": .number(Double(Self.currentSourceVersion)),
                "sourceDocument": .object(originalFields)
            ])
        ]

        for key in ["meta", "composition", "assets", "markers", "editorView", "layers"] {
            if let value = migratedFields[key] {
                vexelFields[key] = value
            }
        }
        if vexelFields["meta"] == nil {
            vexelFields["meta"] = .object(["title": .string("Imported Kinesis Project")])
        }

        let document = ProjectDocument(fields: vexelFields)
        let issues = document.validate()
        if let firstError = issues.first(where: { $0.severity == .error }) {
            try? FileManager.default.removeItem(at: projectDirectory)
            throw KnsprojImportError.invalidProjectJSON(firstError.message)
        }

        return KnsprojImportResult(
            project: document,
            projectDirectory: projectDirectory,
            sourceVersion: sourceVersion,
            importedAssetCount: filesToExtract.filter { $0.1.hasPrefix("assets/") }.count,
            importedEntryCount: filesToExtract.count
        )
    }

    public static func normalizedPath(_ raw: String) -> String? {
        guard !raw.isEmpty,
              !raw.hasPrefix("/"),
              !raw.contains("\\"),
              !raw.contains(":"),
              !raw.utf8.contains(0) else {
            return nil
        }
        let components = raw.split(separator: "/", omittingEmptySubsequences: false)
        guard !components.isEmpty,
              !components.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else {
            return nil
        }
        return components.joined(separator: "/")
    }

    private static func migrate(_ original: [String: JSONValue], from version: Int) -> [String: JSONValue] {
        var document = original
        var current = version
        while current < currentSourceVersion {
            switch current {
            case 1:
                document = migrateV1ToV2(document)
            case 6:
                document = migrateV6ToV7(document)
            case 11:
                document = migrateV11ToV12(document)
            default:
                break
            }
            current += 1
            document["formatVersion"] = .number(Double(current))
        }
        return document
    }

    private static func migrateV1ToV2(_ document: [String: JSONValue]) -> [String: JSONValue] {
        func migrateLayer(_ value: JSONValue) -> JSONValue {
            guard var layer = value.objectValue else { return value }
            if let effects = layer["effects"]?.arrayValue {
                var migrated: [JSONValue] = []
                for effect in effects {
                    guard let object = effect.objectValue,
                          object["type"]?.stringValue == "colorAdjust" else {
                        migrated.append(effect)
                        continue
                    }
                    let enabled = object["enabled"]
                    func replacement(_ type: String, keys: [String]) -> JSONValue? {
                        let present = keys.filter { object[$0] != nil }
                        guard !present.isEmpty else { return nil }
                        var result: [String: JSONValue] = ["type": .string(type)]
                        if let enabled { result["enabled"] = enabled }
                        for key in present { result[key] = object[key] }
                        return .object(result)
                    }
                    let parts = [
                        replacement("hueShift", keys: ["hue"]),
                        replacement("brightnessContrast", keys: ["brightness", "contrast"]),
                        replacement("saturation", keys: ["saturation"])
                    ].compactMap { $0 }
                    if parts.isEmpty {
                        var neutral: [String: JSONValue] = ["type": .string("brightnessContrast")]
                        if let enabled { neutral["enabled"] = enabled }
                        migrated.append(.object(neutral))
                    } else {
                        migrated.append(contentsOf: parts)
                    }
                }
                layer["effects"] = .array(migrated)
            }
            if let children = layer["layers"]?.arrayValue {
                layer["layers"] = .array(children.map(migrateLayer))
            }
            return .object(layer)
        }
        var result = document
        if let layers = result["layers"]?.arrayValue {
            result["layers"] = .array(layers.map(migrateLayer))
        }
        return result
    }

    private static func migrateV6ToV7(_ document: [String: JSONValue]) -> [String: JSONValue] {
        func walk(_ value: JSONValue) -> JSONValue {
            switch value {
            case .object(let object):
                if object.count == 1, let cyclic = object["cyclic"]?.objectValue {
                    var updated = cyclic
                    let offset = cyclic["offset"]?.numberValue ?? 0
                    updated.removeValue(forKey: "offset")
                    if offset != 0 { updated["phase"] = .number(offset) }
                    return .object(["cyclic": .object(updated)])
                }
                return .object(object.mapValues(walk))
            case .array(let values):
                return .array(values.map(walk))
            default:
                return value
            }
        }
        return document.mapValues(walk)
    }

    private static func migrateV11ToV12(_ document: [String: JSONValue]) -> [String: JSONValue] {
        func walk(_ value: JSONValue) -> JSONValue {
            switch value {
            case .object(let object):
                var updated: [String: JSONValue] = [:]
                let isMedia = object["asset"] != nil && object["roto"] != nil
                for (key, child) in object {
                    if isMedia && key == "roto" {
                        if object["cutout"] == nil { updated["cutout"] = child }
                    } else {
                        updated[key] = walk(child)
                    }
                }
                return .object(updated)
            case .array(let values):
                return .array(values.map(walk))
            default:
                return value
            }
        }
        return walk(.object(document)).objectValue ?? document
    }
}
