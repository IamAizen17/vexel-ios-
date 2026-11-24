import Foundation

public struct ScenePoint: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double = 0, y: Double = 0) {
        self.x = x
        self.y = y
    }
}

public struct EvaluatedLayer: Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let type: String
    public let position: ScenePoint
    public let scale: ScenePoint
    public let rotationDegrees: Double
    public let opacity: Double
    public let size: ScenePoint
    public let shapeKind: String?
    public let fillColor: String?
    public let text: String?
    public let fontSize: Double?
    public let effects: [String]
    public let assetID: String?
    public let localTime: Double
}

public struct FrameScene: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let fps: Int
    public let duration: Double
    public let background: String
    public let layers: [EvaluatedLayer]
}

public enum SceneEvaluator {
    private struct Transform {
        var position = ScenePoint()
        var scale = ScenePoint(x: 1, y: 1)
        var rotation = 0.0
        var opacity = 1.0
    }

    public static func evaluate(_ project: ProjectDocument, at requestedTime: Double) -> FrameScene {
        let composition = project.fields["composition"]?.objectValue ?? [:]
        let width = Int(composition["width"]?.numberValue ?? 1080)
        let height = Int(composition["height"]?.numberValue ?? 1920)
        let fps = Int(composition["fps"]?.numberValue ?? 30)
        let duration = composition["duration"]?.numberValue ?? 10
        let time = requestedTime.isFinite ? min(max(0, requestedTime), max(0, duration)) : 0
        var layers: [EvaluatedLayer] = []
        evaluateLayers(
            project.fields["layers"]?.arrayValue ?? [],
            at: time,
            parentStart: 0,
            parentTransform: Transform(),
            into: &layers
        )
        return FrameScene(
            width: max(1, width),
            height: max(1, height),
            fps: max(1, fps),
            duration: max(0, duration),
            background: colorHex(composition["background"], at: time) ?? "#000000",
            layers: layers
        )
    }

    private static func evaluateLayers(
        _ values: [JSONValue],
        at time: Double,
        parentStart: Double,
        parentTransform: Transform,
        into output: inout [EvaluatedLayer]
    ) {
        let byID = Dictionary(
            values.compactMap { value -> (String, [String: JSONValue])? in
                guard let object = value.objectValue,
                      let id = object["id"]?.stringValue else { return nil }
                return (id, object)
            },
            uniquingKeysWith: { first, _ in first }
        )
        for value in values {
            guard let object = value.objectValue else { continue }
            let type = object["type"]?.stringValue ?? "shape"
            let start = parentStart + (object["start"]?.numberValue ?? 0)
            let duration = max(0, object["duration"]?.numberValue ?? .greatestFiniteMagnitude)
            guard object["visible"]?.boolValue ?? true,
                  time >= start,
                  time < start + duration else { continue }

            let localTime = max(0, time - start)
            let inherited = resolveParentTransform(
                object["parent"]?.stringValue,
                byID: byID,
                at: time,
                parentStart: parentStart,
                parentTransform: parentTransform,
                visited: []
            )
            let transform = compose(inherited, readTransform(object["transform"]?.objectValue, at: localTime))
            if type == "group" {
                evaluateLayers(
                    object["layers"]?.arrayValue ?? [],
                    at: time,
                    parentStart: start,
                    parentTransform: transform,
                    into: &output
                )
                continue
            }

            guard type != "null", type != "camera", type != "light", type != "audio" else { continue }
            let shape = object["shape"]?.objectValue ?? [:]
            let text = object["text"]?.objectValue
            let fill = shape["fill"]?.objectValue
            let effects = (object["effects"]?.arrayValue ?? []).compactMap {
                $0.objectValue?["type"]?.stringValue
            }
            let size = vector(sample(shape["size"], at: localTime), fallback: ScenePoint(x: 200, y: 200))
            let textColor = colorHex(text?["color"], at: localTime)
            let fillColor = colorHex(fill?["color"], at: localTime) ?? colorHex(shape["color"], at: localTime) ?? textColor
            let contentAssetID = object[type]?.objectValue?["asset"]?.stringValue
            output.append(EvaluatedLayer(
                id: object["id"]?.stringValue ?? "layer-\(output.count)",
                name: object["name"]?.stringValue ?? type.capitalized,
                type: type,
                position: transform.position,
                scale: transform.scale,
                rotationDegrees: transform.rotation,
                opacity: transform.opacity.clamped(to: 0...1),
                size: size,
                shapeKind: shape["kind"]?.stringValue,
                fillColor: fillColor,
                text: text?["content"]?.stringValue,
                fontSize: sample(text?["fontSize"], at: localTime)?.numberValue,
                effects: effects,
                assetID: contentAssetID,
                localTime: localTime
            ))
        }
    }

    private static func readTransform(_ object: [String: JSONValue]?, at time: Double) -> Transform {
        guard let object else { return Transform() }
        let position = sample(object["position"], at: time)
        let scale = sample(object["scale"], at: time)
        let rotation = sample(object["rotation"], at: time)
        let opacity = sample(object["opacity"], at: time)
        return Transform(
            position: vector(position, fallback: ScenePoint()),
            scale: vector(scale, fallback: ScenePoint(x: 1, y: 1)),
            rotation: rotation?.numberValue ?? 0,
            opacity: opacity?.numberValue ?? 1
        )
    }

    private static func resolveParentTransform(
        _ parentID: String?,
        byID: [String: [String: JSONValue]],
        at time: Double,
        parentStart: Double,
        parentTransform: Transform,
        visited: Set<String>
    ) -> Transform {
        guard let parentID, !visited.contains(parentID),
              let parent = byID[parentID] else { return parentTransform }
        var nextVisited = visited
        nextVisited.insert(parentID)
        let start = parentStart + (parent["start"]?.numberValue ?? 0)
        let localTime = max(0, time - start)
        let inherited = resolveParentTransform(
            parent["parent"]?.stringValue,
            byID: byID,
            at: time,
            parentStart: parentStart,
            parentTransform: parentTransform,
            visited: nextVisited
        )
        return compose(inherited, readTransform(parent["transform"]?.objectValue, at: localTime))
    }

    private static func compose(_ parent: Transform, _ child: Transform) -> Transform {
        let radians = parent.rotation * .pi / 180
        let scaledX = child.position.x * parent.scale.x
        let scaledY = child.position.y * parent.scale.y
        return Transform(
            position: ScenePoint(
                x: parent.position.x + scaledX * cos(radians) - scaledY * sin(radians),
                y: parent.position.y + scaledX * sin(radians) + scaledY * cos(radians)
            ),
            scale: ScenePoint(x: parent.scale.x * child.scale.x, y: parent.scale.y * child.scale.y),
            rotation: parent.rotation + child.rotation,
            opacity: parent.opacity * child.opacity
        )
    }

    private static func sample(_ value: JSONValue?, at time: Double) -> JSONValue? {
        guard let value else { return nil }
        guard let object = value.objectValue, let frames = object["keyframes"]?.arrayValue else {
            return value.objectValue?["value"] ?? value
        }
        let sorted = frames.compactMap { frame -> (Double, JSONValue, JSONValue?)? in
            guard let item = frame.objectValue,
                  let frameTime = item["time"]?.numberValue,
                  frameTime.isFinite,
                  let frameValue = item["value"] else { return nil }
            return (frameTime, frameValue, item["easing"])
        }.sorted { $0.0 < $1.0 }
        guard let first = sorted.first else { return object["value"] }
        if time <= first.0 { return first.1 }
        guard let last = sorted.last else { return first.1 }

        var sampleTime = time
        if time > last.0, last.0 > first.0 {
            let loop = object["loop"]?.stringValue
            if loop == "cycle" || loop == "pingpong" {
                let span = last.0 - first.0
                let elapsed = time - first.0
                let cycle = floor(elapsed / span)
                let local = elapsed - cycle * span
                sampleTime = loop == "pingpong" && Int(cycle) % 2 == 1
                    ? last.0 - local
                    : first.0 + local
            }
        }
        if sampleTime >= last.0 { return last.1 }
        for index in 1..<sorted.count where sampleTime <= sorted[index].0 {
            let left = sorted[index - 1]
            let right = sorted[index]
            let span = right.0 - left.0
            let rawProgress = span > 0 ? (sampleTime - left.0) / span : 0
            let progress = easingProgress(left.2, rawProgress: rawProgress)
            return interpolate(left.1, right.1, progress: progress)
        }
        return last.1
    }

    private static func easingProgress(_ easing: JSONValue?, rawProgress: Double) -> Double {
        let t = rawProgress.clamped(to: 0...1)
        guard let easing else { return t }
        if let id = easing.stringValue {
            if id == "hold" { return t >= 1 ? 1 : 0 }
            if let curve = presetBezier(id) { return cubicBezier(t, curve.0, curve.1, curve.2, curve.3) }
            switch id {
            case "easeOutBounce": return bounceOut(t)
            case "easeInBounce": return 1 - bounceOut(1 - t)
            case "easeInOutBounce": return t < 0.5 ? (1 - bounceOut(1 - 2 * t)) / 2 : (1 + bounceOut(2 * t - 1)) / 2
            case "easeInElastic":
                return t == 0 || t == 1 ? t : -pow(2, 10 * t - 10) * sin((t * 10 - 10.75) * (2 * .pi / 3))
            case "easeOutElastic":
                return t == 0 || t == 1 ? t : pow(2, -10 * t) * sin((t * 10 - 0.75) * (2 * .pi / 3)) + 1
            case "easeInOutElastic":
                if t == 0 || t == 1 { return t }
                return t < 0.5
                    ? -(pow(2, 20 * t - 10) * sin((20 * t - 11.125) * (2 * .pi / 4.5))) / 2
                    : (pow(2, -20 * t + 10) * sin((20 * t - 11.125) * (2 * .pi / 4.5))) / 2 + 1
            default: return t
            }
        }
        guard let object = easing.objectValue else { return t }
        if let bezier = object["cubicBezier"]?.arrayValue, bezier.count == 4,
           let x1 = bezier[0].numberValue, let y1 = bezier[1].numberValue,
           let x2 = bezier[2].numberValue, let y2 = bezier[3].numberValue {
            return cubicBezier(t, x1, y1, x2, y2)
        }
        if let cyclic = object["cyclic"]?.objectValue {
            if t <= 0 { return 0 }
            if t >= 1 { return 1 }
            let offset = cyclic["offset"]?.numberValue ?? 0
            let cycles = (cyclic["cycles"]?.numberValue ?? 3.5).clamped(to: 0.5...64)
            let phase = (cyclic["phase"]?.numberValue ?? 0).clamped(to: -1...1)
            let peak = 0.5 + 0.45 * offset.clamped(to: -1...1)
            let x = cycles * (t - phase)
            let whole = floor(x)
            let fraction = x - whole
            let fullCycles = floor(cycles)
            let tail = cycles - fullCycles
            let warped: Double
            if whole == fullCycles, tail > 0.000001, phase == 0 {
                warped = tail * cyclicWarp(fraction / tail, peak: peak)
            } else {
                warped = cyclicWarp(fraction, peak: peak)
            }
            return 0.5 - 0.5 * cos(2 * .pi * warped)
        }
        return t
    }

    private static func presetBezier(_ id: String) -> (Double, Double, Double, Double)? {
        switch id {
        case "linear": return (0, 0, 1, 1)
        case "ease": return (0.25, 0.1, 0.25, 1)
        case "easeIn": return (0.42, 0, 1, 1)
        case "easeOut": return (0, 0, 0.58, 1)
        case "easeInOut": return (0.42, 0, 0.58, 1)
        case "easeInSine": return (0.12, 0, 0.39, 0)
        case "easeOutSine": return (0.61, 1, 0.88, 1)
        case "easeInOutSine": return (0.37, 0, 0.63, 1)
        case "easeInQuad": return (0.11, 0, 0.5, 0)
        case "easeOutQuad": return (0.5, 1, 0.89, 1)
        case "easeInOutQuad": return (0.45, 0, 0.55, 1)
        case "easeInCubic": return (0.32, 0, 0.67, 0)
        case "easeOutCubic": return (0.33, 1, 0.68, 1)
        case "easeInOutCubic": return (0.65, 0, 0.35, 1)
        case "easeInQuart": return (0.5, 0, 0.75, 0)
        case "easeOutQuart": return (0.25, 1, 0.5, 1)
        case "easeInOutQuart": return (0.76, 0, 0.24, 1)
        case "easeInQuint": return (0.64, 0, 0.78, 0)
        case "easeOutQuint": return (0.22, 1, 0.36, 1)
        case "easeInOutQuint": return (0.83, 0, 0.17, 1)
        case "easeInExpo": return (0.7, 0, 0.84, 0)
        case "easeOutExpo": return (0.16, 1, 0.3, 1)
        case "easeInOutExpo": return (0.87, 0, 0.13, 1)
        case "easeInCirc": return (0.55, 0, 1, 0.45)
        case "easeOutCirc": return (0, 0.55, 0.45, 1)
        case "easeInOutCirc": return (0.85, 0, 0.15, 1)
        case "easeInBack": return (0.36, 0, 0.66, -0.56)
        case "easeOutBack": return (0.34, 1.56, 0.64, 1)
        case "easeInOutBack": return (0.68, -0.6, 0.32, 1.6)
        default: return nil
        }
    }

    private static func cubicBezier(
        _ x: Double,
        _ x1: Double,
        _ y1: Double,
        _ x2: Double,
        _ y2: Double
    ) -> Double {
        func coordinate(_ t: Double, _ p1: Double, _ p2: Double) -> Double {
            let inverse = 1 - t
            return 3 * inverse * inverse * t * p1 + 3 * inverse * t * t * p2 + t * t * t
        }
        var low = 0.0
        var high = 1.0
        var parameter = x
        for _ in 0..<20 {
            let estimate = coordinate(parameter, x1, x2)
            if abs(estimate - x) < 0.000001 { break }
            if estimate < x { low = parameter } else { high = parameter }
            parameter = (low + high) / 2
        }
        return coordinate(parameter, y1, y2)
    }

    private static func bounceOut(_ value: Double) -> Double {
        let n = 7.5625
        let d = 2.75
        if value < 1 / d { return n * value * value }
        if value < 2 / d {
            let x = value - 1.5 / d
            return n * x * x + 0.75
        }
        if value < 2.5 / d {
            let x = value - 2.25 / d
            return n * x * x + 0.9375
        }
        let x = value - 2.625 / d
        return n * x * x + 0.984375
    }

    private static func cyclicWarp(_ value: Double, peak: Double) -> Double {
        value < peak ? 0.5 * value / peak : 0.5 + 0.5 * (value - peak) / (1 - peak)
    }

    private static func interpolate(_ lhs: JSONValue, _ rhs: JSONValue, progress: Double) -> JSONValue {
        let t = progress
        switch (lhs, rhs) {
        case (.number(let a), .number(let b)):
            return .number(a + (b - a) * t)
        case (.array(let a), .array(let b)) where a.count == b.count:
            return .array(zip(a, b).map { pair in interpolate(pair.0, pair.1, progress: t) })
        case (.string(let a), .string(let b)):
            return .string(interpolateHexColor(a, b, progress: t) ?? (t < 1 ? a : b))
        default:
            return t < 1 ? lhs : rhs
        }
    }

    private static func interpolateHexColor(_ lhs: String, _ rhs: String, progress: Double) -> String? {
        func channels(_ value: String) -> [Double]? {
            let hex = value.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            guard (hex.count == 6 || hex.count == 8), let number = UInt64(hex, radix: 16) else { return nil }
            if hex.count == 6 {
                return [Double((number >> 16) & 255), Double((number >> 8) & 255), Double(number & 255)]
            }
            return [Double((number >> 24) & 255), Double((number >> 16) & 255), Double((number >> 8) & 255), Double(number & 255)]
        }
        guard let a = channels(lhs), let b = channels(rhs), a.count == b.count else { return nil }
        let values = zip(a, b).map { UInt8(($0.0 + ($0.1 - $0.0) * progress).clamped(to: 0...255).rounded()) }
        return "#" + values.map { String(format: "%02X", $0) }.joined()
    }

    private static func colorHex(_ value: JSONValue?, at time: Double) -> String? {
        guard let value = sample(value, at: time) else { return nil }
        if let string = value.stringValue { return string }
        let components: [Double]
        if let array = value.arrayValue {
            components = array.compactMap(\.numberValue)
        } else if let object = value.objectValue {
            components = ["r", "g", "b"].compactMap { object[$0]?.numberValue }
        } else {
            return nil
        }
        guard components.count >= 3 else { return nil }
        let channels = components.prefix(3).map { UInt8(($0.clamped(to: 0...1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", channels[0], channels[1], channels[2])
    }

    private static func vector(_ value: JSONValue?, fallback: ScenePoint) -> ScenePoint {
        guard let value else { return fallback }
        if let array = value.arrayValue, array.count >= 2,
           let x = array[0].numberValue, let y = array[1].numberValue {
            return ScenePoint(x: x, y: y)
        }
        if let object = value.objectValue,
           let x = object["x"]?.numberValue,
           let y = object["y"]?.numberValue {
            return ScenePoint(x: x, y: y)
        }
        if let number = value.numberValue { return ScenePoint(x: number, y: number) }
        return fallback
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
