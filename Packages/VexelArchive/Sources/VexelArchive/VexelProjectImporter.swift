import Foundation

public enum VexelProjectImporter {
        private static let maximumAndroidCompatibilityVersion = 12

    public static func importDocument(from data: Data) throws -> ProjectDocument {
        let source = try ProjectDocument(data: data)
        let sourceFormat = source.fields["format"]?.stringValue

        if sourceFormat == ProjectDocument.format {
            let issues = source.validate().filter { $0.severity == .error }
            guard issues.isEmpty else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: [],
                    debugDescription: issues.map { "\($0.path): \($0.message)" }.joined(separator: "\n")
                ))
            }
            return source
        }

        guard let sourceFormat, sourceFormat != ProjectDocument.format else {
            throw ProjectDocumentError.unsupportedFormat(sourceFormat)
        }

        guard let rawVersion = source.fields["formatVersion"]?.numberValue,
              rawVersion.isFinite,
              rawVersion.rounded(.towardZero) == rawVersion,
              (1...Double(maximumAndroidCompatibilityVersion)).contains(rawVersion) else {
            throw ProjectDocumentError.unsupportedVersion(nil)
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
}
