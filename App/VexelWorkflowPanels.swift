import SwiftUI

struct VexelMarker: Identifiable {
    var id = UUID()
    var name = "Marker"
    var time: Double
    var color = "Teal"
}

struct VexelMarkerSheet: View {
    let marker: VexelMarker
    let onSave: (VexelMarker) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var time: Double
    @State private var color = "Teal"

    init(marker: VexelMarker, onSave: @escaping (VexelMarker) -> Void) {
        self.marker = marker
        self.onSave = onSave
        _name = State(initialValue: marker.name)
        _time = State(initialValue: marker.time)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Marker") {
                    TextField("Name", text: $name)
                    HStack { Text("Time"); Spacer(); Text("\(time, specifier: "%.2f") s").foregroundStyle(.secondary) }
                    Slider(value: $time, in: 0...3600).tint(VexelPalette.accent)
                    Picker("Color", selection: $color) {
                        Text("Teal").tag("Teal"); Text("Amber").tag("Amber"); Text("Pink").tag("Pink"); Text("Blue").tag("Blue")
                    }
                }
            }
            .scrollContentBackground(.hidden).background(VexelPalette.background)
            .navigationTitle("Edit marker").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = marker
                        updated.name = name.isEmpty ? "Marker" : name
                        updated.time = time
                        updated.color = color
                        onSave(updated)
                        dismiss()
                    }
                }
            }
        }
            }
}

struct VexelStabilizationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var method = "Perspective"
    @State private var smoothness = 0.6
    @State private var crop = 0.15
    @State private var rollingShutter = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Stabilization method") {
                    Picker("Method", selection: $method) {
                        Text("Perspective").tag("Perspective")
                        Text("Similarity").tag("Similarity")
                        Text("Translation").tag("Translation")
                    }
                    Toggle("Rolling shutter correction", isOn: $rollingShutter).tint(VexelPalette.accent)
                }
                Section("Smoothing") {
                    sliderRow("Smoothness", value: $smoothness)
                    sliderRow("Crop amount", value: $crop)
                }
                Section {
                    Text("Motion analysis and stabilization rendering will be connected with the media engine.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden).background(VexelPalette.background)
            .navigationTitle("Stabilize video").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Start analysis") { dismiss() } }
            }
        }
            }

    private func sliderRow(_ title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading) {
            HStack { Text(title); Spacer(); Text("\(Int(value.wrappedValue * 100))%").foregroundStyle(.secondary) }
            Slider(value: value, in: 0...1).tint(VexelPalette.accent)
        }
    }
}

struct VexelMediaJobSheet: View {
    let title: String
    @Environment(\.dismiss) private var dismiss
    @State private var progress = 0.42
    @State private var cancelled = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Image(systemName: cancelled ? "xmark.circle" : "waveform.path.ecg")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(cancelled ? VexelPalette.pink : VexelPalette.accent)
                Text(cancelled ? "Job cancelled" : title)
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(VexelPalette.text)
                ProgressView(value: cancelled ? 0 : progress)
                    .tint(VexelPalette.accent)
                HStack {
                    Text(cancelled ? "Cancelled" : "Processing media")
                    Spacer()
                    Text("\(Int(progress * 100))%")
                }
                .font(.system(size: 10, design: .monospaced)).foregroundStyle(VexelPalette.secondary)
                VexelActionButton(title: cancelled ? "Close" : "Cancel job", systemImage: cancelled ? "checkmark" : "xmark", prominent: true) {
                    if cancelled { dismiss() } else { cancelled = true }
                }
                Text("This is a UI preview. Background processing and cancellation will be connected to the media job manager.")
                    .font(.system(size: 10)).foregroundStyle(VexelPalette.secondary).multilineTextAlignment(.center)
                Spacer()
            }
            .padding(24).background(VexelPalette.background)
            .navigationTitle("Media job").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
        }
            }
}
