import AVFoundation
import Darwin
import Foundation
import VexelCore

@MainActor
final class VexelAudioPlaybackEngine: ObservableObject {
    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []

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
        let clips = audioClips(document.fields["layers"]?.arrayValue ?? [], parentStart: 0)
        let now = mach_absolute_time()

        for clip in clips {
            let elapsed = max(0, time - clip.start)
            let remaining = clip.duration - elapsed
            guard remaining > 0,
                  let path = assetPaths[clip.assetID] else { continue }
            let fileURL = assetsDirectory.appendingPathComponent(path)
            guard let file = try? AVAudioFile(forReading: fileURL) else { continue }
            let sampleRate = file.processingFormat.sampleRate
            guard sampleRate > 0 else { continue }

            let startFrame = AVAudioFramePosition(elapsed * sampleRate)
            guard startFrame < file.length else { continue }
            let availableFrames = file.length - startFrame
            let requestedFrames = AVAudioFramePosition(remaining * sampleRate)
            let frameCount = AVAudioFrameCount(min(availableFrames, requestedFrames))
            guard frameCount > 0 else { continue }

            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: file.processingFormat)
            let delay = max(0, clip.start - time)
            let hostDelay = AVAudioTime.hostTime(forSeconds: delay)
            let (hostTime, overflow) = now.addingReportingOverflow(hostDelay)
            guard !overflow else {
                engine.detach(player)
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
        }

        guard !players.isEmpty else { return }
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        engine.prepare()
        do {
            try engine.start()
            players.forEach { $0.play() }
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        players.forEach { player in
            player.stop()
            engine.detach(player)
        }
        players.removeAll()
        engine.stop()
    }

    private func audioClips(_ layers: [JSONValue], parentStart: Double) -> [(assetID: String, start: Double, duration: Double)] {
        var result: [(String, Double, Double)] = []
        for value in layers {
            guard let object = value.objectValue else { continue }
            let start = parentStart + max(0, object["start"]?.numberValue ?? 0)
            let duration = max(0, object["duration"]?.numberValue ?? 0)
            let type = object["type"]?.stringValue ?? ""
            if type == "group" {
                result.append(contentsOf: audioClips(object["layers"]?.arrayValue ?? [], parentStart: start))
            } else if type == "audio",
                      object["visible"]?.boolValue ?? true,
                      let assetID = object["audio"]?.objectValue?["asset"]?.stringValue {
                result.append((assetID, start, duration))
            }
        }
        return result
    }
}

private extension JSONValue {
    var boolValue: Bool? {
        guard case .bool(let value) = self else { return nil }
        return value
    }
}
