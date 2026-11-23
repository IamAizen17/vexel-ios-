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
    public static let currentVersion = 1

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

    public var title: String {
        fields["meta"]?.objectValue?["title"]?.stringValue ?? "Untitled"
    }

    public var compositionSize: (width: Int, height: Int) {
        let composition = fields["composition"]?.objectValue
        let width = Int(composition?["width"]?.numberValue ?? 1080)
        let height = Int(composition?["height"]?.numberValue ?? 1920)
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
        if documentFormat == Self.format && version != Self.currentVersion {
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

        if let assets = fields["assets"]?.arrayValue {
            var identifiers = Set<String>()
            for (index, asset) in assets.enumerated() {
                guard let object = asset.objectValue else {
                    issues.append(ProjectIssue(severity: .error, path: "assets[\(index)]", message: "Asset must be an object."))
                    continue
                }
                guard let id = object["id"]?.stringValue, !id.isEmpty else {
                    issues.append(ProjectIssue(severity: .error, path: "assets[\(index)].id", message: "Asset ID is required."))
                    continue
                }
                if !identifiers.insert(id).inserted {
                    issues.append(ProjectIssue(severity: .error, path: "assets[\(index)].id", message: "Asset IDs must be unique."))
                }
                guard let path = object["path"]?.stringValue, Self.isSafeAssetPath(path) else {
                    issues.append(ProjectIssue(severity: .error, path: "assets[\(index)].path", message: "Asset path must be a safe relative path under assets/."))
                    continue
                }
            }
        }

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
            if let duration = object["duration"]?.numberValue, duration <= 0 {
                issues.append(ProjectIssue(severity: .error, path: "\(location).duration", message: "Layer duration must be greater than zero."))
            }
            if let children = object["layers"]?.arrayValue {
                validateLayers(children, path: "\(location).layers", identifiers: &identifiers, issues: &issues)
            }
        }
    }

    private static func isSafeAssetPath(_ path: String) -> Bool {
        let normalized = path.replacingOccurrences(of: "\\", with: "/")
        guard normalized.hasPrefix("assets/"),
              !normalized.hasPrefix("/"),
              !normalized.contains(":") else { return false }
        let components = normalized.split(separator: "/", omittingEmptySubsequences: false)
        return components.count >= 2 && !components.contains("..") && !components.contains(".") && !components.contains("")
    }
}
