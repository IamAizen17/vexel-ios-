import Foundation

enum VexelProjectStore {
    private static let directoryName = "Projects"
    private static let fileName = "index.json"
    private static let encoder: JSONEncoder = {
        let value = JSONEncoder()
        value.outputFormatting = [.prettyPrinted, .sortedKeys]
        value.dateEncodingStrategy = .iso8601
        return value
    }()
    private static let decoder: JSONDecoder = {
        let value = JSONDecoder()
        value.dateDecodingStrategy = .iso8601
        return value
    }()

    static func load() throws -> [VexelProjectItem] {
        let directory = try projectDirectory()
        let url = directory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        return try decoder.decode([VexelProjectItem].self, from: data)
    }

    static func save(_ projects: [VexelProjectItem]) throws {
        let directory = try projectDirectory()
        let data = try encoder.encode(projects)
        try data.write(to: directory.appendingPathComponent(fileName), options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    private static func projectDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent(directoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = false
        var mutable = directory
        try? mutable.setResourceValues(values)
        return directory
    }
}
