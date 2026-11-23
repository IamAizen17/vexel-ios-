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
            var meta = fields["meta"]?.objectValue ?? [:]
            meta["importedFrom"] = .string("Legacy Android project")
            meta["importedFormatVersion"] = .number(rawVersion)
            fields["meta"] = .object(meta)
            return ProjectDocument(fields: fields)
        }

        guard format == ProjectDocument.format else {
            throw ZIPProjectArchiveError.unsupportedProjectFormat
        }
        return source
    }
