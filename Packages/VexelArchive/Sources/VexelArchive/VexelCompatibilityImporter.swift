import Foundation
import VexelCore

enum VexelCompatibilityImporter {
    static let legacyAndroidFormatIdentifier = "knsproj"
    static let maximumLegacyAndroidVersion = 12

    static func importDocument(_ source: ProjectDocument) throws -> ProjectDocument {
        let format = source.fields["format"]?.stringValue
        guard format == legacyAndroidFormatIdentifier else {
            guard format == ProjectDocument.format else {
                throw ZIPProjectArchiveError.unsupportedProjectFormat
            }
            return source
        }

        let rawVersion = source.fields["formatVersion"]?.numberValue
        guard let rawVersion,
              rawVersion.isFinite,
              rawVersion.rounded(.towardZero) == rawVersion,
              (1...Double(maximumLegacyAndroidVersion)).contains(rawVersion) else {
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
        return ProjectDocument(fields: fields)
    }
}
