import Foundation
import VexelCore

extension VexelProjectItem {
    init(document: ProjectDocument) {
        let composition = document.fields["composition"]?.objectValue ?? [:]
        let width = Int(composition["width"]?.numberValue ?? 1080)
        let height = Int(composition["height"]?.numberValue ?? 1920)
        let fps = Int(composition["fps"]?.numberValue ?? 30)
        let duration = composition["duration"]?.numberValue ?? 10
        self.init(title: document.title, width: width, height: height, fps: fps, duration: duration)
        documentJSON = String(data: (try? document.encoded()) ?? Data(), encoding: .utf8)
        assetsDirectory = nil
        timelineTracks = (document.fields["layers"]?.arrayValue ?? []).compactMap(Self.track(from:))
        layerNames = Self.flattenNames(timelineTracks)
        markers = (document.fields["markers"]?.arrayValue ?? []).compactMap { value in
            guard let object = value.objectValue else { return nil }
            return VexelMarker(
                id: UUID(),
                name: object["name"]?.stringValue ?? "Marker",
                time: object["time"]?.numberValue ?? 0,
                color: object["color"]?.stringValue ?? "Teal",
                sourceID: object["id"]?.stringValue
            )
        }
        modified = Date()
    }

    mutating func synchronizeDocument() {
        var document: ProjectDocument
        if let documentJSON, let data = documentJSON.data(using: .utf8), let existing = try? ProjectDocument(data: data) {
            document = existing
        } else {
            document = ProjectDocument.starter(title: title)
        }
        var fields = document.fields
        let documentFormat = fields["format"]?.stringValue ?? ProjectDocument.format
        fields["format"] = .string(documentFormat)
        if documentFormat != "knsproj" {
            fields["formatVersion"] = .number(Double(ProjectDocument.currentVersion))
        }
        fields["generator"] = .string("Vexel iOS")
        var meta = fields["meta"]?.objectValue ?? [:]
        meta["title"] = .string(title)
        meta["modifiedAt"] = .string(ISO8601DateFormatter().string(from: modified))
        fields["meta"] = .object(meta)
        var composition = fields["composition"]?.objectValue ?? [:]
        composition["width"] = .number(Double(width))
        composition["height"] = .number(Double(height))
        composition["fps"] = .number(Double(fps))
        composition["duration"] = .number(duration)
        fields["composition"] = .object(composition)

        let previous = Dictionary(
            (fields["layers"]?.arrayValue ?? []).compactMap { value -> (String, [String: JSONValue])? in
                guard let object = value.objectValue, let id = object["id"]?.stringValue else { return nil }
                return (id, object)
            },
            uniquingKeysWith: { first, _ in first }
        )
        fields["layers"] = .array(timelineTracks.map { Self.layerValue($0, previous: previous) })
        fields["markers"] = .array(markers.map { marker in
            .object([
                "id": .string(marker.sourceID ?? marker.id.uuidString),
                "time": .number(marker.time),
                "name": .string(marker.name),
                "color": .string(Self.hexColor(marker.color))
            ])
        })
        document = ProjectDocument(fields: fields)
        if let data = try? document.encoded(), let string = String(data: data, encoding: .utf8) {
            documentJSON = string
        }
    }

    func makeProjectDocument() throws -> ProjectDocument {
        if let documentJSON, let data = documentJSON.data(using: .utf8) {
            return try ProjectDocument(data: data)
        }
        var copy = self
        copy.synchronizeDocument()
        guard let json = copy.documentJSON, let data = json.data(using: .utf8) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return try ProjectDocument(data: data)
    }

    private static func track(from value: JSONValue) -> VexelTimelineTrack? {
        guard let object = value.objectValue,
              let sourceID = object["id"]?.stringValue else { return nil }
        let type = object["type"]?.stringValue ?? "shape"
        let kind: VexelTimelineTrack.Kind
        switch type {
        case "group": kind = .group
        case "text": kind = .text
        case "audio": kind = .audio
        case "object3d", "model3d": kind = .rendered3D
        default: kind = .visual
        }
        let children = (object["layers"]?.arrayValue ?? []).compactMap(Self.track(from:))
        let effects = (object["effects"]?.arrayValue ?? []).compactMap { $0.objectValue?["type"]?.stringValue }
        var animatableFields = object
        animatableFields.removeValue(forKey: "layers")
        let keyframes = Self.keyframeTimes(in: .object(animatableFields)).sorted()
        let sourceJSON = (try? JSONEncoder().encode(value)).flatMap { String(data: $0, encoding: .utf8) }
        let stableID = UUID(uuidString: sourceID) ?? UUID()
        return VexelTimelineTrack(
            id: stableID,
            name: object["name"]?.stringValue ?? (type.capitalized + " Layer"),
            start: object["start"]?.numberValue ?? 0,
            duration: object["duration"]?.numberValue ?? 5,
            kind: kind,
            visible: object["visible"]?.boolValue ?? true,
            locked: object["locked"]?.boolValue ?? false,
            isGroup: type == "group",
            isExpanded: true,
            children: children,
            keyframes: keyframes,
            effects: effects,
            sourceID: sourceID,
            sourceType: type,
            sourceJSON: sourceJSON
        )
    }

    private static func flattenNames(_ tracks: [VexelTimelineTrack]) -> [String] {
        tracks.flatMap { [$0.name] + flattenNames($0.children) }
    }

    private static func layerValue(
        _ track: VexelTimelineTrack,
        previous: [String: [String: JSONValue]]
    ) -> JSONValue {
        let id = track.sourceID ?? track.id.uuidString
        let fallbackObject: [String: JSONValue] = {
            guard let data = track.sourceJSON?.data(using: .utf8),
                  let value = try? JSONDecoder().decode(JSONValue.self, from: data) else { return [:] }
            return value.objectValue ?? [:]
        }()
        var object = previous[id] ?? fallbackObject
        let previousKeyframes = keyframeTimes(in: .object(object))
        let type: String
        if let sourceType = track.sourceType {
            type = sourceType
        } else {
            switch track.kind {
            case .group: type = "group"
            case .text: type = "text"
            case .audio: type = "audio"
            case .rendered3D: type = "object3d"
            case .visual: type = "shape"
            }
        }
        object["id"] = .string(id)
        object["type"] = .string(type)
        object["name"] = .string(track.name)
        object["start"] = .number(track.start)
        object["duration"] = .number(max(track.duration, 1.0 / 120.0))
        object["visible"] = .bool(track.visible)
        object["locked"] = .bool(track.locked)
        if object["transform"] == nil {
            object["transform"] = .object([
                "position": .array([.number(0), .number(0)]),
                "scale": .array([.number(1), .number(1)]),
                "rotation": .number(0),
                "opacity": .number(1)
            ])
        }
        switch track.kind {
        case .group:
            object["layers"] = .array(track.children.map { layerValue($0, previous: previous) })
        case .text:
            if object["text"] == nil {
                object["text"] = .object(["content": .string(track.name), "fontSize": .number(64), "color": .string("#FFFFFF")])
            }
        case .audio:
            if object["audio"] == nil {
                object["audio"] = .object([:])
            }
        case .rendered3D:
            if object["object3d"] == nil {
                object["object3d"] = .object(["primitive": .string("cube"), "size": .number(200)])
            }
        case .visual:
            if object["shape"] == nil {
                object["shape"] = .object([
                    "kind": .string("rectangle"),
                    "size": .array([.number(400), .number(400)]),
                    "fill": .object(["color": .string("#55CDBE")])
                ])
            }
        }
        let oldEffects = Dictionary(
            (object["effects"]?.arrayValue ?? []).compactMap { item -> (String, JSONValue)? in
                guard let value = item.objectValue, let type = value["type"]?.stringValue else { return nil }
                return (type, item)
            },
            uniquingKeysWith: { first, _ in first }
        )
        object["effects"] = .array(track.effects.map { oldEffects[$0] ?? .object(["type": .string($0), "params": .object([:])]) })
        let addedKeyframes = Set(track.keyframes.filter { $0.isFinite && $0 >= 0 }).subtracting(previousKeyframes)
        if !addedKeyframes.isEmpty {
            applyPositionKeyframes(addedKeyframes.sorted(), to: &object)
        }
        return .object(object)
    }

    private static func keyframeTimes(in value: JSONValue) -> Set<Double> {
        switch value {
        case .object(let object):
            var result = Set<Double>()
            if let frames = object["keyframes"]?.arrayValue {
                for frame in frames {
                    if let time = frame.objectValue?["time"]?.numberValue, time.isFinite, time >= 0 {
                        result.insert(time)
                    }
                }
            }
            for child in object.values { result.formUnion(keyframeTimes(in: child)) }
            return result
        case .array(let values):
            return values.reduce(into: Set<Double>()) { $0.formUnion(keyframeTimes(in: $1)) }
        default:
            return []
        }
    }

    private static func applyPositionKeyframes(_ times: [Double], to object: inout [String: JSONValue]) {
        var transform = object["transform"]?.objectValue ?? [:]
        let existing = transform["position"] ?? .array([.number(0), .number(0)])
        var animation = existing.objectValue ?? [:]
        let staticValue = animation["value"] ?? existing
        var frames = animation["keyframes"]?.arrayValue ?? []
        if frames.isEmpty {
            frames = [
                .object(["time": .number(0), "value": staticValue])
            ]
        }
        var known = Set(frames.compactMap { $0.objectValue?["time"]?.numberValue })
        for time in times where known.insert(time).inserted {
            let prior = frames
                .filter { ($0.objectValue?["time"]?.numberValue ?? .infinity) <= time }
                .max { ($0.objectValue?["time"]?.numberValue ?? 0) < ($1.objectValue?["time"]?.numberValue ?? 0) }
            let value = prior?.objectValue?["value"] ?? staticValue
            frames.append(.object([
                "time": .number(time),
                "value": value,
                "easing": .string("linear")
            ]))
        }
        frames.sort { ($0.objectValue?["time"]?.numberValue ?? 0) < ($1.objectValue?["time"]?.numberValue ?? 0) }
        animation["keyframes"] = .array(frames)
        animation.removeValue(forKey: "value")
        transform["position"] = .object(animation)
        object["transform"] = .object(transform)
    }

    private static func hexColor(_ name: String) -> String {
        switch name.lowercased() {
        case "pink", "red": return "#FF7894"
        case "amber", "yellow": return "#F5C66B"
        case "blue": return "#79B9FF"
        default: return "#55CDBE"
        }
    }
}

private extension JSONValue {
    var boolValue: Bool? {
        guard case .bool(let value) = self else { return nil }
        return value
    }
}
