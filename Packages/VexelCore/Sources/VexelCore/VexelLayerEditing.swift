import Foundation

public enum VexelLayerEditing {
    public static let minimumDuration = 1.0 / 60.0

    public static func duplicate(
        _ layer: VexelLayer,
        takenIDs: Set<String>,
        newID: String,
        idFactory: (VexelLayerType) -> String
    ) -> VexelLayer {
        let copied = reassignIDs(layer, takenIDs: takenIDs, rootID: newID, idFactory: idFactory)
        return copied.withName(layer.name.map { $0.isEmpty ? "" : $0 + " copy" })
    }

    public static func split(
        _ layer: VexelLayer,
        at localTime: Double,
        takenIDs: Set<String>,
        newID: String,
        idFactory: (VexelLayerType) -> String
    ) -> (first: VexelLayer, second: VexelLayer)? {
        guard localTime.isFinite,
              localTime >= minimumDuration,
              localTime <= (layer.duration ?? 0) - minimumDuration else {
            return nil
        }

        let first = layer.withDuration(localTime).withTransitionOut(nil)
        let trimmed = trimStart(layer, by: localTime)
        let second = reassignIDs(
            trimmed,
            takenIDs: takenIDs,
            rootID: newID,
            idFactory: idFactory
        ).withTransitionIn(nil).withName(layer.name)
        return (first, second)
    }

    private static func trimStart(_ layer: VexelLayer, by requestedDelta: Double) -> VexelLayer {
        var delta = min(requestedDelta, (layer.duration ?? requestedDelta) - minimumDuration)
        let mediaKey = layer.type == .video ? "video" : (layer.type == .audio ? "audio" : nil)
        if let mediaKey,
           let media = layer.content?.objectValue,
           let sourceStart = media["sourceStart"]?.numberValue,
           (media["speed"]?.numberValue ?? 1) > 0 {
            let speed = media["speed"]?.numberValue ?? 1
            delta = max(delta, -sourceStart / speed)
        }

        var result = layer
        result.transform = layer.transform.map { shift($0, by: -delta) }
        result.transform3D = layer.transform3D.map { shift($0, by: -delta) }
        result.effects = layer.effects.map { effect in
            var copy = effect
            copy.parameters = effect.parameters.mapValues { shift($0, by: -delta) }
            return copy
        }
        result.masks = layer.masks.map { shift($0, by: -delta) }
        result.matte = layer.matte.map { shift($0, by: -delta) }
        result.transitionIn = layer.transitionIn.map { shift($0, by: -delta) }
        result.transitionOut = layer.transitionOut.map { shift($0, by: -delta) }
        result.content = layer.content.map { shift($0, by: -delta) }
        result.motionBlur = layer.motionBlur
        result.label = layer.label
        result.unknownFields = layer.unknownFields.mapValues { shift($0, by: -delta) }
        result.layers = layer.layers.map { child in
            var copy = child
            copy.start = (child.start ?? 0) - delta
            return copy
        }
        result.start = (layer.start ?? 0) + delta
        result.duration = (layer.duration ?? 0) - delta

        if let mediaKey, var media = result.content?.objectValue,
           let sourceStart = media["sourceStart"]?.numberValue {
            let speed = media["speed"]?.numberValue ?? 1
            media["sourceStart"] = .number(max(0, sourceStart + delta * speed))
            result.content = .object(media)
        }
        return result
    }

    private static func shift(_ transform: VexelTransform, by delta: Double) -> VexelTransform {
        var result = transform
        result.properties = transform.properties.mapValues { shift($0, by: delta) }
        result.unknownFields = transform.unknownFields.mapValues { shift($0, by: delta) }
        return result
    }

    private static func shift(_ value: VexelAnimatableValue, by delta: Double) -> VexelAnimatableValue {
        switch value {
        case .constant(let json):
            return .constant(shift(json, by: delta))
        case .animated(let track):
            var copy = track
            copy.keyframes = track.keyframes.map { frame in
                var shifted = frame
                shifted.time += delta
                shifted.value = shift(frame.value, by: delta)
                shifted.unknownFields = frame.unknownFields.mapValues { shift($0, by: delta) }
                return shifted
            }
            copy.loop = track.loop
            copy.unknownFields = track.unknownFields.mapValues { shift($0, by: delta) }
            return .animated(copy)
        }
    }

    private static func shift(_ value: JSONValue, by delta: Double) -> JSONValue {
        switch value {
        case .object(let object):
            var result: [String: JSONValue] = [:]
            for (key, child) in object {
                if key == "keyframes", let frames = child.arrayValue {
                    result[key] = .array(frames.map { frame in
                        guard var fields = frame.objectValue else { return shift(frame, by: delta) }
                        if let time = fields["time"]?.numberValue { fields["time"] = .number(time + delta) }
                        if let value = fields["value"] { fields["value"] = shift(value, by: delta) }
                        fields = fields.mapValues { shift($0, by: delta) }
                        if let time = frame.objectValue?["time"]?.numberValue {
                            fields["time"] = .number(time + delta)
                        }
                        return .object(fields)
                    })
                } else if key == "animators", let animators = child.arrayValue {
                    result[key] = .array(animators.map { animator in
                        guard var fields = animator.objectValue else { return shift(animator, by: delta) }
                        if let start = fields["start"]?.numberValue { fields["start"] = .number(start + delta) }
                        return .object(fields.mapValues { shift($0, by: delta) })
                    })
                } else {
                    result[key] = shift(child, by: delta)
                }
            }
            return .object(result)
        case .array(let values):
            return .array(values.map { shift($0, by: delta) })
        case .string, .number, .bool, .null:
            return value
        }
    }

    private static func reassignIDs(
        _ layer: VexelLayer,
        takenIDs: Set<String>,
        rootID: String,
        idFactory: (VexelLayerType) -> String
    ) -> VexelLayer {
        var used = takenIDs
        var mapping: [String: String] = [:]

        func assign(_ current: VexelLayer, forcedID: String?) {
            let identifier: String
            if let forcedID {
                precondition(!used.contains(forcedID), "The requested root ID must be unique.")
                identifier = forcedID
            } else {
                var candidate = idFactory(current.type)
                while used.contains(candidate) {
                    candidate = idFactory(current.type)
                }
                identifier = candidate
            }
            used.insert(identifier)
            mapping[current.id] = identifier
            current.layers.forEach { assign($0, forcedID: nil) }
        }
        assign(layer, forcedID: rootID)

        func rewrite(_ current: VexelLayer, isRoot: Bool) -> VexelLayer {
            var copy = current
            copy.id = mapping[current.id] ?? current.id
            if !isRoot {
                if let parent = current.parent { copy.parent = mapping[parent] ?? parent }
                if let matte = current.matte?.objectValue,
                   let target = matte["layer"]?.stringValue {
                    var remapped = matte
                    remapped["layer"] = .string(mapping[target] ?? target)
                    copy.matte = .object(remapped)
                }
            }
            copy.layers = current.layers.map { rewrite($0, isRoot: false) }
            return copy
        }
        return rewrite(layer, isRoot: true)
    }
}

private extension VexelLayer {
    func withName(_ value: String?) -> VexelLayer {
        var copy = self
        copy.name = value
        return copy
    }

    func withDuration(_ value: Double) -> VexelLayer {
        var copy = self
        copy.duration = value
        return copy
    }

    func withTransitionIn(_ value: JSONValue?) -> VexelLayer {
        var copy = self
        copy.transitionIn = value
        return copy
    }

    func withTransitionOut(_ value: JSONValue?) -> VexelLayer {
        var copy = self
        copy.transitionOut = value
        return copy
    }
}
