import Foundation
import VexelCore
import VexelArchive

public struct PluginCapabilityManifest: Codable, Sendable, Equatable {
    public let identifier: String
    public let version: String
    public let requestedCapabilities: Set<String>

    public init(identifier: String, version: String, requestedCapabilities: Set<String>) {
        self.identifier = identifier
        self.version = version
        self.requestedCapabilities = requestedCapabilities
    }
}

public enum PluginValidationError: Error, Equatable {
    case invalidIdentifier
    case unsupportedVersion
    case deniedCapability(String)
    case invalidSignature
    case unsafePackage
}
