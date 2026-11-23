import Foundation

public enum ShaderSourceLanguage: String, Codable, Sendable, Equatable {
    case glslES300
    case glslES310
    case metal
}

public enum ShaderTargetLanguage: String, Codable, Sendable {
    case spirv
    case metal
}

public enum ShaderStage: String, Codable, Sendable {
    case vertex
    case fragment
    case compute
}

public struct ShaderSource: Sendable {
    public let identifier: String
    public let language: ShaderSourceLanguage
    public let stage: ShaderStage
    public let source: String
    public let entryPoint: String

    public init(
        identifier: String,
        language: ShaderSourceLanguage,
        stage: ShaderStage,
        source: String,
        entryPoint: String = "main"
    ) {
        self.identifier = identifier
        self.language = language
        self.stage = stage
        self.source = source
        self.entryPoint = entryPoint
    }
}

public struct ShaderResourceBinding: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case uniformBuffer
        case sampledTexture
        case sampler
        case storageBuffer
        case storageTexture
    }

    public let name: String
    public let kind: Kind
    public let descriptorSet: Int
    public let binding: Int
    public let metalIndex: Int

    public init(name: String, kind: Kind, descriptorSet: Int, binding: Int, metalIndex: Int) {
        self.name = name
        self.kind = kind
        self.descriptorSet = descriptorSet
        self.binding = binding
        self.metalIndex = metalIndex
    }
}

public struct ShaderTranslationArtifact: Sendable {
    public let sourceIdentifier: String
    public let sourceDigest: String
    public let spirv: Data
    public let metalSource: String
    public let entryPoint: String
    public let stage: ShaderStage
    public let bindings: [ShaderResourceBinding]

    public init(
        sourceIdentifier: String,
        sourceDigest: String,
        spirv: Data,
        metalSource: String,
        entryPoint: String,
        stage: ShaderStage,
        bindings: [ShaderResourceBinding]
    ) {
        self.sourceIdentifier = sourceIdentifier
        self.sourceDigest = sourceDigest
        self.spirv = spirv
        self.metalSource = metalSource
        self.entryPoint = entryPoint
        self.stage = stage
        self.bindings = bindings
    }
}

public struct ShaderDiagnostic: Equatable, Sendable {
    public enum Severity: String, Sendable {
        case warning
        case error
    }

    public let severity: Severity
    public let message: String
    public let line: Int?

    public init(severity: Severity, message: String, line: Int? = nil) {
        self.severity = severity
        self.message = message
        self.line = line
    }
}

public enum ShaderTranslationError: Error, Equatable {
    case emptyIdentifier
    case emptySource
    case sourceTooLarge(limit: Int)
    case unsupportedLanguage(ShaderSourceLanguage)
    case invalidSPIRVMagic
    case backendUnavailable(String)
    case compilationFailed([ShaderDiagnostic])
}

public protocol GLSLToSPIRVCompiler: Sendable {
    func compile(_ source: ShaderSource) throws -> Data
}

public protocol SPIRVToMSLCompiler: Sendable {
    func translate(
        _ spirv: Data,
        stage: ShaderStage,
        entryPoint: String
    ) throws -> (source: String, bindings: [ShaderResourceBinding])
}

public struct ShaderTranslationPipeline: Sendable {
    public static let defaultMaximumSourceBytes = 1_048_576
    private let glslCompiler: any GLSLToSPIRVCompiler
    private let mslCompiler: any SPIRVToMSLCompiler
    private let maximumSourceBytes: Int

    public init(
        glslCompiler: any GLSLToSPIRVCompiler,
        mslCompiler: any SPIRVToMSLCompiler,
        maximumSourceBytes: Int = Self.defaultMaximumSourceBytes
    ) {
        self.glslCompiler = glslCompiler
        self.mslCompiler = mslCompiler
        self.maximumSourceBytes = max(1, maximumSourceBytes)
    }

    public func translate(_ input: ShaderSource) throws -> ShaderTranslationArtifact {
        guard !input.identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ShaderTranslationError.emptyIdentifier
        }
        guard !input.source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ShaderTranslationError.emptySource
        }
        guard input.source.utf8.count <= maximumSourceBytes else {
            throw ShaderTranslationError.sourceTooLarge(limit: maximumSourceBytes)
        }
        guard input.language == .glslES300 || input.language == .glslES310 else {
            throw ShaderTranslationError.unsupportedLanguage(input.language)
        }

        let module = try glslCompiler.compile(input)
        guard module.count >= 4,
              module.prefix(4).elementsEqual([0x03, 0x02, 0x23, 0x07]) else {
            throw ShaderTranslationError.invalidSPIRVMagic
        }

        let translated = try mslCompiler.translate(
            module,
            stage: input.stage,
            entryPoint: input.entryPoint
        )
        guard !translated.source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ShaderTranslationError.compilationFailed([
                ShaderDiagnostic(severity: .error, message: "Translator returned empty Metal source.")
            ])
        }

        return ShaderTranslationArtifact(
            sourceIdentifier: input.identifier,
            sourceDigest: Self.digest(input.source),
            spirv: module,
            metalSource: translated.source,
            entryPoint: input.entryPoint,
            stage: input.stage,
            bindings: translated.bindings
        )
    }

    private static func digest(_ source: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in source.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }
}
