import AVFAudio
import Foundation

public struct PCMBufferFormat: Sendable, Equatable {
    public let sampleRate: Double
    public let channelCount: AVAudioChannelCount

    public init(sampleRate: Double = 48_000, channelCount: AVAudioChannelCount = 2) {
        self.sampleRate = sampleRate
        self.channelCount = channelCount
    }

    public var isValid: Bool { sampleRate.isFinite && sampleRate > 0 && channelCount > 0 }
}

public protocol OfflineAudioMixing: Sendable {
    func render(startSample: Int64, frameCount: AVAudioFrameCount, format: PCMBufferFormat) async throws -> AVAudioPCMBuffer
}

public enum AudioEngineError: Error, Equatable {
    case invalidFormat
    case sourceUnavailable(String)
    case renderFailed(String)
}
