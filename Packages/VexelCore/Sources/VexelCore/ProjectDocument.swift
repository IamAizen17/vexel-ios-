import Foundation

public struct ProjectIssue: Equatable, Sendable {
    public enum Severity: String, Sendable {
        case warning
        case error
    }

    public let severity: Severity
    public let path: String
    public let message: String

    public init(severity: Severity, path: String, message: String) {
        self.severity = severity
        self.path = path
        self.message = message
    }
}

public enum ProjectDocumentError: Error, Equatable {
    case invalidRoot
    case unsupportedFormat(String?)
    case unsupportedVersion(Int?)
}

public struct ProjectDocument: Codable, Equatable, Sendable {
    public static let format = "vexelproj"
    public static let currentVersion = 2

    public var fields: [String: JSONValue]

    public init(fields: [String: JSONValue]) {
        self.fields = fields
    }

    public init(data: Data) throws {
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        guard case .object(let fields) = decoded else {
            throw ProjectDocumentError.invalidRoot
        }
        self.fields = fields
    }

    public func migratedToCurrentVersion() throws -> ProjectDocument {
        guard fields["format"]?.stringValue == Self.format else {
            throw ProjectDocumentError.unsupportedFormat(fields["format"]?.stringValue)
        }
        guard let rawVersion = fields["formatVersion"]?.numberValue,
              rawVersion.isFinite,
              rawVersion.rounded(.towardZero) == rawVersion,
              rawVersion >= 1,
              rawVersion <= Double(Int.max) else {
            throw ProjectDocumentError.unsupportedVersion(nil)
        }
        var version = Int(rawVersion)
        guard version <= Self.currentVersion else {
            throw ProjectDocumentError.unsupportedVersion(version)
        }

        var migratedFields = fields
        while version < Self.currentVersion {
            switch version {
            case 1:
                Self.migrateV1ToV2(&migratedFields)
            default:
                throw ProjectDocumentError.unsupportedVersion(version)
            }
            version += 1
            migratedFields["formatVersion"] = .number(Double(version))
        }
        return ProjectDocument(fields: migratedFields)
    }

    private static func migrateV1ToV2(_ fields: inout [String: JSONValue]) {
        fields["generator"] = fields["generator"] ?? .string("Vexel")

        var metadata = fields["meta"]?.objectValue ?? [:]
        if metadata["title"]?.stringValue?.isEmpty ?? true {
            metadata["title"] = .string("Untitled")
        }
        fields["meta"] = .object(metadata)

        if fields["assets"] == nil { fields["assets"] = .array([]) }
        if fields["markers"] == nil { fields["markers"] = .array([]) }
        if fields["layers"] == nil { fields["layers"] = .array([]) }

        if var composition = fields["composition"]?.objectValue {
            if composition["background"] == nil {
                composition["background"] = .string("#0D0F12")
            }
            fields["composition"] = .object(composition)
        }
    }

    public var title: String {
        fields["meta"]?.objectValue?["title"]?.stringValue ?? "Untitled"
    }

    public var compositionSize: (width: Int, height: Int) {
        let composition = fields["composition"]?.objectValue
        let width = Self.boundedInteger(composition?["width"]?.numberValue, range: 16...8192, fallback: 1080)
        let height = Self.boundedInteger(composition?["height"]?.numberValue, range: 16...8192, fallback: 1920)
        return (width, height)
    }

    public var layerCount: Int {
        fields["layers"]?.arrayValue?.count ?? 0
    }

    public static func starter(title: String = "Untitled") -> ProjectDocument {
        ProjectDocument(fields: [
            "format": .string(format),
            "formatVersion": .number(Double(currentVersion)),
            "generator": .string("Vexel"),
            "meta": .object([
                "title": .string(title),
                "createdAt": .string(ISO8601DateFormatter().string(from: Date()))
            ]),
            "composition": .object([
                "width": .number(1080),
                "height": .number(1920),
                "fps": .number(30),
                "duration": .number(10),
                "background": .string("#0D0F12")
            ]),
            "assets": .array([]),
            "markers": .array([]),
            "layers": .array([])
        ])
    }

    public func validate() -> [ProjectIssue] {
        var issues: [ProjectIssue] = []
        validateFiniteNumbers(.object(fields), path: "$", issues: &issues)

        let documentFormat = fields["format"]?.stringValue
        let version = fields["formatVersion"]?.numberValue.flatMap { value -> Int? in
            guard value.isFinite, value.rounded(.towardZero) == value, value >= 1, value <= 10_000 else { return nil }
            return Int(value)
        }
        guard let documentFormat, documentFormat == Self.format else {
            issues.append(ProjectIssue(severity: .error, path: "format", message: "Expected a native Vexel project."))
            return issues
        }
        guard let version else {
            issues.append(ProjectIssue(severity: .error, path: "formatVersion", message: "A positive integer formatVersion is required."))
            return issues
        }
        if version != Self.currentVersion {
            issues.append(ProjectIssue(severity: .error, path: "formatVersion", message: "Unsupported Vexel project version. Expected \(Self.currentVersion)."))
            return issues
        }
        guard let composition = fields["composition"]?.objectValue else {
            issues.append(ProjectIssue(severity: .error, path: "composition", message: "Composition object is required."))
            return issues
        }

        let width = composition["width"]?.numberValue ?? 0
        let height = composition["height"]?.numberValue ?? 0
        let fps = composition["fps"]?.numberValue ?? 0
        let duration = composition["duration"]?.numberValue ?? 0

        if !(16...8192).contains(width) {
            issues.append(ProjectIssue(severity: .error, path: "composition.width", message: "Width must be between 16 and 8192 pixels."))
        }
        if !(16...8192).contains(height) {
            issues.append(ProjectIssue(severity: .error, path: "composition.height", message: "Height must be between 16 and 8192 pixels."))
        }
        if !(1...120).contains(fps) {
            issues.append(ProjectIssue(severity: .error, path: "composition.fps", message: "Frame rate must be between 1 and 120 FPS."))
        }
        if !(0.01...3600).contains(duration) {
            issues.append(ProjectIssue(severity: .error, path: "composition.duration", message: "Duration must be greater than zero and no more than one hour." ))
        }

        var assetTypes: [String: String] = [:]
        var assetIdentifiers = Set<String>()
        if let assets = fields["assets"]?.arrayValue {
            for (index, asset) in assets.enumerated() {
                guard let object = asset.objectValue else {
                    issues.append(ProjectIssue(severity: .error, path: "assets[\(index)]", message: "Asset must be an object."))
                    continue
                }
                guard let id = object["id"]?.stringValue, !id.isEmpty else {
                    issues.append(ProjectIssue(severity: .error, path: "assets[\(index)].id", message: "Asset ID is required."))
                    continue
                }
                if !assetIdentifiers.insert(id).inserted {
                    issues.append(ProjectIssue(severity: .error, path: "assets[\(index)].id", message: "Asset IDs must be unique."))
                }
                let type = object["type"]?.stringValue
                if let type, ["image", "video", "audio", "model", "font"].contains(type) {
                    assetTypes[id] = type
                } else {
                    issues.append(ProjectIssue(severity: .error, path: "assets[\(index)].type", message: "Asset type must be one of image, video, audio, model, or font."))
                }
                guard let path = object["path"]?.stringValue, Self.isSafeAssetPath(path) else {
                    issues.append(ProjectIssue(severity: .error, path: "assets[\(index)].path", message: "Asset path must be a safe relative path under assets/."))
                    continue
                }
            }
        }
        validateAssetReferences(fields, assetTypes: assetTypes, issues: &issues)

        if let layers = fields["layers"]?.arrayValue {
            var identifiers = Set<String>()
            validateLayers(layers, path: "layers", identifiers: &identifiers, issues: &issues)
        }

        return issues
    }

    public func encoded(prettyPrinted: Bool = true) throws -> Data {
        let encoder = JSONEncoder()
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        return try encoder.encode(JSONValue.object(fields))
    }

    private func validateLayers(
        _ layers: [JSONValue],
        path: String,
        identifiers: inout Set<String>,
        issues: inout [ProjectIssue]
    ) {
        for (index, layer) in layers.enumerated() {
            let location = "\(path)[\(index)]"
            guard let object = layer.objectValue else {
                issues.append(ProjectIssue(severity: .error, path: location, message: "Layer must be an object."))
                continue
            }
            guard let id = object["id"]?.stringValue, !id.isEmpty else {
                issues.append(ProjectIssue(severity: .error, path: "\(location).id", message: "Layer ID is required."))
                continue
            }
            if !identifiers.insert(id).inserted {
                issues.append(ProjectIssue(severity: .error, path: "\(location).id", message: "Layer IDs must be unique across the project."))
            }
            if let duration = object["duration"]?.numberValue,
               !duration.isFinite || duration <= 0 || duration > 3600 {
                issues.append(ProjectIssue(severity: .error, path: "\(location).duration", message: "Layer duration must be finite, greater than zero, and no more than one hour."))
            }
            if let children = object["layers"]?.arrayValue {
                validateLayers(children, path: "\(location).layers", identifiers: &identifiers, issues: &issues)
            }
        }
    }

    private func validateAssetReferences(
        _ fields: [String: JSONValue],
        assetTypes: [String: String],
        issues: inout [ProjectIssue]
    ) {
        func check(_ value: JSONValue?, expectedType: String, path: String) {
            guard let id = value?.stringValue else { return }
            guard let actualType = assetTypes[id] else {
                issues.append(ProjectIssue(severity: .error, path: path, message: "Referenced asset '\(id)' does not exist."))
                return
            }
            if actualType != expectedType {
                issues.append(ProjectIssue(severity: .error, path: path, message: "Asset '\(id)' must be of type '\(expectedType)', not '\(actualType)'."))
            }
        }

        let composition = fields["composition"]?.objectValue
        check(composition?["environment"]?.objectValue?["asset"], expectedType: "image", path: "composition.environment.asset")

        func validateLayers(_ values: [JSONValue], path: String) {
            for (index, value) in values.enumerated() {
                guard let layer = value.objectValue else { continue }
                let location = "\(path)[\(index)]"
                switch layer["type"]?.stringValue {
                case "text":
                    check(layer["text"]?.objectValue?["font"]?.objectValue?["asset"], expectedType: "font", path: "\(location).text.font.asset")
                case "image":
                    check(layer["image"]?.objectValue?["asset"], expectedType: "image", path: "\(location).image.asset")
                case "video":
                    let video = layer["video"]?.objectValue
                    check(video?["asset"], expectedType: "video", path: "\(location).video.asset")
                    check(video?["cutout"]?.objectValue?["source"], expectedType: "video", path: "\(location).video.cutout.source")
                case "audio":
                    check(layer["audio"]?.objectValue?["asset"], expectedType: "audio", path: "\(location).audio.asset")
                case "object3d":
                    let object3d = layer["object3d"]?.objectValue
                    check(object3d?["material"]?.objectValue?["texture"], expectedType: "image", path: "\(location).object3d.material.texture")
                    check(object3d?["text"]?.objectValue?["font"]?.objectValue?["asset"], expectedType: "font", path: "\(location).object3d.text.font.asset")
                case "model3d":
                    let model = layer["model3d"]?.objectValue
                    check(model?["asset"], expectedType: "model", path: "\(location).model3d.asset")
                    check(model?["material"]?.objectValue?["texture"], expectedType: "image", path: "\(location).model3d.material.texture")
                default:
                    break
                }
                validateLayers(layer["layers"]?.arrayValue ?? [], path: "\(location).layers")
            }
        }
        validateLayers(fields["layers"]?.arrayValue ?? [], path: "layers")
    }

    private func validateFiniteNumbers(_ value: JSONValue, path: String, issues: inout [ProjectIssue]) {
        switch value {
        case .number(let number):
            if !number.isFinite {
                issues.append(ProjectIssue(severity: .error, path: path, message: "Numeric values must be finite."))
            }
        case .object(let object):
            for (key, child) in object {
                validateFiniteNumbers(child, path: "\(path).\(key)", issues: &issues)
            }
        case .array(let values):
            for (index, child) in values.enumerated() {
                validateFiniteNumbers(child, path: "\(path)[\(index)]", issues: &issues)
            }
        case .string, .bool, .null:
            break
        }
    }

    private static func boundedInteger(_ value: Double?, range: ClosedRange<Int>, fallback: Int) -> Int {
        guard let value, value.isFinite, value >= Double(range.lowerBound), value <= Double(range.upperBound) else {
            return fallback
        }
        return Int(value.rounded())
    }

    private static func isSafeAssetPath(_ path: String) -> Bool {
        guard path.hasPrefix("assets/"),
              !path.hasPrefix("/"),
              !path.contains("\\"),
              !path.contains(":") else { return false }
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        return components.count >= 2 && !components.contains("..") && !components.contains(".") && !components.contains("")
    }
}
