import Foundation

public enum VexelPropertyStorage: Equatable, Sendable {
    case transform(is3D: Bool)
    case content
    case contentObject(parent: String, key: String)
}

public enum VexelPropertyValueKind: Equatable, Sendable {
    case scalar
    case vector(Int)
    case any
}

public struct VexelPropertyDescriptor: Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let storage: VexelPropertyStorage
    public let valueKind: VexelPropertyValueKind
    public let defaultValue: JSONValue
    public let storageKey: String
    public let minimum: Double?
    public let maximum: Double?
    public let supportedLayerTypes: [VexelLayerType]

    public init(
        id: String,
        title: String,
        storage: VexelPropertyStorage,
        storageKey: String? = nil,
        valueKind: VexelPropertyValueKind,
        defaultValue: JSONValue,
        minimum: Double? = nil,
        maximum: Double? = nil,
        supportedLayerTypes: [VexelLayerType]
    ) {
        self.id = id
        self.title = title
        self.storage = storage
        self.valueKind = valueKind
        self.defaultValue = defaultValue
        self.storageKey = storageKey ?? id
        self.minimum = minimum
        self.maximum = maximum
        self.supportedLayerTypes = supportedLayerTypes
    }

    public func supports(_ layer: VexelLayer) -> Bool {
        supportedLayerTypes.contains(layer.type)
    }

    public func validate(_ value: JSONValue) throws {
        let numbers: [Double]
        switch valueKind {
        case .scalar:
            guard let number = value.numberValue, number.isFinite else {
                throw VexelPropertyDescriptorError.invalidValue(id)
            }
            numbers = [number]
        case .vector(let count):
            guard let components = value.arrayValue, components.count == count else {
                throw VexelPropertyDescriptorError.invalidValue(id)
            }
            numbers = components.compactMap(\.numberValue)
            guard numbers.count == count, numbers.allSatisfy(\.isFinite) else {
                throw VexelPropertyDescriptorError.invalidValue(id)
            }
        case .any:
            numbers = []
        }
        if let minimum, numbers.contains(where: { $0 < minimum }) {
            throw VexelPropertyDescriptorError.invalidValue(id)
        }
        if let maximum, numbers.contains(where: { $0 > maximum }) {
            throw VexelPropertyDescriptorError.invalidValue(id)
        }
    }

    public func value(in layer: VexelLayer) -> VexelAnimatableValue? {
        guard supports(layer) else { return nil }
        switch storage {
        case .transform(let is3D):
            return (is3D ? layer.transform3D : layer.transform)?.properties[storageKey]
        case .content:
            return VexelObjectFields(layer.content?.objectValue ?? [:]).animatable(storageKey)
        case .contentObject(let parent, let key):
            return VexelObjectFields(layer.content?.objectValue ?? [:]).object(parent)?.animatable(key)
        }
    }

    public func setBaseValue(_ value: JSONValue, on layer: inout VexelLayer) throws {
        guard supports(layer) else { throw VexelPropertyDescriptorError.unsupportedLayer(id) }
        try validate(value)
        switch storage {
        case .transform(let is3D):
            var transform = is3D ? (layer.transform3D ?? VexelTransform()) : (layer.transform ?? VexelTransform())
            if case .animated(var animation)? = transform.properties[id] {
                animation.value = value
                transform.properties[id] = .animated(animation)
            } else {
                transform.properties[id] = .constant(value)
            }
            if is3D { layer.transform3D = transform } else { layer.transform = transform }
        case .content:
            var fields = VexelObjectFields(layer.content?.objectValue ?? [:])
            if case .animated(var animation)? = fields.animatable(id) {
                animation.value = value
                fields.setAnimatable(.animated(animation), for: storageKey)
            } else {
                fields.setAnimatable(.constant(value), for: storageKey)
            }
            layer.content = .object(fields.values)
        case .contentObject(let parent, let key):
            var fields = VexelObjectFields(layer.content?.objectValue ?? [:])
            var nested = fields.object(parent) ?? VexelObjectFields()
            if case .animated(var animation)? = nested.animatable(key) {
                animation.value = value
                nested.setAnimatable(.animated(animation), for: key)
            } else {
                nested.setAnimatable(.constant(value), for: key)
            }
            fields[parent] = .object(nested.values)
            layer.content = .object(fields.values)
        }
    }

    public func upsertKeyframe(_ keyframe: VexelKeyframe, on layer: inout VexelLayer) throws {
        guard supports(layer) else { throw VexelPropertyDescriptorError.unsupportedLayer(id) }
        guard keyframe.time.isFinite, keyframe.time >= 0,
              keyframe.time <= (layer.duration ?? 3600) else {
            throw VexelPropertyDescriptorError.invalidTime
        }
        try validate(keyframe.value)
        var animation: VexelAnimationTrack
        switch value(in: layer) {
        case .some(.animated(let existing)):
            animation = existing
        case .some(.constant(let current)):
            animation = VexelAnimationTrack(value: current)
        case .none:
            animation = VexelAnimationTrack(value: defaultValue)
        }
        if let index = animation.keyframes.firstIndex(where: { abs($0.time - keyframe.time) < 0.000001 }) {
            animation.keyframes[index] = keyframe
        } else {
            animation.keyframes.append(keyframe)
        }
        animation.keyframes.sort { $0.time < $1.time }
        setAnimation(.animated(animation), on: &layer)
    }

    public func removeKeyframe(at time: Double, on layer: inout VexelLayer) throws {
        guard supports(layer) else { throw VexelPropertyDescriptorError.unsupportedLayer(id) }
        guard time.isFinite, time >= 0 else { throw VexelPropertyDescriptorError.invalidTime }
        guard case .animated(var animation)? = value(in: layer) else { return }
        animation.keyframes.removeAll { abs($0.time - time) < 0.000001 }
        if animation.keyframes.isEmpty {
            if let base = animation.value {
                setAnimation(.constant(base), on: &layer)
            } else {
                removeValue(on: &layer)
            }
        } else {
            setAnimation(.animated(animation), on: &layer)
        }
    }

    private func setAnimation(_ value: VexelAnimatableValue, on layer: inout VexelLayer) {
        switch storage {
        case .transform(let is3D):
            var transform = is3D ? (layer.transform3D ?? VexelTransform()) : (layer.transform ?? VexelTransform())
            transform.properties[id] = value
            if is3D { layer.transform3D = transform } else { layer.transform = transform }
        case .content:
            var fields = VexelObjectFields(layer.content?.objectValue ?? [:])
            fields.setAnimatable(value, for: storageKey)
            layer.content = .object(fields.values)
        case .contentObject(let parent, let key):
            var fields = VexelObjectFields(layer.content?.objectValue ?? [:])
            var nested = fields.object(parent) ?? VexelObjectFields()
            nested.setAnimatable(value, for: key)
            fields[parent] = .object(nested.values)
            layer.content = .object(fields.values)
        }
    }

    private func removeValue(on layer: inout VexelLayer) {
        switch storage {
        case .transform(let is3D):
            var transform = is3D ? (layer.transform3D ?? VexelTransform()) : (layer.transform ?? VexelTransform())
            transform.properties.removeValue(forKey: storageKey)
            if is3D { layer.transform3D = transform } else { layer.transform = transform }
        case .content:
            var fields = VexelObjectFields(layer.content?.objectValue ?? [:])
            fields.setAnimatable(nil, for: storageKey)
            layer.content = .object(fields.values)
        case .contentObject(let parent, let key):
            var fields = VexelObjectFields(layer.content?.objectValue ?? [:])
            var nested = fields.object(parent) ?? VexelObjectFields()
            nested.setAnimatable(nil, for: key)
            fields[parent] = .object(nested.values)
            layer.content = .object(fields.values)
        }
    }
}

public enum VexelPropertyDescriptorError: Error, Equatable, Sendable {
    case unknownProperty(String)
    case unsupportedLayer(String)
    case invalidValue(String)
    case invalidTime
}

public enum VexelPropertyCatalog {
    private static let visual2D: [VexelLayerType] = [.text, .shape, .image, .video, .group, .null]
    private static let visual3D: [VexelLayerType] = [.object3D, .model3D]
    private static let scalarTypes: [VexelLayerType] = [.text, .shape, .image, .video, .audio, .object3D, .model3D, .camera, .light]

    public static let all: [VexelPropertyDescriptor] = [
        .init(id: "position", title: "Position", storage: .transform(is3D: false), valueKind: .vector(2), defaultValue: .array([.number(0), .number(0)]), supportedLayerTypes: visual2D),
        .init(id: "anchor", title: "Anchor", storage: .transform(is3D: false), valueKind: .vector(2), defaultValue: .array([.number(0), .number(0)]), supportedLayerTypes: visual2D),
        .init(id: "scale", title: "Scale", storage: .transform(is3D: false), valueKind: .vector(2), defaultValue: .array([.number(1), .number(1)]), minimum: -100, maximum: 100, supportedLayerTypes: visual2D),
        .init(id: "rotation", title: "Rotation", storage: .transform(is3D: false), valueKind: .scalar, defaultValue: .number(0), minimum: -360000, maximum: 360000, supportedLayerTypes: visual2D),
        .init(id: "opacity", title: "Opacity", storage: .transform(is3D: false), valueKind: .scalar, defaultValue: .number(1), minimum: 0, maximum: 1, supportedLayerTypes: visual2D),
        .init(id: "position3D", title: "Position", storage: .transform(is3D: true), storageKey: "position", valueKind: .vector(3), defaultValue: .array([.number(0), .number(0), .number(0)]), supportedLayerTypes: visual3D),
        .init(id: "anchor3D", title: "Anchor", storage: .transform(is3D: true), storageKey: "anchor", valueKind: .vector(3), defaultValue: .array([.number(0), .number(0), .number(0)]), supportedLayerTypes: visual3D),
        .init(id: "scale3D", title: "Scale", storage: .transform(is3D: true), storageKey: "scale", valueKind: .vector(3), defaultValue: .array([.number(1), .number(1), .number(1)]), minimum: -100, maximum: 100, supportedLayerTypes: visual3D),
        .init(id: "rotation3D", title: "Rotation", storage: .transform(is3D: true), storageKey: "rotation", valueKind: .vector(3), defaultValue: .array([.number(0), .number(0), .number(0)]), minimum: -360000, maximum: 360000, supportedLayerTypes: visual3D),
        .init(id: "opacity3D", title: "Opacity", storage: .transform(is3D: true), storageKey: "opacity", valueKind: .scalar, defaultValue: .number(1), minimum: 0, maximum: 1, supportedLayerTypes: visual3D),
        .init(id: "text.fontSize", title: "Font size", storage: .content, storageKey: "fontSize", valueKind: .scalar, defaultValue: .number(96), minimum: 1, maximum: 2048, supportedLayerTypes: [.text]),
        .init(id: "text.letterSpacing", title: "Letter spacing", storage: .content, storageKey: "letterSpacing", valueKind: .scalar, defaultValue: .number(0), minimum: -10, maximum: 10, supportedLayerTypes: [.text]),
        .init(id: "text.color", title: "Text color", storage: .content, storageKey: "color", valueKind: .any, defaultValue: .string("#FFFFFF"), supportedLayerTypes: [.text]),
        .init(id: "shape.size", title: "Size", storage: .content, storageKey: "size", valueKind: .vector(2), defaultValue: .array([.number(100), .number(100)]), minimum: 0, maximum: 8192, supportedLayerTypes: [.shape]),
        .init(id: "shape.roundness", title: "Roundness", storage: .content, storageKey: "roundness", valueKind: .scalar, defaultValue: .number(0), minimum: 0, maximum: 4096, supportedLayerTypes: [.shape]),
        .init(id: "shape.sides", title: "Sides", storage: .content, storageKey: "sides", valueKind: .scalar, defaultValue: .number(5), minimum: 3, maximum: 128, supportedLayerTypes: [.shape]),
        .init(id: "shape.innerRatio", title: "Inner ratio", storage: .content, storageKey: "innerRatio", valueKind: .scalar, defaultValue: .number(0.5), minimum: 0, maximum: 1, supportedLayerTypes: [.shape]),
        .init(id: "media.volume", title: "Volume", storage: .content, storageKey: "volume", valueKind: .scalar, defaultValue: .number(1), minimum: 0, maximum: 4, supportedLayerTypes: [.video, .audio]),
        .init(id: "object3D.size", title: "Object size", storage: .content, storageKey: "size", valueKind: .vector(3), defaultValue: .array([.number(1), .number(1), .number(1)]), minimum: 0, maximum: 8192, supportedLayerTypes: [.object3D, .model3D]),
        .init(id: "camera.position", title: "Camera position", storage: .content, storageKey: "position", valueKind: .vector(3), defaultValue: .array([.number(0), .number(0), .number(0)]), supportedLayerTypes: [.camera]),
        .init(id: "camera.target", title: "Camera target", storage: .content, storageKey: "target", valueKind: .vector(3), defaultValue: .array([.number(0), .number(0), .number(-1)]), supportedLayerTypes: [.camera]),
        .init(id: "camera.rotation", title: "Camera rotation", storage: .content, storageKey: "rotation", valueKind: .vector(3), defaultValue: .array([.number(0), .number(0), .number(0)]), supportedLayerTypes: [.camera]),
        .init(id: "camera.fov", title: "Field of view", storage: .content, storageKey: "fov", valueKind: .scalar, defaultValue: .number(50), minimum: 1, maximum: 179, supportedLayerTypes: [.camera]),
        .init(id: "camera.dof.focusDistance", title: "Focus distance", storage: .contentObject(parent: "dof", key: "focusDistance"), storageKey: "focusDistance", valueKind: .scalar, defaultValue: .number(10), minimum: 0, maximum: 100000, supportedLayerTypes: [.camera]),
        .init(id: "camera.dof.range", title: "Depth of field range", storage: .contentObject(parent: "dof", key: "range"), storageKey: "range", valueKind: .scalar, defaultValue: .number(5), minimum: 0, maximum: 100000, supportedLayerTypes: [.camera]),
        .init(id: "camera.dof.blur", title: "Depth of field blur", storage: .contentObject(parent: "dof", key: "blur"), storageKey: "blur", valueKind: .scalar, defaultValue: .number(0), minimum: 0, maximum: 1000, supportedLayerTypes: [.camera]),
        .init(id: "light.color", title: "Light color", storage: .content, storageKey: "color", valueKind: .any, defaultValue: .string("#FFFFFF"), supportedLayerTypes: [.light]),
        .init(id: "light.intensity", title: "Light intensity", storage: .content, storageKey: "intensity", valueKind: .scalar, defaultValue: .number(1), minimum: 0, maximum: 100000, supportedLayerTypes: [.light]),
        .init(id: "light.position", title: "Light position", storage: .content, storageKey: "position", valueKind: .vector(3), defaultValue: .array([.number(0), .number(0), .number(0)]), supportedLayerTypes: [.light]),
        .init(id: "light.target", title: "Light target", storage: .content, storageKey: "target", valueKind: .vector(3), defaultValue: .array([.number(0), .number(0), .number(-1)]), supportedLayerTypes: [.light]),
        .init(id: "light.radius", title: "Light radius", storage: .content, storageKey: "radius", valueKind: .scalar, defaultValue: .number(1), minimum: 0, maximum: 100000, supportedLayerTypes: [.light]),
        .init(id: "light.shadowDarkness", title: "Shadow darkness", storage: .content, storageKey: "shadowDarkness", valueKind: .scalar, defaultValue: .number(0.5), minimum: 0, maximum: 1, supportedLayerTypes: [.light]),
        .init(id: "material.color", title: "Material color", storage: .contentObject(parent: "material", key: "color"), storageKey: "color", valueKind: .any, defaultValue: .string("#FFFFFF"), supportedLayerTypes: [.object3D, .model3D]),
        .init(id: "material.metallic", title: "Metallic", storage: .contentObject(parent: "material", key: "metallic"), storageKey: "metallic", valueKind: .scalar, defaultValue: .number(0), minimum: 0, maximum: 1, supportedLayerTypes: [.object3D, .model3D]),
        .init(id: "material.roughness", title: "Roughness", storage: .contentObject(parent: "material", key: "roughness"), storageKey: "roughness", valueKind: .scalar, defaultValue: .number(0.5), minimum: 0, maximum: 1, supportedLayerTypes: [.object3D, .model3D]),
        .init(id: "material.emissive", title: "Emissive", storage: .contentObject(parent: "material", key: "emissive"), storageKey: "emissive", valueKind: .any, defaultValue: .number(0), supportedLayerTypes: [.object3D, .model3D])
    ]

    public static func descriptor(for id: String) -> VexelPropertyDescriptor? {
        all.first { $0.id == id }
    }

    public static func descriptors(for layer: VexelLayer) -> [VexelPropertyDescriptor] {
        all.filter { $0.supports(layer) }
    }
}
