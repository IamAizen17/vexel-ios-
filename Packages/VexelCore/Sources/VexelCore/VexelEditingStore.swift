import Foundation

public enum VexelEditingCommand: Sendable {
    case renameProject(String)
    case setComposition(width: Int, height: Int, fps: Double, duration: Double)
    case addLayer(VexelLayer, containerID: String?, index: Int?)
    case removeLayer(id: String)
    case duplicateLayer(id: String, newID: String)
    case splitLayer(id: String, localTime: Double, newID: String)
    case groupLayers(firstID: String, secondID: String, groupID: String, name: String)
    case ungroupLayer(id: String)
    case moveLayer(id: String, toContainerID: String?, index: Int?)
    case renameLayer(id: String, name: String)
    case setLayerVisibility(id: String, visible: Bool)
    case setLayerLock(id: String, locked: Bool)
    case addEffect(layerID: String, effect: VexelEffect)
    case removeEffect(layerID: String, type: String)
    case setLayerTiming(id: String, start: Double, duration: Double)
    case setTransformValue(id: String, property: String, value: VexelAnimatableValue, is3D: Bool)
    case setKeyframe(layerID: String, property: String, keyframe: VexelKeyframe, is3D: Bool)
    case removeKeyframe(layerID: String, property: String, time: Double, is3D: Bool)
    case upsertMarker(VexelMarkerData)
    case removeMarker(id: String)
    case setParent(id: String, parentID: String?)
    case replaceSnapshot(VexelNativeProject)
}

public enum VexelEditingStoreError: Error, Equatable, Sendable {
    case layerNotFound(String)
    case containerNotFound(String)
    case containerIsNotGroup(String)
    case duplicateIdentifier(String)
    case invalidOperation(String)
    case invalidProject([ProjectIssue])
}

public actor VexelEditingStore {
    private var project: VexelNativeProject
    private var undoHistory: [VexelNativeProject] = []
    private var redoHistory: [VexelNativeProject] = []
    private let historyLimit: Int
    private var lastCoalescingKey: String?

    public init(project: VexelNativeProject, historyLimit: Int = 100) throws {
        let migratedDocument = try project.projectDocument().migratedToCurrentVersion()
        let migratedProject = try VexelNativeProject(document: migratedDocument)
        try Self.validate(migratedProject)
        self.project = migratedProject
        self.historyLimit = max(1, historyLimit)
    }

    public var canUndo: Bool { !undoHistory.isEmpty }
    public var canRedo: Bool { !redoHistory.isEmpty }

    public func snapshot() -> VexelNativeProject {
        project
    }

    public func execute(_ command: VexelEditingCommand, coalescingKey: String? = nil) throws {
        var candidate = project
        try Self.apply(command, to: &candidate)
        try Self.validate(candidate)
        guard candidate != project else {
            lastCoalescingKey = coalescingKey
            return
        }

        if coalescingKey == nil || coalescingKey != lastCoalescingKey {
            undoHistory.append(project)
            if undoHistory.count > historyLimit {
                undoHistory.removeFirst(undoHistory.count - historyLimit)
            }
        }
        project = candidate
        redoHistory.removeAll(keepingCapacity: true)
        lastCoalescingKey = coalescingKey
    }

    @discardableResult
    public func undo() -> Bool {
        guard let previous = undoHistory.popLast() else { return false }
        redoHistory.append(project)
        project = previous
        lastCoalescingKey = nil
        return true
    }

    @discardableResult
    public func redo() -> Bool {
        guard let next = redoHistory.popLast() else { return false }
        undoHistory.append(project)
        if undoHistory.count > historyLimit {
            undoHistory.removeFirst(undoHistory.count - historyLimit)
        }
        project = next
        lastCoalescingKey = nil
        return true
    }

    private static func validate(_ project: VexelNativeProject) throws {
        let document = try project.projectDocument()
        let errors = document.validate().filter { $0.severity == .error }
        guard errors.isEmpty else {
            throw VexelEditingStoreError.invalidProject(errors)
        }
    }

    private static func apply(_ command: VexelEditingCommand, to project: inout VexelNativeProject) throws {
        switch command {
        case .renameProject(let title):
            let value = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, value.count <= 256 else {
                throw VexelEditingStoreError.invalidOperation("Project title must contain 1 to 256 characters.")
            }
            project.meta["title"] = .string(value)

        case .setComposition(let width, let height, let fps, let duration):
            guard (16...8192).contains(width), (16...8192).contains(height),
                  fps.isFinite, (1...120).contains(fps),
                  duration.isFinite, (0.01...3600).contains(duration) else {
                throw VexelEditingStoreError.invalidOperation("Composition dimensions, frame rate, or duration are outside supported bounds.")
            }
            project.composition.width = width
            project.composition.height = height
            project.composition.fps = fps
            project.composition.duration = duration

        case .addLayer(let layer, let containerID, let index):
            let ids = allLayerIDs(in: project.layers)
            guard !ids.contains(layer.id) else {
                throw VexelEditingStoreError.duplicateIdentifier(layer.id)
            }
            let incomingIDs = allLayerIDs(in: [layer])
            guard incomingIDs.count == layerCount(in: [layer]) else {
                throw VexelEditingStoreError.invalidOperation("The inserted layer tree contains duplicate identifiers.")
            }
            if let duplicate = incomingIDs.first(where: ids.contains) {
                throw VexelEditingStoreError.duplicateIdentifier(duplicate)
            }
            try insert(layer, into: &project.layers, containerID: containerID, index: index)

        case .removeLayer(let id):
            guard let target = findLayer(id, in: project.layers) else {
                throw VexelEditingStoreError.layerNotFound(id)
            }
            let removedIDs = allLayerIDs(in: [target])
            guard !hasExternalReferences(to: removedIDs, in: project.layers, excluding: removedIDs) else {
                throw VexelEditingStoreError.invalidOperation("Remove or update layers that reference this layer before deleting it.")
            }
            guard removeLayer(id, from: &project.layers) != nil else {
                throw VexelEditingStoreError.layerNotFound(id)
            }

        case .duplicateLayer(let id, let newID):
            guard !allLayerIDs(in: project.layers).contains(newID) else {
                throw VexelEditingStoreError.duplicateIdentifier(newID)
            }
            guard let source = findLayer(id, in: project.layers) else {
                throw VexelEditingStoreError.layerNotFound(id)
            }
            let containerID = containerID(of: id, in: project.layers)
            let siblingIndex = siblingIndex(of: id, in: project.layers)
            var sequence = 0
            let copy = VexelLayerEditing.duplicate(
                source,
                takenIDs: allLayerIDs(in: project.layers),
                newID: newID,
                idFactory: { type in
                    sequence += 1
                    return VexelStableIdentifier.uuid(forSourceID: "\(newID):\(sequence):\(type.rawValue)").uuidString
                }
            )
            try insert(copy, into: &project.layers, containerID: containerID, index: siblingIndex.map { $0 + 1 })

        case .splitLayer(let id, let localTime, let newID):
            guard !allLayerIDs(in: project.layers).contains(newID) else {
                throw VexelEditingStoreError.duplicateIdentifier(newID)
            }
            guard let source = findLayer(id, in: project.layers) else {
                throw VexelEditingStoreError.layerNotFound(id)
            }
            var sequence = 0
            guard let split = VexelLayerEditing.split(
                source,
                at: localTime,
                takenIDs: allLayerIDs(in: project.layers),
                newID: newID,
                idFactory: { type in
                    sequence += 1
                    return VexelStableIdentifier.uuid(forSourceID: "\(newID):\(sequence):\(type.rawValue)").uuidString
                }
            ) else {
                throw VexelEditingStoreError.invalidOperation("The split point must leave at least one frame on both sides of the layer.")
            }
            let containerID = containerID(of: id, in: project.layers)
            let index = siblingIndex(of: id, in: project.layers)
            guard removeLayer(id, from: &project.layers) != nil else {
                throw VexelEditingStoreError.layerNotFound(id)
            }
            try insert(split.first, into: &project.layers, containerID: containerID, index: index)
            try insert(split.second, into: &project.layers, containerID: containerID, index: index.map { $0 + 1 })

        case .groupLayers(let firstID, let secondID, let groupID, let name):
            guard !allLayerIDs(in: project.layers).contains(groupID) else {
                throw VexelEditingStoreError.duplicateIdentifier(groupID)
            }
            guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name.count <= 256 else {
                throw VexelEditingStoreError.invalidOperation("Group names must contain 1 to 256 characters.")
            }
            guard let first = findLayer(firstID, in: project.layers) else {
                throw VexelEditingStoreError.layerNotFound(firstID)
            }
            guard let second = findLayer(secondID, in: project.layers) else {
                throw VexelEditingStoreError.layerNotFound(secondID)
            }
            let container = containerID(of: firstID, in: project.layers)
            guard container == containerID(of: secondID, in: project.layers),
                  let firstIndex = siblingIndex(of: firstID, in: project.layers),
                  let secondIndex = siblingIndex(of: secondID, in: project.layers),
                  secondIndex == firstIndex + 1 else {
                throw VexelEditingStoreError.invalidOperation("Only adjacent sibling layers can be grouped.")
            }
            let childIDs: Set<String> = [firstID, secondID]
            for child in [first, second] {
                if let parent = child.parent, !childIDs.contains(parent) {
                    throw VexelEditingStoreError.invalidOperation("Grouped layers cannot retain parent references outside the new group.")
                }
                if let matteID = child.matte?.objectValue?["layer"]?.stringValue, !childIDs.contains(matteID) {
                    throw VexelEditingStoreError.invalidOperation("Grouped layers cannot retain matte references outside the new group.")
                }
            }
            guard !hasExternalReferences(to: childIDs, in: project.layers, excluding: childIDs) else {
                throw VexelEditingStoreError.invalidOperation("Other layers reference one of the selected layers.")
            }
            let groupStart = min(first.start ?? 0, second.start ?? 0)
            let groupEnd = max((first.start ?? 0) + (first.duration ?? 0), (second.start ?? 0) + (second.duration ?? 0))
            guard groupEnd > groupStart else {
                throw VexelEditingStoreError.invalidOperation("The selected layers do not have a valid combined duration.")
            }
            var children = [first, second]
            for index in children.indices {
                children[index].start = (children[index].start ?? 0) - groupStart
            }
            let group = VexelLayer(
                id: groupID,
                type: .group,
                name: name,
                start: groupStart,
                duration: groupEnd - groupStart,
                layers: children
            )
            let inserted = updateContainer(container, in: &project.layers) { siblings in
                siblings.removeSubrange(firstIndex...secondIndex)
                siblings.insert(group, at: firstIndex)
            }
            guard inserted else {
                throw VexelEditingStoreError.containerNotFound(container ?? firstID)
            }

        case .ungroupLayer(let id):
            guard let group = findLayer(id, in: project.layers) else {
                throw VexelEditingStoreError.layerNotFound(id)
            }
            guard group.type == .group else {
                throw VexelEditingStoreError.invalidOperation("Only group layers can be ungrouped.")
            }
            let groupIDs = allLayerIDs(in: [group])
            guard !hasExternalReferences(to: [id], in: project.layers, excluding: groupIDs),
                  group.parent == nil, group.matte == nil else {
                throw VexelEditingStoreError.invalidOperation("The group has external parent, matte, or layer references.")
            }
            guard group.transform == nil, group.transform3D == nil, group.effects.isEmpty,
                  group.masks.isEmpty, group.transitionIn == nil, group.transitionOut == nil,
                  group.blendMode == nil, group.motionBlur == nil, group.label == nil,
                  group.content == nil, group.unknownFields.isEmpty else {
                throw VexelEditingStoreError.invalidOperation("Ungrouping would discard group-level properties.")
            }
            let container = containerID(of: id, in: project.layers)
            guard let index = siblingIndex(of: id, in: project.layers) else {
                throw VexelEditingStoreError.layerNotFound(id)
            }
            var promoted = group.layers
            for childIndex in promoted.indices {
                promoted[childIndex].start = (promoted[childIndex].start ?? 0) + (group.start ?? 0)
                if group.visible == false { promoted[childIndex].visible = false }
                if group.locked == true { promoted[childIndex].locked = true }
            }
            let replaced = updateContainer(container, in: &project.layers) { siblings in
                siblings.remove(at: index)
                siblings.insert(contentsOf: promoted, at: index)
            }
            guard replaced else {
                throw VexelEditingStoreError.containerNotFound(container ?? id)
            }

        case .moveLayer(let id, let toContainerID, let index):
            guard let source = findLayer(id, in: project.layers) else {
                throw VexelEditingStoreError.layerNotFound(id)
            }
            if let toContainerID, allLayerIDs(in: [source]).contains(toContainerID) {
                throw VexelEditingStoreError.invalidOperation("A group cannot be moved inside itself or one of its descendants.")
            }
            let oldContainer = containerID(of: id, in: project.layers)
            if oldContainer != toContainerID, (source.parent != nil || source.matte != nil) {
                throw VexelEditingStoreError.invalidOperation("A layer with sibling parent or matte references cannot move to another group.")
            }
            guard removeLayer(id, from: &project.layers) != nil else {
                throw VexelEditingStoreError.layerNotFound(id)
            }
            try insert(source, into: &project.layers, containerID: toContainerID, index: index)

        case .renameLayer(let id, let name):
            guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name.count <= 256 else {
                throw VexelEditingStoreError.invalidOperation("Layer names must contain 1 to 256 characters.")
            }
            guard updateLayer(id, in: &project.layers, { $0.name = name }) else {
                throw VexelEditingStoreError.layerNotFound(id)
            }

        case .setLayerVisibility(let id, let visible):
            guard updateLayer(id, in: &project.layers, { $0.visible = visible }) else {
                throw VexelEditingStoreError.layerNotFound(id)
            }

        case .setLayerLock(let id, let locked):
            guard updateLayer(id, in: &project.layers, { $0.locked = locked }) else {
                throw VexelEditingStoreError.layerNotFound(id)
            }

        case .addEffect(let layerID, let effect):
            guard updateLayer(layerID, in: &project.layers, { layer in
                if !layer.effects.contains(where: { $0.type == effect.type }) {
                    layer.effects.append(effect)
                }
            }) else {
                throw VexelEditingStoreError.layerNotFound(layerID)
            }

        case .removeEffect(let layerID, let type):
            guard updateLayer(layerID, in: &project.layers, { layer in
                layer.effects.removeAll { $0.type == type }
            }) else {
                throw VexelEditingStoreError.layerNotFound(layerID)
            }

        case .setLayerTiming(let id, let start, let duration):
            guard start.isFinite, duration.isFinite, duration > 0, duration <= 3600 else {
                throw VexelEditingStoreError.invalidOperation("Layer timing must be finite and duration must be between zero and one hour.")
            }
            guard updateLayer(id, in: &project.layers, {
                $0.start = start
                $0.duration = duration
            }) else {
                throw VexelEditingStoreError.layerNotFound(id)
            }

        case .setTransformValue(let id, let property, let value, let is3D):
            guard !property.isEmpty, property.count <= 64 else {
                throw VexelEditingStoreError.invalidOperation("Transform property names must contain 1 to 64 characters.")
            }
            guard let target = findLayer(id, in: project.layers) else {
                throw VexelEditingStoreError.layerNotFound(id)
            }
            guard is3D == is3DLayer(target) else {
                throw VexelEditingStoreError.invalidOperation("The selected transform space does not match the layer type.")
            }
            guard updateLayer(id, in: &project.layers, { layer in
                var transform = is3D ? (layer.transform3D ?? VexelTransform()) : (layer.transform ?? VexelTransform())
                transform.properties[property] = value
                if is3D {
                    layer.transform3D = transform
                } else {
                    layer.transform = transform
                }
            }) else {
                throw VexelEditingStoreError.layerNotFound(id)
            }

        case .setKeyframe(let layerID, let property, let keyframe, let is3D):
            guard !property.isEmpty, property.count <= 64,
                  keyframe.time.isFinite, keyframe.time >= 0 else {
                throw VexelEditingStoreError.invalidOperation("Keyframe property and time must be valid.")
            }
            guard let target = findLayer(layerID, in: project.layers) else {
                throw VexelEditingStoreError.layerNotFound(layerID)
            }
            guard is3D == is3DLayer(target) else {
                throw VexelEditingStoreError.invalidOperation("The selected transform space does not match the layer type.")
            }
            guard keyframe.time <= (target.duration ?? project.composition.duration) else {
                throw VexelEditingStoreError.invalidOperation("Keyframes must be within the layer duration.")
            }
            guard updateLayer(layerID, in: &project.layers, { layer in
                var transform = is3D ? (layer.transform3D ?? VexelTransform()) : (layer.transform ?? VexelTransform())
                let current = transform.properties[property]
                var animation: VexelAnimationTrack
                switch current {
                case .some(.animated(let existing)):
                    animation = existing
                case .some(.constant(let value)):
                    animation = VexelAnimationTrack(value: value)
                case .none:
                    animation = VexelAnimationTrack()
                }
                if let index = animation.keyframes.firstIndex(where: { abs($0.time - keyframe.time) < 0.000001 }) {
                    animation.keyframes[index] = keyframe
                } else {
                    animation.keyframes.append(keyframe)
                }
                animation.keyframes.sort { $0.time < $1.time }
                transform.properties[property] = .animated(animation)
                if is3D { layer.transform3D = transform } else { layer.transform = transform }
            }) else {
                throw VexelEditingStoreError.layerNotFound(layerID)
            }

        case .removeKeyframe(let layerID, let property, let time, let is3D):
            guard time.isFinite, time >= 0, !property.isEmpty else {
                throw VexelEditingStoreError.invalidOperation("Keyframe property and time must be valid.")
            }
            guard let target = findLayer(layerID, in: project.layers) else {
                throw VexelEditingStoreError.layerNotFound(layerID)
            }
            guard is3D == is3DLayer(target) else {
                throw VexelEditingStoreError.invalidOperation("The selected transform space does not match the layer type.")
            }
            guard updateLayer(layerID, in: &project.layers, { layer in
                var transform = is3D ? (layer.transform3D ?? VexelTransform()) : (layer.transform ?? VexelTransform())
                guard case .animated(var animation)? = transform.properties[property] else { return }
                animation.keyframes.removeAll { abs($0.time - time) < 0.000001 }
                if animation.keyframes.isEmpty, let value = animation.value {
                    transform.properties[property] = .constant(value)
                } else {
                    transform.properties[property] = .animated(animation)
                }
                if is3D { layer.transform3D = transform } else { layer.transform = transform }
            }) else {
                throw VexelEditingStoreError.layerNotFound(layerID)
            }

        case .upsertMarker(let marker):
            guard !marker.id.isEmpty, marker.id.count <= 256,
                  marker.time.isFinite, marker.time >= 0,
                  marker.time <= project.composition.duration,
                  (marker.name?.count ?? 0) <= 256 else {
                throw VexelEditingStoreError.invalidOperation("Marker identity, name, or time is outside supported bounds.")
            }
            if let index = project.markers.firstIndex(where: { $0.id == marker.id }) {
                project.markers[index] = marker
            } else {
                project.markers.append(marker)
            }
            project.markers.sort { $0.time < $1.time }

        case .removeMarker(let id):
            guard let index = project.markers.firstIndex(where: { $0.id == id }) else {
                throw VexelEditingStoreError.invalidOperation("Marker does not exist.")
            }
            project.markers.remove(at: index)

        case .replaceSnapshot(let snapshot):
            project = snapshot

        case .setParent(let id, let parentID):
            guard let layer = findLayer(id, in: project.layers) else {
                throw VexelEditingStoreError.layerNotFound(id)
            }
            guard let parentID else {
                guard updateLayer(id, in: &project.layers, { $0.parent = nil }) else {
                    throw VexelEditingStoreError.layerNotFound(id)
                }
                return
            }
            guard parentID != id else {
                throw VexelEditingStoreError.invalidOperation("A layer cannot parent itself.")
            }
            guard let parent = findLayer(parentID, in: project.layers) else {
                throw VexelEditingStoreError.layerNotFound(parentID)
            }
            guard containerID(of: id, in: project.layers) == containerID(of: parentID, in: project.layers) else {
                throw VexelEditingStoreError.invalidOperation("Parent and child must be siblings in the same group.")
            }
            guard is3DLayer(layer) == is3DLayer(parent),
                  ![VexelLayerType.audio, .camera, .light].contains(parent.type) else {
                throw VexelEditingStoreError.invalidOperation("Parent and child layer types are incompatible.")
            }
            var ancestorID: String? = parentID
            var visited = Set<String>()
            while let currentID = ancestorID {
                guard currentID != id, visited.insert(currentID).inserted else {
                    throw VexelEditingStoreError.invalidOperation("Parenting would create a hierarchy cycle.")
                }
                ancestorID = findLayer(currentID, in: project.layers)?.parent
            }
            guard updateLayer(id, in: &project.layers, { $0.parent = parentID }) else {
                throw VexelEditingStoreError.layerNotFound(id)
            }
        }
    }

    private static func insert(
        _ layer: VexelLayer,
        into layers: inout [VexelLayer],
        containerID: String?,
        index: Int?
    ) throws {
        guard let containerID else {
            let position = min(max(index ?? layers.count, 0), layers.count)
            layers.insert(layer, at: position)
            return
        }
        guard let container = findLayer(containerID, in: layers) else {
            throw VexelEditingStoreError.containerNotFound(containerID)
        }
        guard container.type == .group else {
            throw VexelEditingStoreError.containerIsNotGroup(containerID)
        }
        guard updateLayer(containerID, in: &layers, { group in
            let position = min(max(index ?? group.layers.count, 0), group.layers.count)
            group.layers.insert(layer, at: position)
        }) else {
            throw VexelEditingStoreError.containerNotFound(containerID)
        }
    }

    private static func updateContainer(
        _ containerID: String?,
        in layers: inout [VexelLayer],
        _ update: (inout [VexelLayer]) -> Void
    ) -> Bool {
        guard let containerID else {
            update(&layers)
            return true
        }
        return updateLayer(containerID, in: &layers) { group in
            guard group.type == .group else { return }
            update(&group.layers)
        }
    }

    private static func updateLayer(
        _ id: String,
        in layers: inout [VexelLayer],
        _ update: (inout VexelLayer) -> Void
    ) -> Bool {
        for index in layers.indices {
            if layers[index].id == id {
                update(&layers[index])
                return true
            }
            if updateLayer(id, in: &layers[index].layers, update) {
                return true
            }
        }
        return false
    }

    private static func findLayer(_ id: String, in layers: [VexelLayer]) -> VexelLayer? {
        for layer in layers {
            if layer.id == id { return layer }
            if let nested = findLayer(id, in: layer.layers) { return nested }
        }
        return nil
    }

    private static func removeLayer(_ id: String, from layers: inout [VexelLayer]) -> VexelLayer? {
        if let index = layers.firstIndex(where: { $0.id == id }) {
            return layers.remove(at: index)
        }
        for index in layers.indices {
            if let removed = removeLayer(id, from: &layers[index].layers) {
                return removed
            }
        }
        return nil
    }

    private static func containerID(of id: String, in layers: [VexelLayer], parentID: String? = nil) -> String? {
        for layer in layers {
            if layer.id == id { return parentID }
            if let nested = containerID(of: id, in: layer.layers, parentID: layer.id) {
                return nested
            }
        }
        return nil
    }

    private static func siblingIndex(of id: String, in layers: [VexelLayer]) -> Int? {
        if let index = layers.firstIndex(where: { $0.id == id }) { return index }
        for layer in layers {
            if let index = siblingIndex(of: id, in: layer.layers) { return index }
        }
        return nil
    }

    private static func allLayerIDs(in layers: [VexelLayer]) -> Set<String> {
        layers.reduce(into: Set<String>()) { result, layer in
            result.insert(layer.id)
            result.formUnion(allLayerIDs(in: layer.layers))
        }
    }

    private static func layerCount(in layers: [VexelLayer]) -> Int {
        layers.reduce(0) { $0 + 1 + layerCount(in: $1.layers) }
    }

    private static func hasExternalReferences(
        to ids: Set<String>,
        in layers: [VexelLayer],
        excluding excludedIDs: Set<String>
    ) -> Bool {
        for layer in layers {
            if !excludedIDs.contains(layer.id) {
                if let parent = layer.parent, ids.contains(parent) { return true }
                if let matteID = layer.matte?.objectValue?["layer"]?.stringValue, ids.contains(matteID) { return true }
            }
            if hasExternalReferences(to: ids, in: layer.layers, excluding: excludedIDs) {
                return true
            }
        }
        return false
    }

    private static func is3DLayer(_ layer: VexelLayer) -> Bool {
        if layer.type == .null,
           case .bool(let is3D)? = layer.content?.objectValue?["threeD"] {
            return is3D
        }
        return [.object3D, .model3D, .camera, .light].contains(layer.type)
    }
}
