import SwiftUI

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

    private var layersPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VexelSectionLabel(title: "Composition layers", trailing: "\(layerNames.count) TOTAL")
                Spacer()
                Button { layerNames.insert("New Layer", at: 0) } label: { Image(systemName: "plus.circle.fill").foregroundStyle(VexelPalette.accent).font(.system(size: 21)) }
            }
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(layerNames.enumerated()), id: \.offset) { index, name in
                        HStack(spacing: 10) {
                            Image(systemName: index == 2 ? "waveform" : (index == 0 ? "textformat" : "square"))
                                .foregroundStyle(index == 2 ? VexelPalette.pink : VexelPalette.accent)
                                .frame(width: 32, height: 32).background(VexelPalette.field, in: RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(name).font(.system(size: 12, weight: .semibold)).foregroundStyle(VexelPalette.text)
                                Text(index == 2 ? "Audio · Stereo" : "2D Layer · Visible").font(.system(size: 9)).foregroundStyle(VexelPalette.secondary)
                            }
                            Spacer()
                            Image(systemName: "eye").foregroundStyle(VexelPalette.secondary)
                            Image(systemName: "lock.open").foregroundStyle(VexelPalette.secondary)
                        }
                        .padding(10).background(VexelPalette.card, in: RoundedRectangle(cornerRadius: 11))
                    }
                }
            }
            HStack {
                VexelActionButton(title: "Add layer", systemImage: "plus", prominent: true) { layerNames.insert("New Layer", at: 0) }
                VexelActionButton(title: "Duplicate", systemImage: "plus.square.on.square") { if let first = layerNames.first { layerNames.insert(first + " Copy", at: 0) } }
            }
        }
    }

    private var shapesPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            VexelSectionLabel(title: "2D primitives")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(["Rectangle", "Ellipse", "Polygon", "Star", "Line", "Path"], id: \.self) { shape in
                    toolTile(shape, symbol: shapeSymbol(shape)) {
                        layerNames.insert("\(shape) Layer", at: 0)
                    }
                }
            }
            VexelSectionLabel(title: "3D primitives")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(["Cube", "Sphere", "Cylinder", "Cone", "Plane", "Torus", "Point light", "Spot light", "Area light"], id: \.self) { shape in
                    toolTile(shape, symbol: "cube") { layerNames.insert("\(shape) Layer", at: 0) }
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
            VexelActionButton(title: "Add 3D text", systemImage: "cube.transparent") { layerNames.insert("3D Text Layer", at: 0) }
            Spacer()
        }
    }

    private var mediaPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            VexelSectionLabel(title: "Import media")
            mediaRow("Images", detail: "PNG, JPEG, HEIC", symbol: "photo", action: "pick-image")
            mediaRow("Video", detail: "MOV, MP4", symbol: "film", action: "pick-image")
            mediaRow("Audio", detail: "WAV, MP3, M4A", symbol: "waveform", action: "pick-audio")
            mediaRow("3D models", detail: "GLB, glTF", symbol: "cube", action: "pick-image")
            mediaRow("Fonts", detail: "OTF, TTF", symbol: "textformat", action: "pick-image")
            VexelPanel {
                Label("Imported assets will be listed in the project media bin.", systemImage: "info.circle")
                    .font(.system(size: 11)).foregroundStyle(VexelPalette.secondary)
            }
            VexelActionButton(title: "Open cutout brush", systemImage: "scribble.variable") { advancedPage = .cutout }
            Spacer()
        }
    }

    private var modelPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            VexelSectionLabel(title: "3D scene objects")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(["Cube", "Sphere", "Cylinder", "Cone", "Plane", "Torus", "Text 3D", "Null 3D", "Camera", "Environment"], id: \.self) { name in
                    toolTile(name, symbol: "cube.transparent") { layerNames.insert(name, at: 0) }
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
                        .disabled(!shortcutAvailable(item.2))
                        .opacity(shortcutAvailable(item.2) ? 1 : 0.4)
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
                        VexelActionButton(title: "Curve editor", systemImage: "waveform.path", action: onCurve)
                        VexelActionButton(title: "Expressions", systemImage: "chevron.left.forwardslash.chevron.right") { advancedPage = .expression }
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
                VStack(alignment: .leading, spacing: 10) {
                    Label("Audio mixer", systemImage: "slider.horizontal.3").font(.system(size: 13, weight: .bold)).foregroundStyle(VexelPalette.text)
                    ForEach(["Master", "Track 1", "Track 2"], id: \.self) { track in
                        HStack {
                            Text(track).font(.system(size: 11)).foregroundStyle(VexelPalette.soft)
                            Slider(value: .constant(0.8)).tint(VexelPalette.accent)
                            Text("-2 dB").font(.system(size: 9, design: .monospaced)).foregroundStyle(VexelPalette.secondary)
                        }
                    }
                }
            }
            mediaRow("Add audio", detail: "Import audio from Files or Photos", symbol: "waveform", action: "pick-audio")
            mediaRow("Record voiceover", detail: "Microphone capture", symbol: "mic", action: "record")
            VexelActionButton(title: "Open mixer and EQ", systemImage: "slider.horizontal.3", prominent: true) { advancedPage = .audio }
            VexelSectionLabel(title: "Audio processing")
            ForEach(["Waveform display", "Noise reduction", "Fade in / out", "Time stretch", "Beat markers"], id: \.self) { item in
                HStack { Text(item).font(.system(size: 12)).foregroundStyle(VexelPalette.text); Spacer(); Image(systemName: "chevron.right").foregroundStyle(VexelPalette.secondary) }
                    .padding(11).background(VexelPalette.card, in: RoundedRectangle(cornerRadius: 9))
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

    private func mediaRow(_ title: String, detail: String, symbol: String, action: String) -> some View {
        Button { onAction(action) } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol).foregroundStyle(VexelPalette.accent).frame(width: 34, height: 34).background(VexelPalette.field, in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(VexelPalette.text)
                    Text(detail).font(.system(size: 10)).foregroundStyle(VexelPalette.secondary)
                }
                Spacer()
                Image(systemName: "plus.circle").foregroundStyle(VexelPalette.accent)
            }
            .padding(10).background(VexelPalette.card, in: RoundedRectangle(cornerRadius: 11))
        }.buttonStyle(.plain)
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
                        valueField("X", value: $positionX, unit: "px")
                        valueField("Y", value: $positionY, unit: "px")
                    }
                    propertyGroup("ANCHOR") {
                        valueField("X", value: $anchorX, unit: "px")
                        valueField("Y", value: $anchorY, unit: "px")
                    }
                    propertyGroup("SCALE") {
                        valueField("X", value: $scaleX, unit: "%")
                        valueField("Y", value: $scaleY, unit: "%")
                    }
                    propertyGroup("ROTATION") { valueField("Z", value: $rotation, unit: "°") }
                    propertyGroup("OPACITY") { valueField("Alpha", value: $opacity, unit: "%") }
                    propertyGroup("LAYER SETTINGS") {
                        Toggle("Visible", isOn: $visible).tint(VexelPalette.accent)
                        Toggle("Locked", isOn: $locked).tint(VexelPalette.accent)
                        valueField("Start", value: $startTime, unit: "s")
                        valueField("Duration", value: $layerDuration, unit: "s")
                        Picker("Blend mode", selection: $blendMode) {
                            ForEach(["Normal", "Add", "Multiply", "Screen"], id: \.self) { Text($0).tag($0) }
                        }.tint(VexelPalette.accent)
                        Toggle("Motion blur", isOn: $motionBlur).tint(VexelPalette.accent)
                    }
                    propertyGroup("KEYFRAMES") {
                        HStack {
                            VexelActionButton(title: "Add keyframe", systemImage: "diamond.fill") {}
                                .disabled(true)
                            VexelActionButton(title: "Edit curve", systemImage: "point.topleft.down.to.point.bottomright.curvepath", action: onCurve)
                        }
                        Text("Keyframe commands and parenting are pending the editing engine.")
                            .font(.system(size: 9)).foregroundStyle(VexelPalette.secondary)
                    }

                case "Text":
                    propertyGroup("TEXT CONTENT") {
                        TextEditor(text: $textContent)
                            .font(.system(size: 12))
                            .frame(minHeight: 76)
                            .scrollContentBackground(.hidden)
                            .padding(6)
                            .background(VexelPalette.field, in: RoundedRectangle(cornerRadius: 8))
                    }
                    propertyGroup("FONT") {
                        Picker("Family", selection: $fontFamily) {
                            ForEach(["sans-serif", "serif", "monospace", "cursive", "sans-serif-condensed"], id: \.self) { Text($0).tag($0) }
                        }.tint(VexelPalette.accent)
                        valueField("Size", value: $fontSize, unit: "px")
                        valueField("Weight", value: $fontWeight, unit: "")
                        Toggle("Italic", isOn: $italic).tint(VexelPalette.accent)
                        valueField("Line height", value: $lineHeight, unit: "×")
                        valueField("Letter spacing", value: $letterSpacing, unit: "em")
                        Picker("Alignment", selection: $textAlignment) {
                            ForEach(["Left", "Center", "Right"], id: \.self) { Text($0).tag($0) }
                        }.tint(VexelPalette.accent)
                    }
                    propertyGroup("TEXT ANIMATORS") {
                        Picker("Animator type", selection: $animatorType) {
                            ForEach(["Typewriter", "Fade", "Slide up", "Slide down", "Slide left", "Slide right", "Scale", "Rotate", "Wave"], id: \.self) { Text($0).tag($0) }
                        }.tint(VexelPalette.accent)
                        Text("Character, word and line selectors, ordering, stagger, duration and expression selectors will be connected to the text animation model.")
                            .font(.system(size: 9)).foregroundStyle(VexelPalette.secondary)
                    }

                case "Effects":
                    propertyGroup("EFFECT STACK") {
                        Text("No effects applied").font(.system(size: 11)).foregroundStyle(VexelPalette.secondary)
                        VexelActionButton(title: "Open effect library", systemImage: "plus", prominent: true, action: onAddEffect)
                    }
                    Text("Effect parameter controls are generated from the source registry in the effect browser. Effect stack ordering and persistence are pending.")
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

                Text("Inspector controls are currently UI state only. Changes are not yet committed to the project engine.")
                    .font(.system(size: 9)).foregroundStyle(VexelPalette.secondary)
            }
            .padding(.bottom, 12)
        }
    }

    private func propertyGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            VexelSectionLabel(title: title)
            VexelPanel(padding: 10) { VStack(alignment: .leading, spacing: 9, content: content) }
        }
    }

    private func valueField(_ title: String, value: Binding<Double>, unit: String) -> some View {
        HStack {
            Text(title).font(.system(size: 10, weight: .medium)).foregroundStyle(VexelPalette.soft)
            Spacer()
            TextField(title, value: value, format: .number.precision(.fractionLength(0...2)))
                .multilineTextAlignment(.trailing).keyboardType(.numbersAndPunctuation)
                .font(.system(size: 10, design: .monospaced)).foregroundStyle(VexelPalette.text)
                .frame(width: 64).padding(6).background(VexelPalette.field, in: RoundedRectangle(cornerRadius: 6))
            Text(unit).font(.system(size: 9)).foregroundStyle(VexelPalette.secondary).frame(width: 24, alignment: .leading)
        }
    }
}

struct VexelGraphEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProperty = "Position X"
    @State private var smooth = true
    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Picker("Property", selection: $selectedProperty) {
                    ForEach(["Position X", "Position Y", "Scale", "Rotation", "Opacity"], id: \.self) { Text($0).tag($0) }
                }.pickerStyle(.menu).tint(VexelPalette.accent)
                GeometryReader { proxy in
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(VexelPalette.preview)
                        Path { path in
                            for x in 0...8 {
                                let px = CGFloat(x) * proxy.size.width / 8
                                path.move(to: CGPoint(x: px, y: 0)); path.addLine(to: CGPoint(x: px, y: proxy.size.height))
                            }
                            for y in 0...5 {
                                let py = CGFloat(y) * proxy.size.height / 5
                                path.move(to: CGPoint(x: 0, y: py)); path.addLine(to: CGPoint(x: proxy.size.width, y: py))
                            }
                        }.stroke(VexelPalette.line, lineWidth: 0.7)
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: proxy.size.height * 0.82))
                            path.addCurve(to: CGPoint(x: proxy.size.width, y: proxy.size.height * 0.18), control1: CGPoint(x: proxy.size.width * 0.25, y: proxy.size.height * 0.82), control2: CGPoint(x: proxy.size.width * 0.65, y: proxy.size.height * 0.18))
                        }.stroke(VexelPalette.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        ForEach(0..<4, id: \.self) { i in
                            Circle().fill(VexelPalette.amber).frame(width: 9, height: 9).position(x: proxy.size.width * CGFloat(i) / 3, y: proxy.size.height * (0.82 - CGFloat(i) / 3 * 0.64))
                        }
                    }
                }
                .frame(minHeight: 220)
                VexelPanel {
                    Toggle("Smooth interpolation", isOn: $smooth).tint(VexelPalette.accent)
                    HStack {
                        VexelActionButton(title: "Add keyframe", systemImage: "diamond.fill", prominent: true) {}
                        VexelActionButton(title: "Fit graph", systemImage: "arrow.up.left.and.arrow.down.right") {}
                    }
                }
                Spacer()
            }
            .padding(16).background(VexelPalette.background)
            .navigationTitle("Graph editor").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }    }
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
