import Foundation
import Metal
import VexelShaderCompiler

public enum MetalShaderLibraryError: Error, Equatable {
    case missingEntryPoint(String)
}

public struct MetalShaderLibraryCompiler {
    public let device: MTLDevice

    public init(device: MTLDevice) {
        self.device = device
    }

    public func compile(_ artifact: ShaderTranslationArtifact) throws -> MTLLibrary {
        try device.makeLibrary(source: artifact.metalSource, options: nil)
    }

    public func makeFunction(
        from library: MTLLibrary,
        artifact: ShaderTranslationArtifact
    ) throws -> MTLFunction {
        guard let function = library.makeFunction(name: artifact.entryPoint) else {
            throw MetalShaderLibraryError.missingEntryPoint(artifact.entryPoint)
        }
        return function
    }
}
