import AVFoundation
import Combine
import Darwin
import Foundation
import VexelCore

@MainActor
final class VexelAudioPlaybackEngine: ObservableObject {
    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var rateUnits: [AVAudioUnitVarispeed] = []
    private var files: [AVAudioFile] = []

    private struct Clip {
        let assetID: String
        let start: Double
        let duration: Double
        let sourceStart: Double
        let speed: Double
        let volume: Float
        let muted: Bool
    }

    func play(project: VexelProjectItem, from time: Double) throws {
        stop()
        guard let data = project.documentJSON?.data(using: .utf8) else { return }
        let document = try ProjectDocument(data: data)
        guard let assetsDirectory = project.assetsDirectory else { return }
        let assetPaths = Dictionary(
            (document.fields["assets"]?.arrayValue ?? []).compactMap { value -> (String, String)? in
                guard let object = value.objectValue,
                      let id = object["id"]?.stringValue,
                      let path = object["path"]?.stringValue else { return nil }
                return (id, path)
            },
            uniquingKeysWith: { first, _ in first }
        )
        let clips = audioClips(document.fields["layers"]?.arrayValue ?? [], parentStart: 0, compositionTime: time)
            .filter { !$0.muted && $0.volume > 0 && $0.duration > 0 && $0.start + $0.duration > time }
        var scheduled: [(AVAudioPlayerNode, AVAudioFile, AVAudioUnitVarispeed, Clip, AVAudioFramePosition, AVAudioFrameCount)] = []

        for clip in clips {
            guard let path = assetPaths[clip.assetID] else { continue }
            let fileURL = assetsDirectory.appendingPathComponent(path)
            guard let file = try? AVAudioFile(forReading: fileURL) else { continue }
            let sampleRate = file.processingFormat.sampleRate
            guard sampleRate > 0 else { continue }

            let elapsed = max(0, time - clip.start)
            let speed = clip.speed.clamped(to: 0.25...4)
            let sourceOffset = clip.sourceStart + elapsed * speed
            let startFrame = AVAudioFramePosition(sourceOffset * sampleRate)
            guard startFrame >= 0, startFrame < file.length else { continue }
            let availableFrames = file.length - startFrame
            let requestedFrames = AVAudioFramePosition((clip.duration - elapsed) * speed * sampleRate)
            let frameCount = AVAudioFrameCount(min(availableFrames, max(0, requestedFrames)))
            guard frameCount > 0 else { continue }

            let player = AVAudioPlayerNode()
            let rateUnit = AVAudioUnitVarispeed()
            rateUnit.rate = Float(speed)
            engine.attach(player)
            engine.attach(rateUnit)
            engine.connect(player, to: rateUnit, format: file.processingFormat)
            engine.connect(rateUnit, to: engine.mainMixerNode, format: file.processingFormat)
            player.volume = clip.volume.clamped(to: 0...1)
            scheduled.append((player, file, rateUnit, clip, startFrame, frameCount))
        }

        guard !scheduled.isEmpty else { return }
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        engine.prepare()
        do {
            try engine.start()
            let now = mach_absolute_time()
            for (player, file, rateUnit, clip, startFrame, frameCount) in scheduled {
                let delay = max(0, clip.start - time)
                let hostDelay = AVAudioTime.hostTime(forSeconds: delay)
                let (hostTime, overflow) = now.addingReportingOverflow(hostDelay)
                guard !overflow else {
                    engine.detach(player)
                    engine.detach(rateUnit)
                    continue
                }
                player.scheduleSegment(
                    file,
                    startingFrame: startFrame,
                    frameCount: frameCount,
                    at: AVAudioTime(hostTime: hostTime),
                    completionHandler: nil
                )
                players.append(player)
                rateUnits.append(rateUnit)
                files.append(file)
                player.play()
            }
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        players.forEach { $0.stop(); engine.detach($0) }
        rateUnits.forEach { engine.detach($0) }
        players.removeAll()
        rateUnits.removeAll()
        files.removeAll()
        engine.stop()
    }

    private func audioClips(_ layers: [JSONValue], parentStart: Double, compositionTime: Double) -> [Clip] {
        var result: [Clip] = []
        for value in layers {
            guard let object = value.objectValue else { continue }
            let start = parentStart + max(0, object["start"]?.numberValue ?? 0)
            let duration = max(0, object["duration"]?.numberValue ?? 0)
            let type = object["type"]?.stringValue ?? ""
            if type == "group" {
                result.append(contentsOf: audioClips(object["layers"]?.arrayValue ?? [], parentStart: start, compositionTime: compositionTime))
            } else if type == "audio",
                      object["visible"]?.boolValue ?? true,
                      let media = object["audio"]?.objectValue,
                      let assetID = media["asset"]?.stringValue {
                let muted = media["muted"]?.boolValue ?? false
                let localTime = max(0, compositionTime - start)
                let speed = sampleNumber(media["speed"], at: localTime).clamped(to: 0.25...4)
                let sourceStart = max(0, media["sourceStart"]?.numberValue ?? 0)
                let volume = sampleNumber(media["volume"], at: localTime).clamped(to: 0...1)
                result.append(Clip(
                    assetID: assetID,
                    start: start,
                    duration: duration,
                    sourceStart: sourceStart,
                    speed: speed,
                    volume: Float(volume),
                    muted: muted
                ))
            }
        }
        return result
    }

    private func sampleNumber(_ value: JSONValue?, at time: Double) -> Double {
        guard let value else { return 1 }
        guard let object = value.objectValue, let frames = object["keyframes"]?.arrayValue else {
            return value.objectValue?["value"]?.numberValue ?? value.numberValue ?? 1
        }
        let sorted = frames.compactMap { frame -> (Double, Double)? in
            guard let object = frame.objectValue,
                  let keyTime = object["time"]?.numberValue,
                  let number = object["value"]?.numberValue else { return nil }
            return (keyTime, number)
        }.sorted { $0.0 < $1.0 }
        guard let first = sorted.first else { return object["value"]?.numberValue ?? 1 }
        if time <= first.0 { return first.1 }
        guard let last = sorted.last else { return first.1 }
        if time >= last.0 { return last.1 }
        for index in 1..<sorted.count where time <= sorted[index].0 {
            let left = sorted[index - 1]
            let right = sorted[index]
            let progress = (time - left.0) / max(0.000001, right.0 - left.0)
            return left.1 + (right.1 - left.1) * progress
        }
        return last.1
    }
}

private extension JSONValue {
    var boolValue: Bool? {
        guard case .bool(let value) = self else { return nil }
        return value
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
