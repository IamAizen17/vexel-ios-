import Foundation

public struct UnavailableGLSLCompiler: GLSLToSPIRVCompiler {
    public let reason: String

    public init(reason: String = "The glslang iOS toolchain has not been linked into this build.") {
        self.reason = reason
    }

    public func compile(_ source: ShaderSource) throws -> Data {
        throw ShaderTranslationError.backendUnavailable(reason)
    }
}

public struct UnavailableMSLTranslator: SPIRVToMSLCompiler {
    public let reason: String

    public init(reason: String = "The SPIRV-Cross Metal backend has not been linked into this build.") {
        self.reason = reason
    }

    public func translate(
        _ spirv: Data,
        stage: ShaderStage,
        entryPoint: String
    ) throws -> (source: String, entryPoint: String, bindings: [ShaderResourceBinding]) {
        throw ShaderTranslationError.backendUnavailable(reason)
    }
}
