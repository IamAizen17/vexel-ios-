import Foundation

public enum VexelLayerType: String, Codable, CaseIterable, Sendable {
    case text, shape, image, video, audio, group
    case object3D = "object3d"
    case model3D = "model3d"
    case camera, light
    case null

    public var contentKey: String? {
        switch self {
        case .text: "text"
        case .shape: "shape"
        case .image: "image"
        case .video: "video"
        case .audio: "audio"
        case .group: nil
        case .object3D: "object3d"
        case .model3D: "model3d"
        case .camera: "camera"
        case .light: "light"
        case .null: nil
        }
    }
}

public struct VexelNativeProject: Codable, Equatable, Sendable {
    public var format: String
    public var formatVersion: Int
    public var generator: String?
    public var meta: [String: JSONValue]
    public var composition: VexelComposition
    public var assets: [VexelAsset]
    public var markers: [VexelMarkerData]
    public var editorView: JSONValue?
    public var layers: [VexelLayer]
    public var unknownFields: [String: JSONValue]

    public init(
        format: String = ProjectDocument.format,
        formatVersion: Int = ProjectDocument.currentVersion,
        generator: String? = "Vexel",
        meta: [String: JSONValue] = [:],
        composition: VexelComposition,
        assets: [VexelAsset] = [],
        markers: [VexelMarkerData] = [],
        editorView: JSONValue? = nil,
        layers: [VexelLayer] = [],
        unknownFields: [String: JSONValue] = [:]
    ) {
        self.format = format
        self.formatVersion = formatVersion
        self.generator = generator
        self.meta = meta
        self.composition = composition
        self.assets = assets
        self.markers = markers
        self.editorView = editorView
        self.layers = layers
        self.unknownFields = unknownFields
    }

    public init(document: ProjectDocument) throws {
        self = try JSONDecoder().decode(Self.self, from: document.encoded(prettyPrinted: false))
    }

    public func projectDocument() throws -> ProjectDocument {
        let data = try JSONEncoder().encode(self)
        return try ProjectDocument(data: data)
    }

    private enum CodingKeys: String, CodingKey {
        case format, formatVersion, generator, meta, composition, assets, markers, editorView, layers
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        format = try container.decode(String.self, forKey: .init("format"))
        formatVersion = try container.decode(Int.self, forKey: .init("formatVersion"))
        generator = try container.decodeIfPresent(String.self, forKey: .init("generator"))
        meta = try container.decodeIfPresent([String: JSONValue].self, forKey: .init("meta")) ?? [:]
        composition = try container.decode(VexelComposition.self, forKey: .init("composition"))
        assets = try container.decodeIfPresent([VexelAsset].self, forKey: .init("assets")) ?? []
        markers = try container.decodeIfPresent([VexelMarkerData].self, forKey: .init("markers")) ?? []
        editorView = try container.decodeIfPresent(JSONValue.self, forKey: .init("editorView"))
        layers = try container.decodeIfPresent([VexelLayer].self, forKey: .init("layers")) ?? []
        let known = Set(CodingKeys.allCases.map(\.rawValue))
        unknownFields = try Self.decodeUnknown(from: container, excluding: known)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        try container.encode(format, forKey: .init("format"))
        try container.encode(formatVersion, forKey: .init("formatVersion"))
        try container.encodeIfPresent(generator, forKey: .init("generator"))
        try container.encode(meta, forKey: .init("meta"))
        try container.encode(composition, forKey: .init("composition"))
        try container.encode(assets, forKey: .init("assets"))
        try container.encode(markers, forKey: .init("markers"))
        try container.encodeIfPresent(editorView, forKey: .init("editorView"))
        try container.encode(layers, forKey: .init("layers"))
        for (key, value) in unknownFields where CodingKeys(rawValue: key) == nil {
            try container.encode(value, forKey: .init(key))
        }
    }

    private static func decodeUnknown(
        from container: KeyedDecodingContainer<DynamicCodingKey>,
        excluding known: Set<String>
    ) throws -> [String: JSONValue] {
        var result: [String: JSONValue] = [:]
        for key in container.allKeys where !known.contains(key.stringValue) {
            result[key.stringValue] = try container.decode(JSONValue.self, forKey: key)
        }
        return result
    }
}

public struct VexelComposition: Codable, Equatable, Sendable {
    public var width: Int
    public var height: Int
    public var fps: Double
    public var duration: Double
    public var background: JSONValue?
    public var motionBlur: JSONValue?
    public var lighting: JSONValue?
    public var environment: JSONValue?
    public var unknownFields: [String: JSONValue]

    public init(width: Int, height: Int, fps: Double, duration: Double, background: JSONValue? = nil,
                motionBlur: JSONValue? = nil, lighting: JSONValue? = nil, environment: JSONValue? = nil,
                unknownFields: [String: JSONValue] = [:]) {
        self.width = width
        self.height = height
        self.fps = fps
        self.duration = duration
        self.background = background
        self.motionBlur = motionBlur
        self.lighting = lighting
        self.environment = environment
        self.unknownFields = unknownFields
    }

    private enum Keys: String, CaseIterable { case width, height, fps, duration, background, motionBlur, lighting, environment }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DynamicCodingKey.self)
        width = try c.decode(Int.self, forKey: .init("width"))
        height = try c.decode(Int.self, forKey: .init("height"))
        fps = try c.decode(Double.self, forKey: .init("fps"))
        duration = try c.decode(Double.self, forKey: .init("duration"))
        background = try c.decodeIfPresent(JSONValue.self, forKey: .init("background"))
        motionBlur = try c.decodeIfPresent(JSONValue.self, forKey: .init("motionBlur"))
        lighting = try c.decodeIfPresent(JSONValue.self, forKey: .init("lighting"))
        environment = try c.decodeIfPresent(JSONValue.self, forKey: .init("environment"))
        unknownFields = try VexelNativeProject.decodeExtra(c, known: Set(Keys.allCases.map(\.rawValue)))
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: DynamicCodingKey.self)
        try c.encode(width, forKey: .init("width")); try c.encode(height, forKey: .init("height"))
        try c.encode(fps, forKey: .init("fps")); try c.encode(duration, forKey: .init("duration"))
        try c.encodeIfPresent(background, forKey: .init("background"))
        try c.encodeIfPresent(motionBlur, forKey: .init("motionBlur"))
        try c.encodeIfPresent(lighting, forKey: .init("lighting"))
        try c.encodeIfPresent(environment, forKey: .init("environment"))
        for (key, value) in unknownFields where !Keys.allCases.map(\.rawValue).contains(key) {
            try c.encode(value, forKey: .init(key))
        }
    }
}

public struct VexelAsset: Codable, Equatable, Sendable {
    public var id: String
    public var type: String
    public var path: String
    public var displayName: String?
    public var mimeType: String?
    public var width: Int?
    public var height: Int?
    public var duration: Double?
    public var hasAudio: Bool?
    public var sha256: String?
    public var unknownFields: [String: JSONValue]

    private enum Keys: String, CaseIterable {
        case id, type, path, displayName, mimeType, width, height, duration, hasAudio, sha256
    }
    public init(id: String, type: String, path: String, displayName: String? = nil, mimeType: String? = nil,
                width: Int? = nil, height: Int? = nil, duration: Double? = nil, hasAudio: Bool? = nil,
                sha256: String? = nil, unknownFields: [String: JSONValue] = [:]) {
        self.id = id; self.type = type; self.path = path; self.displayName = displayName; self.mimeType = mimeType
        self.width = width; self.height = height; self.duration = duration; self.hasAudio = hasAudio
        self.sha256 = sha256; self.unknownFields = unknownFields
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DynamicCodingKey.self)
        id = try c.decode(String.self, forKey: .init("id")); type = try c.decode(String.self, forKey: .init("type"))
        path = try c.decode(String.self, forKey: .init("path"))
        displayName = try c.decodeIfPresent(String.self, forKey: .init("displayName"))
        mimeType = try c.decodeIfPresent(String.self, forKey: .init("mimeType"))
        width = try c.decodeIfPresent(Int.self, forKey: .init("width")); height = try c.decodeIfPresent(Int.self, forKey: .init("height"))
        duration = try c.decodeIfPresent(Double.self, forKey: .init("duration"))
        hasAudio = try c.decodeIfPresent(Bool.self, forKey: .init("hasAudio"))
        sha256 = try c.decodeIfPresent(String.self, forKey: .init("sha256"))
        unknownFields = try VexelNativeProject.decodeExtra(c, known: Set(Keys.allCases.map(\.rawValue)))
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: DynamicCodingKey.self)
        try c.encode(id, forKey: .init("id")); try c.encode(type, forKey: .init("type")); try c.encode(path, forKey: .init("path"))
        try c.encodeIfPresent(displayName, forKey: .init("displayName")); try c.encodeIfPresent(mimeType, forKey: .init("mimeType"))
        try c.encodeIfPresent(width, forKey: .init("width")); try c.encodeIfPresent(height, forKey: .init("height"))
        try c.encodeIfPresent(duration, forKey: .init("duration")); try c.encodeIfPresent(hasAudio, forKey: .init("hasAudio"))
        try c.encodeIfPresent(sha256, forKey: .init("sha256"))
        for (key, value) in unknownFields where !Keys.allCases.map(\.rawValue).contains(key) { try c.encode(value, forKey: .init(key)) }
    }
}

public struct VexelMarkerData: Codable, Equatable, Sendable {
    public var id: String
    public var time: Double
    public var name: String?
    public var color: String?
    public var unknownFields: [String: JSONValue]
    public init(id: String, time: Double, name: String? = nil, color: String? = nil, unknownFields: [String: JSONValue] = [:]) {
        self.id = id; self.time = time; self.name = name; self.color = color; self.unknownFields = unknownFields
    }
    private enum Keys: String, CaseIterable { case id, time, name, color }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DynamicCodingKey.self)
        id = try c.decode(String.self, forKey: .init("id")); time = try c.decode(Double.self, forKey: .init("time"))
        name = try c.decodeIfPresent(String.self, forKey: .init("name")); color = try c.decodeIfPresent(String.self, forKey: .init("color"))
        unknownFields = try VexelNativeProject.decodeExtra(c, known: Set(Keys.allCases.map(\.rawValue)))
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: DynamicCodingKey.self)
        try c.encode(id, forKey: .init("id")); try c.encode(time, forKey: .init("time"))
        try c.encodeIfPresent(name, forKey: .init("name")); try c.encodeIfPresent(color, forKey: .init("color"))
        for (key, value) in unknownFields where !Keys.allCases.map(\.rawValue).contains(key) { try c.encode(value, forKey: .init(key)) }
    }
}

public struct VexelLayer: Codable, Equatable, Sendable {
    public var id: String
    public var type: VexelLayerType
    public var name: String?
    public var start: Double?
    public var duration: Double?
    public var visible: Bool?
    public var locked: Bool?
    public var parent: String?
    public var label: JSONValue?
    public var blendMode: String?
    public var motionBlur: JSONValue?
    public var transform: VexelTransform?
    public var transform3D: VexelTransform?
    public var effects: [VexelEffect]
    public var masks: [JSONValue]
    public var matte: JSONValue?
    public var transitionIn: JSONValue?
    public var transitionOut: JSONValue?
    public var content: JSONValue?
    public var layers: [VexelLayer]
    public var unknownFields: [String: JSONValue]

    private static let commonKeys: Set<String> = [
        "id", "type", "name", "start", "duration", "visible", "locked", "parent", "label", "blendMode",
        "motionBlur", "transform", "transform3d", "effects", "masks", "matte", "transitionIn", "transitionOut", "layers"
    ]

    public init(id: String, type: VexelLayerType, name: String? = nil, start: Double? = nil, duration: Double? = nil,
                visible: Bool? = nil, locked: Bool? = nil, parent: String? = nil, label: JSONValue? = nil,
                blendMode: String? = nil, motionBlur: JSONValue? = nil, transform: VexelTransform? = nil,
                transform3D: VexelTransform? = nil, effects: [VexelEffect] = [], masks: [JSONValue] = [],
                matte: JSONValue? = nil, transitionIn: JSONValue? = nil, transitionOut: JSONValue? = nil,
                content: JSONValue? = nil, layers: [VexelLayer] = [], unknownFields: [String: JSONValue] = [:]) {
        self.id = id; self.type = type; self.name = name; self.start = start; self.duration = duration
        self.visible = visible; self.locked = locked; self.parent = parent; self.label = label
        self.blendMode = blendMode; self.motionBlur = motionBlur; self.transform = transform; self.transform3D = transform3D
        self.effects = effects; self.masks = masks; self.matte = matte; self.transitionIn = transitionIn
        self.transitionOut = transitionOut; self.content = content; self.layers = layers; self.unknownFields = unknownFields
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DynamicCodingKey.self)
        id = try c.decode(String.self, forKey: .init("id")); type = try c.decode(VexelLayerType.self, forKey: .init("type"))
        name = try c.decodeIfPresent(String.self, forKey: .init("name"))
        start = try c.decodeIfPresent(Double.self, forKey: .init("start")); duration = try c.decodeIfPresent(Double.self, forKey: .init("duration"))
        visible = try c.decodeIfPresent(Bool.self, forKey: .init("visible")); locked = try c.decodeIfPresent(Bool.self, forKey: .init("locked"))
        parent = try c.decodeIfPresent(String.self, forKey: .init("parent")); label = try c.decodeIfPresent(JSONValue.self, forKey: .init("label"))
        blendMode = try c.decodeIfPresent(String.self, forKey: .init("blendMode")); motionBlur = try c.decodeIfPresent(JSONValue.self, forKey: .init("motionBlur"))
        transform = try c.decodeIfPresent(VexelTransform.self, forKey: .init("transform"))
        transform3D = try c.decodeIfPresent(VexelTransform.self, forKey: .init("transform3d"))
        effects = try c.decodeIfPresent([VexelEffect].self, forKey: .init("effects")) ?? []
        masks = try c.decodeIfPresent([JSONValue].self, forKey: .init("masks")) ?? []
        matte = try c.decodeIfPresent(JSONValue.self, forKey: .init("matte"))
        transitionIn = try c.decodeIfPresent(JSONValue.self, forKey: .init("transitionIn"))
        transitionOut = try c.decodeIfPresent(JSONValue.self, forKey: .init("transitionOut"))
        if let key = type.contentKey { content = try c.decodeIfPresent(JSONValue.self, forKey: .init(key)) } else { content = nil }
        layers = try c.decodeIfPresent([VexelLayer].self, forKey: .init("layers")) ?? []
        var known = Self.commonKeys
        if let key = type.contentKey { known.insert(key) }
        unknownFields = try VexelNativeProject.decodeExtra(c, known: known)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: DynamicCodingKey.self)
        try c.encode(id, forKey: .init("id")); try c.encode(type, forKey: .init("type"))
        try c.encodeIfPresent(name, forKey: .init("name")); try c.encodeIfPresent(start, forKey: .init("start"))
        try c.encodeIfPresent(duration, forKey: .init("duration")); try c.encodeIfPresent(visible, forKey: .init("visible"))
        try c.encodeIfPresent(locked, forKey: .init("locked")); try c.encodeIfPresent(parent, forKey: .init("parent"))
        try c.encodeIfPresent(label, forKey: .init("label")); try c.encodeIfPresent(blendMode, forKey: .init("blendMode"))
        try c.encodeIfPresent(motionBlur, forKey: .init("motionBlur")); try c.encodeIfPresent(transform, forKey: .init("transform"))
        try c.encodeIfPresent(transform3D, forKey: .init("transform3d")); try c.encode(effects, forKey: .init("effects"))
        try c.encode(masks, forKey: .init("masks")); try c.encodeIfPresent(matte, forKey: .init("matte"))
        try c.encodeIfPresent(transitionIn, forKey: .init("transitionIn")); try c.encodeIfPresent(transitionOut, forKey: .init("transitionOut"))
        if let key = type.contentKey { try c.encodeIfPresent(content, forKey: .init(key)) }
        if type == .group || !layers.isEmpty { try c.encode(layers, forKey: .init("layers")) }
        var known = Self.commonKeys
        if let key = type.contentKey { known.insert(key) }
        for (key, value) in unknownFields where !known.contains(key) { try c.encode(value, forKey: .init(key)) }
    }
}

public struct VexelTransform: Codable, Equatable, Sendable {
    public var properties: [String: VexelAnimatableValue]
    public var unknownFields: [String: JSONValue]
    public init(properties: [String: VexelAnimatableValue] = [:], unknownFields: [String: JSONValue] = [:]) {
        self.properties = properties; self.unknownFields = unknownFields
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DynamicCodingKey.self)
        var values: [String: VexelAnimatableValue] = [:]
        var extras: [String: JSONValue] = [:]
        for key in c.allKeys {
            if let value = try? c.decode(VexelAnimatableValue.self, forKey: key) { values[key.stringValue] = value }
            else { extras[key.stringValue] = try c.decode(JSONValue.self, forKey: key) }
        }
        properties = values; unknownFields = extras
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: DynamicCodingKey.self)
        for (key, value) in properties { try c.encode(value, forKey: .init(key)) }
        for (key, value) in unknownFields where properties[key] == nil { try c.encode(value, forKey: .init(key)) }
    }
}

public enum VexelAnimatableValue: Codable, Equatable, Sendable {
    case constant(JSONValue)
    case animated(VexelAnimationTrack)

    public init(from decoder: Decoder) throws {
        let value = try JSONValue(from: decoder)
        if let object = value.objectValue, object["keyframes"]?.arrayValue != nil {
            self = .animated(try JSONDecoder().decode(VexelAnimationTrack.self, from: JSONEncoder().encode(value)))
        } else {
            self = .constant(value)
        }
    }
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .constant(let value): try value.encode(to: encoder)
        case .animated(let track): try track.encode(to: encoder)
        }
    }
}

public struct VexelAnimationTrack: Codable, Equatable, Sendable {
    public var keyframes: [VexelKeyframe]
    public var loop: JSONValue?
    public var expression: String?
    public var unknownFields: [String: JSONValue]
    public init(keyframes: [VexelKeyframe], loop: JSONValue? = nil, expression: String? = nil, unknownFields: [String: JSONValue] = [:]) {
        self.keyframes = keyframes; self.loop = loop; self.expression = expression; self.unknownFields = unknownFields
    }
    private enum Keys: String, CaseIterable { case keyframes, loop, expression }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DynamicCodingKey.self)
        keyframes = try c.decode([VexelKeyframe].self, forKey: .init("keyframes"))
        loop = try c.decodeIfPresent(JSONValue.self, forKey: .init("loop"))
        expression = try c.decodeIfPresent(String.self, forKey: .init("expression"))
        unknownFields = try VexelNativeProject.decodeExtra(c, known: Set(Keys.allCases.map(\.rawValue)))
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: DynamicCodingKey.self)
        try c.encode(keyframes, forKey: .init("keyframes")); try c.encodeIfPresent(loop, forKey: .init("loop"))
        try c.encodeIfPresent(expression, forKey: .init("expression"))
        for (key, value) in unknownFields where !Keys.allCases.map(\.rawValue).contains(key) { try c.encode(value, forKey: .init(key)) }
    }
}

public struct VexelKeyframe: Codable, Equatable, Sendable {
    public var time: Double
    public var value: JSONValue
    public var easing: JSONValue?
    public var unknownFields: [String: JSONValue]
    public init(time: Double, value: JSONValue, easing: JSONValue? = nil, unknownFields: [String: JSONValue] = [:]) {
        self.time = time; self.value = value; self.easing = easing; self.unknownFields = unknownFields
    }
    private enum Keys: String, CaseIterable { case time, value, easing }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DynamicCodingKey.self)
        time = try c.decode(Double.self, forKey: .init("time")); value = try c.decode(JSONValue.self, forKey: .init("value"))
        easing = try c.decodeIfPresent(JSONValue.self, forKey: .init("easing"))
        unknownFields = try VexelNativeProject.decodeExtra(c, known: Set(Keys.allCases.map(\.rawValue)))
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: DynamicCodingKey.self)
        try c.encode(time, forKey: .init("time")); try c.encode(value, forKey: .init("value"))
        try c.encodeIfPresent(easing, forKey: .init("easing"))
        for (key, value) in unknownFields where !Keys.allCases.map(\.rawValue).contains(key) { try c.encode(value, forKey: .init(key)) }
    }
}

public struct VexelEffect: Codable, Equatable, Sendable {
    public var type: String
    public var enabled: Bool?
    public var parameters: [String: JSONValue]
    public init(type: String, enabled: Bool? = nil, parameters: [String: JSONValue] = [:]) {
        self.type = type; self.enabled = enabled; self.parameters = parameters
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DynamicCodingKey.self)
        type = try c.decode(String.self, forKey: .init("type"))
        enabled = try c.decodeIfPresent(Bool.self, forKey: .init("enabled"))
        var values: [String: JSONValue] = [:]
        for key in c.allKeys where key.stringValue != "type" && key.stringValue != "enabled" {
            values[key.stringValue] = try c.decode(JSONValue.self, forKey: key)
        }
        parameters = values
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: DynamicCodingKey.self)
        try c.encode(type, forKey: .init("type")); try c.encodeIfPresent(enabled, forKey: .init("enabled"))
        for (key, value) in parameters where key != "type" && key != "enabled" { try c.encode(value, forKey: .init(key)) }
    }
}

private struct DynamicCodingKey: CodingKey, Hashable {
    var stringValue: String
    var intValue: Int? { nil }
    init(_ string: String) { stringValue = string }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

private extension VexelNativeProject {
    static func decodeExtra(
        _ container: KeyedDecodingContainer<DynamicCodingKey>,
        known: Set<String>
    ) throws -> [String: JSONValue] {
        var result: [String: JSONValue] = [:]
        for key in container.allKeys where !known.contains(key.stringValue) {
            result[key.stringValue] = try container.decode(JSONValue.self, forKey: key)
        }
        return result
    }
}

private extension VexelNativeProject.CodingKeys {
    static var allCases: [Self] { [.format, .formatVersion, .generator, .meta, .composition, .assets, .markers, .editorView, .layers] }
}
