import XCTest
@testable import VexelShaderCompiler

private struct TestGLSLCompiler: GLSLToSPIRVCompiler {
    let module: Data
    func compile(_ source: ShaderSource) throws -> Data { module }
}

private struct TestMSLCompiler: SPIRVToMSLCompiler {
    func translate(
        _ spirv: Data,
        stage: ShaderStage,
        entryPoint: String
    ) throws -> (source: String, bindings: [ShaderResourceBinding]) {
        ("fragment float4 test() { return float4(1.0); }", "test", [])
    }
}

final class ShaderTranslationTests: XCTestCase {
    private let validModule = Data([0x03, 0x02, 0x23, 0x07, 0x00, 0x00, 0x00, 0x00])

    func testTranslatesGLSLThroughSPIRVIntoMSL() throws {
        let pipeline = ShaderTranslationPipeline(
            glslCompiler: TestGLSLCompiler(module: validModule),
            mslCompiler: TestMSLCompiler()
        )
        let artifact = try pipeline.translate(
            ShaderSource(
                identifier: "test.copy",
                language: .glslES300,
                stage: .fragment,
                source: "#version 300 es\nvoid main() {}"
            )
        )

        XCTAssertEqual(artifact.sourceIdentifier, "test.copy")
        XCTAssertEqual(artifact.spirv, validModule)
        XCTAssertTrue(artifact.metalSource.contains("fragment"))
        XCTAssertFalse(artifact.sourceDigest.isEmpty)
    }

    func testRejectsEmptyIdentifier() {
        let pipeline = ShaderTranslationPipeline(
            glslCompiler: TestGLSLCompiler(module: validModule),
            mslCompiler: TestMSLCompiler()
        )
        XCTAssertThrowsError(try pipeline.translate(
            ShaderSource(identifier: " ", language: .glslES300, stage: .fragment, source: "void main() {}")
        )) { error in
            XCTAssertEqual(error as? ShaderTranslationError, .emptyIdentifier)
        }
    }

    func testRejectsOversizedSourceBeforeCallingCompiler() {
        let pipeline = ShaderTranslationPipeline(
            glslCompiler: TestGLSLCompiler(module: validModule),
            mslCompiler: TestMSLCompiler(),
            maximumSourceBytes: 4
        )
        XCTAssertThrowsError(try pipeline.translate(
            ShaderSource(identifier: "test", language: .glslES300, stage: .fragment, source: "12345")
        )) { error in
            XCTAssertEqual(error as? ShaderTranslationError, .sourceTooLarge(limit: 4))
        }
    }

    func testRejectsInvalidSPIRVMagic() {
        let pipeline = ShaderTranslationPipeline(
            glslCompiler: TestGLSLCompiler(module: Data([0, 0, 0, 0])),
            mslCompiler: TestMSLCompiler()
        )
        XCTAssertThrowsError(try pipeline.translate(
            ShaderSource(identifier: "test", language: .glslES300, stage: .fragment, source: "void main() {}")
        )) { error in
            XCTAssertEqual(error as? ShaderTranslationError, .invalidSPIRVMagic)
        }
    }

    func testReportsMissingNativeToolchainInsteadOfPretendingToCompile() {
        let compiler = UnavailableGLSLCompiler()
        XCTAssertThrowsError(try compiler.compile(
            ShaderSource(identifier: "test", language: .glslES300, stage: .fragment, source: "void main() {}")
        ))
    }
}
