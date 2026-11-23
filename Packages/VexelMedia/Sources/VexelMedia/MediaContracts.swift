import AVFoundation
import CoreVideo
import Foundation

public struct MediaAssetDescriptor: Sendable, Equatable {
    public let identifier: String
    public let url: URL
    public let duration: CMTime
    public let isVideo: Bool
    public let hasAudio: Bool

    public init(identifier: String, url: URL, duration: CMTime, isVideo: Bool, hasAudio: Bool) {
        self.identifier = identifier
        self.url = url
        self.duration = duration
        self.isVideo = isVideo
        self.hasAudio = hasAudio
    }
}

public protocol VideoFrameProviding: Sendable {
    func frame(at time: CMTime) async throws -> CVPixelBuffer?
}

public enum MediaEngineError: Error, Equatable {
    case assetUnavailable(String)
    case unsupportedMedia(String)
    case frameDecodeFailed(String)
}
