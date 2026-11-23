import AVFoundation
import Foundation
import VexelCore
import VexelRenderer
import VexelMedia
import VexelAudio

public struct ExportConfiguration: Sendable, Equatable {
    public let width: Int
    public let height: Int
    public let frameRateNumerator: Int32
    public let frameRateDenominator: Int32
    public let startTime: CMTime
    public let endTime: CMTime

    public init(width: Int, height: Int, frameRateNumerator: Int32, frameRateDenominator: Int32, startTime: CMTime, endTime: CMTime) {
        self.width = width
        self.height = height
        self.frameRateNumerator = frameRateNumerator
        self.frameRateDenominator = frameRateDenominator
        self.startTime = startTime
        self.endTime = endTime
    }

    public var isValid: Bool {
        width > 0 && height > 0 && frameRateNumerator > 0 && frameRateDenominator > 0 &&
        CMTimeCompare(endTime, startTime) > 0
    }
}

public enum ExportEngineError: Error, Equatable {
    case invalidConfiguration
    case cancelled
    case writerFailed(String)
}
