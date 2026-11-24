import Foundation

public struct VexelEffectParameterType: RawRepresentable, Codable, Equatable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let number = Self(rawValue: "number")
    public static let integer = Self(rawValue: "integer")
    public static let boolean = Self(rawValue: "boolean")
    public static let color = Self(rawValue: "color")
    public static let choice = Self(rawValue: "choice")
    public static let point = Self(rawValue: "point")
    public static let stops = Self(rawValue: "stops")

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct VexelEffectParameterDefinition: Codable, Equatable, Sendable {
    public var name: String
    public var type: VexelEffectParameterType
    public var defaultValue: JSONValue?
    public var minimum: Double?
    public var maximum: Double?
    public var choices: [String]?
    public var unknownFields: [String: JSONValue]

    public init(
        name: String,
        type: VexelEffectParameterType,
        defaultValue: JSONValue? = nil,
        minimum: Double? = nil,
        maximum: Double? = nil,
        choices: [String]? = nil,
        unknownFields: [String: JSONValue] = [:]
    ) {
        self.name = name
        self.type = type
        self.defaultValue = defaultValue
        self.minimum = minimum
        self.maximum = maximum
        self.choices = choices
        self.unknownFields = unknownFields
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: EffectSchemaCodingKey.self)
        name = try container.decode(String.self, forKey: .init("name"))
        type = try container.decode(VexelEffectParameterType.self, forKey: .init("type"))
        defaultValue = try container.decodeIfPresent(JSONValue.self, forKey: .init("default"))
        minimum = try container.decodeIfPresent(Double.self, forKey: .init("min"))
        maximum = try container.decodeIfPresent(Double.self, forKey: .init("max"))
        choices = try container.decodeIfPresent([String].self, forKey: .init("choices"))
        let known: Set<String> = ["name", "type", "default", "min", "max", "choices"]
        unknownFields = try Self.decodeUnknown(container, excluding: known)
        if let minimum, let maximum, (!minimum.isFinite || !maximum.isFinite || minimum > maximum) {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Effect parameter bounds must be finite and ordered."))
        }
        if type == .choice && (choices?.isEmpty ?? true) {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Choice parameters require at least one choice."))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: EffectSchemaCodingKey.self)
        try container.encode(name, forKey: .init("name"))
        try container.encode(type, forKey: .init("type"))
        try container.encodeIfPresent(defaultValue, forKey: .init("default"))
        try container.encodeIfPresent(minimum, forKey: .init("min"))
        try container.encodeIfPresent(maximum, forKey: .init("max"))
        try container.encodeIfPresent(choices, forKey: .init("choices"))
        let known: Set<String> = ["name", "type", "default", "min", "max", "choices"]
        for (key, value) in unknownFields where !known.contains(key) {
            try container.encode(value, forKey: .init(key))
        }
    }

    private static func decodeUnknown(
        _ container: KeyedDecodingContainer<EffectSchemaCodingKey>,
        excluding known: Set<String>
    ) throws -> [String: JSONValue] {
        var values: [String: JSONValue] = [:]
        for key in container.allKeys where !known.contains(key.stringValue) {
            values[key.stringValue] = try container.decode(JSONValue.self, forKey: key)
        }
        return values
    }
}

public struct VexelEffectDefinition: Codable, Equatable, Sendable {
    public var id: String
    public var category: String
    public var portugueseName: String?
    public var englishName: String
    public var target: String
    public var needsBackdrop: Bool
    public var parameters: [VexelEffectParameterDefinition]

    private enum CodingKeys: String, CodingKey {
        case id, category, portugueseName = "pt", englishName = "en", target, needsBackdrop, parameters = "params"
    }

    public init(
        id: String,
        category: String,
        englishName: String,
        target: String,
        needsBackdrop: Bool,
        portugueseName: String? = nil,
        parameters: [VexelEffectParameterDefinition] = []
    ) {
        self.id = id
        self.category = category
        self.portugueseName = portugueseName
        self.englishName = englishName
        self.target = target
        self.needsBackdrop = needsBackdrop
        self.parameters = parameters
    }
}

public struct VexelEffectCategory: Codable, Equatable, Sendable {
    public var id: String
    public var portugueseName: String?
    public var englishName: String

    private enum CodingKeys: String, CodingKey {
        case id, portugueseName = "pt", englishName = "en"
    }

    public init(id: String, englishName: String, portugueseName: String? = nil) {
        self.id = id
        self.englishName = englishName
        self.portugueseName = portugueseName
    }
}

public struct VexelEffectCatalog: Codable, Equatable, Sendable {
    public var version: Int
    public var categories: [VexelEffectCategory]
    public var effects: [VexelEffectDefinition]

    public init(version: Int, categories: [VexelEffectCategory], effects: [VexelEffectDefinition]) {
        self.version = version
        self.categories = categories
        self.effects = effects
    }

    public func effect(id: String) -> VexelEffectDefinition? {
        effects.first { $0.id == id }
    }
}

private struct EffectSchemaCodingKey: CodingKey, Hashable {
    var stringValue: String
    var intValue: Int? { nil }

    init(_ value: String) {
        stringValue = value
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        return nil
    }
}
