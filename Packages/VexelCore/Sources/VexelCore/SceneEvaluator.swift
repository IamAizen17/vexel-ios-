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
            background: composition["background"]?.stringValue ?? "#000000",
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
        for value in values {
            guard let object = value.objectValue else { continue }
            let type = object["type"]?.stringValue ?? "shape"
            let start = parentStart + max(0, object["start"]?.numberValue ?? 0)
            let duration = max(0, object["duration"]?.numberValue ?? .greatestFiniteMagnitude)
            guard object["visible"]?.boolValue ?? true,
                  time >= start,
                  time <= start + duration else { continue }

            let localTime = max(0, time - start)
            let transform = compose(parentTransform, readTransform(object["transform"]?.objectValue, at: localTime))
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

            let shape = object["shape"]?.objectValue ?? [:]
            let text = object["text"]?.objectValue
            let fill = shape["fill"]?.objectValue
            let effects = (object["effects"]?.arrayValue ?? []).compactMap {
                $0.objectValue?["type"]?.stringValue
            }
            let size = vector(shape["size"], fallback: ScenePoint(x: 200, y: 200))
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
                fillColor: fill?["color"]?.stringValue ?? shape["color"]?.stringValue,
                text: text?["content"]?.stringValue,
                fontSize: text?["fontSize"]?.numberValue,
                effects: effects
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
        let sorted = frames.compactMap { frame -> (Double, JSONValue)? in
            guard let item = frame.objectValue,
                  let frameTime = item["time"]?.numberValue,
                  frameTime.isFinite,
                  let frameValue = item["value"] else { return nil }
            return (frameTime, frameValue)
        }.sorted { $0.0 < $1.0 }
        guard let first = sorted.first else { return object["value"] }
        if time <= first.0 { return first.1 }
        guard let last = sorted.last else { return first.1 }
        if time >= last.0 { return last.1 }
        for index in 1..<sorted.count where time <= sorted[index].0 {
            let left = sorted[index - 1]
            let right = sorted[index]
            let span = right.0 - left.0
            let progress = span > 0 ? (time - left.0) / span : 0
            return interpolate(left.1, right.1, progress: progress)
        }
        return last.1
    }

    private static func interpolate(_ lhs: JSONValue, _ rhs: JSONValue, progress: Double) -> JSONValue {
        let t = progress.clamped(to: 0...1)
        switch (lhs, rhs) {
        case (.number(let a), .number(let b)):
            return .number(a + (b - a) * t)
        case (.array(let a), .array(let b)) where a.count == b.count:
            return .array(zip(a, b).map { pair in interpolate(pair.0, pair.1, progress: t) })
        default:
            return t < 1 ? lhs : rhs
        }
    }

    private static func vector(_ value: JSONValue?, fallback: ScenePoint) -> ScenePoint {
        guard let value else { return fallback }
        if let array = value.arrayValue, array.count >= 2,
           let x = array[0].numberValue, let y = array[1].numberValue {
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
