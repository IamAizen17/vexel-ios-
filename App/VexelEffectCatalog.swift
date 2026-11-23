import Foundation
import VexelCore

struct VexelEffectCategory: Decodable, Identifiable {
    let id: String
    let en: String
    let pt: String
}

struct VexelEffectParameter: Decodable, Equatable, Identifiable {
    let name: String
    let type: String
    let defaultValue: JSONValue
    let min: Double?
    let max: Double?
    let choices: [String]?

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name, type, min, max, choices
        case defaultValue = "default"
    }

    var displayName: String {
        name
            .replacingOccurrences(of: "([A-Z])", with: " $1", options: .regularExpression)
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}

struct VexelEffectDefinition: Decodable, Identifiable {
    let id: String
    let category: String
    let pt: String
    let en: String
    let target: String
    let needsBackdrop: Bool
    let params: [VexelEffectParameter]
}

private struct VexelEffectRegistryDocument: Decodable {
    let categories: [VexelEffectCategory]
    let effects: [VexelEffectDefinition]
}

struct VexelEffectItem: Identifiable {
    let definition: VexelEffectDefinition

    var id: String { definition.id }
    var name: String { definition.en }
    var category: String {
        VexelEffectCatalog.categoryName(for: definition.category)
    }
    var target: String { definition.target }
    var needsBackdrop: Bool { definition.needsBackdrop }
    var params: [VexelEffectParameter] { definition.params }
}

enum VexelEffectCatalog {
    private static let registry: VexelEffectRegistryDocument = {
        guard
            let url = Bundle.main.url(forResource: "effects", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let value = try? JSONDecoder().decode(VexelEffectRegistryDocument.self, from: data)
        else {
            assertionFailure("The canonical effects.json registry is missing or invalid.")
            return VexelEffectRegistryDocument(categories: [], effects: [])
        }
        return value
    }()

    static let categories: [String] = registry.categories.map(\.en)
    static let all: [VexelEffectItem] = registry.effects.map(VexelEffectItem.init)
    static let effectCount = all.count

    static func categoryName(for id: String) -> String {
        registry.categories.first(where: { $0.id == id })?.en ?? id
    }

    static func effects(in category: String) -> [VexelEffectItem] {
        guard category == "All effects" else {
            return all.filter { $0.category == category }
        }
        return all
    }

    static func search(_ query: String) -> [VexelEffectItem] {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return all }
        return all.filter {
            $0.name.localizedCaseInsensitiveContains(value) ||
            $0.id.localizedCaseInsensitiveContains(value) ||
            $0.category.localizedCaseInsensitiveContains(value)
        }
    }
}
