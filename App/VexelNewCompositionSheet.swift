import SwiftUI

struct VexelNewCompositionSheet: View {
    let onCreate: (VexelProjectItem) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = "Untitled Composition"
    @State private var width: Double
    @State private var height: Double
    @State private var fps: Double
    @State private var duration: Double

    private let frameRates = [24.0, 25.0, 30.0, 50.0, 60.0, 120.0]

    init(onCreate: @escaping (VexelProjectItem) -> Void) {
        self.onCreate = onCreate
        let saved = VexelCompositionDefaults.load()
        _width = State(initialValue: Double(saved.width))
        _height = State(initialValue: Double(saved.height))
        _fps = State(initialValue: Double(saved.fps))
        _duration = State(initialValue: saved.duration)
    }

    private var selectedPresetName: String? {
        ProjectPreset.all.first {
            $0.width == Int(width) && $0.height == Int(height) && $0.fps == Int(fps)
        }?.name
    }

    private var canCreate: Bool {
        width.isFinite && height.isFinite && duration.isFinite &&
        width >= 16 && width <= 8192 && height >= 16 && height <= 8192 &&
        duration >= 1 && duration <= 120 && frameRates.contains(fps)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("NEW PROJECT").font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1.8).foregroundStyle(VexelPalette.accent)
                        Text("Set your canvas.").font(.system(size: 26, weight: .bold, design: .rounded)).foregroundStyle(VexelPalette.text)
                        Text("Choose a format, then fine-tune your composition settings.").font(.system(size: 12)).foregroundStyle(VexelPalette.secondary)
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(VexelPalette.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("LAST USED SETTINGS")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .tracking(0.8)
                                .foregroundStyle(VexelPalette.text)
                            Text("Your canvas defaults are saved on this device.")
                                .font(.system(size: 9))
                                .foregroundStyle(VexelPalette.secondary)
                        }
                        Spacer()
                        Button("Reset") {
                            VexelCompositionDefaults.reset()
                            let defaults = VexelCompositionDefaults.default
                            width = Double(defaults.width)
                            height = Double(defaults.height)
                            fps = Double(defaults.fps)
                            duration = defaults.duration
                        }
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(VexelPalette.accent)
                        .accessibilityIdentifier("newProject.resetDefaults")
                    }
                    .padding(12)
                    .background(VexelPalette.card, in: RoundedRectangle(cornerRadius: 11))
                    VStack(alignment: .leading, spacing: 9) {
                        VexelSectionLabel(title: "Composition name")
                        TextField("Untitled Composition", text: $title)
                            .font(.system(size: 14, weight: .medium)).padding(.horizontal, 13).frame(height: 46)
                            .background(VexelPalette.field, in: RoundedRectangle(cornerRadius: 11))
                            .accessibilityIdentifier("newProject.name")
                    }
                    VStack(alignment: .leading, spacing: 11) {
                        VexelSectionLabel(title: "Canvas format", trailing: "PRESETS")
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                            ForEach(ProjectPreset.all) { preset in
                                Button {
                                    width = Double(preset.width)
                                    height = Double(preset.height)
                                    fps = Double(preset.fps)
                                    duration = preset.duration
                                } label: {
                                    VStack(spacing: 8) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 9).fill(VexelPalette.preview).frame(height: 64)
                                            RoundedRectangle(cornerRadius: 3)
                                                .stroke(selectedPresetName == preset.name ? VexelPalette.accent : VexelPalette.secondary.opacity(0.7), lineWidth: selectedPresetName == preset.name ? 1.8 : 1)
                                                .frame(width: preset.width > preset.height ? 48 : (preset.width == preset.height ? 39 : 25),
                                                       height: preset.width > preset.height ? 27 : (preset.width == preset.height ? 39 : 46))
                                        }
                                        Text(preset.name).font(.system(size: 10, weight: .semibold)).foregroundStyle(VexelPalette.text).lineLimit(1)
                                        Text("\(preset.width) × \(preset.height)").font(.system(size: 8, design: .monospaced)).foregroundStyle(VexelPalette.secondary)
                                    }
                                    .padding(8).frame(maxWidth: .infinity)
                                    .background(selectedPresetName == preset.name ? VexelPalette.accent.opacity(0.09) : VexelPalette.card, in: RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(selectedPresetName == preset.name ? VexelPalette.accent.opacity(0.75) : VexelPalette.line, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("preset.\(preset.name.lowercased().replacingOccurrences(of: " ", with: "-"))")
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        VexelSectionLabel(title: "Custom dimensions")
                        HStack(spacing: 10) {
                            numericField("Width", value: $width)
                            Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundStyle(VexelPalette.secondary)
                            numericField("Height", value: $height)
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        VexelSectionLabel(title: "Frame rate")
                        HStack(spacing: 6) {
                            ForEach(frameRates, id: \.self) { rate in
                                Button { fps = rate } label: {
                                    Text("\(Int(rate))").font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(fps == rate ? Color.black : VexelPalette.soft)
                                        .frame(maxWidth: .infinity).frame(height: 36)
                                        .background(fps == rate ? VexelPalette.accent : VexelPalette.field, in: RoundedRectangle(cornerRadius: 9))
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("newProject.fps.\(Int(rate))")
                            }
                        }
                        Text("\(Int(fps)) frames per second").font(.system(size: 9)).foregroundStyle(VexelPalette.secondary)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VexelSectionLabel(title: "Duration")
                            Spacer()
                            Text("\(Int(duration)) SEC").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(VexelPalette.accent)
                        }
                        Slider(value: $duration, in: 1...120, step: 1)
                            .tint(VexelPalette.accent)
                            .accessibilityIdentifier("newProject.duration")
                        HStack {
                            Text("1 SECOND")
                            Spacer()
                            Text("120 SECONDS")
                        }.font(.system(size: 8, weight: .medium, design: .monospaced)).foregroundStyle(VexelPalette.secondary)
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle").foregroundStyle(VexelPalette.accent)
                        Text("Maximum canvas dimension: 8192 px. Duration: 1–120 seconds.").font(.system(size: 10)).foregroundStyle(VexelPalette.secondary)
                    }
                }
                .padding(18).padding(.bottom, 12)
            }
            .background(VexelPalette.background)
            .navigationTitle("New composition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(VexelPalette.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        VexelCompositionDefaults(
                            width: Int(width),
                            height: Int(height),
                            fps: Int(fps),
                            duration: duration
                        ).save()
                        onCreate(VexelProjectItem(title: name.isEmpty ? "Untitled Composition" : name,
                                                  width: Int(width), height: Int(height), fps: Int(fps), duration: duration))
                    }
                    .disabled(!canCreate)
                    .accessibilityIdentifier("newProject.create")
                }
            }
        }
        .tint(VexelPalette.accent)
    }

    private func numericField(_ label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased()).font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(0.8).foregroundStyle(VexelPalette.secondary)
            TextField(label, value: value, format: .number)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .keyboardType(.numberPad).multilineTextAlignment(.leading)
                .accessibilityIdentifier("newProject.\(label.lowercased())")
                .padding(.horizontal, 12).frame(height: 42)
                .background(VexelPalette.field, in: RoundedRectangle(cornerRadius: 9))
        }
        .frame(maxWidth: .infinity)
    }
}
