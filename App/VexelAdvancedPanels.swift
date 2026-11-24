import SwiftUI
import VexelCore

struct VexelPropertiesSheet: View {
    let layerName: String
    let layerKind: VexelTimelineTrack.Kind?
    let onAddEffect: () -> Void
    let effectIDs: [String]
    let onRemoveEffect: (String) -> Void
    let position: [Double]
    let onPositionCommit: (Double, Double) -> Void
    let transformValues: [String: [Double]]
    let onTransformCommit: (String, [Double]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var tab = "Transform"

    private var availableTabs: [String] {
        guard let layerKind else { return ["Composition"] }
        var values = ["Transform"]
        if layerKind == .text { values.append("Text") }
        if layerKind != .audio { values.append("Effects") }
        if layerKind == .visual || layerKind == .text || layerKind == .group { values.append("Masks") }
        if layerKind != .audio { values.append("Transitions") }
        return values
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Property group", selection: $tab) {
                    ForEach(availableTabs, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented)
                VexelPropertiesPanel(
                    tab: tab,
                    layerName: layerName,
                    layerKind: layerKind,
                    onCurve: {},
                    onAddEffect: onAddEffect,
                    effectIDs: effectIDs,
                    onRemoveEffect: onRemoveEffect,
                    position: position,
                    onPositionCommit: onPositionCommit,
                    transformValues: transformValues,
                    onTransformCommit: onTransformCommit
                )
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(VexelPalette.background)
            .navigationTitle("Properties")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}


struct VexelAudioWorkspace: View {
    @Environment(\.dismiss) private var dismiss
    @State private var master = 0.85
    @State private var trackOne = 0.72
    @State private var trackTwo = 0.62
    @State private var noiseReduction = false
    @State private var normalize = true
    @State private var eq: [Double] = [0, 0, 0, 0, 0]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VexelSectionLabel(title: "Mixer")
                    VexelPanel {
                        VStack(spacing: 14) {
                            mixerRow("Master", value: $master, symbol: "speaker.wave.3")
                            mixerRow("Track 1", value: $trackOne, symbol: "waveform")
                            mixerRow("Track 2", value: $trackTwo, symbol: "waveform")
                        }
                    }
                    VexelSectionLabel(title: "Equalizer", trailing: "5-BAND")
                    VexelPanel {
                        HStack(alignment: .bottom, spacing: 12) {
                            ForEach(eq.indices, id: \.self) { index in
                                VStack(spacing: 7) {
                                    Text("\(Int(eq[index] * 12))").font(.system(size: 8, design: .monospaced)).foregroundStyle(VexelPalette.secondary)
                                    Slider(value: $eq[index], in: -1...1).tint(VexelPalette.accent).rotationEffect(.degrees(-90)).frame(width: 85, height: 26)
                                    Text(["LOW", "LM", "MID", "HM", "HIGH"][index]).font(.system(size: 8, weight: .bold)).foregroundStyle(VexelPalette.secondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(height: 125)
                    }
                    VexelSectionLabel(title: "Processing")
                    VexelPanel {
                        Toggle("Noise reduction", isOn: $noiseReduction).tint(VexelPalette.accent)
                        Toggle("Normalize audio", isOn: $normalize).tint(VexelPalette.accent)
                        HStack { Text("Fade in"); Spacer(); Text("0.5 s").foregroundStyle(VexelPalette.secondary) }
                        HStack { Text("Fade out"); Spacer(); Text("0.5 s").foregroundStyle(VexelPalette.secondary) }
                    }
                    Text("Audio controls are presentation state until AVAudioEngine is connected.")
                        .font(.system(size: 10)).foregroundStyle(VexelPalette.secondary)
                }
                .padding(16)
            }
            .background(VexelPalette.background)
            .navigationTitle("Audio workspace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
        }
            }

    private func mixerRow(_ title: String, value: Binding<Double>, symbol: String) -> some View {
        HStack {
            Image(systemName: symbol).foregroundStyle(VexelPalette.accent).frame(width: 24)
            Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(VexelPalette.text).frame(width: 58, alignment: .leading)
            Slider(value: value, in: 0...1).tint(VexelPalette.accent)
            Text("\(Int(value.wrappedValue * 100))%").font(.system(size: 9, design: .monospaced)).foregroundStyle(VexelPalette.secondary).frame(width: 30)
        }
    }
}

struct VexelCaptionWorkspace: View {
    @Environment(\.dismiss) private var dismiss
    @State private var captions = ["Your first caption", "Second subtitle line"]
    @State private var selected = 0
    @State private var fontSize = 42.0
    @State private var background = true
    @State private var alignment = "Center"

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                VexelSectionLabel(title: "Caption segments", trailing: "\(captions.count) ITEMS")
                ForEach(captions.indices, id: \.self) { index in
                    HStack {
                        Text(String(format: "%02d", index + 1)).font(.system(size: 10, design: .monospaced)).foregroundStyle(VexelPalette.accent)
                        TextField("Caption text", text: $captions[index]).font(.system(size: 12))
                        Spacer()
                        Button { selected = index } label: { Image(systemName: selected == index ? "checkmark.circle.fill" : "circle").foregroundStyle(selected == index ? VexelPalette.accent : VexelPalette.secondary) }
                    }
                    .padding(11).background(VexelPalette.card, in: RoundedRectangle(cornerRadius: 10))
                }
                HStack {
                    VexelActionButton(title: "Add caption", systemImage: "plus", prominent: true) { captions.append("New caption"); selected = captions.count - 1 }
                    VexelActionButton(title: "Import SRT", systemImage: "doc.text") {}
                }
                VexelSectionLabel(title: "Caption style")
                VexelPanel {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack { Text("Font size"); Spacer(); Text("\(Int(fontSize)) pt").foregroundStyle(VexelPalette.secondary) }
                        Slider(value: $fontSize, in: 12...120).tint(VexelPalette.accent)
                        Toggle("Text background", isOn: $background).tint(VexelPalette.accent)
                        Picker("Alignment", selection: $alignment) {
                            Text("Left").tag("Left"); Text("Center").tag("Center"); Text("Right").tag("Right")
                        }.pickerStyle(.segmented)
                    }
                }
                Spacer()
            }
            .padding(16).background(VexelPalette.background)
            .navigationTitle("Captions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
        }
            }
}

struct VexelCameraWorkspace: View {
    @Environment(\.dismiss) private var dismiss
    @State private var projection = "Perspective"
    @State private var focalLength = 50.0
    @State private var focusDistance = 5.0
    @State private var depthOfField = false
    @State private var position: [Double] = [0, 0, 0]
    @State private var rotation: [Double] = [0, 0, 0]

    var body: some View {
        NavigationStack {
            Form {
                Section("Camera") {
                    Picker("Projection", selection: $projection) { Text("Perspective").tag("Perspective"); Text("Orthographic").tag("Orthographic") }
                    Toggle("Depth of field", isOn: $depthOfField).tint(VexelPalette.accent)
                    cameraSlider("Focal length", value: $focalLength, range: 10...200, unit: "mm")
                    cameraSlider("Focus distance", value: $focusDistance, range: 0.1...100, unit: "m")
                }
                Section("Position") {
                    ForEach(0..<3, id: \.self) { i in cameraSlider(["X", "Y", "Z"][i], value: $position[i], range: -1000...1000, unit: "px") }
                }
                Section("Rotation") {
                    ForEach(0..<3, id: \.self) { i in cameraSlider(["X", "Y", "Z"][i], value: $rotation[i], range: -360...360, unit: "°") }
                }
                Section {
                    Text("Camera controls are UI-only until the scene evaluator and 3D renderer are ported.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden).background(VexelPalette.background)
            .navigationTitle("Camera controls")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
        }
            }

    private func cameraSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack { Text(title); Spacer(); Text("\(value.wrappedValue, specifier: "%.1f") \(unit)").foregroundStyle(.secondary) }
            Slider(value: value, in: range).tint(VexelPalette.accent)
        }
    }
}

struct VexelCutoutBrushWorkspace: View {
    @Environment(\.dismiss) private var dismiss
    @State private var mode = "Keep"
    @State private var size = 0.12
    @State private var feather = 0.2
    @State private var opacity = 1.0
    @State private var currentFrame = 0
    @State private var propagate = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                VexelSectionLabel(title: "Roto brush", trailing: "FRAME \(currentFrame + 1)")
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(VexelPalette.preview)
                    VStack(spacing: 9) {
                        Image(systemName: "person.crop.rectangle").font(.system(size: 42, weight: .ultraLight)).foregroundStyle(VexelPalette.secondary)
                        Text("Select a video layer to paint a cutout matte").font(.system(size: 11)).foregroundStyle(VexelPalette.secondary)
                    }
                }
                .frame(maxHeight: .infinity)
                Picker("Brush mode", selection: $mode) {
                    Text("Keep").tag("Keep"); Text("Remove").tag("Remove")
                }.pickerStyle(.segmented)
                brushSlider("Brush size", value: $size)
                brushSlider("Feather", value: $feather)
                brushSlider("Opacity", value: $opacity)
                Toggle("Propagate strokes to nearby frames", isOn: $propagate).font(.system(size: 11)).tint(VexelPalette.accent)
                HStack {
                    VexelIconButton(symbol: "arrow.uturn.backward") {}
                    VexelActionButton(title: "Clear frame", systemImage: "eraser") {}
                    Spacer()
                    VexelIconButton(symbol: "chevron.left") { currentFrame = max(0, currentFrame - 1) }
                    VexelIconButton(symbol: "chevron.right") { currentFrame += 1 }
                    VexelActionButton(title: "Apply matte", systemImage: "checkmark", prominent: true) { dismiss() }
                }
            }
            .padding(16).background(VexelPalette.background)
            .navigationTitle("Cutout brush")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Close") { dismiss() } } }
        }
            }

    private func brushSlider(_ title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack { Text(title).font(.system(size: 10)); Spacer(); Text("\(Int(value.wrappedValue * 100))%").font(.system(size: 9, design: .monospaced)).foregroundStyle(VexelPalette.secondary) }
            Slider(value: value, in: 0...1).tint(VexelPalette.accent)
        }
    }
}

struct VexelExpressionWorkspace: View {
    @Environment(\.dismiss) private var dismiss
    @State private var expression = "wiggle(3, 40)"
    @State private var selectedPreset = "Wiggle"
    @State private var showValidation = false

    private let presets: [(String, String)] = [
        ("Wiggle", "wiggle(3, 40)"),
        ("Loop", "loopOut(\"pingpong\")"),
        ("Bounce", "value + Math.sin(time * 8) * 20"),
        ("Pulse", "100 + Math.sin(time * 4) * 10"),
        ("Time", "time * 100")
    ]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                VexelSectionLabel(title: "Expression editor", trailing: "JAVASCRIPT")
                Text("Expressions are evaluated by the project animation system. This editor is a UI shell until the expression runtime is ported.")
                    .font(.system(size: 11)).foregroundStyle(VexelPalette.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(presets, id: \.0) { preset in
                            Button(preset.0) { selectedPreset = preset.0; expression = preset.1 }
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(selectedPreset == preset.0 ? Color.black : VexelPalette.soft)
                                .padding(.horizontal, 11).padding(.vertical, 8)
                                .background(selectedPreset == preset.0 ? VexelPalette.accent : VexelPalette.field, in: Capsule())
                        }
                    }
                }
                TextEditor(text: $expression)
                    .font(.system(size: 13, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(VexelPalette.text)
                    .padding(10)
                    .frame(minHeight: 180)
                    .background(VexelPalette.preview, in: RoundedRectangle(cornerRadius: 12))
                HStack {
                    VexelActionButton(title: "Validate", systemImage: "checkmark.seal") { showValidation = true }
                    VexelActionButton(title: "Apply expression", systemImage: "play.fill", prominent: true) { showValidation = true }
                }
                if showValidation {
                    Label("Expression runtime not connected", systemImage: "info.circle")
                        .font(.system(size: 11)).foregroundStyle(VexelPalette.amber)
                }
                Spacer()
            }
            .padding(16).background(VexelPalette.background)
            .navigationTitle("Expression")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
        }
            }
}


struct VexelTextToSpeechWorkspace: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text = "Your next frame starts here."
    @State private var voice = "Kokoro · Heart"
    @State private var speed = 1.0
    @State private var pitch = 1.0
    @State private var format = "WAV"
    @State private var generated = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                VexelSectionLabel(title: "Speech synthesis", trailing: "TTS")
                TextEditor(text: $text)
                    .font(.system(size: 13))
                    .foregroundStyle(VexelPalette.text)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(minHeight: 120)
                    .background(VexelPalette.preview, in: RoundedRectangle(cornerRadius: 12))
                VexelPanel {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Voice", selection: $voice) {
                            Text("Kokoro · Heart").tag("Kokoro · Heart")
                            Text("Kokoro · Bella").tag("Kokoro · Bella")
                            Text("System voice").tag("System voice")
                        }
                        .tint(VexelPalette.accent)
                        slider("Speed", value: $speed, range: 0.5...2)
                        slider("Pitch", value: $pitch, range: 0.5...1.5)
                        Picker("Output format", selection: $format) {
                            Text("WAV").tag("WAV"); Text("M4A").tag("M4A")
                        }
                        .pickerStyle(.segmented)
                    }
                }
                VexelActionButton(title: "Generate speech layer", systemImage: "waveform", prominent: true) { generated = true }
                if generated {
                    Label("Speech generation UI is ready. Model download and audio synthesis are not connected yet.", systemImage: "info.circle")
                        .font(.system(size: 10)).foregroundStyle(VexelPalette.amber)
                }
                Spacer()
            }
            .padding(16).background(VexelPalette.background)
            .navigationTitle("Text to speech")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
        }
            }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack { Text(title).font(.system(size: 11)); Spacer(); Text(value.wrappedValue.formatted(.number.precision(.fractionLength(2)))).font(.system(size: 10, design: .monospaced)).foregroundStyle(VexelPalette.secondary) }
            Slider(value: value, in: range).tint(VexelPalette.accent)
        }
    }
}

struct VexelEffectDetailSheet: View {
    let effect: VexelEffectItem
    let targetLayerName: String?
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var parameterValues: [String: JSONValue] = [:]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VexelSectionLabel(title: effect.category, trailing: effect.id.uppercased())
                    RoundedRectangle(cornerRadius: 14)
                        .fill(VexelPalette.preview)
                        .frame(height: 132)
                        .overlay {
                            VStack(spacing: 8) {
                                Image(systemName: "sparkles").font(.system(size: 34, weight: .ultraLight)).foregroundStyle(VexelPalette.accent)
                                Text(effect.name).font(.system(size: 15, weight: .bold)).foregroundStyle(VexelPalette.text)
                                Text(effect.target == "layer_3d" ? "3D LAYER EFFECT" : "LAYER EFFECT")
                                    .font(.system(size: 8, weight: .bold)).tracking(1.5).foregroundStyle(VexelPalette.secondary)
                            }
                        }

                    VexelPanel {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Effect parameters").font(.system(size: 13, weight: .bold)).foregroundStyle(VexelPalette.text)
                                Spacer()
                                Text("\(effect.params.count) PARAMETERS").font(.system(size: 8, weight: .semibold, design: .monospaced)).foregroundStyle(VexelPalette.secondary)
                            }
                            if effect.params.isEmpty {
                                Text("This effect has no editable parameters in the source registry.")
                                    .font(.system(size: 11)).foregroundStyle(VexelPalette.secondary)
                            } else {
                                ForEach(effect.params) { parameter in
                                    parameterControl(parameter)
                                }
                                .disabled(true)
                            }
                        }
                    }

                    VexelPanel {
                        VStack(alignment: .leading, spacing: 7) {
                            Label(effect.needsBackdrop ? "Reads the backdrop" : "Layer-local processing", systemImage: "square.3.layers.3d")
                            Text("Target layer: \(targetLayerName ?? "None selected")")
                                .font(.system(size: 10)).foregroundStyle(VexelPalette.secondary)
                                .font(.system(size: 11, weight: .semibold)).foregroundStyle(VexelPalette.text)
                            if effect.target == "layer_3d" {
                                Text("This effect only accepts rendered 3D object or model layers. Target validation will be enforced by the editing engine.")
                                    .font(.system(size: 10)).foregroundStyle(VexelPalette.secondary)
                            } else {
                                Text("Parameter names, types, defaults and numeric bounds are loaded from the pinned source registry.")
                                    .font(.system(size: 10)).foregroundStyle(VexelPalette.secondary)
                            }
                        }
                    }

                    VexelActionButton(title: "Add to effect stack", systemImage: "plus", prominent: true) { onApply(); dismiss() }
                        .disabled(targetLayerName == nil)
                    Text("Effect identifiers can be added to the layer stack. Parameter editing and GPU execution are disabled until serialization and the shader runtime are integrated.")
                        .font(.system(size: 10)).foregroundStyle(VexelPalette.secondary)
                }
                .padding(16)
            }
            .background(VexelPalette.background)
            .navigationTitle(effect.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Close") { dismiss() } } }
        }
        .onAppear {
            parameterValues = Dictionary(uniqueKeysWithValues: effect.params.map { ($0.name, $0.defaultValue) })
        }
    }

    @ViewBuilder
    private func parameterControl(_ parameter: VexelEffectParameter) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            switch parameter.type {
            case "number", "integer":
                HStack {
                    Text(parameter.displayName).font(.system(size: 11, weight: .medium)).foregroundStyle(VexelPalette.text)
                    Spacer()
                    Text(numberBinding(parameter).wrappedValue.formatted(.number.precision(.fractionLength(0...3))))
                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(VexelPalette.secondary)
                }
                Slider(
                    value: numberBinding(parameter),
                    in: parameterRange(parameter),
                    step: parameter.type == "integer" ? 1 : sliderStep(parameter)
                )
                .tint(VexelPalette.accent)

            case "boolean":
                Toggle(parameter.displayName, isOn: boolBinding(parameter))
                    .font(.system(size: 11, weight: .medium))
                    .tint(VexelPalette.accent)

            case "choice":
                Picker(parameter.displayName, selection: stringBinding(parameter)) {
                    ForEach(parameter.choices ?? [], id: \.self) { choice in
                        Text(choice).tag(choice)
                    }
                }
                .font(.system(size: 11))
                .tint(VexelPalette.accent)

            case "color":
                HStack {
                    Text(parameter.displayName).font(.system(size: 11, weight: .medium)).foregroundStyle(VexelPalette.text)
                    Spacer()
                    TextField("#FFFFFF", text: stringBinding(parameter))
                        .font(.system(size: 10, design: .monospaced))
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .frame(maxWidth: 120)
                }

            case "point":
                Text(parameter.displayName).font(.system(size: 11, weight: .medium)).foregroundStyle(VexelPalette.text)
                pointControl(parameter, index: 0, label: "X")
                pointControl(parameter, index: 1, label: "Y")

            case "stops":
                let count = parameter.defaultValue.arrayValue?.count ?? 0
                HStack {
                    Text(parameter.displayName).font(.system(size: 11, weight: .medium)).foregroundStyle(VexelPalette.text)
                    Spacer()
                    Text("\(count) gradient stops").font(.system(size: 10, design: .monospaced)).foregroundStyle(VexelPalette.secondary)
                }
                Text("Gradient stop editing is not connected yet.")
                    .font(.system(size: 9)).foregroundStyle(VexelPalette.secondary)

            default:
                Text(parameter.displayName).font(.system(size: 11, weight: .medium)).foregroundStyle(VexelPalette.text)
                Text("Unsupported source parameter type: \(parameter.type)")
                    .font(.system(size: 9)).foregroundStyle(VexelPalette.secondary)
            }
        }
    }

    private func parameterRange(_ parameter: VexelEffectParameter) -> ClosedRange<Double> {
        let fallback = parameter.defaultValue.numberValue ?? 0
        let lower = parameter.min ?? fallback - 1
        let upper = parameter.max ?? fallback + 1
        return lower < upper ? lower...upper : (fallback - 1)...(fallback + 1)
    }

    private func sliderStep(_ parameter: VexelEffectParameter) -> Double {
        let range = parameterRange(parameter)
        return range.upperBound - range.lowerBound > 100 ? 0.1 : 0.01
    }

    private func numberBinding(_ parameter: VexelEffectParameter) -> Binding<Double> {
        Binding(
            get: { parameterValues[parameter.name]?.numberValue ?? parameter.defaultValue.numberValue ?? 0 },
            set: { parameterValues[parameter.name] = .number($0) }
        )
    }

    private func boolBinding(_ parameter: VexelEffectParameter) -> Binding<Bool> {
        Binding(
            get: {
                guard case .bool(let value) = parameterValues[parameter.name] ?? parameter.defaultValue else { return false }
                return value
            },
            set: { parameterValues[parameter.name] = .bool($0) }
        )
    }

    private func stringBinding(_ parameter: VexelEffectParameter) -> Binding<String> {
        Binding(
            get: { parameterValues[parameter.name]?.stringValue ?? parameter.defaultValue.stringValue ?? "" },
            set: { parameterValues[parameter.name] = .string($0) }
        )
    }

    private func pointControl(_ parameter: VexelEffectParameter, index: Int, label: String) -> some View {
        let binding = Binding<Double>(
            get: {
                let values = parameterValues[parameter.name]?.arrayValue ?? parameter.defaultValue.arrayValue ?? []
                return values.indices.contains(index) ? (values[index].numberValue ?? 0) : 0
            },
            set: { value in
                var values = parameterValues[parameter.name]?.arrayValue ?? parameter.defaultValue.arrayValue ?? [.number(0), .number(0)]
                while values.count < 2 { values.append(.number(0)) }
                values[index] = .number(value)
                parameterValues[parameter.name] = .array(values)
            }
        )
        return HStack {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundStyle(VexelPalette.secondary).frame(width: 14)
            Slider(value: binding, in: -2000...2000).tint(VexelPalette.accent)
            Text(binding.wrappedValue.formatted(.number.precision(.fractionLength(0...1))))
                .font(.system(size: 9, design: .monospaced)).foregroundStyle(VexelPalette.secondary).frame(width: 54, alignment: .trailing)
        }
    }
}


struct VexelRealCameraWorkspace: View {
    @Environment(\.dismiss) private var dismiss
    @State private var followX = true
    @State private var followY = true
    @State private var followZ = false
    @State private var intensity = 1.0
    @State private var smoothing = 0.65
    @State private var simplify = true
    @State private var tolerance = 0.5
    @State private var calibrateAtStart = true
    @State private var recordPosition = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VexelSectionLabel(title: "Real camera motion", trailing: "SENSOR INPUT")
                    Text("Capture device movement and convert it into camera keyframes. The sensor capture and keyframe pipeline are not connected yet.")
                        .font(.system(size: 11)).foregroundStyle(VexelPalette.secondary)
                    VexelPanel {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Follow axes").font(.system(size: 12, weight: .bold)).foregroundStyle(VexelPalette.text)
                            HStack {
                                axisToggle("X", value: $followX)
                                axisToggle("Y", value: $followY)
                                axisToggle("Z", value: $followZ)
                            }
                            realCameraSlider("Intensity", value: $intensity, range: 0.1...3, suffix: "×")
                        }
                    }
                    VexelSectionLabel(title: "Smoothing")
                    VexelPanel {
                        VStack(alignment: .leading, spacing: 12) {
                            realCameraSlider("Smoothing", value: $smoothing, range: 0...1, suffix: "%", multiplier: 100)
                            Toggle("Simplify keyframes", isOn: $simplify).tint(VexelPalette.accent)
                            if simplify {
                                realCameraSlider("Tolerance", value: $tolerance, range: 0.05...3, suffix: "°")
                            }
                        }
                    }
                    VexelSectionLabel(title: "Capture options")
                    VexelPanel {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Calibrate at start", isOn: $calibrateAtStart).tint(VexelPalette.accent)
                            Toggle("Record position", isOn: $recordPosition).tint(VexelPalette.accent)
                        }
                    }
                    VexelActionButton(title: "Record motion", systemImage: "record.circle", prominent: true) {}
                        .disabled(true)
                    Text("Recording, countdown, review, retry, accept and discard states will be enabled with the CoreMotion capture controller.")
                        .font(.system(size: 10)).foregroundStyle(VexelPalette.secondary)
                }
                .padding(16)
            }
            .background(VexelPalette.background)
            .navigationTitle("Real camera")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
        }
    }

    private func axisToggle(_ title: String, value: Binding<Bool>) -> some View {
        Toggle(title, isOn: value).labelsHidden().toggleStyle(.button).tint(VexelPalette.accent)
    }

    private func realCameraSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, suffix: String, multiplier: Double = 1) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(VexelPalette.text)
                Spacer()
                Text("\(value.wrappedValue * multiplier, specifier: "%.2f")\(suffix)")
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(VexelPalette.secondary)
            }
            Slider(value: value, in: range).tint(VexelPalette.accent)
        }
    }
}

struct VexelSavedVersionsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 36, weight: .light)).foregroundStyle(VexelPalette.secondary)
                Text("No saved versions").font(.system(size: 15, weight: .bold)).foregroundStyle(VexelPalette.text)
                Text("Recovery snapshots and restorable project versions will appear here after the project snapshot store is implemented.")
                    .font(.system(size: 11)).foregroundStyle(VexelPalette.secondary).multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(20).background(VexelPalette.background)
            .navigationTitle("Saved versions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}
