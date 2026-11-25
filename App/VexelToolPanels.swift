import SwiftUI
import VexelCore

private enum VexelAdvancedEditorPage: Identifiable {
    case audio, captions, camera, realCamera, cutout, expression, speech
    case effect(VexelEffectItem)

    var id: String {
        switch self {
        case .audio: return "audio"
        case .captions: return "captions"
        case .camera: return "camera"
        case .realCamera: return "real-camera"
        case .cutout: return "cutout"
        case .expression: return "expression"
        case .speech: return "speech"
        case .effect(let effect): return "effect-\(effect.id)"
        }
    }
}

struct VexelToolSheet: View {
    let tool: VexelEditorTool
    let tracks: [VexelTimelineTrack]
    @Binding var layerNames: [String]
    let selectedLayerName: String?
    let selectedLayerKind: VexelTimelineTrack.Kind?
    let onAction: (String) -> Void
    let onGraph: () -> Void
    let onCurve: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var effectCategory: String?
    @State private var selectedSubpage = "Overview"
    @State private var advancedPage: VexelAdvancedEditorPage?
    @State private var savedElements: [String] = []
    @State private var showSaveElementDialog = false
    @State private var newElementName = "New element"

    var body: some View {
        NavigationStack {
            Group {
                switch tool {
                case .layers: layersPage
                case .shapes: shapesPage
                case .text: textPage
                case .media: mediaPage
                case .model3D: modelPage
                case .effects: effectsPage
                case .motion: motionPage
                case .audio: audioPage
                case .camera: cameraPage
                case .captions: captionsPage
                case .elements: elementsPage
                case .plugins: pluginsPage
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(VexelPalette.background)
            .navigationTitle(tool.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("VEXEL").font(.system(size: 10, weight: .black)).tracking(2).foregroundStyle(VexelPalette.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() }.foregroundStyle(VexelPalette.accent) }
            }
        }
                .sheet(item: $advancedPage) { page in
            switch page {
            case .audio: VexelAudioWorkspace().presentationDetents([.large])
            case .captions: VexelCaptionWorkspace().presentationDetents([.large])
            case .camera: VexelCameraWorkspace().presentationDetents([.large])
            case .realCamera: VexelRealCameraWorkspace().presentationDetents([.large])
            case .cutout: VexelCutoutBrushWorkspace().presentationDetents([.large])
            case .expression: VexelExpressionWorkspace().presentationDetents([.large])
            case .speech: VexelTextToSpeechWorkspace().presentationDetents([.large])
            case .effect(let effect):
                VexelEffectDetailSheet(effect: effect, targetLayerName: selectedLayerName) { onAction("effect:\(effect.id)") }
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private var flattenedTracks: [VexelTimelineTrack] {
        func flatten(_ values: [VexelTimelineTrack]) -> [VexelTimelineTrack] {
            values.flatMap { [$0] + flatten($0.children) }
        }
        return flatten(tracks)
    }

    private var layersPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VexelSectionLabel(title: "Composition layers", trailing: "\(flattenedTracks.count) TOTAL")
                Spacer()
                Button { onAction("add-layer") } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(VexelPalette.accent)
                        .font(.system(size: 21))
                }
                .accessibilityLabel("Add layer")
            }
            if flattenedTracks.isEmpty {
                VexelEmptyState(
                    symbol: "square.3.layers.3d",
                    title: "No layers yet",
                    detail: "Add a shape, text layer or media asset to begin."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(flattenedTracks) { track in
                            HStack(spacing: 8) {
                                Button {
                                    onAction("select-layer-id:\(track.id.uuidString)")
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: track.kind == .audio ? "waveform" : (track.kind == .text ? "textformat" : (track.isGroup ? "folder" : (track.kind == .rendered3D ? "cube" : "square"))))
                                            .foregroundStyle(track.kind == .audio ? VexelPalette.pink : VexelPalette.accent)
                                            .frame(width: 32, height: 32)
                                            .background(VexelPalette.field, in: RoundedRectangle(cornerRadius: 8))
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(track.name)
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(VexelPalette.text)
                                                .lineLimit(1)
                                            Text("\(track.kind.rawValue.uppercased()) · \(track.visible ? "VISIBLE" : "HIDDEN")")
                                                .font(.system(size: 8, weight: .medium, design: .monospaced))
                                                .foregroundStyle(VexelPalette.secondary)
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("layers.select.\(track.id.uuidString)")
                                Button {
                                    onAction("toggle-visibility-id:\(track.id.uuidString)")
                                } label: {
                                    Image(systemName: track.visible ? "eye" : "eye.slash")
                                        .foregroundStyle(track.visible ? VexelPalette.secondary : VexelPalette.amber)
                                        .frame(width: 30, height: 36)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(track.visible ? "Hide \(track.name)" : "Show \(track.name)")
                                .accessibilityIdentifier("layers.visibility.\(track.id.uuidString)")
                                Button {
                                    onAction("toggle-lock-id:\(track.id.uuidString)")
                                } label: {
                                    Image(systemName: track.locked ? "lock.fill" : "lock.open")
                                        .foregroundStyle(track.locked ? VexelPalette.amber : VexelPalette.secondary)
                                        .frame(width: 30, height: 36)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(track.locked ? "Unlock \(track.name)" : "Lock \(track.name)")
                                .accessibilityIdentifier("layers.lock.\(track.id.uuidString)")
                            }
                            .padding(9)
                            .background(VexelPalette.card, in: RoundedRectangle(cornerRadius: 11))
                        }
                    }
                }
            }
            HStack {
                VexelActionButton(title: "Add layer", systemImage: "plus", prominent: true) { onAction("add-layer") }
                VexelActionButton(title: "Duplicate", systemImage: "plus.square.on.square") { onAction("duplicate-layer") }
            }
        }
    }

    private var shapesPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            VexelSectionLabel(title: "2D primitives")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(["Rectangle", "Ellipse", "Polygon", "Star", "Line", "Path"], id: \.self) { shape in
                    toolTile(shape, symbol: shapeSymbol(shape)) {
                        onAction("add-shape:\(shape)")
                    }
                }
            }
            VexelSectionLabel(title: "3D primitives")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(["Cube", "Sphere", "Cylinder", "Cone", "Plane", "Torus", "Point light", "Spot light", "Area light"], id: \.self) { shape in
                    toolTile(shape, symbol: "cube") { }.disabled(true)
                }
            }
            Spacer()
        }
    }

    private var textPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            VexelSectionLabel(title: "Text layers")
            Text("Add typography to your composition. Text styling, animators and 3D text controls will live in the inspector.")
                .font(.system(size: 12)).foregroundStyle(VexelPalette.secondary)
            VexelPanel {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Aa").font(.system(size: 40, weight: .black, design: .rounded)).foregroundStyle(VexelPalette.text)
                    Text("New text layer").font(.system(size: 13, weight: .semibold)).foregroundStyle(VexelPalette.text)
                    Text("Manrope · 48 pt · White").font(.system(size: 10)).foregroundStyle(VexelPalette.secondary)
                }
            }
            VexelActionButton(title: "Add text layer", systemImage: "textformat", prominent: true) {
                onAction("add-text")
            }
            VexelActionButton(title: "Add 3D text (unavailable)", systemImage: "cube.transparent") {}.disabled(true)
            Spacer()
        }
    }

    private var mediaPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            VexelSectionLabel(title: "Import media")
            mediaRow("Images", detail: "PNG, JPEG, HEIC", symbol: "photo", action: "pick-image")
            mediaRow("Video", detail: "MOV, MP4", symbol: "film", action: "pick-image")
            mediaRow("Audio", detail: "WAV, MP3, M4A", symbol: "waveform", action: "pick-audio")
            mediaRow("3D models", detail: "GLB, glTF · Import support coming soon", symbol: "cube", action: "unsupported", isEnabled: false)
            mediaRow("Fonts", detail: "OTF, TTF · Font management coming soon", symbol: "textformat", action: "unsupported", isEnabled: false)
            VexelPanel {
                Label("Imported assets will be listed in the project media bin.", systemImage: "info.circle")
                    .font(.system(size: 11)).foregroundStyle(VexelPalette.secondary)
            }
            VexelActionButton(title: "Cutout brush · Coming soon", systemImage: "scribble.variable") {}.disabled(true)
            Spacer()
        }
    }

    private var modelPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            VexelSectionLabel(title: "3D scene objects")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(["Cube", "Sphere", "Cylinder", "Cone", "Plane", "Torus", "Text 3D", "Null 3D", "Camera", "Environment"], id: \.self) { name in
                    toolTile(name, symbol: "cube.transparent") {}.disabled(true)
                }
            }
            Spacer()
        }
    }

    private var effectsPage: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(VexelPalette.secondary)
                TextField("Search effects", text: $search).font(.system(size: 12))
                if !search.isEmpty {
                    Button { search = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(VexelPalette.secondary)
                    }.buttonStyle(.plain)
                }
            }
            .padding(11).background(VexelPalette.field, in: RoundedRectangle(cornerRadius: 10))

            if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && effectCategory == nil {
                VexelSectionLabel(title: "Effect categories", trailing: "\(VexelEffectCatalog.effectCount) EFFECTS")
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                        ForEach(VexelEffectCatalog.categories, id: \.self) { category in
                            let count = VexelEffectCatalog.effects(in: category).count
                            Button { effectCategory = category } label: {
                                VStack(alignment: .leading, spacing: 9) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(VexelPalette.field)
                                        .frame(height: 54)
                                        .overlay(Image(systemName: categorySymbol(category)).font(.system(size: 20)).foregroundStyle(VexelPalette.accent))
                                    Text(category).font(.system(size: 11, weight: .semibold)).foregroundStyle(VexelPalette.text)
                                    Text("\(count) effects").font(.system(size: 9)).foregroundStyle(VexelPalette.secondary)
                                }
                                .padding(10)
                                .background(VexelPalette.card, in: RoundedRectangle(cornerRadius: 11))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                HStack {
                    Button {
                        effectCategory = nil
                        search = ""
                    } label: {
                        Label("Categories", systemImage: "chevron.left")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(VexelPalette.accent)
                    VexelSectionLabel(
                        title: search.isEmpty ? (effectCategory ?? "All effects") : "Search results",
                        trailing: "\(visibleEffects.count) EFFECTS"
                    )
                }

                VexelSectionLabel(title: "Effect shortcuts", trailing: "EDITOR TOOLS")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(visibleShortcuts, id: \.2) { item in
                        Button { onAction(item.2) } label: {
                            Label(item.0, systemImage: item.1)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(VexelPalette.soft)
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(VexelPalette.card, in: RoundedRectangle(cornerRadius: 9))
                        }
                        .buttonStyle(.plain)
                        .disabled(true)
                        .opacity(0.4)
                    }
                }

                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                        ForEach(visibleEffects) { effect in
                            Button { advancedPage = .effect(effect) } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    RoundedRectangle(cornerRadius: 7).fill(VexelPalette.field)
                                        .frame(height: 58)
                                        .overlay {
                                            VStack(spacing: 3) {
                                                Image(systemName: effectSymbol(effect.name))
                                                    .font(.system(size: 21)).foregroundStyle(VexelPalette.accent)
                                                if effect.target == "layer_3d" {
                                                    Text("3D ONLY").font(.system(size: 7, weight: .bold)).foregroundStyle(VexelPalette.amber)
                                                }
                                            }
                                        }
                                    Text(effect.name).font(.system(size: 11, weight: .semibold)).foregroundStyle(VexelPalette.text)
                                    Text(effect.category).font(.system(size: 9)).foregroundStyle(VexelPalette.secondary)
                                }
                                .padding(9).background(VexelPalette.card, in: RoundedRectangle(cornerRadius: 11))
                            }
                            .buttonStyle(.plain)
                            .disabled(effect.target == "layer_3d" && selectedLayerKind != .rendered3D)
                            .opacity(effect.target == "layer_3d" && selectedLayerKind != .rendered3D ? 0.4 : 1)
                        }
                    }
                }
            }

            if let selectedLayerName {
                HStack(spacing: 8) {
                    Image(systemName: "square.3.layers.3d").foregroundStyle(VexelPalette.secondary)
                    Text("Apply to").font(.system(size: 10, weight: .semibold)).foregroundStyle(VexelPalette.soft)
                    Text(selectedLayerName)
                        .font(.system(size: 10, weight: .medium)).foregroundStyle(VexelPalette.text).lineLimit(1)
                    Spacer()
                }
                .padding(10)
                .background(VexelPalette.bar, in: RoundedRectangle(cornerRadius: 9))
            } else {
                Text("Select a layer before selecting an effect.")
                    .font(.system(size: 10)).foregroundStyle(VexelPalette.secondary)
            }
        }
    }

    private var visibleShortcuts: [(String, String, String)] {
        let all: [(String, String, String, String)] = [
            ("Mask", "circle.dotted", "shortcut:mask", "keying"),
            ("Track matte", "square.on.square", "shortcut:track-matte", "keying"),
            ("Transitions", "arrow.left.arrow.right", "shortcut:transitions", "time"),
            ("Text animators", "textformat.abc", "shortcut:text-animators", "text")
        ]
        if !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return all.filter { $0.0.localizedCaseInsensitiveContains(search) || $0.2.localizedCaseInsensitiveContains(search) }
                .map { ($0.0, $0.1, $0.2) }
        }
        guard let category = effectCategory, category != "All effects" else { return [] }
        return all.filter { VexelEffectCatalog.categoryName(for: $0.3) == category }
            .map { ($0.0, $0.1, $0.2) }
    }

    private func shortcutAvailable(_ id: String) -> Bool {
        guard let selectedLayerKind else { return false }
        switch id {
        case "shortcut:mask", "shortcut:track-matte":
            return selectedLayerKind == .visual || selectedLayerKind == .text || selectedLayerKind == .group
        case "shortcut:text-animators":
            return selectedLayerKind == .text
        case "shortcut:transitions":
            return true
        default:
            return false
        }
    }

    private var visibleEffects: [VexelEffectItem] {
        if !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return VexelEffectCatalog.search(search)
        }
        return VexelEffectCatalog.effects(in: effectCategory ?? "All effects")
    }

    private func categorySymbol(_ category: String) -> String {
        switch category {
        case "Color & light": return "sun.max"
        case "Blur & sharpen": return "drop.halffull"
        case "Distort": return "water.waves"
        case "Move & transform": return "move.3d"
        case "Stylize": return "sparkles"
        case "Glitch": return "waveform.path.ecg"
        case "Drawing & edges": return "pencil.tip.crop.circle"
        case "Procedural": return "grid"
        case "Matte, mask & key": return "circle.lefthalf.filled"
        case "Time & transition": return "clock.arrow.2.circlepath"
        case "Text": return "textformat"
        default: return "slider.horizontal.3"
        }
    }

    private var motionPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            VexelSectionLabel(title: "Animation")
            VexelPanel {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Keyframe controls", systemImage: "diamond").font(.system(size: 13, weight: .bold)).foregroundStyle(VexelPalette.text)
                    HStack {
                        VexelActionButton(title: "Add keyframe", systemImage: "diamond.fill", prominent: true) { onAction("add-keyframe") }
                        VexelActionButton(title: "Graph editor", systemImage: "point.topleft.down.to.point.bottomright.curvepath", action: onGraph)
                    }
                    HStack {
                        VexelActionButton(title: "Curve editor (unavailable)", systemImage: "waveform.path", action: onCurve).disabled(true)
                        VexelActionButton(title: "Expressions (unavailable)", systemImage: "chevron.left.forwardslash.chevron.right") {}.disabled(true)
                    }
                }
            }
            VexelSectionLabel(title: "Interpolation")
            ForEach(["Linear", "Ease in", "Ease out", "Ease in / out", "Hold", "Bezier"], id: \.self) { name in
                HStack { Text(name).font(.system(size: 12, weight: .medium)).foregroundStyle(VexelPalette.text); Spacer(); Image(systemName: "chevron.right").foregroundStyle(VexelPalette.secondary) }
                    .padding(12).background(VexelPalette.card, in: RoundedRectangle(cornerRadius: 10))
            }
            Spacer()
        }
    }

    private var audioPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            VexelSectionLabel(title: "Audio workspace")
            VexelPanel {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Timeline audio preview", systemImage: "waveform")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(VexelPalette.text)
                    Text("Imported audio clips can be placed and previewed on the timeline. Mixer automation, EQ and processing are not connected yet.")
                        .font(.system(size: 11))
                        .foregroundStyle(VexelPalette.secondary)
                }
            }
            mediaRow("Add audio", detail: "Choose a supported audio file", symbol: "waveform", action: "pick-audio")
            mediaRow("Record voiceover", detail: "Microphone capture · Coming soon", symbol: "mic", action: "unsupported", isEnabled: false)
            VexelSectionLabel(title: "Audio processing", trailing: "PLANNED")
            ForEach(["Mixer and automation", "Equalizer", "Noise reduction", "Fade in / out", "Time stretch", "Beat detection"], id: \.self) { item in
                HStack {
                    Text(item).font(.system(size: 12)).foregroundStyle(VexelPalette.secondary)
                    Spacer()
                    Text("SOON")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(VexelPalette.secondary)
                }
                .padding(11)
                .background(VexelPalette.card.opacity(0.6), in: RoundedRectangle(cornerRadius: 9))
            }
            Spacer()
        }
    }

    private var cameraPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            VexelSectionLabel(title: "Camera layer")
            VexelPanel {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "camera.aperture").font(.system(size: 31)).foregroundStyle(VexelPalette.accent)
                    Text("Virtual camera").font(.system(size: 13, weight: .bold)).foregroundStyle(VexelPalette.text)
                    Text("Create and animate a 2D or 3D camera. Camera projection and viewport navigation will be wired to the scene evaluator.")
                        .font(.system(size: 11)).foregroundStyle(VexelPalette.secondary)
                }
            }
            ForEach(["Position", "Rotation", "Zoom / focal length", "Depth of field", "Focus distance"], id: \.self) { item in
                HStack { Text(item).font(.system(size: 12)).foregroundStyle(VexelPalette.text); Spacer(); Text("0").font(.system(size: 10, design: .monospaced)).foregroundStyle(VexelPalette.secondary) }
                    .padding(12).background(VexelPalette.card, in: RoundedRectangle(cornerRadius: 9))
            }
            VexelActionButton(title: "Camera controls", systemImage: "camera.aperture") { advancedPage = .camera }
            VexelActionButton(title: "Real camera motion capture", systemImage: "camera.metering.center.weighted") {
                advancedPage = .realCamera
            }
            VexelActionButton(title: "Add camera", systemImage: "camera", prominent: true) { onAction("add-camera") }
            Spacer()
        }
    }

    private var captionsPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            VexelSectionLabel(title: "Captions and subtitles")
            VexelPanel {
                VStack(alignment: .leading, spacing: 9) {
                    Label("Caption tracks", systemImage: "captions.bubble").font(.system(size: 13, weight: .bold)).foregroundStyle(VexelPalette.text)
                    Text("Create timed subtitle segments, style caption text, and synchronize them with audio.")
                        .font(.system(size: 11)).foregroundStyle(VexelPalette.secondary)
                    VexelActionButton(title: "Add caption", systemImage: "plus", prominent: true) { layerNames.insert("Caption Layer", at: 0) }
                    VexelActionButton(title: "Open caption editor", systemImage: "captions.bubble") { advancedPage = .captions }
                }
            }
            ForEach(["Import SRT", "Generate from speech", "Caption style", "Timing and alignment"], id: \.self) { item in
                HStack { Text(item).font(.system(size: 12)).foregroundStyle(VexelPalette.text); Spacer(); Image(systemName: "chevron.right").foregroundStyle(VexelPalette.secondary) }
                    .padding(12).background(VexelPalette.card, in: RoundedRectangle(cornerRadius: 10))
            }
            VexelActionButton(title: "Text to speech", systemImage: "waveform", prominent: true) { advancedPage = .speech }
            Spacer()
        }
    }

    private var elementsPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            VexelSectionLabel(title: "Saved elements", trailing: "\(savedElements.count) ITEMS")
            if savedElements.isEmpty {
                VexelEmptyState(symbol: "square.grid.2x2", title: "No saved elements", detail: "Save reusable compositions, title cards and graphics here.")
            } else {
                ScrollView {
                    LazyVStack(spacing: 9) {
                        ForEach(savedElements, id: \.self) { element in
                            HStack(spacing: 10) {
                                Image(systemName: "square.grid.2x2").foregroundStyle(VexelPalette.accent)
                                    .frame(width: 34, height: 34).background(VexelPalette.field, in: RoundedRectangle(cornerRadius: 8))
                                Text(element).font(.system(size: 12, weight: .semibold)).foregroundStyle(VexelPalette.text)
                                Spacer()
                                Button { layerNames.insert(element, at: 0) } label: {
                                    Image(systemName: "plus.circle").foregroundStyle(VexelPalette.accent)
                                }
                                Button { savedElements.removeAll { $0 == element } } label: {
                                    Image(systemName: "trash").foregroundStyle(VexelPalette.pink)
                                }
                            }
                            .padding(10).background(VexelPalette.card, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
            VexelActionButton(title: "Save current selection", systemImage: "bookmark", prominent: true) {
                newElementName = "New element"
                showSaveElementDialog = true
            }
            Spacer()
        }
        .alert("Save element", isPresented: $showSaveElementDialog) {
            TextField("Element name", text: $newElementName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let name = newElementName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty { savedElements.append(name) }
            }
        } message: {
            Text("Save the current selection to your reusable element library.")
        }
    }

    private var pluginsPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            VexelSectionLabel(title: "Extensions")
            VexelPanel {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Plugin manager", systemImage: "puzzlepiece.extension").font(.system(size: 13, weight: .bold)).foregroundStyle(VexelPalette.text)
                    Text("Install extension packages, inspect their commands and manage enabled plugins.")
                        .font(.system(size: 11)).foregroundStyle(VexelPalette.secondary)
                    VexelActionButton(title: "Open plugin manager", systemImage: "arrow.up.right", prominent: true) { onAction("show-plugins") }
                }
            }
            ForEach(["Installed", "Available", "Examples"], id: \.self) { item in
                HStack { Text(item).font(.system(size: 12, weight: .semibold)).foregroundStyle(VexelPalette.text); Spacer(); Text("0").font(.system(size: 10, design: .monospaced)).foregroundStyle(VexelPalette.secondary) }
                    .padding(12).background(VexelPalette.card, in: RoundedRectangle(cornerRadius: 9))
            }
            Spacer()
        }
    }

    private func mediaRow(
        _ title: String,
        detail: String,
        symbol: String,
        action: String,
        isEnabled: Bool = true
    ) -> some View {
        Button { onAction(action) } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .foregroundStyle(isEnabled ? VexelPalette.accent : VexelPalette.secondary)
                    .frame(width: 34, height: 34)
                    .background(VexelPalette.field, in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(isEnabled ? VexelPalette.text : VexelPalette.secondary)
                    Text(detail).font(.system(size: 10)).foregroundStyle(VexelPalette.secondary)
                }
                Spacer()
                if isEnabled {
                    Image(systemName: "plus.circle").foregroundStyle(VexelPalette.accent)
                } else {
                    Text("SOON")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(VexelPalette.secondary)
                }
            }
            .padding(10)
            .background(VexelPalette.card.opacity(isEnabled ? 1 : 0.55), in: RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private func toolTile(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 9) {
                Image(systemName: symbol).font(.system(size: 22, weight: .light)).foregroundStyle(VexelPalette.accent)
                Text(title).font(.system(size: 10, weight: .semibold)).foregroundStyle(VexelPalette.text)
            }
            .frame(maxWidth: .infinity).frame(height: 76)
            .background(VexelPalette.card, in: RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(VexelPalette.line, lineWidth: 1))
        }.buttonStyle(.plain)
    }

    private func shapeSymbol(_ shape: String) -> String {
        switch shape { case "Ellipse": return "circle"; case "Star": return "star"; case "Line": return "line.diagonal"; case "Path": return "scribble"; default: return "square" }
    }

    private func effectSymbol(_ effect: String) -> String {
        if effect.contains("Blur") { return "drop.halffull" }
        if effect.contains("Glow") || effect.contains("Light") { return "sun.max" }
        if effect.contains("Color") || effect.contains("Hue") { return "slider.horizontal.3" }
        if effect.contains("Motion") { return "wind" }
        return "sparkles"
    }
}

struct VexelPropertiesPanel: View {
    let tab: String
    let layerName: String
    let layerKind: VexelTimelineTrack.Kind?
    let onCurve: () -> Void
    let onAddEffect: () -> Void
    let effectIDs: [String]
    let onRemoveEffect: (String) -> Void
    let position: [Double]
    let onPositionCommit: (Double, Double) -> Void
    let transformValues: [String: [Double]]
    let onTransformCommit: (String, [Double]) -> Void
    let textValues: [String: JSONValue]
    let onTextCommit: (VexelTextProperty, JSONValue) -> Void

    @State private var positionX = 0.0
    @State private var positionY = 0.0
    @State private var anchorX = 0.0
    @State private var anchorY = 0.0
    @State private var scaleX = 100.0
    @State private var scaleY = 100.0
    @State private var rotation = 0.0
    @State private var opacity = 100.0
    @State private var startTime = 0.0
    @State private var layerDuration = 10.0
    @State private var visible = true
    @State private var locked = false
    @State private var motionBlur = false
    @State private var blendMode = "Normal"
    @State private var textContent = "Text"
    @State private var fontFamily = "sans-serif"
    @State private var fontSize = 96.0
    @State private var fontWeight = 700.0
    @State private var letterSpacing = 0.0
    @State private var lineHeight = 1.2
    @State private var italic = false
    @State private var textAlignment = "Center"
    @State private var animatorType = "Fade"
    @State private var maskShape = "Rectangle"
    @State private var maskMode = "Add"
    @State private var maskEnabled = true
    @State private var maskInverted = false
    @State private var matteLayer = "None"
    @State private var matteMode = "Alpha"
    @State private var transitionIn = "None"
    @State private var transitionOut = "None"
    @State private var transitionDuration = 0.5
    @State private var compositionWidth = 1080.0
    @State private var compositionHeight = 1920.0
    @State private var compositionFPS = 30.0
    @State private var compositionDuration = 10.0
    @State private var compositionMotionBlur = true
    @State private var shutterAngle = 180.0
    @State private var motionBlurSamples = 8.0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(layerName).font(.system(size: 13, weight: .bold)).foregroundStyle(VexelPalette.text)
                        Text("SELECTED LAYER").font(.system(size: 8, weight: .bold)).tracking(1.2).foregroundStyle(VexelPalette.secondary)
                    }
                    Spacer()
                    Image(systemName: "eye").foregroundStyle(VexelPalette.secondary)
                }

                switch tab {
                case "Transform":
                    propertyGroup("POSITION") {
                        valueField("X", value: $positionX, unit: "px", accessibilityIdentifier: "inspector.position.x") {
                            onPositionCommit(positionX, positionY)
                        }
                        valueField("Y", value: $positionY, unit: "px", accessibilityIdentifier: "inspector.position.y") {
                            onPositionCommit(positionX, positionY)
                        }
                        Text("Position changes are committed to the native project.")
                            .font(.system(size: 9)).foregroundStyle(VexelPalette.secondary)
                    }
                    propertyGroup("ANCHOR") {
                        valueField("X", value: $anchorX, unit: "px", accessibilityIdentifier: "inspector.anchor.x") {
                            onTransformCommit("anchor", [anchorX, anchorY] + (transformValues["anchor"]?.dropFirst(2).map { $0 } ?? []))
                        }
                        valueField("Y", value: $anchorY, unit: "px", accessibilityIdentifier: "inspector.anchor.y") {
                            onTransformCommit("anchor", [anchorX, anchorY] + (transformValues["anchor"]?.dropFirst(2).map { $0 } ?? []))
                        }
                    }
                    propertyGroup("SCALE") {
                        valueField("X", value: $scaleX, unit: "%", accessibilityIdentifier: "inspector.scale.x") {
                            onTransformCommit("scale", [scaleX / 100, scaleY / 100] + (transformValues["scale"]?.dropFirst(2).map { $0 } ?? []))
                        }
                        valueField("Y", value: $scaleY, unit: "%", accessibilityIdentifier: "inspector.scale.y") {
                            onTransformCommit("scale", [scaleX / 100, scaleY / 100] + (transformValues["scale"]?.dropFirst(2).map { $0 } ?? []))
                        }
                    }
                    propertyGroup("ROTATION & OPACITY") {
                        valueField("Rotation", value: $rotation, unit: "°", accessibilityIdentifier: "inspector.rotation") {
                            if transformValues["rotation"]?.count == 3 {
                                var components = transformValues["rotation"] ?? [0, 0, 0]
                                components[2] = rotation
                                onTransformCommit("rotation", components)
                            } else {
                                onTransformCommit("rotation", [rotation])
                            }
                        }
                        valueField("Opacity", value: $opacity, unit: "%", accessibilityIdentifier: "inspector.opacity") {
                            onTransformCommit("opacity", [opacity / 100])
                        }
                    }

                case "Text":
                    propertyGroup("TEXT CONTENT") {
                        TextEditor(text: $textContent)
                            .font(.system(size: 12))
                            .frame(minHeight: 76)
                            .scrollContentBackground(.hidden)
                            .padding(6)
                            .background(VexelPalette.field, in: RoundedRectangle(cornerRadius: 8))
                            .accessibilityIdentifier("inspector.text.content")
                        VexelActionButton(title: "Apply text", systemImage: "checkmark", prominent: true) {
                            onTextCommit(.content, .string(textContent))
                        }
                        .accessibilityIdentifier("inspector.text.save")
                    }
                    propertyGroup("FONT") {
                        Picker("Family", selection: $fontFamily) {
                            ForEach(["sans-serif", "serif", "monospace", "cursive", "sans-serif-condensed"], id: \.self) { Text($0).tag($0) }
                        }
                        .tint(VexelPalette.accent)
                        .onChange(of: fontFamily) { onTextCommit(.fontFamily, .string($0)) }
                        valueField("Size", value: $fontSize, unit: "px", accessibilityIdentifier: "inspector.text.fontSize") {
                            onTextCommit(.fontSize, .number(fontSize))
                        }
                        valueField("Weight", value: $fontWeight, unit: "", accessibilityIdentifier: "inspector.text.fontWeight") {
                            onTextCommit(.fontWeight, .number(fontWeight))
                        }
                        Toggle("Italic", isOn: $italic)
                            .tint(VexelPalette.accent)
                            .onChange(of: italic) { onTextCommit(.fontItalic, .bool($0)) }
                        valueField("Line height", value: $lineHeight, unit: "×", accessibilityIdentifier: "inspector.text.lineHeight") {
                            onTextCommit(.lineHeight, .number(lineHeight))
                        }
                        valueField("Letter spacing", value: $letterSpacing, unit: "em", accessibilityIdentifier: "inspector.text.letterSpacing") {
                            onTextCommit(.letterSpacing, .number(letterSpacing))
                        }
                        Picker("Alignment", selection: $textAlignment) {
                            ForEach(["Left", "Center", "Right"], id: \.self) { Text($0).tag($0) }
                        }
                        .tint(VexelPalette.accent)
                        .onChange(of: textAlignment) { onTextCommit(.alignment, .string($0.lowercased())) }
                    }
                    propertyGroup("TEXT ANIMATORS") {
                        Text("Text animators are not editable yet. Existing animator data remains preserved.")
                            .font(.system(size: 9)).foregroundStyle(VexelPalette.secondary)
                    }
                    .disabled(true)

                case "Effects":
                    propertyGroup("EFFECT STACK") {
                        if effectIDs.isEmpty {
                            Text("No effects applied").font(.system(size: 11)).foregroundStyle(VexelPalette.secondary)
                        } else {
                            ForEach(effectIDs, id: \.self) { effectID in
                                HStack {
                                    Text(effectID).font(.system(size: 10, weight: .medium)).foregroundStyle(VexelPalette.text)
                                    Spacer()
                                    Button(role: .destructive) { onRemoveEffect(effectID) } label: {
                                        Image(systemName: "trash").foregroundStyle(VexelPalette.pink)
                                    }
                                }
                            }
                        }
                        VexelActionButton(title: "Open effect library", systemImage: "plus", prominent: true, action: onAddEffect)
                    }
                    Text("Effect identifiers are stored on the layer. Shader execution and parameter serialization remain pending.")
                        .font(.system(size: 9)).foregroundStyle(VexelPalette.secondary)

                case "Masks":
                    propertyGroup("MASK") {
                        Picker("Shape", selection: $maskShape) {
                            ForEach(["Rectangle", "Ellipse"], id: \.self) { Text($0).tag($0) }
                        }.tint(VexelPalette.accent)
                        Picker("Mode", selection: $maskMode) {
                            ForEach(["Add", "Subtract", "Intersect"], id: \.self) { Text($0).tag($0) }
                        }.tint(VexelPalette.accent)
                        Toggle("Enabled", isOn: $maskEnabled).tint(VexelPalette.accent)
                        Toggle("Invert", isOn: $maskInverted).tint(VexelPalette.accent)
                        Text("Position, size, roundness, feather and opacity are animated properties.")
                            .font(.system(size: 9)).foregroundStyle(VexelPalette.secondary)
                    }
                    propertyGroup("TRACK MATTE") {
                        Picker("Source layer", selection: $matteLayer) {
                            Text("None").tag("None")
                            Text("Sibling layer").tag("Sibling layer")
                        }.tint(VexelPalette.accent)
                        Picker("Mode", selection: $matteMode) {
                            ForEach(["Alpha", "Alpha inverted", "Luma", "Luma inverted"], id: \.self) { Text($0).tag($0) }
                        }.tint(VexelPalette.accent)
                    }

                case "Transitions":
                    propertyGroup("TRANSITION IN") {
                        Picker("Type", selection: $transitionIn) {
                            ForEach(["None", "Fade", "Slide left", "Slide right", "Slide up", "Slide down", "Zoom in", "Zoom out", "Spin", "Blur", "Wipe left", "Wipe right"], id: \.self) { Text($0).tag($0) }
                        }.tint(VexelPalette.accent)
                        valueField("Duration", value: $transitionDuration, unit: "s")
                    }
                    propertyGroup("TRANSITION OUT") {
                        Picker("Type", selection: $transitionOut) {
                            ForEach(["None", "Fade", "Slide left", "Slide right", "Slide up", "Slide down", "Zoom in", "Zoom out", "Spin", "Blur", "Wipe left", "Wipe right"], id: \.self) { Text($0).tag($0) }
                        }.tint(VexelPalette.accent)
                        valueField("Duration", value: $transitionDuration, unit: "s")
                    }
                    Text("Transition easing and duration will be stored in the layer model.")
                        .font(.system(size: 9)).foregroundStyle(VexelPalette.secondary)

                case "Composition":
                    propertyGroup("COMPOSITION FORMAT") {
                        valueField("Width", value: $compositionWidth, unit: "px")
                        valueField("Height", value: $compositionHeight, unit: "px")
                        valueField("Frame rate", value: $compositionFPS, unit: "fps")
                        valueField("Duration", value: $compositionDuration, unit: "s")
                    }
                    propertyGroup("MOTION BLUR") {
                        Toggle("Enabled", isOn: $compositionMotionBlur).tint(VexelPalette.accent)
                        valueField("Shutter angle", value: $shutterAngle, unit: "°")
                        valueField("Samples", value: $motionBlurSamples, unit: "")
                    }
                    Text("Composition controls are presentation state until the project model is connected.")
                        .font(.system(size: 9)).foregroundStyle(VexelPalette.secondary)
                default:
                    VexelEmptyState(symbol: "slider.horizontal.3", title: "Inspector", detail: "Select a layer to inspect its properties.")
                }

            }
            .padding(.bottom, 12)
        }
        .onAppear {
            positionX = position.first ?? 0
            positionY = position.dropFirst().first ?? 0
            synchronizeTransformFields()
            synchronizeTextFields()
        }
        .onChange(of: textValues) { _ in synchronizeTextFields() }
        .onChange(of: position) { values in
            positionX = values.first ?? 0
            positionY = values.dropFirst().first ?? 0
        }
        .onChange(of: transformValues) { _ in synchronizeTransformFields() }
        .disabled(!["Transform", "Effects", "Text"].contains(tab))
    }

    private func synchronizeTextFields() {
        textContent = textValues["content"]?.stringValue ?? "Text"
        fontFamily = textValues["fontFamily"]?.stringValue ?? "sans-serif"
        fontWeight = textValues["fontWeight"]?.numberValue ?? 700
        if case .bool(let value)? = textValues["fontItalic"] { italic = value } else { italic = false }
        fontSize = textValues["fontSize"]?.numberValue ?? 96
        lineHeight = textValues["lineHeight"]?.numberValue ?? 1.2
        letterSpacing = textValues["letterSpacing"]?.numberValue ?? 0
        textAlignment = (textValues["alignment"]?.stringValue ?? "center").capitalized
    }

    private func synchronizeTransformFields() {
        anchorX = transformValues["anchor"]?.first ?? 0
        anchorY = transformValues["anchor"]?.dropFirst().first ?? 0
        scaleX = (transformValues["scale"]?.first ?? 1) * 100
        scaleY = (transformValues["scale"]?.dropFirst().first ?? 1) * 100
        let rotationValues = transformValues["rotation"] ?? [0]
        rotation = rotationValues.count == 3 ? rotationValues[2] : rotationValues[0]
        opacity = (transformValues["opacity"]?.first ?? 1) * 100
    }

    private func propertyGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            VexelSectionLabel(title: title)
            VexelPanel(padding: 10) { VStack(alignment: .leading, spacing: 9, content: content) }
        }
    }

    private func valueField(
        _ title: String,
        value: Binding<Double>,
        unit: String,
        accessibilityIdentifier: String? = nil,
        onCommit: (() -> Void)? = nil
    ) -> some View {
        HStack {
            Text(title).font(.system(size: 10, weight: .medium)).foregroundStyle(VexelPalette.soft)
            Spacer()
            TextField(title, value: value, format: .number.precision(.fractionLength(0...2)))
                .multilineTextAlignment(.trailing).keyboardType(.numbersAndPunctuation)
                .font(.system(size: 10, design: .monospaced)).foregroundStyle(VexelPalette.text)
                .frame(width: 64).padding(6).background(VexelPalette.field, in: RoundedRectangle(cornerRadius: 6))
                .accessibilityIdentifier(accessibilityIdentifier ?? "inspector.value.\(title.lowercased())")
                .onSubmit { onCommit?() }
            Text(unit).font(.system(size: 9)).foregroundStyle(VexelPalette.secondary).frame(width: 24, alignment: .leading)
        }
    }
}

struct VexelGraphEditor: View {
    @Environment(\.dismiss) private var dismiss
    let descriptors: [VexelPropertyDescriptor]
    let keyframesByProperty: [String: [VexelKeyframe]]
    let playheadTime: Double
    let onAddKeyframe: (String) -> Void
    let onRemoveKeyframe: (String) -> Void
    @State private var selectedPropertyID: String

    init(
        descriptors: [VexelPropertyDescriptor],
        keyframesByProperty: [String: [VexelKeyframe]],
        playheadTime: Double,
        onAddKeyframe: @escaping (String) -> Void,
        onRemoveKeyframe: @escaping (String) -> Void
    ) {
        self.descriptors = descriptors
        self.keyframesByProperty = keyframesByProperty
        self.playheadTime = playheadTime
        self.onAddKeyframe = onAddKeyframe
        self.onRemoveKeyframe = onRemoveKeyframe
        _selectedPropertyID = State(initialValue: descriptors.first?.id ?? "")
    }

    private var selectedKeyframes: [VexelKeyframe] {
        keyframesByProperty[selectedPropertyID] ?? []
    }

    private var hasKeyframeAtPlayhead: Bool {
        selectedKeyframes.contains { abs($0.time - playheadTime) < 0.000001 }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if descriptors.isEmpty {
                    Spacer()
                    Text("Select a supported layer to manage its keyframes.")
                        .font(.system(size: 13))
                        .foregroundStyle(VexelPalette.secondary)
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    Picker("Property", selection: $selectedPropertyID) {
                        ForEach(descriptors) { descriptor in
                            Text(descriptor.title).tag(descriptor.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(VexelPalette.accent)
                    .accessibilityIdentifier("keyframe.property")

                    HStack {
                        Text("PLAYHEAD")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(VexelPalette.secondary)
                        Spacer()
                        Text(String(format: "%.3f s", playheadTime))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(VexelPalette.text)
                    }
                    .padding(12)
                    .background(VexelPalette.card, in: RoundedRectangle(cornerRadius: 10))

                    VexelSectionLabel(title: "KEYFRAMES · \(selectedKeyframes.count)")
                    if selectedKeyframes.isEmpty {
                        Text("No keyframes on this property yet.")
                            .font(.system(size: 12))
                            .foregroundStyle(VexelPalette.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(VexelPalette.card, in: RoundedRectangle(cornerRadius: 10))
                    } else {
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(Array(selectedKeyframes.enumerated()), id: \.offset) { entry in
                                    HStack {
                                        Image(systemName: "diamond.fill")
                                            .font(.system(size: 9))
                                            .foregroundStyle(VexelPalette.accent)
                                        Text("Keyframe \(entry.offset + 1)")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(VexelPalette.text)
                                        Spacer()
                                        Text(String(format: "%.3f s", entry.element.time))
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(VexelPalette.secondary)
                                            .accessibilityIdentifier("keyframe.time.\(String(format: "%.3f", entry.element.time))")
                                    }
                                    .padding(11)
                                    .background(VexelPalette.card, in: RoundedRectangle(cornerRadius: 9))
                                }
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        Button {
                            onAddKeyframe(selectedPropertyID)
                        } label: {
                            Label("Add at playhead", systemImage: "diamond.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(VexelPalette.accent)
                        .accessibilityIdentifier("keyframe.add")

                        Button {
                            onRemoveKeyframe(selectedPropertyID)
                        } label: {
                            Label("Remove", systemImage: "minus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!hasKeyframeAtPlayhead)
                        .accessibilityIdentifier("keyframe.remove")
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(16)
            .background(VexelPalette.background)
            .navigationTitle("Keyframe editor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}

struct VexelCurveEditor: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("vexel.savedEasings") private var savedEasingsData = "[]"
    @State private var curveName = "Custom curve"
    @State private var showingSaveCurve = false
    @State private var x1 = 0.25
    @State private var y1 = 0.1
    @State private var x2 = 0.25
    @State private var y2 = 1.0
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                VexelSectionLabel(title: "Bezier interpolation")
                GeometryReader { proxy in
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(VexelPalette.preview)
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: proxy.size.height))
                            path.addCurve(to: CGPoint(x: proxy.size.width, y: 0),
                                          control1: CGPoint(x: proxy.size.width * x1, y: proxy.size.height * (1-y1)),
                                          control2: CGPoint(x: proxy.size.width * x2, y: proxy.size.height * (1-y2)))
                        }.stroke(VexelPalette.accent, lineWidth: 3)
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: proxy.size.height)); path.addLine(to: CGPoint(x: proxy.size.width, y: 0))
                        }.stroke(VexelPalette.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                }.frame(height: 220)
                curveSlider("Control point 1 X", value: $x1)
                curveSlider("Control point 1 Y", value: $y1)
                curveSlider("Control point 2 X", value: $x2)
                curveSlider("Control point 2 Y", value: $y2)
                HStack {
                    VexelActionButton(title: "Ease in", systemImage: "arrow.down.right") { x1 = 0.42; y1 = 0; x2 = 1; y2 = 1 }
                    VexelActionButton(title: "Ease out", systemImage: "arrow.up.right") { x1 = 0; y1 = 0; x2 = 0.58; y2 = 1 }
                    VexelActionButton(title: "Linear", systemImage: "line.diagonal") { x1 = 0.33; y1 = 0.33; x2 = 0.66; y2 = 0.66 }
                }
                HStack {
                    Menu {
                        ForEach(savedCurves) { curve in
                            Button(curve.name) {
                                x1 = curve.x1; y1 = curve.y1; x2 = curve.x2; y2 = curve.y2
                            }
                        }
                    } label: {
                        Label("Saved curves", systemImage: "bookmark")
                            .font(.system(size: 10, weight: .semibold)).foregroundStyle(VexelPalette.accent)
                    }
                    .disabled(savedCurves.isEmpty)
                    Spacer()
                    VexelActionButton(title: "Save curve", systemImage: "bookmark.fill", action: { showingSaveCurve = true })
                }
                Spacer()
            }
            .padding(16).background(VexelPalette.background)
            .navigationTitle("Curve editor").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .alert("Save curve", isPresented: $showingSaveCurve) {
            TextField("Curve name", text: $curveName)
            Button("Save", action: saveCurve)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Saved curves are available in the curve editor and Settings. Up to 24 are kept.")
        }
    }

    private var savedCurves: [VexelSavedEasing] {
        guard let data = savedEasingsData.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([VexelSavedEasing].self, from: data)) ?? []
    }

    private func saveCurve() {
        let trimmedName = curveName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmedName.isEmpty ? "Custom curve" : trimmedName
        let curve = VexelSavedEasing(name: name, x1: x1, y1: y1, x2: x2, y2: y2)
        var values = savedCurves
        values.removeAll { abs($0.x1 - x1) < 0.00001 && abs($0.y1 - y1) < 0.00001 && abs($0.x2 - x2) < 0.00001 && abs($0.y2 - y2) < 0.00001 }
        values.append(curve)
        if values.count > 24 { values = Array(values.suffix(24)) }
        guard let data = try? JSONEncoder().encode(values) else { return }
        savedEasingsData = String(decoding: data, as: UTF8.self)
        curveName = "Custom curve"
    }

    private func curveSlider(_ title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack { Text(title).font(.system(size: 11)).foregroundStyle(VexelPalette.soft); Spacer(); Text(value.wrappedValue.formatted(.number.precision(.fractionLength(2)))).font(.system(size: 10, design: .monospaced)).foregroundStyle(VexelPalette.secondary) }
            Slider(value: value, in: 0...1).tint(VexelPalette.accent)
        }
    }
}

struct VexelExportSheet: View {
    let project: VexelProjectItem
    @Environment(\.dismiss) private var dismiss
    @State private var format = "MP4"
    @State private var resolution = "1080p"
    @State private var fps = 30.0
    @State private var quality = 0.85
    var body: some View {
        NavigationStack {
            Form {
                Section("Output") {
                    Picker("Format", selection: $format) { Text("MP4").tag("MP4"); Text("MOV").tag("MOV"); Text("Image sequence").tag("Image sequence") }
                    Picker("Resolution", selection: $resolution) { Text("Original").tag("Original"); Text("1080p").tag("1080p"); Text("720p").tag("720p"); Text("4K").tag("4K") }
                    Picker("Frame rate", selection: $fps) { ForEach([24.0, 30.0, 60.0, 120.0], id: \.self) { Text("\(Int($0)) FPS").tag($0) } }
                    VStack(alignment: .leading) { Text("Quality · \(Int(quality * 100))%"); Slider(value: $quality, in: 0.1...1).tint(VexelPalette.accent) }
                }
                Section("Composition") {
                    LabeledContent("Size", value: "\(project.width) × \(project.height)")
                    LabeledContent("Duration", value: "\(Int(project.duration)) sec")
                }
                Section {
                    Text("Export UI is ready. The AVFoundation render pipeline will be connected after engine porting.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden).background(VexelPalette.background)
            .navigationTitle("Export").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Prepare") { dismiss() } } }
        }    }
}
