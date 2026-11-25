import Foundation
import Metal

public enum MetalRendererError: Error, Equatable {
    case noDevice
    case commandQueueUnavailable
    case invalidGraph(RenderGraphIssue)
}

public final class MetalRenderer {
    public let device: MTLDevice
    public let commandQueue: MTLCommandQueue

    public init(device: MTLDevice? = MTLCreateSystemDefaultDevice()) throws {
        guard let device else { throw MetalRendererError.noDevice }
        guard let queue = device.makeCommandQueue() else { throw MetalRendererError.commandQueueUnavailable }
        self.device = device
        self.commandQueue = queue
    }

    public func validate(_ graph: RenderGraph, externalInputs: Set<RenderResourceID> = []) throws {
        do {
            try graph.validate(externalInputs: externalInputs)
        } catch let issue as RenderGraphIssue {
            throw MetalRendererError.invalidGraph(issue)
        }
    }
}
