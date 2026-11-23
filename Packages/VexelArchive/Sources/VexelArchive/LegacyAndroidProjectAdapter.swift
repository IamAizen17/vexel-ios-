import Foundation
import VexelCore

enum LegacyAndroidProjectAdapter {
    static let legacyFormatIdentifier = "knsproj"
    static let maximumSupportedVersion = 12

    static func importDocument(_ source: ProjectDocument) throws -> ProjectDocument {
        let format = source.fields["format"]?.stringValue
        guard format != legacyFormatIdentifier else {
            let rawVersion = source.fields["formatVersion"]?.numberValue
            guard let rawVersion,
                  rawVersion.isFinite,
                  rawVersion.rounded(.towardZero) == rawVersion,
                  (1...Double(maximumSupportedVersion)).contains(rawVersion) else {
                throw ZIPProjectArchiveError.unsupportedLegacyVersion
            }

            var fields = source.fields
            fields["format"] = .string(ProjectDocument.format)
            fields["formatVersion"] = .number(Double(ProjectDocument.currentVersion))
            fields["generator"] = .string("Vexel")
            fields["compatibility"] = .object([
                "source": .string("android-reference"),
                "sourceVersion": .number(rawVersion)
            ])

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

        guard format == ProjectDocument.format else {
            throw ZIPProjectArchiveError.unsupportedProjectFormat
        }
        return source
    }
}
