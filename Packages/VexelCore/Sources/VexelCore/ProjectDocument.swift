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
              rawVersion < Double(Int.max) else {
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

        for key in ["assets", "markers", "layers"] {
            guard let value = fields[key], value.arrayValue != nil else {
                issues.append(ProjectIssue(severity: .error, path: key, message: "A native project must contain this array."))
                continue
            }
        }

        if let motionBlur = composition["motionBlur"]?.objectValue {
            let samples = motionBlur["samples"]?.numberValue ?? 8
            let shutterAngle = motionBlur["shutterAngle"]?.numberValue ?? 180
            if !(1...64).contains(samples) {
                issues.append(ProjectIssue(severity: .error, path: "composition.motionBlur.samples", message: "Motion blur samples must be between 1 and 64."))
            }
            if !(0...720).contains(shutterAngle) {
                issues.append(ProjectIssue(severity: .error, path: "composition.motionBlur.shutterAngle", message: "Shutter angle must be between 0 and 720 degrees."))
            }
        }
        if let environment = composition["environment"]?.objectValue,
           let intensity = environment["intensity"]?.numberValue,
           !(0...10).contains(intensity) {
            issues.append(ProjectIssue(severity: .error, path: "composition.environment.intensity", message: "Environment intensity must be between 0 and 10."))
        }

        var markerIDs = Set<String>()
        if let markers = fields["markers"]?.arrayValue {
            for (index, marker) in markers.enumerated() {
                let path = "markers[\(index)]"
                guard let object = marker.objectValue else {
                    issues.append(ProjectIssue(severity: .error, path: path, message: "Marker must be an object."))
                    continue
                }
                guard let id = object["id"]?.stringValue, !id.isEmpty else {
                    issues.append(ProjectIssue(severity: .error, path: "\(path).id", message: "Marker ID is required."))
                    continue
                }
                if !markerIDs.insert(id).inserted {
                    issues.append(ProjectIssue(severity: .error, path: "\(path).id", message: "Marker IDs must be unique."))
                }
                let time = object["time"]?.numberValue ?? -1
                if !(0...3600).contains(time) {
                    issues.append(ProjectIssue(severity: .error, path: "\(path).time", message: "Marker time must be between 0 and 3600 seconds."))
                }
            }
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
            validateLayerSemantics(layers, path: "layers", depth: 0, issues: &issues)
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



    private func validateLayerSemantics(
        _ layers: [JSONValue],
        path: String,
        depth: Int,
        issues: inout [ProjectIssue]
    ) {
        if depth > 16 {
            issues.append(ProjectIssue(severity: .error, path: path, message: "Group nesting exceeds the maximum depth of 16."))
            return
        }

        var siblings: [String: [String: JSONValue]] = [:]
        for value in layers {
            guard let object = value.objectValue, let id = object["id"]?.stringValue else { continue }
            siblings[id] = object
        }

        for (index, value) in layers.enumerated() {
            guard let layer = value.objectValue else { continue }
            let location = "\(path)[\(index)]"
            let id = layer["id"]?.stringValue ?? ""
            let type = layer["type"]?.stringValue ?? "unknown"
            let children = layer["layers"]?.arrayValue ?? []

            if !children.isEmpty && type != "group" {
                issues.append(ProjectIssue(severity: .error, path: "\(location).layers", message: "Only group layers may contain child layers."))
            }

            if let parentID = layer["parent"]?.stringValue {
                if parentID == id {
                    issues.append(ProjectIssue(severity: .error, path: "\(location).parent", message: "A layer cannot parent itself."))
                } else if let parent = siblings[parentID] {
                    let parentType = parent["type"]?.stringValue ?? "unknown"
                    let childIs3D = Self.is3DLayer(type: type, fields: layer)
                    let parentIs3D = Self.is3DLayer(type: parentType, fields: parent)
                    if childIs3D != parentIs3D || ["audio", "camera", "light"].contains(parentType) {
                        issues.append(ProjectIssue(severity: .error, path: "\(location).parent", message: "Parent and child layer types are incompatible."))
                    }
                } else {
                    issues.append(ProjectIssue(severity: .error, path: "\(location).parent", message: "Parent must identify a sibling layer in the same group."))
                }
            }

            if let matteID = layer["matte"]?.objectValue?["layer"]?.stringValue {
                if matteID == id {
                    issues.append(ProjectIssue(severity: .error, path: "\(location).matte.layer", message: "A layer cannot use itself as a matte."))
                } else if let matteLayer = siblings[matteID] {
                    let matteType = matteLayer["type"]?.stringValue ?? "unknown"
                    if !["text", "shape", "image", "video", "group"].contains(type) ||
                       !["text", "shape", "image", "video", "group", "object3d", "model3d"].contains(matteType) {
                        issues.append(ProjectIssue(severity: .error, path: "\(location).matte", message: "Track mattes require 2D visual layers."))
                    }
                    if matteLayer["matte"]?.objectValue?["layer"]?.stringValue == id {
                        issues.append(ProjectIssue(severity: .error, path: "\(location).matte.layer", message: "Two layers cannot be each other's matte."))
                    }
                } else {
                    issues.append(ProjectIssue(severity: .error, path: "\(location).matte.layer", message: "Matte source must identify a sibling layer in the same group."))
                }
            }

            for transitionKey in ["transitionIn", "transitionOut"] {
                if let transition = layer[transitionKey]?.objectValue,
                   let transitionDuration = transition["duration"]?.numberValue,
                   transitionDuration <= 0 {
                    issues.append(ProjectIssue(severity: .error, path: "\(location).\(transitionKey).duration", message: "Transition duration must be greater than zero."))
                }
            }

            if let text = layer["text"]?.objectValue,
               let font = text["font"]?.objectValue,
               let weight = font["weight"]?.numberValue,
               !(100...900).contains(weight) {
                issues.append(ProjectIssue(severity: .error, path: "\(location).text.font.weight", message: "Font weight must be between 100 and 900."))
            }

            for mediaKey in ["video", "audio"] {
                guard let media = layer[mediaKey]?.objectValue else { continue }
                let speed = media["speed"]?.numberValue ?? 1
                let sourceStart = media["sourceStart"]?.numberValue ?? 0
                if speed <= 0 {
                    issues.append(ProjectIssue(severity: .error, path: "\(location).\(mediaKey).speed", message: "Media playback speed must be greater than zero."))
                }
                if sourceStart < 0 {
                    issues.append(ProjectIssue(severity: .error, path: "\(location).\(mediaKey).sourceStart", message: "Media source start must be non-negative."))
                }
                if mediaKey == "video", let cutout = media["cutout"]?.objectValue {
                    validateCutout(cutout, path: "\(location).video.cutout", issues: &issues)
                }
                if let bands = media["eq"]?.arrayValue {
                    if bands.count > 8 {
                        issues.append(ProjectIssue(severity: .error, path: "\(location).\(mediaKey).eq", message: "At most eight equalizer bands are supported."))
                    }
                    for (bandIndex, bandValue) in bands.enumerated() {
                        guard let band = bandValue.objectValue else { continue }
                        let frequency = band["frequency"]?.numberValue ?? 0
                        let gain = band["gain"]?.numberValue ?? 0
                        let q = band["q"]?.numberValue ?? 0
                        if !(20...20000).contains(frequency) || !(-24...24).contains(gain) || !(0.1...10).contains(q) {
                            issues.append(ProjectIssue(severity: .error, path: "\(location).\(mediaKey).eq[\(bandIndex)]", message: "Equalizer frequency, gain, and Q are outside supported ranges."))
                        }
                    }
                }
            }

            if let light = layer["light"]?.objectValue,
               let softness = light["shadowSoftness"]?.numberValue,
               !(0...8).contains(softness) {
                issues.append(ProjectIssue(severity: .error, path: "\(location).light.shadowSoftness", message: "Shadow softness must be between 0 and 8."))
            }

            validateKeyframeOrdering(.object(layer), path: location, issues: &issues)
            validateLayerSemantics(children, path: "\(location).layers", depth: depth + 1, issues: &issues)
        }

        for (id, layer) in siblings {
            var cursor: String? = id
            var visited = Set<String>()
            while let currentID = cursor, let current = siblings[currentID] {
                if !visited.insert(currentID).inserted {
                    issues.append(ProjectIssue(severity: .error, path: "\(path).\(id).parent", message: "Parent chain contains a cycle."))
                    break
                }
                cursor = current["parent"]?.stringValue
            }
            _ = layer
        }
    }

    private static func is3DLayer(type: String, fields: [String: JSONValue]) -> Bool {
        if type == "null" {
            return fields["null"]?.objectValue?["threeD"]?.boolValue ?? false
        }
        return ["object3d", "model3d", "camera", "light"].contains(type)
    }

    private func validateCutout(
        _ cutout: [String: JSONValue],
        path: String,
        issues: inout [ProjectIssue]
    ) {
        let sourceStart = cutout["sourceStart"]?.numberValue ?? 0
        let duration = cutout["duration"]?.numberValue ?? 0
        if sourceStart < 0 || !(duration > 0 && duration <= 3600) {
            issues.append(ProjectIssue(severity: .error, path: path, message: "Cutout source start must be non-negative and duration must be between zero and one hour."))
        }
        let frames = cutout["frames"]?.arrayValue ?? []
        if frames.count > 240 {
            issues.append(ProjectIssue(severity: .error, path: "\(path).frames", message: "A cutout recipe may contain at most 240 painted frames."))
        }
        for (frameIndex, frameValue) in frames.enumerated() {
            guard let frame = frameValue.objectValue else { continue }
            let framePath = "\(path).frames[\(frameIndex)]"
            let time = frame["time"]?.numberValue ?? -1
            if time < 0 || time > duration {
                issues.append(ProjectIssue(severity: .error, path: "\(framePath).time", message: "Painted frame time must be within the cutout duration."))
            }
            let strokes = frame["strokes"]?.arrayValue ?? []
            if strokes.count > 64 {
                issues.append(ProjectIssue(severity: .error, path: "\(framePath).strokes", message: "A painted frame may contain at most 64 strokes."))
            }
            for (strokeIndex, strokeValue) in strokes.enumerated() {
                guard let stroke = strokeValue.objectValue else { continue }
                let strokePath = "\(framePath).strokes[\(strokeIndex)]"
                let mode = stroke["mode"]?.stringValue ?? "add"
                if mode != "add" && mode != "remove" {
                    issues.append(ProjectIssue(severity: .error, path: "\(strokePath).mode", message: "Cutout stroke mode must be add or remove."))
                }
                let size = stroke["size"]?.numberValue ?? 0.06
                if !(0.005...0.5).contains(size) {
                    issues.append(ProjectIssue(severity: .error, path: "\(strokePath).size", message: "Cutout brush size must be between 0.005 and 0.5."))
                }
                let points = stroke["points"]?.arrayValue ?? []
                if points.isEmpty || points.count > 2000 {
                    issues.append(ProjectIssue(severity: .error, path: "\(strokePath).points", message: "A stroke must contain between 1 and 2000 points."))
                }
                for (pointIndex, point) in points.enumerated() {
                    let coordinates = point.arrayValue ?? []
                    if coordinates.count != 2 ||
                       coordinates.contains(where: { value in
                           guard let number = value.numberValue else { return true }
                           return !(0...1).contains(number)
                       }) {
                        issues.append(ProjectIssue(severity: .error, path: "\(strokePath).points[\(pointIndex)]", message: "Stroke points must be normalized [x, y] coordinates between 0 and 1."))
                    }
                }
            }
        }
    }

    private func validateKeyframeOrdering(_ value: JSONValue, path: String, issues: inout [ProjectIssue]) {
        switch value {
        case .object(let object):
            for (key, child) in object {
                let childPath = "\(path).\(key)"
                if key == "keyframes", let frames = child.arrayValue {
                    var previous: Double?
                    for (index, frame) in frames.enumerated() {
                        let time = frame.objectValue?["time"]?.numberValue
                        guard let time else {
                            issues.append(ProjectIssue(severity: .error, path: "\(childPath)[\(index)].time", message: "Keyframe time is required."))
                            continue
                        }
                        if let previous, time - previous < 0.000001 {
                            issues.append(ProjectIssue(severity: .error, path: "\(childPath)[\(index)].time", message: "Keyframe times must be strictly increasing."))
                        }
                        previous = time
                    }
                } else {
                    validateKeyframeOrdering(child, path: childPath, issues: &issues)
                }
            }
        case .array(let values):
            for (index, child) in values.enumerated() {
                validateKeyframeOrdering(child, path: "\(path)[\(index)]", issues: &issues)
            }
        case .string, .number, .bool, .null:
            break
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
