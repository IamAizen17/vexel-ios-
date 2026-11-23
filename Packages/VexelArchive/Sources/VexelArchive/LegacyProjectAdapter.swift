import Foundation
import VexelCore

public enum LegacyProjectAdapter {
    private static let legacyAndroidFormat = "knsproj"
    private static let maximumSourceVersion = 12

    public static func importDocument(from data: Data) throws -> ProjectDocument {
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        guard case .object(var fields) = decoded else {
            throw ProjectDocumentError.invalidRoot
        }

        let format = fields["format"]?.stringValue
        guard format == ProjectDocument.format || format == legacyAndroidFormat else {
            throw ProjectDocumentError.unsupportedFormat(format)
        }

        if format == ProjectDocument.format {
            return try ProjectDocument(data: data)
        }

        let sourceVersion = fields["formatVersion"]?.numberValue.flatMap { value -> Int? in
            guard value.isFinite,
                  value.rounded(.towardZero) == value,
                  value >= 1,
                  value <= Double(Int.max) else { return nil }
            return Int(value)
        }
        guard let sourceVersion, sourceVersion <= maximumSourceVersion else {
            throw ProjectDocumentError.unsupportedVersion(sourceVersion)
        }

        fields["format"] = .string(ProjectDocument.format)
        fields["formatVersion"] = .number(Double(ProjectDocument.currentVersion))

        var compatibility = fields["compatibility"]?.objectValue ?? [:]
        compatibility["source"] = .string("legacy-android")
        compatibility["sourceVersion"] = .number(Double(sourceVersion))
        fields["compatibility"] = .object(compatibility)

        let project = ProjectDocument(fields: fields)
        let errors = project.validate().filter { $0.severity == .error }
        guard errors.isEmpty else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: [],
                debugDescription: errors.map { "\($0.path): \($0.message)" }.joined(separator: "\n")
            ))
        }
        return project
    }
}
