import Foundation


public struct VexelUnsupportedFeature: Equatable, Sendable {
    public let path: String
    public let feature: String
    public let reason: String

    public init(path: String, feature: String, reason: String) {
        self.path = path
        self.feature = feature
        self.reason = reason
    }
}

public enum VexelProjectImporter {
    static let legacyAndroidFormatIdentifier = "knsproj"
    private static let maximumAndroidCompatibilityVersion = 12

    public static func importDocument(from data: Data) throws -> ProjectDocument {
        let source = try ProjectDocument(data: data)
        let sourceFormat = source.fields["format"]?.stringValue

        if sourceFormat == ProjectDocument.format {
            let issues = source.validate().filter { $0.severity == .error }
            guard issues.isEmpty else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: [],
                    debugDescription: issues.map { "\($0.path): \($0.message)" }.joined(separator: "\n")
                ))
            }
            return source
        }

        guard sourceFormat == legacyAndroidFormatIdentifier else {
            throw ProjectDocumentError.unsupportedFormat(sourceFormat)
        }

        guard let rawVersion = source.fields["formatVersion"]?.numberValue,
              rawVersion.isFinite,
              rawVersion.rounded(.towardZero) == rawVersion,
              (1...Double(maximumAndroidCompatibilityVersion)).contains(rawVersion) else {
            throw ProjectDocumentError.unsupportedVersion(nil)
        }

        let sourceVersion = Int(rawVersion)
        var fields = migrateKNSFields(source.fields, from: sourceVersion)
        let sourceGenerator = fields["generator"]?.stringValue
        fields["format"] = .string(ProjectDocument.format)
        fields["formatVersion"] = .number(Double(ProjectDocument.currentVersion))
        fields["generator"] = .string("Vexel")
        var compatibility = fields["compatibility"]?.objectValue ?? [:]
        compatibility["source"] = .string("android-reference")
        compatibility["sourceVersion"] = .number(rawVersion)
        compatibility["migratedSourceVersion"] = .number(Double(maximumAndroidCompatibilityVersion))
        if let sourceGenerator { compatibility["sourceGenerator"] = .string(sourceGenerator) }
        fields["compatibility"] = .object(compatibility)

        let imported = ProjectDocument(fields: fields)
        let issues = imported.validate().filter { $0.severity == .error }
        guard issues.isEmpty else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: [],
                debugDescription: issues.map { "\($0.path): \($0.message)" }.joined(separator: "\n")
            ))
        }
        return imported
    }


    public static func compatibilityReport(for project: ProjectDocument) -> [VexelUnsupportedFeature] {
        var result: [VexelUnsupportedFeature] = []
        let composition = project.fields["composition"]?.objectValue ?? [:]
        for key in ["motionBlur", "lighting", "environment"] where composition[key] != nil {
            result.append(VexelUnsupportedFeature(
                path: "composition.\\(key)",
                feature: key,
                reason: "This feature is preserved in the project document but is not implemented by the current iOS rendering pipeline."
            ))
        }

        func inspect(_ layers: [JSONValue], path: String) {
            for (index, value) in layers.enumerated() {
                guard let layer = value.objectValue else { continue }
                let location = "\\(path)[\\(index)]"
                let type = layer["type"]?.stringValue ?? "unknown"
                if ["video", "audio", "object3d", "model3d", "camera", "light"].contains(type) {
                    result.append(VexelUnsupportedFeature(
                        path: "\\(location).type",
                        feature: type,
                        reason: "The layer is retained for round-trip compatibility but its playback or rendering implementation is incomplete."
                    ))
                }
                for key in ["masks", "matte", "transitionIn", "transitionOut"] where layer[key] != nil {
                    result.append(VexelUnsupportedFeature(
                        path: "\\(location).\\(key)",
                        feature: key,
                        reason: "The serialized feature is preserved, but the corresponding editor/render operation is not implemented."
                    ))
                }
                if let effects = layer["effects"]?.arrayValue {
                    for (effectIndex, effect) in effects.enumerated() {
                        let effectType = effect.objectValue?["type"]?.stringValue ?? "unknown"
                        result.append(VexelUnsupportedFeature(
                            path: "\\(location).effects[\\(effectIndex)]",
                            feature: "effect:\\(effectType)",
                            reason: "Effect parameters are preserved, but this effect is not yet connected to the iOS render graph."
                        ))
                    }
                }
                func findExpressions(_ value: JSONValue, at valuePath: String) {
                    switch value {
                    case .object(let object):
                        for (key, child) in object where key != "layers" {
                            let childPath = "\\(valuePath).\\(key)"
                            if key == "expression", child.stringValue != nil {
                                result.append(VexelUnsupportedFeature(
                                    path: childPath,
                                    feature: "expression",
                                    reason: "Android Rhino expressions are preserved but are not evaluated by the restricted iOS expression engine."
                                ))
                            } else {
                                findExpressions(child, at: childPath)
                            }
                        }
                    case .array(let values):
                        for (childIndex, child) in values.enumerated() {
                            findExpressions(child, at: "\\(valuePath)[\\(childIndex)]")
                        }
                    case .string, .number, .bool, .null:
                        break
                    }
                }
                findExpressions(.object(layer), at: location)
                inspect(layer["layers"]?.arrayValue ?? [], path: "\\(location).layers")
            }
        }
        inspect(project.fields["layers"]?.arrayValue ?? [], path: "layers")
        return result
    }

    private static func migrateKNSFields(
        _ source: [String: JSONValue],
        from version: Int
    ) -> [String: JSONValue] {
        var fields = source
        if version <= 1, let layers = fields["layers"]?.arrayValue {
            fields["layers"] = .array(migrateV1Layers(layers))
        }
        if version <= 6 {
            fields = fields.mapValues(migrateV6CyclicEasing)
        }
        if version <= 11 {
            fields = fields.mapValues(migrateV11CutoutKey)
        }
        fields["formatVersion"] = .number(Double(maximumAndroidCompatibilityVersion))
        return fields
    }

    private static func migrateV1Layers(_ layers: [JSONValue]) -> [JSONValue] {
        layers.map { value in
            guard var layer = value.objectValue else { return value }
            if let effects = layer["effects"]?.arrayValue {
                layer["effects"] = .array(effects.flatMap(migrateV1Effect))
            }
            if let children = layer["layers"]?.arrayValue {
                layer["layers"] = .array(migrateV1Layers(children))
            }
            return .object(layer)
        }
    }

    private static func migrateV1Effect(_ value: JSONValue) -> [JSONValue] {
        guard let effect = value.objectValue,
              effect["type"]?.stringValue == "colorAdjust" else { return [value] }
        let enabled = effect["enabled"]
        var result: [[String: JSONValue]] = []

        func append(_ type: String, keys: [String]) {
            let present = keys.filter { effect[$0] != nil }
            guard !present.isEmpty else { return }
            var migrated: [String: JSONValue] = ["type": .string(type)]
            if let enabled { migrated["enabled"] = enabled }
            for key in present {
                if let value = effect[key] { migrated[key] = value }
            }
            result.append(migrated)
        }

        append("hueShift", keys: ["hue"])
        append("brightnessContrast", keys: ["brightness", "contrast"])
        append("saturation", keys: ["saturation"])
        if result.isEmpty {
            var neutral: [String: JSONValue] = ["type": .string("brightnessContrast")]
            if let enabled { neutral["enabled"] = enabled }
            result.append(neutral)
        }
        return result.map(JSONValue.object)
    }

    private static func migrateV6CyclicEasing(_ value: JSONValue) -> JSONValue {
        switch value {
        case .object(let object):
            if object.count == 1, let cyclicValue = object["cyclic"]?.objectValue {
                var cyclic = cyclicValue
                let phase = cyclic["offset"]?.numberValue ?? 0
                cyclic.removeValue(forKey: "offset")
                if phase != 0 { cyclic["phase"] = .number(phase) }
                return .object(["cyclic": .object(cyclic)])
            }
            return .object(object.mapValues(migrateV6CyclicEasing))
        case .array(let values):
            return .array(values.map(migrateV6CyclicEasing))
        default:
            return value
        }
    }

    private static func migrateV11CutoutKey(_ value: JSONValue) -> JSONValue {
        switch value {
        case .object(let object):
            var migrated = object.mapValues(migrateV11CutoutKey)
            if object["asset"] != nil, let roto = object["roto"] {
                if migrated["cutout"] == nil { migrated["cutout"] = migrateV11CutoutKey(roto) }
                migrated.removeValue(forKey: "roto")
            }
            return .object(migrated)
        case .array(let values):
            return .array(values.map(migrateV11CutoutKey))
        default:
            return value
        }
    }
}
