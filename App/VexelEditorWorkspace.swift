import SwiftUI
import PhotosUI
import VexelCore
import UniformTypeIdentifiers

enum VexelEditorTool: String, CaseIterable, Identifiable {
    case layers = "Layers", shapes = "Shapes", text = "Text", media = "Media", model3D = "3D"
    case effects = "Effects", motion = "Motion", audio = "Audio", camera = "Camera", captions = "Captions"
    case elements = "Elements", plugins = "Plugins"

    var id: String { rawValue }
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
    @State var project: VexelProjectItem
    let onClose: () -> Void
    let onProjectChange: (VexelProjectItem) -> Void

    @State private var selectedTool: VexelEditorTool?
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
    @State private var undoStack: [VexelProjectItem] = []
    @State private var redoStack: [VexelProjectItem] = []
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

    private var availablePropertyTabs: [String] {
        guard let kind = selectedTimelineTrack?.kind else { return ["Composition"] }
        var tabs = ["Transform"]
        if kind == .text { tabs.append("Text") }
        if kind != .audio { tabs.append("Effects") }
        if kind == .visual || kind == .text || kind == .group { tabs.append("Masks") }
        if kind != .audio { tabs.append("Transitions") }
        return tabs
    }

    private var isWide: Bool { horizontalSizeClass == .regular }

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
                    inspectorPanel.frame(width: 290)
                }
                .padding(14)
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
        .sheet(isPresented: $showCompositionSettings) { CompositionSettingsSheet(project: $project, onSavedVersions: { showSavedVersions = true }) .presentationDetents([.medium, .large]) }
        .sheet(isPresented: $showSavedVersions) { VexelSavedVersionsSheet().presentationDetents([.medium, .large]) }
        .sheet(isPresented: $showGraph) { VexelGraphEditor() .presentationDetents([.large]) }
        .sheet(isPresented: $showCurve) { VexelCurveEditor() .presentationDetents([.large]) }
        .sheet(isPresented: $showProperties) {
            VexelPropertiesSheet(
                layerName: selectedTimelineTrack?.name ?? "Composition",
                layerKind: selectedTimelineTrack?.kind,
                onAddEffect: { selectedTool = .effects },
                effectIDs: selectedTimelineTrack?.effects ?? [],
                onRemoveEffect: { removeEffect($0) }
            )
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showStabilization) { VexelStabilizationSheet().presentationDetents([.medium, .large]) }
        .sheet(isPresented: $showCutoutBrush) { VexelCutoutBrushWorkspace().presentationDetents([.large]) }
        .sheet(isPresented: $showCameraControls) { VexelCameraWorkspace().presentationDetents([.large]) }
        .sheet(isPresented: $showMediaJob) { VexelMediaJobSheet(title: "Media analysis").presentationDetents([.medium, .large]) }
        .sheet(item: $editingMarker) { marker in
            VexelMarkerSheet(marker: marker) { updated in
                if let index = project.markers.firstIndex(where: { $0.id == updated.id }) {
                    project.markers[index] = updated
                } else {
                    project.markers.append(updated)
                }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingMediaPicker) {
            MediaPicker { _ in
                showingNotice = "Media selected. Asset ingestion and timeline insertion will be connected in the media-engine milestone."
            }
        }
        .fileImporter(isPresented: $showingAudioPicker, allowedContentTypes: [.audio], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                showingNotice = "Selected \(url.lastPathComponent). Audio decoding and timeline insertion are not connected yet."
            case .failure(let error):
                showingNotice = error.localizedDescription
            }
        }
        .alert("Rename composition", isPresented: $showRename) {
            TextField("Name", text: $project.title)
            Button("Cancel", role: .cancel) {}
            Button("Save") { onProjectChange(project) }
        }
        .alert("Editor", isPresented: Binding(get: { showingNotice != nil }, set: { if !$0 { showingNotice = nil } })) {
            Button("OK", role: .cancel) { showingNotice = nil }
        } message: { Text(showingNotice ?? "") }
        .onAppear {
            layerNames = project.layerNames
            synchronizeTimelineTracks(project.layerNames)
        }
        .onChange(of: selectedTrackID) { _ in selectedTab = "Transform" }
        .onChange(of: layerNames) { names in
            project.layerNames = names
            synchronizeTimelineTracks(names)
            project.modified = Date()
            onProjectChange(project)
        }
        .onChange(of: project) { updated in onProjectChange(updated) }
        .onChange(of: currentTime) { _ in project.modified = Date() }
        .task(id: isPlaying) {
            guard isPlaying else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 33_333_333)
                guard !Task.isCancelled else { break }
                let nextTime = currentTime + 1.0 / Double(max(project.fps, 1))
                if nextTime >= project.duration {
                    if loopPlayback {
                        currentTime = 0
                    } else {
                        currentTime = project.duration
                        isPlaying = false
                    }
                } else {
                    currentTime = nextTime
                }
            }
        }
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
            VexelIconButton(symbol: "arrow.uturn.backward", disabled: undoStack.isEmpty) { undoEdit() }
            VexelIconButton(symbol: "arrow.uturn.forward", disabled: redoStack.isEmpty) { redoEdit() }
            VexelIconButton(symbol: "slider.horizontal.3") { showCompositionSettings = true }
            VexelIconButton(symbol: "square.and.arrow.up", active: true) { showExport = true }
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
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
                    VexelEmptyState(symbol: "viewfinder", title: "Your canvas is empty", detail: "Add text, shapes or media from the tool shelf below.")
                } else {
                    RoundedRectangle(cornerRadius: 2).fill(Color(hex: 0x1B1A28))
                        .frame(width: isWide ? 180 : 116, height: isWide ? 112 : 198)
                        .overlay {
                            VStack(spacing: 8) {
                                Rectangle().fill(VexelPalette.accent).frame(width: 40, height: 3)
                                Text("YOUR\nNEXT FRAME")
                                    .font(.system(size: 15, weight: .black, design: .rounded))
                                    .tracking(1).multilineTextAlignment(.center).foregroundStyle(VexelPalette.text)
                            }
                        }
                        .overlay(RoundedRectangle(cornerRadius: 2).stroke(VexelPalette.accent.opacity(0.6), lineWidth: 1))
                    VStack {
                        HStack {
                            Text("2D VIEW").font(.system(size: 8, weight: .bold)).tracking(1.3)
                            Spacer()
                            Text("1080P").font(.system(size: 8, weight: .bold, design: .monospaced))
                        }
                        Spacer()
                        HStack {
                            Text("PREVIEW RENDERER NOT CONNECTED").font(.system(size: 8, weight: .medium)).tracking(0.5)
                            Spacer()
                            Image(systemName: "viewfinder")
                        }
                    }
                    .foregroundStyle(VexelPalette.secondary.opacity(0.8)).padding(12)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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
            }.buttonStyle(.plain)
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
        .padding(.horizontal, 14).padding(.vertical, 7)
        .background(VexelPalette.bar.opacity(0.8))
    }

    private var timelinePanel: some View {
        VexelTimelinePanel(
            tracks: $project.timelineTracks,
            currentTime: $currentTime,
            markers: $project.markers,
            selectedTrackID: $selectedTrackID,
            duration: project.duration,
            fps: project.fps,
            onMarkerEdit: { editingMarker = $0 },
            onNotice: { showingNotice = $0 }
        )
    }

    private func synchronizeTimelineTracks(_ names: [String]) {
        var existing = project.timelineTracks
        for name in names where !existing.contains(where: { $0.name == name }) {
            let kind: VexelTimelineTrack.Kind
            switch name {
            case "Text Layer", "Caption Layer": kind = .text
            case "Cube", "Sphere", "Cylinder", "Cone", "Plane", "Torus", "Text 3D", "Model 3D": kind = .rendered3D
            default: kind = .visual
            }
            existing.append(VexelTimelineTrack(name: name, duration: project.duration, kind: kind))
        }
        existing.removeAll { !names.contains($0.name) }
        project.timelineTracks = existing
        if selectedTrackID == nil { selectedTrackID = existing.first?.id }
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
                    Button { selectedTool = .audio } label: { Label("Audio controls", systemImage: "waveform") }
                    Button { showingNotice = "Audio extraction will connect to AVFoundation media processing." } label: { Label("Extract audio", systemImage: "waveform.badge.plus") }
                    Button { showMediaJob = true } label: { Label("Remove background", systemImage: "person.crop.rectangle") }
                    Button { showStabilization = true } label: { Label("Stabilize", systemImage: "scope") }
                    Button { showCutoutBrush = true } label: { Label("Cutout brush", systemImage: "scribble.variable") }
                    Button { showCameraControls = true } label: { Label("Camera controls", systemImage: "camera.aperture") }
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
    }

    private var toolBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(VexelEditorTool.allCases) { tool in
                    Button { selectedTool = tool } label: {
                        VStack(spacing: 5) {
                            Image(systemName: tool.symbol).font(.system(size: 16, weight: .medium))
                            Text(tool.rawValue).font(.system(size: 8, weight: .semibold))
                        }
                        .foregroundStyle(VexelPalette.soft)
                        .frame(width: 57, height: 54)
                        .background(VexelPalette.field.opacity(0.55), in: RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 8)
        }
        .background(VexelPalette.bar)
    }

    private var inspectorPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VexelSectionLabel(title: "Inspector")
                Spacer()
                VexelIconButton(symbol: "point.topleft.down.to.point.bottomright.curvepath") { showGraph = true }
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
                onRemoveEffect: { removeEffect($0) }
            )
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(VexelPalette.sheet, in: RoundedRectangle(cornerRadius: 16))
    }

    private func commitEdit(_ mutation: () -> Void) {
        undoStack.append(project)
        if undoStack.count > 100 { undoStack.removeFirst() }
        redoStack.removeAll()
        mutation()
        project.layerNames = layerNames
        project.modified = Date()
        synchronizeTimelineTracks(layerNames)
        onProjectChange(project)
    }

    private func undoEdit() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(project)
        project = previous
        layerNames = previous.layerNames
        selectedTrackID = previous.timelineTracks.first?.id
        onProjectChange(project)
    }

    private func redoEdit() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(project)
        project = next
        layerNames = next.layerNames
        selectedTrackID = next.timelineTracks.first?.id
        onProjectChange(project)
    }

    private func addLayer(named name: String, kind: VexelTimelineTrack.Kind) {
        commitEdit {
            let resolvedName = uniqueLayerName(name)
            let track = VexelTimelineTrack(name: resolvedName, duration: project.duration, kind: kind)
            project.timelineTracks.insert(track, at: 0)
            layerNames.insert(resolvedName, at: 0)
            selectedTrackID = track.id
            selectedLayer = 0
        }
    }

    private func uniqueLayerName(_ base: String) -> String {
        guard layerNames.contains(base) else { return base }
        var suffix = 2
        while layerNames.contains("\(base) \(suffix)") { suffix += 1 }
        return "\(base) \(suffix)"
    }

    private func selectedTopLevelIndex() -> Int? {
        guard let selectedTrackID else { return nil }
        return project.timelineTracks.firstIndex { $0.id == selectedTrackID }
    }

    private func duplicateSelectedTrack() {
        guard let index = selectedTopLevelIndex() else {
            showingNotice = "Select a top-level timeline layer to duplicate."
            return
        }
        commitEdit {
            let source = project.timelineTracks[index]
            let name = uniqueLayerName(source.name + " Copy")
            let duplicate = VexelTimelineTrack(name: name, start: source.start, duration: source.duration, kind: source.kind, visible: source.visible, locked: false, isGroup: source.isGroup, isExpanded: source.isExpanded, children: source.children, keyframes: source.keyframes, effects: source.effects)
            project.timelineTracks.insert(duplicate, at: index + 1)
            layerNames.insert(name, at: min(index + 1, layerNames.count))
            selectedTrackID = duplicate.id
            selectedLayer = min(index + 1, layerNames.count - 1)
        }
    }

    private func deleteSelectedTrack() {
        guard let index = selectedTopLevelIndex() else {
            showingNotice = "Select a top-level timeline layer to delete."
            return
        }
        commitEdit {
            project.timelineTracks.remove(at: index)
            if layerNames.indices.contains(index) { layerNames.remove(at: index) }
            selectedLayer = max(0, min(index - 1, layerNames.count - 1))
            selectedTrackID = project.timelineTracks.indices.contains(selectedLayer) ? project.timelineTracks[selectedLayer].id : project.timelineTracks.first?.id
        }
    }

    private func addKeyframeAtPlayhead() {
        guard let selectedTrackID else {
            showingNotice = "Select a timeline layer before adding a keyframe."
            return
        }
        let rate = Double(max(project.fps, 1))
        let frameTime = (currentTime * rate).rounded() / rate
        commitEdit {
            let found = updateTrack(id: selectedTrackID, in: &project.timelineTracks) { track in
                guard frameTime >= track.start, frameTime <= track.start + track.duration else { return }
                if !track.keyframes.contains(where: { abs($0 - frameTime) < 0.0001 }) {
                    track.keyframes.append(frameTime)
                    track.keyframes.sort()
                }
            }
            if !found { showingNotice = "The selected layer could not be found." }
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
        commitEdit {
            var left = source
            left.duration = splitTime - source.start
            left.keyframes = source.keyframes.filter { $0 <= splitTime }
            let rightName = uniqueLayerName(source.name + " Split")
            let right = VexelTimelineTrack(name: rightName, start: splitTime, duration: end - splitTime, kind: source.kind, visible: source.visible, locked: source.locked, isGroup: source.isGroup, isExpanded: source.isExpanded, children: source.children, keyframes: source.keyframes.filter { $0 >= splitTime }.map { $0 - splitTime })
            project.timelineTracks[index] = left
            project.timelineTracks.insert(right, at: index + 1)
            layerNames.insert(rightName, at: min(index + 1, layerNames.count))
            selectedTrackID = right.id
            selectedLayer = min(index + 1, layerNames.count - 1)
        }
    }

    private func groupSelectedWithNextTrack() {
        guard let index = selectedTopLevelIndex(), project.timelineTracks.indices.contains(index + 1) else {
            showingNotice = "Select a layer with an adjacent layer beneath it to create a group."
            return
        }
        commitEdit {
            let pair = Array(project.timelineTracks[index...index + 1])
            let groupStart = pair.map(\.start).min() ?? 0
            let groupEnd = pair.map { $0.start + $0.duration }.max() ?? groupStart
            var children = pair
            for childIndex in children.indices { children[childIndex].start -= groupStart }
            let groupName = uniqueLayerName("Group")
            let group = VexelTimelineTrack(name: groupName, start: groupStart, duration: max(0.001, groupEnd - groupStart), kind: .group, isGroup: true, isExpanded: true, children: children)
            project.timelineTracks.replaceSubrange(index...(index + 1), with: [group])
            layerNames.removeSubrange(index...(index + 1))
            layerNames.insert(groupName, at: index)
            selectedTrackID = group.id
            selectedLayer = index
        }
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
        guard let selectedTrackID else { return }
        commitEdit {
            _ = updateTrack(id: selectedTrackID, in: &project.timelineTracks) { track in
                track.effects.removeAll { $0 == effectID }
            }
        }
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
            if action.hasPrefix("effect:") {
                guard let selectedTrackID else {
                    showingNotice = "Select a layer before adding an effect."
                    return
                }
                let effectID = String(action.dropFirst("effect:".count))
                commitEdit {
                    let found = updateTrack(id: selectedTrackID, in: &project.timelineTracks) { track in
                        if !track.effects.contains(effectID) { track.effects.append(effectID) }
                    }
                    if !found { showingNotice = "The selected layer could not be found." }
                }
                showingNotice = "Added \(effectID) to the selected layer's effect stack. GPU rendering is not enabled yet."
            } else {
                showingNotice = "\(tool.rawValue) operation is not implemented yet."
            }
        }
    }
}

private struct MediaPicker: View {
    var audioOnly = false
    let onSelect: (PhotosPickerItem) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selection: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                PhotosPicker(selection: $selection, matching: .any(of: [.images, .videos])) {
                    Label(audioOnly ? "Choose media" : "Choose image", systemImage: "photo")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(VexelPalette.text)
                        .padding(16).frame(maxWidth: .infinity)
                        .background(VexelPalette.field, in: RoundedRectangle(cornerRadius: 12))
                }
                Text("Selected media will appear as a new timeline layer.").font(.system(size: 11)).foregroundStyle(VexelPalette.secondary)
                Spacer()
            }
            .padding(18).background(VexelPalette.background)
            .navigationTitle(audioOnly ? "Add audio" : "Add media")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
            .onChange(of: selection) { item in if let item { onSelect(item); dismiss() } }
        }
            }
}

private struct CompositionSettingsSheet: View {
    @Binding var project: VexelProjectItem
    let onSavedVersions: () -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Composition") {
                    TextField("Name", text: $project.title)
                    Stepper("Width: \(project.width)", value: $project.width, in: 16...8192, step: 16)
                    Stepper("Height: \(project.height)", value: $project.height, in: 16...8192, step: 16)
                    Stepper("Frame rate: \(project.fps) FPS", value: $project.fps, in: 1...120)
                    Slider(value: $project.duration, in: 1...3600, step: 1)
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
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }    }
}

