import SwiftUI
import PhotosUI
import VexelCore
import UniformTypeIdentifiers
import AVFoundation

enum VexelEditorTool: String, CaseIterable, Identifiable {
    case layers = "Layers", shapes = "Shapes", text = "Text", media = "Media", model3D = "3D"
    case effects = "Effects", motion = "Motion", audio = "Audio", camera = "Camera", captions = "Captions"
    case elements = "Elements", plugins = "Plugins"

    var id: String { rawValue }
    var isAvailable: Bool {
        switch self {
        case .layers, .shapes, .text, .effects, .motion: return true
        case .media, .audio: return true
        case .model3D, .camera, .captions, .elements, .plugins: return false
        }
    }
    var symbol: String {
        switch self {
        case .layers: return "square.3.layers.3d"
        case .shapes: return "shapes"
        case .text: return "textformat"
        case .media: return "photo.on.rectangle"
        case .model3D: return "cube"
        case .effects: return "sparkles"
        case .motion: return "point.topleft.down.to.point.bottomright.curvepath"
        case .audio: return "waveform"
        case .camera: return "camera"
        case .captions: return "captions.bubble"
        case .elements: return "square.grid.2x2"
        case .plugins: return "puzzlepiece.extension"
        }
    }
}

struct VexelEditorWorkspace: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State var project: VexelProjectItem
    let onClose: () -> Void
    let onProjectChange: (VexelProjectItem) -> Void

    @State private var selectedTool: VexelEditorTool?
    @State private var activeDockTool: VexelEditorTool?
    @State private var selectedLayer = 0
    @State private var selectedTab = "Transform"
    @State private var showExport = false
    @State private var showCompositionSettings = false
    @State private var showSavedVersions = false
    @State private var showGraph = false
    @State private var showCurve = false
    @State private var isPlaying = false
    @State private var currentTime = 0.0
    @State private var showRename = false
    @State private var renameDraft = ""
    @State private var timelineDraftTracks: [VexelTimelineTrack] = []
    @State private var timelineDraftMarkers: [VexelMarker] = []
    @State private var canUndoEdits = false
    @State private var canRedoEdits = false
    @State private var editingStore: VexelEditingStore?
    @State private var editingCommandTask: Task<Void, Never>?
    @State private var showingMediaPicker = false
    @State private var showingAudioPicker = false
    @State private var showingNotice: String?
    @State private var layerNames: [String] = []
    @State private var showProperties = false
    @State private var showStabilization = false
    @State private var showCutoutBrush = false
    @State private var showCameraControls = false
    @State private var showMediaJob = false
    @State private var editingMarker: VexelMarker?
    @State private var selectedTrackID: UUID?
    @State private var loopPlayback = false
    @State private var isTimelineGestureActive = false
    @StateObject private var audioPlayback = VexelAudioPlaybackEngine()

    private var selectedTimelineTrack: VexelTimelineTrack? {
        func find(_ values: [VexelTimelineTrack]) -> VexelTimelineTrack? {
            for track in values {
                if track.id == selectedTrackID { return track }
                if let nested = find(track.children) { return nested }
            }
            return nil
        }
        return find(project.timelineTracks)
    }

    private var selectedNativeLayer: VexelLayer? {
        guard let track = selectedTimelineTrack,
              let sourceID = track.sourceID ?? selectedTrackID?.uuidString,
              let native = try? VexelNativeProject(document: project.makeProjectDocument()) else { return nil }
        func find(_ layers: [VexelLayer]) -> VexelLayer? {
            for layer in layers {
                if layer.id == sourceID { return layer }
                if let nested = find(layer.layers) { return nested }
            }
            return nil
        }
        return find(native.layers)
    }

    private var selectedPropertyDescriptors: [VexelPropertyDescriptor] {
        guard let layer = selectedNativeLayer else { return [] }
        return VexelPropertyCatalog.descriptors(for: layer)
    }

    private var selectedKeyframesByProperty: [String: [VexelKeyframe]] {
        guard let layer = selectedNativeLayer else { return [:] }
        return Dictionary(uniqueKeysWithValues: selectedPropertyDescriptors.map { descriptor in
            let frames: [VexelKeyframe]
            if case .animated(let animation)? = descriptor.value(in: layer) {
                frames = animation.keyframes
            } else {
                frames = []
            }
            return (descriptor.id, frames)
        })
    }

    private var keyframeLocalPlayheadTime: Double {
        guard let track = selectedTimelineTrack else { return 0 }
        let rate = Double(max(project.fps, 1))
        return (currentTime * rate).rounded() / rate - track.start
    }

    private var availablePropertyTabs: [String] {
        guard let kind = selectedTimelineTrack?.kind else { return ["Composition"] }
        var tabs = ["Transform"]
        if kind == .text { tabs.append("Text") }
        if kind != .audio { tabs.append("Effects") }
        if kind == .visual || kind == .text || kind == .group { tabs.append("Masks") }
        if kind != .audio { tabs.append("Transitions") }
        return tabs
    }

    private func propertyEditTimeIfAnimated(_ propertyID: String) -> Double? {
        guard let layer = selectedNativeLayer,
              let descriptor = VexelPropertyCatalog.descriptor(for: propertyID),
              case .some(.animated(_)) = descriptor.value(in: layer) else { return nil }
        return keyframeLocalPlayheadTime
    }

    private func commitSelectedPosition(x: Double, y: Double) {
        guard let track = selectedTimelineTrack,
              let sourceID = track.sourceID ?? selectedTrackID?.uuidString else { return }
        let is3D = track.kind == .rendered3D
        let propertyID = is3D ? "position3D" : "position"
        let vector: [JSONValue] = is3D
            ? [.number(x), .number(y), .number(selectedPosition.count > 2 ? selectedPosition[2] : 0)]
            : [.number(x), .number(y)]
        performEditingCommand(.setPropertyValue(
            layerID: sourceID,
            propertyID: propertyID,
            value: .array(vector),
            atTime: propertyEditTimeIfAnimated(propertyID)
        ))
    }

    private var selectedPosition: [Double] {
        guard let track = selectedTimelineTrack,
              let sourceID = track.sourceID ?? selectedTrackID?.uuidString,
              let native = try? VexelNativeProject(document: project.makeProjectDocument()) else {
            return [0, 0]
        }
        func findLayer(_ layers: [VexelLayer]) -> VexelLayer? {
            for layer in layers {
                if layer.id == sourceID { return layer }
                if let nested = findLayer(layer.layers) { return nested }
            }
            return nil
        }
        guard let layer = findLayer(native.layers) else { return [0, 0] }
        let transform = track.kind == .rendered3D ? layer.transform3D : layer.transform
        let property = transform?.properties["position"]
        let value: JSONValue?
        switch property {
        case .some(.constant(let constant)):
            value = constant
        case .some(.animated(let animation)):
            value = animation.value ?? animation.keyframes.first?.value
        case .none:
            value = nil
        }
        guard let components = value?.arrayValue else { return [0, 0] }
        let numbers = components.compactMap(\.numberValue)
        return numbers.count >= 2 ? numbers : [0, 0]
    }

    private var selectedTransformValues: [String: [Double]] {
        let is3D = selectedTimelineTrack?.kind == .rendered3D
        let defaults: [String: [Double]] = [
            "anchor": is3D ? [0, 0, 0] : [0, 0],
            "scale": is3D ? [1, 1, 1] : [1, 1],
            "rotation": is3D ? [0, 0, 0] : [0],
            "opacity": [1]
        ]
        guard let track = selectedTimelineTrack,
              let sourceID = track.sourceID ?? selectedTrackID?.uuidString,
              let native = try? VexelNativeProject(document: project.makeProjectDocument()) else { return defaults }
        func findLayer(_ layers: [VexelLayer]) -> VexelLayer? {
            for layer in layers {
                if layer.id == sourceID { return layer }
                if let nested = findLayer(layer.layers) { return nested }
            }
            return nil
        }
        guard let layer = findLayer(native.layers) else { return defaults }
        let transform = is3D ? layer.transform3D : layer.transform
        var values = defaults
        for property in defaults.keys {
            let value: JSONValue?
            switch transform?.properties[property] {
            case .some(.constant(let constant)): value = constant
            case .some(.animated(let animation)): value = animation.value ?? animation.keyframes.first?.value
            case .none: value = nil
            }
            if let number = value?.numberValue {
                values[property] = [number]
            } else if let components = value?.arrayValue {
                let numbers = components.compactMap(\.numberValue)
                if numbers.count == defaults[property]?.count { values[property] = numbers }
            }
        }
        return values
    }

    private func commitSelectedTransform(property: String, values: [Double]) {
        guard let track = selectedTimelineTrack,
              let sourceID = track.sourceID ?? selectedTrackID?.uuidString,
              !values.isEmpty, values.allSatisfy(\.isFinite) else { return }
        let is3D = track.kind == .rendered3D
        let propertyID = is3D ? "\(property)3D" : property
        let value: JSONValue
        if property == "opacity" || (property == "rotation" && !is3D) {
            value = .number(values[0])
        } else {
            value = .array(values.map { .number($0) })
        }
        performEditingCommand(.setPropertyValue(
            layerID: sourceID,
            propertyID: propertyID,
            value: value,
            atTime: propertyEditTimeIfAnimated(propertyID)
        ))
    }

    private var selectedTextValues: [String: JSONValue] {
        let defaults: [String: JSONValue] = [
            "content": .string("Text"),
            "fontFamily": .string("sans-serif"),
            "fontWeight": .number(700),
            "fontItalic": .bool(false),
            "fontSize": .number(96),
            "lineHeight": .number(1.2),
            "letterSpacing": .number(0),
            "alignment": .string("center")
        ]
        guard let track = selectedTimelineTrack, track.kind == .text,
              let sourceID = track.sourceID ?? selectedTrackID?.uuidString,
              let native = try? VexelNativeProject(document: project.makeProjectDocument()) else { return defaults }
        func findLayer(_ layers: [VexelLayer]) -> VexelLayer? {
            for layer in layers {
                if layer.id == sourceID { return layer }
                if let nested = findLayer(layer.layers) { return nested }
            }
            return nil
        }
        guard let layer = findLayer(native.layers),
              let object = layer.content?.objectValue else { return defaults }
        let fields = VexelObjectFields(object)
        let font = fields.object("font") ?? VexelObjectFields()
        func baseValue(_ key: String, fallback: JSONValue) -> JSONValue {
            switch fields.animatable(key) {
            case .some(.constant(let value)): return value
            case .some(.animated(let animation)):
                return animation.value ?? animation.keyframes.first?.value ?? fallback
            case .none: return fallback
            }
        }
        return [
            "content": .string(fields.string("content") ?? "Text"),
            "fontFamily": .string(font.string("family") ?? "sans-serif"),
            "fontWeight": .number(Double(font.integer("weight") ?? 700)),
            "fontItalic": .bool(font.bool("italic") ?? false),
            "fontSize": baseValue("fontSize", fallback: .number(96)),
            "lineHeight": .number(fields.number("lineHeight") ?? 1.2),
            "letterSpacing": baseValue("letterSpacing", fallback: .number(0)),
            "alignment": .string(fields.string("align") ?? "center")
        ]
    }

    private func commitSelectedTextProperty(property: VexelTextProperty, value: JSONValue) {
        guard let track = selectedTimelineTrack, track.kind == .text,
              let sourceID = track.sourceID ?? selectedTrackID?.uuidString else { return }
        let descriptorID: String?
        switch property {
        case .fontSize: descriptorID = "text.fontSize"
        case .letterSpacing: descriptorID = "text.letterSpacing"
        default: descriptorID = nil
        }
        if let descriptorID {
            performEditingCommand(.setPropertyValue(
                layerID: sourceID,
                propertyID: descriptorID,
                value: value,
                atTime: propertyEditTimeIfAnimated(descriptorID)
            ))
        } else {
            performEditingCommand(.setTextProperty(id: sourceID, property: property, value: value))
        }
    }

    private var isWide: Bool { horizontalSizeClass == .regular }
    private var isCompactLandscape: Bool { horizontalSizeClass == .compact && verticalSizeClass == .compact }
    private var inspectorWidth: CGFloat { 300 }

    var body: some View {
        VStack(spacing: 0) {
            editorHeader
            if isWide {
                HStack(spacing: 14) {
                    VStack(spacing: 0) {
                        previewCanvas
                        transportBar
                        timelinePanel
                        if !layerNames.isEmpty { selectionBar }
                        toolBar
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    inspectorPanel.frame(width: inspectorWidth)
                }
                .padding(14)
            } else if isCompactLandscape {
                HStack(spacing: 8) {
                    VStack(spacing: 0) {
                        previewCanvas
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        transportBar
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    VStack(spacing: 0) {
                        timelinePanel
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        if !layerNames.isEmpty { selectionBar }
                        toolBar
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(8)
            } else {
                previewCanvas
                    .frame(maxHeight: .infinity)
                transportBar
                timelinePanel
                if !layerNames.isEmpty { selectionBar }
                toolBar
            }
        }
        .vexelScreenBackground()
        .sheet(item: $selectedTool) { tool in
            VexelToolSheet(
                tool: tool,
                layerNames: $layerNames,
                selectedLayerName: selectedTimelineTrack?.name,
                selectedLayerKind: selectedTimelineTrack?.kind,
                onAction: { action in handleToolAction(action, for: tool) },
                onGraph: { showGraph = true },
                onCurve: { showCurve = true }
            )
            .presentationDetents(tool == .layers || tool == .effects || tool == .plugins ? [.large] : [.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showExport) { VexelExportSheet(project: project) .presentationDetents([.medium, .large]) }
        .sheet(isPresented: $showCompositionSettings) {
            CompositionSettingsSheet(
                project: project,
                onSavedVersions: { showSavedVersions = true },
                onSave: { draft in
                    performEditingCommand(
                        .updateProjectSettings(
                            title: draft.title,
                            width: draft.width,
                            height: draft.height,
                            fps: Double(draft.fps),
                            duration: draft.duration
                        ),
                        onSuccess: {
                            VexelCompositionDefaults(
                                width: draft.width,
                                height: draft.height,
                                fps: draft.fps,
                                duration: draft.duration
                            ).save()
                        }
                    )
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showSavedVersions) { VexelSavedVersionsSheet().presentationDetents([.medium, .large]) }
        .sheet(isPresented: $showGraph) {
            VexelGraphEditor(
                descriptors: selectedPropertyDescriptors,
                keyframesByProperty: selectedKeyframesByProperty,
                playheadTime: keyframeLocalPlayheadTime,
                onAddKeyframe: { addKeyframeAtPlayhead(propertyID: $0) },
                onRemoveKeyframe: { removeKeyframeAtPlayhead(propertyID: $0) }
            )
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showCurve) { VexelCurveEditor() .presentationDetents([.large]) }
        .sheet(isPresented: $showProperties) {
            VexelPropertiesSheet(
                layerName: selectedTimelineTrack?.name ?? "Composition",
                layerKind: selectedTimelineTrack?.kind,
                onAddEffect: { showProperties = false; selectedTool = .effects },
                effectIDs: selectedTimelineTrack?.effects ?? [],
                onRemoveEffect: { removeEffect($0) },
                position: selectedPosition,
                onPositionCommit: { x, y in commitSelectedPosition(x: x, y: y) },
                transformValues: selectedTransformValues,
                onTransformCommit: { property, values in commitSelectedTransform(property: property, values: values) },
                textValues: selectedTextValues,
                onTextCommit: { property, value in commitSelectedTextProperty(property: property, value: value) }
            )
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showStabilization) { VexelStabilizationSheet().presentationDetents([.medium, .large]) }
        .sheet(isPresented: $showCutoutBrush) { VexelCutoutBrushWorkspace().presentationDetents([.large]) }
        .sheet(isPresented: $showCameraControls) { VexelCameraWorkspace().presentationDetents([.large]) }
        .sheet(isPresented: $showMediaJob) { VexelMediaJobSheet(title: "Media analysis").presentationDetents([.medium, .large]) }
        .sheet(item: $editingMarker) { marker in
            VexelMarkerSheet(marker: marker) { updated in
                saveMarker(updated)
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingMediaPicker) {
            MediaPicker { item in
                Task { await importPickedMedia(item) }
            }
        }
        .fileImporter(isPresented: $showingAudioPicker, allowedContentTypes: [.audio], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task { await importAudioFile(url) }
            case .failure(let error):
                showingNotice = error.localizedDescription
            }
        }
        .alert("Rename composition", isPresented: $showRename) {
            TextField("Name", text: $renameDraft)
            Button("Cancel", role: .cancel) {}
            Button("Save") { performEditingCommand(.renameProject(renameDraft)) }
        }
        .alert("Editor", isPresented: Binding(get: { showingNotice != nil }, set: { if !$0 { showingNotice = nil } })) {
            Button("OK", role: .cancel) { showingNotice = nil }
        } message: { Text(showingNotice ?? "") }
        .onAppear {
            layerNames = flattenTrackNames(project.timelineTracks)
            timelineDraftTracks = project.timelineTracks
            timelineDraftMarkers = project.markers
            if selectedTrackID == nil { selectedTrackID = project.timelineTracks.first?.id }
            resetEditingStoreFromWorkspace()
        }
        .onChange(of: selectedTrackID) { _ in selectedTab = "Transform" }
        .onChange(of: showRename) { showing in if showing { renameDraft = project.title } }
        .onChange(of: project) { updated in
            guard !isTimelineGestureActive else { return }
            timelineDraftTracks = updated.timelineTracks
            timelineDraftMarkers = updated.markers
            layerNames = flattenTrackNames(updated.timelineTracks)
        }
        .task(id: isPlaying) {
            guard isPlaying else {
                audioPlayback.stop()
                return
            }
            do {
                try audioPlayback.play(project: project, from: currentTime)
            } catch {
                showingNotice = "Audio playback failed: \(error.localizedDescription)"
            }
            defer { audioPlayback.stop() }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 33_333_333)
                guard !Task.isCancelled else { break }
                let nextTime = currentTime + 1.0 / Double(max(project.fps, 1))
                if nextTime >= project.duration {
                    if loopPlayback {
                        currentTime = 0
                        do { try audioPlayback.play(project: project, from: 0) }
                        catch { showingNotice = "Audio loop failed: \(error.localizedDescription)" }
                    } else {
                        currentTime = project.duration
                        isPlaying = false
                    }
                } else {
                    currentTime = nextTime
                }
            }
        }
        .onDisappear { audioPlayback.stop() }
    }

    private var editorHeader: some View {
        HStack(spacing: 9) {
            VexelIconButton(symbol: "chevron.left") { onClose() }
            VStack(alignment: .leading, spacing: 3) {
                Text(project.title).font(.system(size: 13, weight: .bold)).foregroundStyle(VexelPalette.text).lineLimit(1)
                Text("\(project.width) × \(project.height) · \(project.fps) FPS")
                    .font(.system(size: 9, design: .monospaced)).foregroundStyle(VexelPalette.secondary)
            }
            .contentShape(Rectangle()).onTapGesture { showRename = true }
            Spacer(minLength: 4)
            VexelIconButton(symbol: "arrow.uturn.backward", disabled: !canUndoEdits) { undoEdit() }
            VexelIconButton(symbol: "arrow.uturn.forward", disabled: !canRedoEdits) { redoEdit() }
            VexelIconButton(symbol: "slider.horizontal.3") { showCompositionSettings = true }
                .accessibilityIdentifier("editor.composition.settings")
            VexelIconButton(symbol: "square.and.arrow.up", active: true) { showExport = true }
        }
        .padding(.horizontal, isCompactLandscape ? 8 : 12)
        .padding(.vertical, isCompactLandscape ? 4 : 9)
        .background(VexelPalette.bar)
        .overlay(alignment: .bottom) { Rectangle().fill(VexelPalette.line).frame(height: 1) }
    }

    private var previewCanvas: some View {
        VStack(spacing: 8) {
            HStack {
                VexelSectionLabel(title: "Preview", trailing: "FIT")
                Spacer()
                Text("00:00:00:\(String(format: "%02d", Int(currentTime * Double(project.fps)) % max(project.fps, 1)))")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(VexelPalette.accent)
            }
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(VexelPalette.preview)
                if layerNames.isEmpty {
                    VexelEmptyState(symbol: "viewfinder", title: "Your canvas is empty", detail: "Add text or shapes from the tool shelf below.")
                } else {
                    VexelScenePreview(project: project, time: currentTime)
                        .padding(8)
                    VStack {
                        HStack {
                            Text("LIVE 2D PREVIEW").font(.system(size: 8, weight: .bold)).tracking(1.2)
                            Spacer()
                            Text("\(project.width) × \(project.height)").font(.system(size: 8, weight: .semibold, design: .monospaced))
                        }
                        Spacer()
                        HStack {
                            Text("CPU SCENE EVALUATOR").font(.system(size: 8, weight: .medium)).tracking(0.5)
                            Spacer()
                            Image(systemName: "viewfinder")
                        }
                    }
                    .foregroundStyle(VexelPalette.secondary.opacity(0.9))
                    .padding(14)
                    .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityIdentifier("editor.preview")
        .padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 8)
    }

    private var transportBar: some View {
        HStack(spacing: 10) {
            VexelIconButton(symbol: "backward.end.fill") { currentTime = 0 }
            VexelIconButton(symbol: "gobackward.5") { currentTime = max(0, currentTime - 5) }
            Button { isPlaying.toggle() } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(Color.black)
                    .frame(width: 38, height: 38).background(VexelPalette.accent, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("editor.playback.toggle")
            VexelIconButton(symbol: "goforward.5") { currentTime = min(project.duration, currentTime + 5) }
            VexelIconButton(symbol: "repeat", active: loopPlayback) { loopPlayback.toggle() }
            VexelIconButton(symbol: "bookmark") {
                if let marker = project.markers.first(where: { abs($0.time - currentTime) <= 0.5 / Double(max(project.fps, 1)) }) {
                    editingMarker = marker
                } else {
                    editingMarker = VexelMarker(time: currentTime)
                }
            }
            Spacer()
            Text(String(format: "%.2f s", currentTime))
                .font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(VexelPalette.accent)
        }
        .padding(.horizontal, 14).padding(.vertical, isCompactLandscape ? 2 : 7)
        .background(VexelPalette.bar.opacity(0.8))
    }

    private var timelinePanel: some View {
        VexelTimelinePanel(
            tracks: $timelineDraftTracks,
            currentTime: $currentTime,
            markers: $timelineDraftMarkers,
            selectedTrackID: $selectedTrackID,
            duration: project.duration,
            fps: project.fps,
            compact: isCompactLandscape,
            onMarkerEdit: { editingMarker = $0 },
            onNotice: { showingNotice = $0 },
            onGraph: {
                guard !selectedPropertyDescriptors.isEmpty else {
                    showingNotice = "Select a layer with supported properties before opening the graph editor."
                    return
                }
                showGraph = true
            },
            onTrackTimingCommit: { trackID, start, duration in
                guard let sourceID = sourceLayerID(for: trackID) else {
                    showingNotice = "The edited timeline layer could not be resolved."
                    return
                }
                performEditingCommand(
                    .setLayerTiming(id: sourceID, start: start, duration: duration),
                )
            },
            onTrackVisibilityChange: { trackID, visible in
                guard let sourceID = sourceLayerID(for: trackID) else { return }
                performEditingCommand(
                    .setLayerVisibility(id: sourceID, visible: visible),
                )
            },
            onTrackLockChange: { trackID, locked in
                guard let sourceID = sourceLayerID(for: trackID) else { return }
                performEditingCommand(
                    .setLayerLock(id: sourceID, locked: locked),
                )
            },
            onEditBegan: {
                audioPlayback.stop()
                isTimelineGestureActive = true
            },
            onEditEnded: {
                isTimelineGestureActive = false
                commitTimelineDraftChanges()
                if isPlaying {
                    do { try audioPlayback.play(project: project, from: currentTime) }
                    catch { showingNotice = "Audio playback failed: \(error.localizedDescription)" }
                }
            }
        )
    }

    private func commitTimelineDraftChanges() {
        func sourceID(_ track: VexelTimelineTrack) -> String {
            track.sourceID ?? track.id.uuidString
        }
        func commitOrderChanges(
            from previous: [VexelTimelineTrack],
            to updated: [VexelTimelineTrack],
            containerID: String?
        ) {
            let oldIDs = previous.map(sourceID)
            let newIDs = updated.map(sourceID)
            if oldIDs != newIDs, Set(oldIDs) == Set(newIDs) {
                performEditingCommand(.reorderLayers(containerID: containerID, orderedIDs: newIDs))
            }
            for track in updated where !track.children.isEmpty {
                guard let previousGroup = previous.first(where: { sourceID($0) == sourceID(track) }) else { continue }
                commitOrderChanges(from: previousGroup.children, to: track.children, containerID: sourceID(track))
            }
        }
        commitOrderChanges(from: project.timelineTracks, to: timelineDraftTracks, containerID: nil)

        let previousMarkers = Dictionary(
            project.markers.map { ($0.sourceID ?? $0.id.uuidString, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let updatedMarkers = Dictionary(
            timelineDraftMarkers.map { ($0.sourceID ?? $0.id.uuidString, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for (id, marker) in updatedMarkers {
            if let previous = previousMarkers[id],
               previous.time == marker.time, previous.name == marker.name, previous.color == marker.color {
                continue
            }
            saveMarker(marker)
        }
        for id in previousMarkers.keys where updatedMarkers[id] == nil {
            performEditingCommand(.removeMarker(id: id))
        }
    }

    private func flattenTrackNames(_ tracks: [VexelTimelineTrack]) -> [String] {
        tracks.flatMap { [$0.name] + flattenTrackNames($0.children) }
    }

    private var selectionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 15) {
                actionItem("Layers", symbol: "square.3.layers.3d") { selectedTool = .layers }
                actionItem("Properties", symbol: "slider.horizontal.3") { showProperties = true }
                actionItem("Keyframe", symbol: "diamond.fill") { addKeyframeAtPlayhead() }
                actionItem("Split", symbol: "scissors") { splitSelectedTrack() }
                actionItem("Group", symbol: "square.3.layers.3d") { groupSelectedWithNextTrack() }
                actionItem("Duplicate", symbol: "plus.square.on.square") { duplicateSelectedTrack() }
                Menu {
                    Button {} label: { Label("Audio controls (unavailable)", systemImage: "waveform") }.disabled(true)
                    Button {} label: { Label("Extract audio (unavailable)", systemImage: "waveform.badge.plus") }.disabled(true)
                    Button {} label: { Label("Remove background (unavailable)", systemImage: "person.crop.rectangle") }.disabled(true)
                    Button {} label: { Label("Stabilize (unavailable)", systemImage: "scope") }.disabled(true)
                    Button {} label: { Label("Cutout brush (unavailable)", systemImage: "scribble.variable") }.disabled(true)
                    Button {} label: { Label("Camera controls (unavailable)", systemImage: "camera.aperture") }.disabled(true)
                    Button { loopPlayback.toggle() } label: { Label("Loop playback", systemImage: "repeat") }
                } label: {
                    Label("More", systemImage: "ellipsis.circle").font(.system(size: 10, weight: .semibold))
                }
                actionItem("Delete", symbol: "trash", tint: VexelPalette.pink) { deleteSelectedTrack() }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
        }
        .foregroundStyle(VexelPalette.soft)
        .background(VexelPalette.bar)
    }

    private func actionItem(_ title: String, symbol: String, tint: Color = VexelPalette.soft, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tint)
                .fixedSize()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("editor.action.\(title.lowercased())")
    }

    private var toolBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: isCompactLandscape ? 3 : 4) {
                ForEach(VexelEditorTool.allCases.filter(\.isAvailable)) { tool in
                    Button {
                        activeDockTool = tool
                        selectedTool = tool
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: tool.symbol).font(.system(size: isCompactLandscape ? 14 : 16, weight: .medium))
                            Text(tool.rawValue).font(.system(size: isCompactLandscape ? 7 : 8, weight: .semibold))
                        }
                        .foregroundStyle(activeDockTool == tool ? VexelPalette.accent : VexelPalette.soft)
                        .frame(width: isCompactLandscape ? 50 : 57, height: isCompactLandscape ? 36 : 54)
                        .background(activeDockTool == tool ? VexelPalette.accent.opacity(0.12) : VexelPalette.field.opacity(0.55), in: RoundedRectangle(cornerRadius: 9))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(activeDockTool == tool ? VexelPalette.accent.opacity(0.55) : VexelPalette.line.opacity(0.35), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("editor.tool.\(tool.rawValue.lowercased())")
                    .disabled(!tool.isAvailable)
                    .opacity(tool.isAvailable ? 1 : 0.38)
                }
            }
            .padding(.horizontal, 8).padding(.vertical, isCompactLandscape ? 3 : 8)
        }
        .background(VexelPalette.bar)
    }

    private var inspectorPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VexelSectionLabel(title: "Inspector")
                Spacer()
                VexelIconButton(symbol: "point.topleft.down.to.point.bottomright.curvepath", disabled: selectedPropertyDescriptors.isEmpty) { showGraph = true }
                    .accessibilityIdentifier("inspector.graph")
            }
            Picker("Inspector", selection: $selectedTab) {
                ForEach(availablePropertyTabs, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu).tint(VexelPalette.accent)
            VexelPropertiesPanel(
                tab: selectedTab,
                layerName: selectedTimelineTrack?.name ?? "Composition",
                layerKind: selectedTimelineTrack?.kind,
                onCurve: { showCurve = true },
                onAddEffect: { selectedTool = .effects },
                effectIDs: selectedTimelineTrack?.effects ?? [],
                onRemoveEffect: { removeEffect($0) },
                position: selectedPosition,
                onPositionCommit: { x, y in commitSelectedPosition(x: x, y: y) },
                transformValues: selectedTransformValues,
                onTransformCommit: { property, values in commitSelectedTransform(property: property, values: values) },
                textValues: selectedTextValues,
                onTextCommit: { property, value in commitSelectedTextProperty(property: property, value: value) }
            )
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(VexelPalette.sheet, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityIdentifier("editor.inspector")
    }

    private func resetEditingStoreFromWorkspace() {
        do {
            let document = try project.makeProjectDocument()
            let nativeProject = try VexelNativeProject(document: document)
            editingStore = try VexelEditingStore(project: nativeProject)
        } catch {
            editingStore = nil
            canUndoEdits = false
            canRedoEdits = false
            showingNotice = "The editing engine could not synchronize this project: \(error.localizedDescription)"
        }
        if let store = editingStore {
            Task { @MainActor in
                canUndoEdits = await store.canUndo
                canRedoEdits = await store.canRedo
            }
        }
    }

    private func performEditingCommand(
        _ command: VexelEditingCommand,
        selecting sourceID: String? = nil,
        onFailure: (() -> Void)? = nil,
        onSuccess: (() -> Void)? = nil
    ) {
        guard let store = editingStore else {
            showingNotice = "The editing engine is unavailable. Reopen the project and try again."
            return
        }
        let previousTask = editingCommandTask
        editingCommandTask = Task { @MainActor in
            await previousTask?.value
            do {
                try await store.execute(command)
                let nativeProject = await store.snapshot()
                let document = try nativeProject.projectDocument()
                var updated = VexelProjectItem(document: document)
                updated.id = project.id
                updated.assetsDirectory = project.assetsDirectory
                updated.modified = Date()
                updated.layerNames = flattenTrackNames(updated.timelineTracks)
                project = updated
                layerNames = updated.layerNames
                if let sourceID {
                    selectedTrackID = VexelStableIdentifier.uuid(forSourceID: sourceID)
                }
                canUndoEdits = await store.canUndo
                canRedoEdits = await store.canRedo
                onProjectChange(updated)
                onSuccess?()
            } catch {
                onFailure?()
                showingNotice = error.localizedDescription
            }
        }
    }

    private func sourceLayerID(for trackID: UUID) -> String? {
        func find(_ tracks: [VexelTimelineTrack]) -> VexelTimelineTrack? {
            for track in tracks {
                if track.id == trackID { return track }
                if let nested = find(track.children) { return nested }
            }
            return nil
        }
        guard let track = find(project.timelineTracks) else { return nil }
        return track.sourceID ?? track.id.uuidString
    }

    private func undoEdit() {
        guard let store = editingStore else { return }
        let previousTask = editingCommandTask
        editingCommandTask = Task { @MainActor in
            await previousTask?.value
            guard await store.undo() else { return }
            await applyStoreSnapshot(store)
        }
    }

    private func redoEdit() {
        guard let store = editingStore else { return }
        let previousTask = editingCommandTask
        editingCommandTask = Task { @MainActor in
            await previousTask?.value
            guard await store.redo() else { return }
            await applyStoreSnapshot(store)
        }
    }

    @MainActor
    private func applyStoreSnapshot(_ store: VexelEditingStore) async {
        do {
            let snapshot = await store.snapshot()
            let document = try snapshot.projectDocument()
            var updated = VexelProjectItem(document: document)
            updated.id = project.id
            updated.assetsDirectory = project.assetsDirectory
            updated.modified = Date()
            updated.layerNames = flattenTrackNames(updated.timelineTracks)
            project = updated
            layerNames = updated.layerNames
            selectedTrackID = updated.timelineTracks.first?.id
            canUndoEdits = await store.canUndo
            canRedoEdits = await store.canRedo
            onProjectChange(updated)
        } catch {
            showingNotice = "The editing history could not be restored: \(error.localizedDescription)"
        }
    }

    private func addLayer(named name: String, kind: VexelTimelineTrack.Kind) {
        let resolvedName = uniqueLayerName(name)
        let id = UUID().uuidString
        let type: VexelLayerType
        let content: JSONValue
        switch kind {
        case .text:
            type = .text
            content = .object([
                "content": .string(resolvedName),
                "fontSize": .number(64),
                "color": .string("#FFFFFF")
            ])
        case .audio:
            type = .audio
            content = .object([:])
        case .group:
            type = .group
            content = .object([:])
        case .rendered3D:
            type = .object3D
            content = .object(["primitive": .string("cube"), "size": .number(200)])
        case .visual:
            type = .shape
            content = .object([
                "kind": .string("rectangle"),
                "size": .array([.number(400), .number(400)]),
                "fill": .object(["color": .string("#55CDBE")])
            ])
        }
        let layer = VexelLayer(
            id: id,
            type: type,
            name: resolvedName,
            start: 0,
            duration: project.duration,
            visible: true,
            locked: false,
            content: content
        )
        performEditingCommand(.addLayer(layer, containerID: nil, index: 0), selecting: id)
    }

    private func uniqueLayerName(_ base: String) -> String {
        guard layerNames.contains(base) else { return base }
        var suffix = 2
        while layerNames.contains("\(base) \(suffix)") { suffix += 1 }
        return "\(base) \(suffix)"
    }

    private func cloneTrack(_ source: VexelTimelineTrack, name: String? = nil, start: Double? = nil, duration: Double? = nil, locked: Bool? = nil) -> VexelTimelineTrack {
        VexelTimelineTrack(
            name: name ?? source.name,
            start: start ?? source.start,
            duration: duration ?? source.duration,
            kind: source.kind,
            visible: source.visible,
            locked: locked ?? source.locked,
            isGroup: source.isGroup,
            isExpanded: source.isExpanded,
            children: source.children.map { cloneTrack($0) },
            keyframes: source.keyframes,
            effects: source.effects,
            sourceType: source.sourceType,
            sourceJSON: source.sourceJSON
        )
    }

    private func selectedTopLevelIndex() -> Int? {
        guard let selectedTrackID else { return nil }
        return project.timelineTracks.firstIndex { $0.id == selectedTrackID }
    }

    private func duplicateSelectedTrack() {
        guard let selectedTimelineTrack else {
            showingNotice = "Select a timeline layer to duplicate."
            return
        }
        let sourceID = selectedTimelineTrack.sourceID ?? selectedTimelineTrack.id.uuidString
        let duplicateID = UUID().uuidString
        performEditingCommand(.duplicateLayer(id: sourceID, newID: duplicateID), selecting: duplicateID)
    }

    private func deleteSelectedTrack() {
        guard let selectedTimelineTrack else {
            showingNotice = "Select a timeline layer to delete."
            return
        }
        let sourceID = selectedTimelineTrack.sourceID ?? selectedTimelineTrack.id.uuidString
        performEditingCommand(.removeLayer(id: sourceID))
    }

    private func addKeyframeAtPlayhead(propertyID requestedPropertyID: String? = nil) {
        guard let track = selectedTimelineTrack,
              let sourceID = track.sourceID ?? selectedTrackID?.uuidString,
              let layer = selectedNativeLayer else {
            showingNotice = "Select a supported layer before adding a keyframe."
            return
        }
        let propertyID = requestedPropertyID ?? (track.kind == .rendered3D ? "position3D" : "position")
        guard let descriptor = VexelPropertyCatalog.descriptor(for: propertyID),
              descriptor.supports(layer) else {
            showingNotice = "That property is not supported by the selected layer."
            return
        }
        let rate = Double(max(project.fps, 1))
        let frameTime = (currentTime * rate).rounded() / rate
        let localTime = frameTime - track.start
        guard localTime >= 0, localTime <= track.duration else {
            showingNotice = "Move the playhead inside the selected layer before adding a keyframe."
            return
        }
        let value: JSONValue
        switch descriptor.value(in: layer) {
        case .some(.constant(let current)):
            value = current
        case .some(.animated(let animation)):
            value = animation.keyframes.last(where: { $0.time <= localTime })?.value
                ?? animation.value
                ?? descriptor.defaultValue
        case .none:
            value = descriptor.defaultValue
        }
        performEditingCommand(.setPropertyKeyframe(
            layerID: sourceID,
            propertyID: propertyID,
            keyframe: VexelKeyframe(time: localTime, value: value)
        ))
    }

    private func removeKeyframeAtPlayhead(propertyID: String) {
        guard let track = selectedTimelineTrack,
              let sourceID = track.sourceID ?? selectedTrackID?.uuidString,
              let layer = selectedNativeLayer,
              let descriptor = VexelPropertyCatalog.descriptor(for: propertyID),
              case .animated(let animation)? = descriptor.value(in: layer) else {
            showingNotice = "The selected property has no keyframes to remove."
            return
        }
        let localTime = keyframeLocalPlayheadTime
        guard animation.keyframes.contains(where: { abs($0.time - localTime) < 0.000001 }) else {
            showingNotice = "There is no keyframe at the playhead for this property."
            return
        }
        performEditingCommand(.removePropertyKeyframe(
            layerID: sourceID,
            propertyID: propertyID,
            time: localTime
        ))
    }

    private func saveMarker(_ marker: VexelMarker) {
        do {
            let native = try VexelNativeProject(document: project.makeProjectDocument())
            let markerID = marker.sourceID ?? marker.id.uuidString
            var value = native.markers.first(where: { $0.id == markerID })
                ?? VexelMarkerData(id: markerID, time: marker.time)
            value.time = marker.time
            value.name = marker.name
            value.color = marker.color
            performEditingCommand(.upsertMarker(value))
        } catch {
            showingNotice = "The marker could not be saved: \(error.localizedDescription)"
        }
    }

    private func splitSelectedTrack() {
        guard let index = selectedTopLevelIndex() else {
            showingNotice = "Select a top-level timeline layer to split."
            return
        }
        let source = project.timelineTracks[index]
        let rate = Double(max(project.fps, 1))
        let splitTime = (currentTime * rate).rounded() / rate
        let end = source.start + source.duration
        guard splitTime > source.start, splitTime < end else {
            showingNotice = "Move the playhead inside the selected clip before splitting."
            return
        }
        let sourceID = source.sourceID ?? source.id.uuidString
        let splitID = UUID().uuidString
        performEditingCommand(
            .splitLayer(id: sourceID, localTime: splitTime - source.start, newID: splitID),
            selecting: splitID
        )
    }

    private func groupSelectedWithNextTrack() {
        guard let index = selectedTopLevelIndex(), project.timelineTracks.indices.contains(index + 1) else {
            showingNotice = "Select a layer with an adjacent layer beneath it to create a group."
            return
        }
        let first = project.timelineTracks[index]
        let second = project.timelineTracks[index + 1]
        let groupID = UUID().uuidString
        performEditingCommand(
            .groupLayers(
                firstID: first.sourceID ?? first.id.uuidString,
                secondID: second.sourceID ?? second.id.uuidString,
                groupID: groupID,
                name: uniqueLayerName("Group")
            ),
            selecting: groupID
        )
    }

    @discardableResult
    private func updateTrack(id: UUID, in tracks: inout [VexelTimelineTrack], mutation: (inout VexelTimelineTrack) -> Void) -> Bool {
        for index in tracks.indices {
            if tracks[index].id == id {
                mutation(&tracks[index])
                return true
            }
            if updateTrack(id: id, in: &tracks[index].children, mutation: mutation) {
                return true
            }
        }
        return false
    }

    private func removeEffect(_ effectID: String) {
        guard let selectedTimelineTrack else { return }
        let sourceID = selectedTimelineTrack.sourceID ?? selectedTimelineTrack.id.uuidString
        performEditingCommand(.removeEffect(layerID: sourceID, type: effectID))
    }

    private func selectLayer(at action: String, prefix: String) {
        guard let index = Int(action.dropFirst(prefix.count)),
              project.timelineTracks.indices.contains(index) else { return }
        selectedLayer = index
        selectedTrackID = project.timelineTracks[index].id
    }

    private func toggleLayerProperty(at action: String, prefix: String, property: String) {
        guard let index = Int(action.dropFirst(prefix.count)),
              project.timelineTracks.indices.contains(index) else { return }
        let track = project.timelineTracks[index]
        let sourceID = track.sourceID ?? track.id.uuidString
        if property == "visible" {
            performEditingCommand(.setLayerVisibility(id: sourceID, visible: !track.visible))
        } else if property == "locked" {
            performEditingCommand(.setLayerLock(id: sourceID, locked: !track.locked))
        }
    }

    @MainActor
    private func importPickedMedia(_ item: PhotosPickerItem) async {
        var importedFile: VexelImportedFile?
        var importedAsset: VexelProjectStore.ImportedAsset?
        do {
            guard let file = try await item.loadTransferable(type: VexelImportedFile.self) else {
                throw VexelProjectStore.StoreError.invalidSourceFile
            }
            importedFile = file
            let contentType = item.supportedContentTypes.first ?? .image
            let kind = contentType.conforms(to: .movie) || contentType.conforms(to: .video) ? "video" : "image"
            let asset = try VexelProjectStore.importAsset(
                from: file.url,
                projectID: project.id,
                type: kind,
                mimeType: contentType.preferredMIMEType
            )
            importedAsset = asset

            var duration = max(0.1, project.duration - currentTime)
            if kind == "video" {
                let mediaAsset = AVURLAsset(url: asset.fileURL)
                if let loadedDuration = try? await mediaAsset.load(.duration),
                   loadedDuration.seconds.isFinite, loadedDuration.seconds > 0 {
                    duration = min(loadedDuration.seconds, max(0.1, project.duration - currentTime))
                }
            }
            let layer = makeImportedLayer(asset, start: currentTime, duration: duration)
            let record = VexelAsset(
                id: asset.id,
                type: VexelAssetType(rawValue: asset.type),
                path: asset.path,
                name: asset.name,
                mimeType: asset.mimeType
            )
            performEditingCommand(
                .importMedia(asset: record, layer: layer),
                selecting: asset.id,
                onFailure: { try? FileManager.default.removeItem(at: asset.fileURL) }
            )
            showingNotice = "Imported \(asset.name) into the project and added it to the timeline."
        } catch {
            if let importedAsset { try? FileManager.default.removeItem(at: importedAsset.fileURL) }
            showingNotice = "Media import failed: \(error.localizedDescription)"
        }
        if let importedFile { try? FileManager.default.removeItem(at: importedFile.url) }
    }

    @MainActor
    private func importAudioFile(_ url: URL) async {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
        var importedAsset: VexelProjectStore.ImportedAsset?
        do {
            let mimeType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType
            let asset = try VexelProjectStore.importAsset(
                from: url,
                projectID: project.id,
                type: "audio",
                mimeType: mimeType
            )
            importedAsset = asset
            var duration = max(0.1, project.duration - currentTime)
            let mediaAsset = AVURLAsset(url: asset.fileURL)
            if let loadedDuration = try? await mediaAsset.load(.duration),
               loadedDuration.seconds.isFinite, loadedDuration.seconds > 0 {
                duration = min(loadedDuration.seconds, max(0.1, project.duration - currentTime))
            }
            let layer = makeImportedLayer(asset, start: currentTime, duration: duration)
            let record = VexelAsset(
                id: asset.id,
                type: VexelAssetType(rawValue: asset.type),
                path: asset.path,
                name: asset.name,
                mimeType: asset.mimeType
            )
            performEditingCommand(
                .importMedia(asset: record, layer: layer),
                selecting: asset.id,
                onFailure: { try? FileManager.default.removeItem(at: asset.fileURL) }
            )
            showingNotice = "Imported \(asset.name) into the project and added an audio track."
        } catch {
            if let importedAsset { try? FileManager.default.removeItem(at: importedAsset.fileURL) }
            showingNotice = "Audio import failed: \(error.localizedDescription)"
        }
    }

    private func makeImportedLayer(
        _ asset: VexelProjectStore.ImportedAsset,
        start: Double,
        duration: Double
    ) -> VexelLayer {
        let transform = VexelTransform(properties: [
            "anchor": .constant(.array([.number(0), .number(0)])),
            "position": .constant(.array([.number(0), .number(0)])),
            "scale": .constant(.array([.number(1), .number(1)])),
            "rotation": .constant(.number(0)),
            "opacity": .constant(.number(1))
        ])
        return VexelLayer(
            id: asset.id,
            type: VexelLayerType(rawValue: asset.type),
            name: asset.name,
            start: start,
            duration: duration,
            visible: true,
            locked: false,
            transform: transform,
            content: .object(["asset": .string(asset.id)])
        )
    }

    private func handleToolAction(_ action: String, for tool: VexelEditorTool) {
        switch action {
        case "add-text": addLayer(named: "Text Layer", kind: .text); selectedTool = nil
        case "add-shape": addLayer(named: "Shape Layer", kind: .visual); selectedTool = nil
        case "pick-image": showingMediaPicker = true; selectedTool = nil
        case "pick-audio": showingAudioPicker = true; selectedTool = nil
        case "show-export": showExport = true; selectedTool = nil
        case "show-graph": showGraph = true
        case "show-curve": showCurve = true
        case "show-composition": showCompositionSettings = true
        case "show-plugins": selectedTool = .plugins
        case "add-layer": addLayer(named: "New Layer", kind: .visual); selectedTool = nil
        case "duplicate-layer": duplicateSelectedTrack()
        case "add-keyframe": addKeyframeAtPlayhead()
        case "shortcut:mask", "shortcut:track-matte", "shortcut:transitions", "shortcut:text-animators":
            showingNotice = "This operation is disabled until its editing and rendering implementation is available."
        default:
            if action.hasPrefix("select-layer:") {
                selectLayer(at: action, prefix: "select-layer:")
            } else if action.hasPrefix("toggle-visibility:") {
                toggleLayerProperty(at: action, prefix: "toggle-visibility:", property: "visible")
            } else if action.hasPrefix("toggle-lock:") {
                toggleLayerProperty(at: action, prefix: "toggle-lock:", property: "locked")
            } else if action.hasPrefix("add-shape:") {
                let shapeName = String(action.dropFirst("add-shape:".count))
                addLayer(named: shapeName + " Layer", kind: .visual)
                selectedTool = nil
            } else if action.hasPrefix("effect:") {
                guard let selectedTrackID else {
                    showingNotice = "Select a layer before adding an effect."
                    return
                }
                let effectID = String(action.dropFirst("effect:".count))
                let sourceID = selectedTimelineTrack?.sourceID ?? selectedTrackID.uuidString
                performEditingCommand(
                    .addEffect(layerID: sourceID, effect: VexelEffect(type: effectID, parameters: [:]))
                )
                showingNotice = "Added \(effectID) to the selected layer's effect stack. Effect rendering is still in progress."
            } else {
                showingNotice = "\(tool.rawValue) operation is not implemented yet."
            }
        }
    }
}

private struct MediaPicker: View {
    let onSelect: (PhotosPickerItem) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selection: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                PhotosPicker(selection: $selection, matching: .any(of: [.images, .videos])) {
                    Label("Choose image or video", systemImage: "photo")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(VexelPalette.text)
                        .padding(16).frame(maxWidth: .infinity)
                        .background(VexelPalette.field, in: RoundedRectangle(cornerRadius: 12))
                }
                Text("Media is copied into the project and added to the timeline.").font(.system(size: 11)).foregroundStyle(VexelPalette.secondary)
                Spacer()
            }
            .padding(18).background(VexelPalette.background)
            .navigationTitle("Add media")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
            .onChange(of: selection) { item in if let item { onSelect(item); dismiss() } }
        }
            }
}

private struct CompositionSettingsSheet: View {
    @State private var project: VexelProjectItem
    let onSavedVersions: () -> Void
    let onSave: (VexelProjectItem) -> Void
    @Environment(\.dismiss) private var dismiss

    init(project: VexelProjectItem, onSavedVersions: @escaping () -> Void, onSave: @escaping (VexelProjectItem) -> Void) {
        _project = State(initialValue: project)
        self.onSavedVersions = onSavedVersions
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Composition") {
                    TextField("Name", text: $project.title)
                    Stepper("Width: \(project.width)", value: $project.width, in: 16...8192, step: 16)
                        .accessibilityIdentifier("compositionSettings.width")
                    Stepper("Height: \(project.height)", value: $project.height, in: 16...8192, step: 16)
                        .accessibilityIdentifier("compositionSettings.height")
                    Stepper("Frame rate: \(project.fps) FPS", value: $project.fps, in: 1...120)
                        .accessibilityIdentifier("compositionSettings.fps")
                    Slider(value: $project.duration, in: 1...3600, step: 1)
                        .accessibilityIdentifier("compositionSettings.duration")
                    Text("Duration: \(Int(project.duration)) seconds")
                }
                Section("Project history") {
                    Button(action: onSavedVersions) {
                        Label("Saved versions", systemImage: "clock.arrow.circlepath")
                    }
                    Text("Snapshot restoration will be connected to the project store.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden).background(VexelPalette.background)
            .navigationTitle("Composition settings").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { onSave(project); dismiss() }.accessibilityIdentifier("compositionSettings.save") } }
        }
    }
}

