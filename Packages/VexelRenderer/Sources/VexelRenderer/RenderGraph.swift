import Foundation

public struct RenderResourceID: Hashable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(_ rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }
}

public enum RenderPixelFormat: String, Equatable, Sendable {
    case rgba8Unorm
    case rgba16Float
    case r8Unorm
    case depth32Float
}

public enum RenderColorSpace: String, Equatable, Sendable {
    case linearSRGB
    case sRGB
    case displayP3
    case extendedLinearSRGB
}

public enum RenderAlphaMode: String, Equatable, Sendable {
    case premultiplied
    case straight
    case opaque
}

public struct RenderResourceDescriptor: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let pixelFormat: RenderPixelFormat
    public let colorSpace: RenderColorSpace
    public let alphaMode: RenderAlphaMode

    public init(width: Int, height: Int, pixelFormat: RenderPixelFormat, colorSpace: RenderColorSpace, alphaMode: RenderAlphaMode) {
        self.width = width
        self.height = height
        self.pixelFormat = pixelFormat
        self.colorSpace = colorSpace
        self.alphaMode = alphaMode
    }

    public var estimatedBytes: Int {
        let bytesPerPixel: Int
        switch pixelFormat {
        case .rgba8Unorm: bytesPerPixel = 4
        case .rgba16Float: bytesPerPixel = 8
        case .r8Unorm: bytesPerPixel = 1
        case .depth32Float: bytesPerPixel = 4
        }
        let (pixels, overflowA) = width.multipliedReportingOverflow(by: height)
        let (bytes, overflowB) = pixels.multipliedReportingOverflow(by: bytesPerPixel)
        return overflowA || overflowB ? Int.max : bytes
    }

    public var isValid: Bool {
        width > 0 && height > 0 && estimatedBytes > 0 && estimatedBytes < Int.max
    }
}

public struct RenderPassDescriptor: Equatable, Sendable {
    public let id: String
    public let reads: [RenderResourceID]
    public let writes: RenderResourceID
    public let readsBackdrop: Bool

    public init(id: String, reads: [RenderResourceID], writes: RenderResourceID, readsBackdrop: Bool = false) {
        self.id = id
        self.reads = reads
        self.writes = writes
        self.readsBackdrop = readsBackdrop
    }
}

public enum RenderGraphIssue: Error, Equatable, Sendable {
    case invalidResource(RenderResourceID)
    case duplicatePass(String)
    case duplicateOutput(RenderResourceID)
    case missingInput(pass: String, resource: RenderResourceID)
    case readWriteAlias(pass: String, resource: RenderResourceID)
    case backdropDependencyMissing(pass: String)
}

public struct RenderGraph: Equatable, Sendable {
    public let resources: [RenderResourceID: RenderResourceDescriptor]
    public let passes: [RenderPassDescriptor]

    public init(resources: [RenderResourceID: RenderResourceDescriptor], passes: [RenderPassDescriptor]) {
        self.resources = resources
        self.passes = passes
    }

    public func validate(externalInputs: Set<RenderResourceID> = []) throws {
        for (id, descriptor) in resources where !descriptor.isValid {
            throw RenderGraphIssue.invalidResource(id)
        }

        var passIDs = Set<String>()
        var produced = externalInputs
        for pass in passes {
            guard !pass.id.isEmpty, passIDs.insert(pass.id).inserted else {
                throw RenderGraphIssue.duplicatePass(pass.id)
            }
            guard resources[pass.writes] != nil else { throw RenderGraphIssue.invalidResource(pass.writes) }
            guard !produced.contains(pass.writes) else { throw RenderGraphIssue.duplicateOutput(pass.writes) }
            for input in pass.reads {
                guard resources[input] != nil else { throw RenderGraphIssue.invalidResource(input) }
                guard input != pass.writes else { throw RenderGraphIssue.readWriteAlias(pass: pass.id, resource: input) }
                guard produced.contains(input) else { throw RenderGraphIssue.missingInput(pass: pass.id, resource: input) }
            }
            if pass.readsBackdrop && pass.reads.isEmpty {
                throw RenderGraphIssue.backdropDependencyMissing(pass: pass.id)
            }
            produced.insert(pass.writes)
        }
    }
}
