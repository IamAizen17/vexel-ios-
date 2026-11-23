import Foundation

public struct TimelineTimebase: Equatable, Sendable {
    public let framesPerSecond: Double
    public let duration: Double

    public init(framesPerSecond: Double, duration: Double) throws {
        guard framesPerSecond.isFinite, (1...120).contains(framesPerSecond),
              duration.isFinite, duration > 0, duration <= 3600 else {
            throw TimelineError.invalidTimebase
        }
        self.framesPerSecond = framesPerSecond
        self.duration = duration
    }

    public var frameCount: Int {
        max(1, Int((duration * framesPerSecond).rounded()))
    }

    public func frameTime(_ frame: Int) -> Double {
        Double(frame) / framesPerSecond
    }

    public func frame(at time: Double) -> Int {
        Int((time * framesPerSecond).rounded())
    }

    public func snap(_ time: Double) -> Double {
        frameTime(frame(at: time))
    }

    public func clamped(_ time: Double) -> Double {
        min(max(time, 0), duration)
    }

    public func timecode(_ time: Double) -> String {
        let frameNumber = max(0, frame(at: time))
        let nominalRate = max(1, Int(framesPerSecond.rounded()))
        let seconds = Int(floor(Double(frameNumber) / framesPerSecond))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let wholeSeconds = seconds % 60
        let frameInSecond = frameNumber - Int((Double(seconds) * framesPerSecond).rounded())
        return String(format: "%02d:%02d:%02d:%02d", hours, minutes, wholeSeconds, max(0, min(nominalRate - 1, frameInSecond)))
    }
}

public enum TimelineError: Error, Equatable, LocalizedError {
    case invalidTimebase
    case invalidLayer
    case layerNotFound(String)
    case duplicateLayerID(String)
    case invalidContainer(String)
    case layersMustBeSiblings
    case groupRequired(String)
    case invalidTime
    case invalidIndex
    case invalidProject(String)

    public var errorDescription: String? {
        switch self {
        case .invalidTimebase: return "The composition frame rate or duration is invalid."
        case .invalidLayer: return "A timeline layer must be a JSON object with a non-empty id and type."
        case .layerNotFound(let id): return "Timeline layer '(id)' does not exist."
        case .duplicateLayerID(let id): return "Timeline layer ID '(id)' is already in use."
        case .invalidContainer(let id): return "Timeline container '(id)' does not exist."
        case .layersMustBeSiblings: return "The selected layers must belong to the same timeline container."
        case .groupRequired(let id): return "Timeline container '(id)' is not a group."
        case .invalidTime: return "Timeline time must be a finite number."
        case .invalidIndex: return "The requested timeline index is invalid."
        case .invalidProject(let reason): return "The timeline operation would make the project invalid: (reason)"
        }
    }
}

public actor TimelineEngine {
    private var project: ProjectDocument
    private var undoStack: [ProjectDocument] = []
    private var redoStack: [ProjectDocument] = []
    private let historyLimit: Int

    public init(project: ProjectDocument, historyLimit: Int = 200) {
        self.project = project
        self.historyLimit = max(1, historyLimit)
    }

    public func snapshot() -> ProjectDocument { project }
    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    public func undo() -> ProjectDocument {
        guard let previous = undoStack.popLast() else { return project }
        redoStack.append(project)
        project = previous
        return project
    }

    public func redo() -> ProjectDocument {
        guard let next = redoStack.popLast() else { return project }
        undoStack.append(project)
        project = next
        return project
    }

    public func addLayer(_ layer: JSONValue, toGroup groupID: String? = nil, at index: Int? = nil) throws -> ProjectDocument {
        guard let object = layer.objectValue,
              let id = object["id"]?.stringValue, !id.isEmpty,
              object["type"]?.stringValue != nil else {
            throw TimelineError.invalidLayer
        }
        guard !allIDs().contains(id) else { throw TimelineError.duplicateLayerID(id) }

        var next = project
        let current = container(in: next, groupID: groupID)
        let insertionIndex = index ?? current.count
        guard insertionIndex >= 0, insertionIndex <= current.count else { throw TimelineError.invalidIndex }
        try replaceContainer(in: &next, groupID: groupID) { layers in
            var result = layers
            result.insert(layer, at: insertionIndex)
            return result
        }
        return try commit(next)
    }

    public func moveLayer(_ id: String, to start: Double) throws -> ProjectDocument {
        guard start.isFinite else { throw TimelineError.invalidTime }
        guard contains(id) else { throw TimelineError.layerNotFound(id) }
        let next = updateLayer(project, id: id) { object in
            object["start"] = .number(start)
        }
        return try commit(next)
    }

    public func setVisibility(_ id: String, visible: Bool) throws -> ProjectDocument {
        try updateExistingLayer(id) { $0["visible"] = .bool(visible) }
    }

    public func setLocked(_ id: String, locked: Bool) throws -> ProjectDocument {
        try updateExistingLayer(id) { $0["locked"] = .bool(locked) }
    }

    public func setDuration(_ id: String, duration: Double) throws -> ProjectDocument {
        guard duration.isFinite, duration > 0 else { throw TimelineError.invalidTime }
        return try updateExistingLayer(id) { $0["duration"] = .number(duration) }
    }

    public func reorderLayer(_ id: String, to destinationIndex: Int) throws -> ProjectDocument {
        guard let location = locate(id, in: project.fields["layers"]?.arrayValue ?? []) else {
            throw TimelineError.layerNotFound(id)
        }
        var next = project
        let siblings = container(in: next, groupID: location.containerID)
        guard destinationIndex >= 0, destinationIndex < siblings.count else {
            throw TimelineError.invalidIndex
        }
        try replaceContainer(in: &next, groupID: location.containerID) { layers in
            var result = layers
            let layer = result.remove(at: location.index)
            result.insert(layer, at: min(destinationIndex, result.count))
            return result
        }
        return try commit(next)
    }

    public func deleteLayers(_ ids: Set<String>) throws -> ProjectDocument {
        guard !ids.isEmpty else { return project }
        let existing = allIDs()
        guard let missing = ids.first(where: { !existing.contains($0) }) else {
            var next = project
            next.fields["layers"] = .array(removeAndClean(project.fields["layers"]?.arrayValue ?? [], ids: ids))
            return try commit(next)
        }
        throw TimelineError.layerNotFound(missing)
    }

    public func duplicateLayer(_ id: String) throws -> ProjectDocument {
        guard let original = findLayer(id, in: project.fields["layers"]?.arrayValue ?? []) else {
            throw TimelineError.layerNotFound(id)
        }
        guard let location = locate(id, in: project.fields["layers"]?.arrayValue ?? []) else {
            throw TimelineError.layerNotFound(id)
        }

        var idMap: [String: String] = [:]
        collectIDs(original, into: &idMap)
        let duplicate = remapLayer(original, idMap: idMap, root: true)
        var next = project
        try replaceContainer(in: &next, groupID: location.containerID) { layers in
            var result = layers
            result.insert(duplicate, at: location.index + 1)
            return result
        }
        return try commit(next)
    }

    public func groupLayers(_ ids: Set<String>, id groupID: String, name: String = "Group") throws -> ProjectDocument {
        guard !ids.isEmpty else { throw TimelineError.invalidLayer }
        guard !allIDs().contains(groupID) else { throw TimelineError.duplicateLayerID(groupID) }
        let rootLayers = project.fields["layers"]?.arrayValue ?? []
        let locations = ids.compactMap { locate($0, in: rootLayers) }
        guard locations.count == ids.count else {
            let missing = ids.first { locate($0, in: rootLayers) == nil } ?? ""
            throw TimelineError.layerNotFound(missing)
        }
        guard let containerID = locations.first?.containerID,
              locations.allSatisfy({ $0.containerID == containerID }) else {
            throw TimelineError.layersMustBeSiblings
        }

        let siblings = container(in: project, groupID: containerID)
        let selected = siblings.filter { ids.contains($0.objectValue?["id"]?.stringValue ?? "") }
        let start = selected.compactMap { $0.objectValue?["start"]?.numberValue }.min() ?? 0
        let end = selected.map { layer -> Double in
            let object = layer.objectValue ?? [:]
            return (object["start"]?.numberValue ?? 0) + (object["duration"]?.numberValue ?? 5)
        }.max() ?? (start + 5)
        let children = selected.map { layer -> JSONValue in
            guard var object = layer.objectValue else { return layer }
            object["start"] = .number((object["start"]?.numberValue ?? 0) - start)
            if let parent = object["parent"]?.stringValue, !ids.contains(parent) {
                object.removeValue(forKey: "parent")
            }
            if let matte = object["matte"]?.objectValue,
               let matteID = matte["layer"]?.stringValue, !ids.contains(matteID) {
                object.removeValue(forKey: "matte")
            }
            return .object(object)
        }
        let group: JSONValue = .object([
            "id": .string(groupID),
            "type": .string("group"),
            "name": .string(name),
            "start": .number(start),
            "duration": .number(max(1.0 / 60.0, end - start)),
            "layers": .array(children)
        ])
        let firstIndex = locations.map(\.index).min() ?? 0
        var next = project
        try replaceContainer(in: &next, groupID: containerID) { layers in
            var remaining = layers.enumerated().compactMap { index, layer -> JSONValue? in
                guard !ids.contains(layer.objectValue?["id"]?.stringValue ?? "") else { return nil }
                guard var object = layer.objectValue else { return layer }
                if let parent = object["parent"]?.stringValue, ids.contains(parent) {
                    object.removeValue(forKey: "parent")
                }
                if let matte = object["matte"]?.objectValue,
                   let matteID = matte["layer"]?.stringValue, ids.contains(matteID) {
                    object.removeValue(forKey: "matte")
                }
                return .object(object)
            }
            remaining.insert(group, at: min(firstIndex, remaining.count))
            return remaining
        }
        return try commit(next)
    }

    public func ungroup(_ groupID: String) throws -> ProjectDocument {
        guard let location = locate(groupID, in: project.fields["layers"]?.arrayValue ?? []),
              let group = findLayer(groupID, in: project.fields["layers"]?.arrayValue ?? []),
              let object = group.objectValue,
              object["type"]?.stringValue == "group" else {
            throw TimelineError.groupRequired(groupID)
        }
        let offset = object["start"]?.numberValue ?? 0
        let children = (object["layers"]?.arrayValue ?? []).map { child -> JSONValue in
            guard var childObject = child.objectValue else { return child }
            childObject["start"] = .number((childObject["start"]?.numberValue ?? 0) + offset)
            return .object(childObject)
        }
        var next = project
        try replaceContainer(in: &next, groupID: location.containerID) { layers in
            var result = layers
            result.remove(at: location.index)
            result.insert(contentsOf: children, at: location.index)
            return result
        }
        return try commit(next)
    }

    private func updateExistingLayer(_ id: String, update: (inout [String: JSONValue]) -> Void) throws -> ProjectDocument {
        guard contains(id) else { throw TimelineError.layerNotFound(id) }
        let next = updateLayer(project, id: id, update: update)
        return try commit(next)
    }

    private func commit(_ next: ProjectDocument) throws -> ProjectDocument {
        if let issue = next.validate().first(where: { $0.severity == .error }) {
            throw TimelineError.invalidProject(issue.message)
        }
        guard next != project else { return project }
        undoStack.append(project)
        if undoStack.count > historyLimit { undoStack.removeFirst(undoStack.count - historyLimit) }
        redoStack.removeAll(keepingCapacity: true)
        project = next
        return project
    }

    private func contains(_ id: String) -> Bool {
        findLayer(id, in: project.fields["layers"]?.arrayValue ?? []) != nil
    }

    private func allIDs() -> Set<String> {
        var result = Set<String>()
        func walk(_ layers: [JSONValue]) {
            for layer in layers {
                guard let object = layer.objectValue else { continue }
                if let id = object["id"]?.stringValue { result.insert(id) }
                walk(object["layers"]?.arrayValue ?? [])
            }
        }
        walk(project.fields["layers"]?.arrayValue ?? [])
        return result
    }

    private func container(in document: ProjectDocument, groupID: String?) -> [JSONValue] {
        guard let groupID else { return document.fields["layers"]?.arrayValue ?? [] }
        guard let group = findLayer(groupID, in: document.fields["layers"]?.arrayValue ?? []),
              group.objectValue?["type"]?.stringValue == "group" else { return [] }
        return group.objectValue?["layers"]?.arrayValue ?? []
    }

    private func replaceContainer(
        in document: inout ProjectDocument,
        groupID: String?,
        transform: ([JSONValue]) -> [JSONValue]
    ) throws {
        guard let groupID else {
            document.fields["layers"] = .array(transform(document.fields["layers"]?.arrayValue ?? []))
            return
        }
        guard containsInDocument(groupID, document: document) else { throw TimelineError.invalidContainer(groupID) }
        document = updateLayer(document, id: groupID) { object in
            guard object["type"]?.stringValue == "group" else { return }
            object["layers"] = .array(transform(object["layers"]?.arrayValue ?? []))
        }
    }

    private func containsInDocument(_ id: String, document: ProjectDocument) -> Bool {
        findLayer(id, in: document.fields["layers"]?.arrayValue ?? []) != nil
    }

    private func findLayer(_ id: String, in layers: [JSONValue]) -> JSONValue? {
        for layer in layers {
            guard let object = layer.objectValue else { continue }
            if object["id"]?.stringValue == id { return layer }
            if let nested = findLayer(id, in: object["layers"]?.arrayValue ?? []) { return nested }
        }
        return nil
    }

    private func locate(_ id: String, in layers: [JSONValue], containerID: String? = nil) -> (containerID: String?, index: Int)? {
        for (index, layer) in layers.enumerated() {
            guard let object = layer.objectValue else { continue }
            if object["id"]?.stringValue == id { return (containerID, index) }
            if object["type"]?.stringValue == "group",
               let nested = locate(id, in: object["layers"]?.arrayValue ?? [], containerID: object["id"]?.stringValue) {
                return nested
            }
        }
        return nil
    }

    private func updateLayer(
        _ document: ProjectDocument,
        id: String,
        update: (inout [String: JSONValue]) -> Void
    ) -> ProjectDocument {
        func walk(_ layers: [JSONValue]) -> [JSONValue] {
            layers.map { layer in
                guard var object = layer.objectValue else { return layer }
                if object["id"]?.stringValue == id {
                    update(&object)
                    return .object(object)
                }
                if let children = object["layers"]?.arrayValue {
                    object["layers"] = .array(walk(children))
                    return .object(object)
                }
                return layer
            }
        }
        var result = document
        result.fields["layers"] = .array(walk(document.fields["layers"]?.arrayValue ?? []))
        return result
    }

    private func removeAndClean(_ layers: [JSONValue], ids: Set<String>) -> [JSONValue] {
        layers.compactMap { layer in
            guard var object = layer.objectValue else { return layer }
            if let id = object["id"]?.stringValue, ids.contains(id) { return nil }
            if let parent = object["parent"]?.stringValue, ids.contains(parent) {
                object.removeValue(forKey: "parent")
            }
            if let matte = object["matte"]?.objectValue,
               let matteID = matte["layer"]?.stringValue, ids.contains(matteID) {
                object.removeValue(forKey: "matte")
            }
            if let children = object["layers"]?.arrayValue {
                object["layers"] = .array(removeAndClean(children, ids: ids))
            }
            return .object(object)
        }
    }

    private func collectIDs(_ layer: JSONValue, into map: inout [String: String]) {
        guard let object = layer.objectValue else { return }
        if let id = object["id"]?.stringValue {
            map[id] = "layer_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(10).lowercased())"
        }
        for child in object["layers"]?.arrayValue ?? [] {
            collectIDs(child, into: &map)
        }
    }

    private func remapLayer(_ layer: JSONValue, idMap: [String: String], root: Bool) -> JSONValue {
        guard var object = layer.objectValue else { return layer }
        if let oldID = object["id"]?.stringValue, let newID = idMap[oldID] {
            object["id"] = .string(newID)
        }
        if root, let name = object["name"]?.stringValue, !name.isEmpty {
            object["name"] = .string("\(name) copy")
        }
        if let parent = object["parent"]?.stringValue, let mapped = idMap[parent] {
            object["parent"] = .string(mapped)
        }
        if let matte = object["matte"]?.objectValue,
           let matteID = matte["layer"]?.stringValue,
           let mapped = idMap[matteID] {
            var updated = matte
            updated["layer"] = .string(mapped)
            object["matte"] = .object(updated)
        }
        if let children = object["layers"]?.arrayValue {
            object["layers"] = .array(children.map { remapLayer($0, idMap: idMap, root: false) })
        }
        return .object(object)
    }
}
