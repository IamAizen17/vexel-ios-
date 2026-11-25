import Foundation

struct VexelCompositionDefaults: Codable, Equatable {
    var width: Int
    var height: Int
    var fps: Int
    var duration: Double

    static let storageKey = "vexel.composition.defaults"
    static let `default` = VexelCompositionDefaults(width: 1080, height: 1920, fps: 30, duration: 10)
    var isValid: Bool {
        (16...8192).contains(width) &&
        (16...8192).contains(height) &&
        (1...120).contains(fps) &&
        duration.isFinite &&
        (1...3600).contains(duration)
    }

    static func load(from defaults: UserDefaults = .standard) -> VexelCompositionDefaults {
        guard let data = defaults.data(forKey: storageKey),
              let value = try? JSONDecoder().decode(VexelCompositionDefaults.self, from: data),
              value.isValid else {
            return .default
        }
        return value
    }

    func save(to defaults: UserDefaults = .standard) {
        guard isValid, let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    static func reset(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey)
    }
}
