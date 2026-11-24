import Foundation

public struct VexelObjectFields: Equatable, Sendable {
    public var values: [String: JSONValue]

    public init(_ values: [String: JSONValue] = [:]) {
        self.values = values
    }

    public subscript(_ key: String) -> JSONValue? {
        get { values[key] }
        set { values[key] = newValue }
    }

    public func string(_ key: String) -> String? { values[key]?.stringValue }
    public func number(_ key: String) -> Double? { values[key]?.numberValue }
    public func bool(_ key: String) -> Bool? {
        guard case .bool(let value) = values[key] else { return nil }
        return value
    }
    public func object(_ key: String) -> VexelObjectFields? {
        values[key]?.objectValue.map(VexelObjectFields.init)
    }
    public func array(_ key: String) -> [JSONValue]? { values[key]?.arrayValue }

    public func animatable(_ key: String) -> VexelAnimatableValue? {
        guard let value = values[key], let data = try? JSONEncoder().encode(value) else { return nil }
        return try? JSONDecoder().decode(VexelAnimatableValue.self, from: data)
    }

    public mutating func setAnimatable(_ value: VexelAnimatableValue?, for key: String) {
        guard let value, let data = try? JSONEncoder().encode(value),
              let json = try? JSONDecoder().decode(JSONValue.self, from: data) else {
            values.removeValue(forKey: key)
            return
        }
        values[key] = json
    }
}

public struct VexelFontContent: Equatable, Sendable {
    public var fields: VexelObjectFields
    public init(fields: VexelObjectFields) { self.fields = fields }
    public var family: String? { fields.string("family") }
    public var weight: Double? { fields.number("weight") }
    public var italic: Bool? { fields.bool("italic") }
    public var asset: String? { fields.string("asset") }
}

public struct VexelTextContent: Equatable, Sendable {
    public var fields: VexelObjectFields
    public init(fields: VexelObjectFields) { self.fields = fields }
    public var content: String? { fields.string("content") }
    public var font: VexelFontContent? { fields.object("font").map(VexelFontContent.init(fields:)) }
    public var fontSize: VexelAnimatableValue? { fields.animatable("fontSize") }
    public var color: VexelAnimatableValue? { fields.animatable("color") }
    public var align: String? { fields.string("align") }
    public var lineHeight: Double? { fields.number("lineHeight") }
    public var letterSpacing: VexelAnimatableValue? { fields.animatable("letterSpacing") }
    public var maxWidth: Double? { fields.number("maxWidth") }
    public var stroke: VexelObjectFields? { fields.object("stroke") }
    public var animators: [JSONValue]? { fields.array("animators") }
    public var propertyAnimators: [JSONValue]? { fields.array("propertyAnimators") }
}

public struct VexelShapeContent: Equatable, Sendable {
    public var fields: VexelObjectFields
    public init(fields: VexelObjectFields) { self.fields = fields }
    public var kind: String? { fields.string("kind") }
    public var size: VexelAnimatableValue? { fields.animatable("size") }
    public var roundness: VexelAnimatableValue? { fields.animatable("roundness") }
    public var sides: VexelAnimatableValue? { fields.animatable("sides") }
    public var innerRatio: VexelAnimatableValue? { fields.animatable("innerRatio") }
    public var path: VexelObjectFields? { fields.object("path") }
    public var fill: VexelObjectFields? { fields.object("fill") }
    public var stroke: VexelObjectFields? { fields.object("stroke") }
    public var trim: VexelObjectFields? { fields.object("trim") }
}

public struct VexelImageContent: Equatable, Sendable {
    public var fields: VexelObjectFields
    public init(fields: VexelObjectFields) { self.fields = fields }
    public var asset: String? { fields.string("asset") }
}

public struct VexelMediaContent: Equatable, Sendable {
    public var fields: VexelObjectFields
    public init(fields: VexelObjectFields) { self.fields = fields }
    public var asset: String? { fields.string("asset") }
    public var sourceStart: Double? { fields.number("sourceStart") }
    public var speed: Double? { fields.number("speed") }
    public var volume: VexelAnimatableValue? { fields.animatable("volume") }
    public var muted: Bool? { fields.bool("muted") }
    public var fadeIn: Double? { fields.number("fadeIn") }
    public var fadeOut: Double? { fields.number("fadeOut") }
    public var alphaPacked: Bool? { fields.bool("alphaPacked") }
    public var equalizerBands: [JSONValue]? { fields.array("eq") }
    public var cutout: VexelObjectFields? { fields.object("cutout") }
}

public struct VexelObject3DContent: Equatable, Sendable {
    public var fields: VexelObjectFields
    public init(fields: VexelObjectFields) { self.fields = fields }
    public var primitive: String? { fields.string("primitive") }
    public var size: VexelAnimatableValue? { fields.animatable("size") }
    public var material: VexelObjectFields? { fields.object("material") }
    public var text: VexelObjectFields? { fields.object("text") }
}

public struct VexelModel3DContent: Equatable, Sendable {
    public var fields: VexelObjectFields
    public init(fields: VexelObjectFields) { self.fields = fields }
    public var asset: String? { fields.string("asset") }
    public var size: VexelAnimatableValue? { fields.animatable("size") }
    public var material: VexelObjectFields? { fields.object("material") }
}

public struct VexelCameraContent: Equatable, Sendable {
    public var fields: VexelObjectFields
    public init(fields: VexelObjectFields) { self.fields = fields }
    public var position: VexelAnimatableValue? { fields.animatable("position") }
    public var target: VexelAnimatableValue? { fields.animatable("target") }
    public var rotation: VexelAnimatableValue? { fields.animatable("rotation") }
    public var aim: String? { fields.string("aim") }
    public var fieldOfView: VexelAnimatableValue? { fields.animatable("fov") }
    public var depthOfField: VexelObjectFields? { fields.object("dof") }
}

public struct VexelLightContent: Equatable, Sendable {
    public var fields: VexelObjectFields
    public init(fields: VexelObjectFields) { self.fields = fields }
    public var kind: String? { fields.string("kind") }
    public var color: VexelAnimatableValue? { fields.animatable("color") }
    public var intensity: VexelAnimatableValue? { fields.animatable("intensity") }
    public var position: VexelAnimatableValue? { fields.animatable("position") }
    public var target: VexelAnimatableValue? { fields.animatable("target") }
    public var radius: VexelAnimatableValue? { fields.animatable("radius") }
    public var castsShadows: Bool? { fields.bool("castShadows") }
    public var shadowDarkness: VexelAnimatableValue? { fields.animatable("shadowDarkness") }
    public var shadowSoftness: Double? { fields.number("shadowSoftness") }
}

public struct VexelNullContent: Equatable, Sendable {
    public var fields: VexelObjectFields
    public init(fields: VexelObjectFields) { self.fields = fields }
    public var is3D: Bool? { fields.bool("threeD") }
}

public enum VexelLayerContent: Equatable, Sendable {
    case text(VexelTextContent)
    case shape(VexelShapeContent)
    case image(VexelImageContent)
    case video(VexelMediaContent)
    case audio(VexelMediaContent)
    case group
    case object3D(VexelObject3DContent)
    case model3D(VexelModel3DContent)
    case camera(VexelCameraContent)
    case light(VexelLightContent)
    case null(VexelNullContent)

    fileprivate var fields: VexelObjectFields? {
        switch self {
        case .text(let value): value.fields
        case .shape(let value): value.fields
        case .image(let value): value.fields
        case .video(let value), .audio(let value): value.fields
        case .group: nil
        case .object3D(let value): value.fields
        case .model3D(let value): value.fields
        case .camera(let value): value.fields
        case .light(let value): value.fields
        case .null(let value): value.fields
        }
    }
}

public struct VexelMask: Equatable, Sendable {
    public var fields: VexelObjectFields
    public init(fields: VexelObjectFields) { self.fields = fields }
    public var shape: String? { fields.string("shape") }
    public var mode: String? { fields.string("mode") }
    public var position: VexelAnimatableValue? { fields.animatable("position") }
    public var size: VexelAnimatableValue? { fields.animatable("size") }
    public var roundness: VexelAnimatableValue? { fields.animatable("roundness") }
    public var feather: VexelAnimatableValue? { fields.animatable("feather") }
    public var opacity: VexelAnimatableValue? { fields.animatable("opacity") }
    public var inverted: Bool? { fields.bool("inverted") }
    public var enabled: Bool? { fields.bool("enabled") }
}

public struct VexelMatte: Equatable, Sendable {
    public var fields: VexelObjectFields
    public init(fields: VexelObjectFields) { self.fields = fields }
    public var layerID: String? { fields.string("layer") }
    public var mode: String? { fields.string("mode") }
}

public struct VexelTransition: Equatable, Sendable {
    public var fields: VexelObjectFields
    public init(fields: VexelObjectFields) { self.fields = fields }
    public var type: String? { fields.string("type") }
    public var duration: Double? { fields.number("duration") }
    public var easing: VexelEasing? {
        guard let value = fields["easing"], let data = try? JSONEncoder().encode(value) else { return nil }
        return try? JSONDecoder().decode(VexelEasing.self, from: data)
    }
    public var distance: Double? { fields.number("distance") }
}


public struct VexelProjectMetadata: Equatable, Sendable {
    public var fields: VexelObjectFields
    public init(fields: VexelObjectFields) { self.fields = fields }
    public var title: String? { fields.string("title") }
    public var description: String? { fields.string("description") }
    public var author: String? { fields.string("author") }
    public var createdAt: String? { fields.string("createdAt") }
    public var modifiedAt: String? { fields.string("modifiedAt") }
}

public struct VexelMotionBlurSettings: Equatable, Sendable {
    public var fields: VexelObjectFields
    public init(fields: VexelObjectFields) { self.fields = fields }
    public var enabled: Bool? { fields.bool("enabled") }
    public var shutterAngle: Double? { fields.number("shutterAngle") }
    public var samples: Int? { fields.number("samples").map(Int.init) }
}

public struct VexelEnvironmentSettings: Equatable, Sendable {
    public var fields: VexelObjectFields
    public init(fields: VexelObjectFields) { self.fields = fields }
    public var asset: String? { fields.string("asset") }
    public var intensity: Double? { fields.number("intensity") }
    public var rotation: Double? { fields.number("rotation") }
}

public enum VexelEditorViewMode: String, Sendable {
    case camera, editor, inside
}

public struct VexelEditorView: Equatable, Sendable {
    public var fields: VexelObjectFields
    public init(fields: VexelObjectFields) { self.fields = fields }
    public var mode: VexelEditorViewMode? { fields.string("mode").flatMap(VexelEditorViewMode.init(rawValue:)) }
    public var target: JSONValue? { fields["target"] }
    public var yaw: Double? { fields.number("yaw") }
    public var pitch: Double? { fields.number("pitch") }
    public var distance: Double? { fields.number("distance") }
    public var fieldOfView: Double? { fields.number("fov") }
}

public extension VexelNativeProject {
    var typedMetadata: VexelProjectMetadata {
        VexelProjectMetadata(fields: VexelObjectFields(meta))
    }

    var typedEditorView: VexelEditorView? {
        editorView?.objectValue.map { VexelEditorView(fields: VexelObjectFields($0)) }
    }
}

public extension VexelComposition {
    var backgroundColor: String? { background?.stringValue }

    var typedMotionBlur: VexelMotionBlurSettings? {
        motionBlur?.objectValue.map { VexelMotionBlurSettings(fields: VexelObjectFields($0)) }
    }

    var typedEnvironment: VexelEnvironmentSettings? {
        environment?.objectValue.map { VexelEnvironmentSettings(fields: VexelObjectFields($0)) }
    }
}

public extension VexelLayer {
    var typedContent: VexelLayerContent? {
        get {
            if type == .group { return .group }
            guard let values = content?.objectValue else { return nil }
            let fields = VexelObjectFields(values)
            switch type {
            case .text: .text(VexelTextContent(fields: fields))
            case .shape: .shape(VexelShapeContent(fields: fields))
            case .image: .image(VexelImageContent(fields: fields))
            case .video: .video(VexelMediaContent(fields: fields))
            case .audio: .audio(VexelMediaContent(fields: fields))
            case .group: .group
            case .object3D: .object3D(VexelObject3DContent(fields: fields))
            case .model3D: .model3D(VexelModel3DContent(fields: fields))
            case .camera: .camera(VexelCameraContent(fields: fields))
            case .light: .light(VexelLightContent(fields: fields))
            case .null: .null(VexelNullContent(fields: fields))
            }
        }
        set {
            guard let newValue else { content = nil; return }
            switch (type, newValue) {
            case (.group, .group):
                content = nil
            case (.text, .text), (.shape, .shape), (.image, .image),
                 (.video, .video), (.audio, .audio), (.object3D, .object3D),
                 (.model3D, .model3D), (.camera, .camera), (.light, .light), (.null, .null):
                content = newValue.fields.map { .object($0.values) }
            default:
                content = nil
            }
        }
    }

    var typedMasks: [VexelMask] {
        get { masks.compactMap { $0.objectValue.map { VexelMask(fields: VexelObjectFields($0)) } } }
        set { masks = newValue.map { .object($0.fields.values) } }
    }

    var typedMatte: VexelMatte? {
        get { matte?.objectValue.map { VexelMatte(fields: VexelObjectFields($0)) } }
        set { matte = newValue.map { .object($0.fields.values) } }
    }

    var typedTransitionIn: VexelTransition? {
        get { transitionIn?.objectValue.map { VexelTransition(fields: VexelObjectFields($0)) } }
        set { transitionIn = newValue.map { .object($0.fields.values) } }
    }

    var typedTransitionOut: VexelTransition? {
        get { transitionOut?.objectValue.map { VexelTransition(fields: VexelObjectFields($0)) } }
        set { transitionOut = newValue.map { .object($0.fields.values) } }
    }
}
