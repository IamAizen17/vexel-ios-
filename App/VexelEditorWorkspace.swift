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
    @State private var showGraph = false
    @State private var showCurve = false
    @State private var isPlaying = false
    @State private var currentTime = 0.0
    @State private var showRename = false
    @State private var undoCount = 0
    @State private var redoCount = 0
    @State private var showingMediaPicker = false
    @State private var showingAudioPicker = false
    @State private var showingNotice: String?
    @State private var layerNames: [String] = ["Text Layer", "Shape Layer", "Audio Layer"]
    @State private var showLayerInspector = false

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
                        selectionBar
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
                selectionBar
                toolBar
            }
        }
        .vexelScreenBackground()
        .sheet(item: $selectedTool) { tool in
            VexelToolSheet(
                tool: tool,
                layerNames: $layerNames,
                onAction: { action in handleToolAction(action, for: tool) },
                onGraph: { showGraph = true },
                onCurve: { showCurve = true }
            )
            .presentationDetents(tool == .layers || tool == .effects || tool == .plugins ? [.large] : [.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showExport) { VexelExportSheet(project: project) .presentationDetents([.medium, .large]) }
        .sheet(isPresented: $showCompositionSettings) { CompositionSettingsSheet(project: $project) .presentationDetents([.medium, .large]) }
        .sheet(isPresented: $showGraph) { VexelGraphEditor() .presentationDetents([.large]) }
        .sheet(isPresented: $showCurve) { VexelCurveEditor() .presentationDetents([.large]) }
        .sheet(isPresented: $showingMediaPicker) {
            MediaPicker { _ in
                layerNames.insert("Image Layer", at: 0)
                project.layerNames = layerNames
                onProjectChange(project)
            }
        }
        .fileImporter(isPresented: $showingAudioPicker, allowedContentTypes: [.audio], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard !urls.isEmpty else { return }
                layerNames.insert("Audio Layer", at: 0)
                project.layerNames = layerNames
                onProjectChange(project)
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
        .onChange(of: currentTime) { _ in project.modified = Date() }
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
            VexelIconButton(symbol: "arrow.uturn.backward", disabled: undoCount == 0) { undoCount = max(0, undoCount - 1); redoCount += 1 }
            VexelIconButton(symbol: "arrow.uturn.forward", disabled: redoCount == 0) { redoCount = max(0, redoCount - 1); undoCount += 1 }
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
            VexelIconButton(symbol: "repeat") { showingNotice = "Loop playback controls will connect to the timeline engine." }
            Spacer()
            Text(String(format: "%.2f s", currentTime))
                .font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(VexelPalette.accent)
        }
        .padding(.horizontal, 14).padding(.vertical, 7)
        .background(VexelPalette.bar.opacity(0.8))
    }

    private var timelinePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VexelSectionLabel(title: "Timeline", trailing: "\(layerNames.count) TRACKS")
                Spacer()
                Button { showGraph = true } label: {
                    Label("Graph", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.system(size: 10, weight: .semibold)).foregroundStyle(VexelPalette.accent)
                }.buttonStyle(.plain)
            }
            GeometryReader { proxy in
                let width = max(proxy.size.width - 80, 120)
                VStack(spacing: 5) {
                    HStack(spacing: 0) {
                        Text("LAYER").frame(width: 80, alignment: .leading)
                        ForEach(0..<5, id: \.self) { tick in
                            Text("\(tick * 2)s").frame(maxWidth: .infinity)
                        }
                    }
                    .font(.system(size: 8, weight: .semibold, design: .monospaced)).foregroundStyle(VexelPalette.secondary)
                    HStack(spacing: 0) {
                        Rectangle().fill(VexelPalette.line).frame(width: 80, height: 1)
                        Rectangle().fill(VexelPalette.line).frame(height: 1)
                    }
                    ForEach(Array(layerNames.enumerated()), id: \.offset) { index, name in
                        HStack(spacing: 5) {
                            Button { selectedLayer = index; showLayerInspector = true } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: index == 2 ? "waveform" : (index == 0 ? "textformat" : "square"))
                                        .foregroundStyle(index == 2 ? VexelPalette.pink : VexelPalette.accent)
                                    Text(name).lineLimit(1)
                                }
                                .font(.system(size: 9, weight: .medium)).foregroundStyle(VexelPalette.soft)
                                .frame(width: 80, alignment: .leading)
                            }.buttonStyle(.plain)
                            GeometryReader { clip in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(index == 2 ? VexelPalette.clipAudio.opacity(0.85) : (index == 0 ? VexelPalette.clipText : VexelPalette.teal.opacity(0.5)))
                                    .frame(width: max(clip.size.width * 0.68, 36), height: 22)
                                    .overlay(alignment: .leading) {
                                        Text(name.uppercased()).font(.system(size: 7, weight: .bold)).lineLimit(1).padding(.horizontal, 6).foregroundStyle(.white.opacity(0.85))
                                    }
                                    .offset(x: CGFloat(index * 18))
                            }
                        }
                        .padding(4)
                        .background(selectedLayer == index ? VexelPalette.accent.opacity(0.08) : VexelPalette.lane, in: RoundedRectangle(cornerRadius: 6))
                        .onTapGesture { selectedLayer = index }
                    }
                }
                .overlay(alignment: .leading) {
                    Rectangle().fill(VexelPalette.accent).frame(width: 1.5).offset(x: 80 + width * CGFloat(currentTime / max(project.duration, 0.1)))
                }
            }
            .frame(height: CGFloat(max(90, layerNames.count * 32 + 25)))
            Slider(value: $currentTime, in: 0...max(project.duration, 0.1))
                .tint(VexelPalette.accent)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(VexelPalette.sheet)
    }

    private var selectionBar: some View {
        HStack(spacing: 8) {
            Button { selectedTool = .layers } label: {
                Label("Layers", systemImage: "square.3.layers.3d")
                    .font(.system(size: 10, weight: .semibold))
            }
            Spacer()
            Button { showLayerInspector = true; selectedTool = .layers } label: {
                Label("Properties", systemImage: "slider.horizontal.3")
                    .font(.system(size: 10, weight: .semibold))
            }
            Button { undoCount += 1; redoCount = 0 } label: {
                Image(systemName: "plus.square.on.square").font(.system(size: 13))
            }
            Button { if !layerNames.isEmpty { layerNames.remove(at: min(selectedLayer, layerNames.count - 1)); selectedLayer = max(0, selectedLayer - 1) } } label: {
                Image(systemName: "trash").font(.system(size: 13))
            }
        }
        .foregroundStyle(VexelPalette.soft)
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(VexelPalette.bar)
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
                ForEach(["Transform", "Style", "Content", "Effects", "Masks", "Layer"], id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu).tint(VexelPalette.accent)
            VexelPropertiesPanel(tab: selectedTab, layerName: layerNames.indices.contains(selectedLayer) ? layerNames[selectedLayer] : "Composition", onCurve: { showCurve = true })
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(VexelPalette.sheet, in: RoundedRectangle(cornerRadius: 16))
    }

    private func handleToolAction(_ action: String, for tool: VexelEditorTool) {
        switch action {
        case "add-text": layerNames.insert("Text Layer", at: 0); selectedTool = nil
        case "add-shape": layerNames.insert("Shape Layer", at: 0); selectedTool = nil
        case "pick-image": showingMediaPicker = true; selectedTool = nil
        case "pick-audio": showingAudioPicker = true; selectedTool = nil
        case "show-export": showExport = true; selectedTool = nil
        case "show-graph": showGraph = true
        case "show-curve": showCurve = true
        case "show-composition": showCompositionSettings = true
        case "show-plugins": selectedTool = .plugins
        case "add-layer": layerNames.insert("New Layer", at: 0); selectedTool = nil
        default: showingNotice = "\(tool.rawValue) controls are ready for the native editing engine integration."
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
        .preferredColorScheme(.dark)
    }
}

private struct CompositionSettingsSheet: View {
    @Binding var project: VexelProjectItem
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
            }
            .scrollContentBackground(.hidden).background(VexelPalette.background)
            .navigationTitle("Composition settings").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }.preferredColorScheme(.dark)
    }
}

private struct VexelExportSheet: View {
    let project: VexelProjectItem
    @Environment(\.dismiss) private var dismiss
    @State private var resolution = "1080p"
    @State private var format = "MP4"
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
                Section("Project") {
                    LabeledContent("Composition", value: "\(project.width) × \(project.height)")
                    LabeledContent("Duration", value: "\(Int(project.duration)) sec")
                }
                Section {
                    Text("Export controls are designed. Rendering and AVFoundation export will be connected after the editor engine port.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden).background(VexelPalette.background)
            .navigationTitle("Export").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Prepare") { dismiss() } }
            }
        }.preferredColorScheme(.dark)
    }
}
