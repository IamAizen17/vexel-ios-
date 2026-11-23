import SwiftUI
import VexelCore

@main
struct VexelApp: App {
    var body: some Scene {
        WindowGroup {
            WorkspaceView()
                .preferredColorScheme(.dark)
        }
    }
}

private struct WorkspaceView: View {
    @State private var project = ProjectDocument.starter(title: "Untitled Composition")
    @State private var selectedSection = "Project"

    private let sections = ["Project", "Media", "Effects", "Export"]

    var body: some View {
        GeometryReader { geometry in
            let isWide = geometry.size.width >= 760

            ZStack {
                Color(red: 0.035, green: 0.043, blue: 0.055).ignoresSafeArea()

                if isWide {
                    iPadWorkspace
                } else {
                    iPhoneWorkspace
                }
            }
        }
        .tint(Color(red: 0.34, green: 0.82, blue: 0.72))
    }

    private var iPhoneWorkspace: some View {
        VStack(spacing: 0) {
            header
            preview
                .padding(.horizontal, 18)
                .padding(.top, 18)
            timeline
                .padding(.top, 22)
            Spacer(minLength: 12)
            toolBar
        }
        .padding(.top, 8)
    }

    private var iPadWorkspace: some View {
        VStack(spacing: 0) {
            header
            HStack(spacing: 16) {
                VStack(spacing: 16) {
                    preview
                    timeline
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                inspector
                    .frame(width: 280)
            }
            .padding(20)
            toolBar
        }
        .padding(.top, 8)
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("VEXEL")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .tracking(2.4)
                    .foregroundStyle(.white)
                Text(project.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.48))
            }
            Spacer()
            Button {} label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            }
            Button {} label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
    }

    private var preview: some View {
        VStack(spacing: 12) {
            HStack {
                Text("CANVAS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.8)
                    .foregroundStyle(.white.opacity(0.42))
                Spacer()
                Text("1080 × 1920")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.42))
            }
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(red: 0.075, green: 0.09, blue: 0.105))
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 0.16, green: 0.20, blue: 0.21))
                    .frame(width: 112, height: 199)
                    .overlay {
                        VStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color(red: 0.35, green: 0.83, blue: 0.73))
                                .frame(width: 46, height: 3)
                            Text("YOUR\\nNEXT FRAME")
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .multilineTextAlignment(.center)
                                .tracking(0.8)
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color(red: 0.35, green: 0.83, blue: 0.73).opacity(0.65), lineWidth: 1)
                    }
                VStack {
                    Spacer()
                    HStack {
                        Label("Preview", systemImage: "play.fill")
                        Spacer()
                        Text("FIT")
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.42))
                }
                .padding(14)
            }
            .aspectRatio(0.92, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TIMELINE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.8)
                    .foregroundStyle(.white.opacity(0.42))
                Spacer()
                Text("00:00:00:00")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.35, green: 0.83, blue: 0.73))
            }
            HStack(spacing: 8) {
                Image(systemName: "textformat")
                    .foregroundStyle(Color(red: 0.35, green: 0.83, blue: 0.73))
                    .frame(width: 30)
                Text("Text Layer")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(red: 0.20, green: 0.49, blue: 0.44))
                    .frame(width: 124, height: 28)
                    .overlay(alignment: .leading) {
                        Text("TITLE")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1)
                            .padding(.leading, 10)
                    }
            }
            .padding(10)
            .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .foregroundStyle(.orange.opacity(0.85))
                    .frame(width: 30)
                Text("Audio Layer")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.orange.opacity(0.24))
                    .frame(width: 180, height: 28)
            }
            .padding(10)
            .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
        }
        .foregroundStyle(.white.opacity(0.88))
        .padding(.horizontal, 18)
    }

    private var inspector: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(selectedSection.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(1.7)
                .foregroundStyle(.white.opacity(0.5))
            ForEach(sections, id: \.self) { section in
                Button {
                    selectedSection = section
                } label: {
                    HStack {
                        Text(section)
                        Spacer()
                        Image(systemName: section == selectedSection ? "checkmark.circle.fill" : "circle")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(section == selectedSection ? Color(red: 0.35, green: 0.83, blue: 0.73) : .white.opacity(0.72))
                    .padding(12)
                    .background(.white.opacity(section == selectedSection ? 0.08 : 0.025), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Text("PROJECT STATUS")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.4))
            Text("\(project.layerCount) layers · \(project.compositionSize.width) × \(project.compositionSize.height)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.65))
        }
        .padding(16)
        .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
    }

    private var toolBar: some View {
        HStack(spacing: 0) {
            tool("square.stack.3d.up", title: "Layers")
            tool("keyframes", title: "Keyframes")
            tool("slider.horizontal.3", title: "Controls")
            tool("sparkles", title: "Effects")
            tool("film", title: "Export")
        }
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(Color.black.opacity(0.28))
    }

    private func tool(_ symbol: String, title: String) -> some View {
        Button {} label: {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .medium))
                Text(title)
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.68))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
