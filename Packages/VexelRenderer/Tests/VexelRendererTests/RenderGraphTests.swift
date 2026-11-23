import XCTest
@testable import VexelRenderer

final class RenderGraphTests: XCTestCase {
    func testValidOrderedGraph() throws {
        let descriptor = RenderResourceDescriptor(width: 64, height: 64, pixelFormat: .rgba8Unorm, colorSpace: .linearSRGB, alphaMode: .premultiplied)
        let graph = RenderGraph(
            resources: ["source": descriptor, "blurred": descriptor, "output": descriptor],
            passes: [
                RenderPassDescriptor(id: "blur", reads: ["source"], writes: "blurred"),
                RenderPassDescriptor(id: "composite", reads: ["blurred"], writes: "output")
            ]
        )
        XCTAssertNoThrow(try graph.validate(externalInputs: ["source"]))
    }

    func testRejectsReadBeforeWrite() {
        let descriptor = RenderResourceDescriptor(width: 32, height: 32, pixelFormat: .rgba8Unorm, colorSpace: .linearSRGB, alphaMode: .premultiplied)
        let graph = RenderGraph(
            resources: ["missing": descriptor, "output": descriptor],
            passes: [RenderPassDescriptor(id: "copy", reads: ["missing"], writes: "output")]
        )
        XCTAssertThrowsError(try graph.validate())
    }

    func testRejectsInvalidDimensions() {
        let descriptor = RenderResourceDescriptor(width: 0, height: 32, pixelFormat: .rgba8Unorm, colorSpace: .linearSRGB, alphaMode: .premultiplied)
        let graph = RenderGraph(resources: ["output": descriptor], passes: [])
        XCTAssertThrowsError(try graph.validate())
    }
}
