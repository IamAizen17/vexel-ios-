import SwiftUI
import UniformTypeIdentifiers
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
    @State private var timelineEngine = TimelineEngine(project: ProjectDocument.starter(title: "Untitled Composition"))
    @State private var selectedLayerID: String?
    @State private var selectedSection = "Project"
    @State private var isImportingProject = false
    @State private var importAlert: String?
    @State private var importedProjectDirectory: URL?
    @State private var shareURL: URL?

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
        .fileImporter(
            isPresented: $isImportingProject,
            allowedContentTypes: [
                UTType(filenameExtension: "knsproj") ?? .data,
                UTType(filenameExtension: "vexelproj") ?? .zip,
                .zip
            ],
            allowsMultipleSelection: false
        ) { result in
            handleProjectImport(result)
        }
        .sheet(isPresented: Binding(
            get: { shareURL != nil },
            set: { if !$0 { shareURL = nil } }
        )) {
            if let shareURL {
                VStack(spacing: 18) {
                    Text("Project saved")
                        .font(.headline)
                    Text(shareURL.lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ShareLink(item: shareURL) {
                        Label("Share or Save to Files", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Close") { self.shareURL = nil }
                }
                .padding(24)
                .presentationDetents([.medium])
            }
        }
        .alert("Project Import", isPresented: Binding(
            get: { importAlert != nil },
            set: { if !$0 { importAlert = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importAlert ?? "")
        }
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
            Button {
                isImportingProject = true
            } label: {
                Image(systemName: "folder")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityLabel("Import Kinesis project")
            Button {
                undoTimeline()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            }
            Button {
                saveCurrentProject()
            } label: {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityLabel("Save Vexel project")
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
                            Text("YOUR\nNEXT FRAME")
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
        VStack(alignment: .leading, spacing: 10) {
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

            let layers = project.fields["layers"]?.arrayValue ?? []
            if layers.isEmpty {
                Text("No layers yet. Add a text layer to begin.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.38))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(Array(layers.enumerated()), id: \.offset) { index, layer in
                    if let object = layer.objectValue {
                        let id = object["id"]?.stringValue ?? "layer-\(index)"
                        let type = object["type"]?.stringValue ?? "layer"
                        let name = object["name"]?.stringValue.flatMap { $0.isEmpty ? nil : $0 } ?? type.capitalized
                        let start = object["start"]?.numberValue ?? 0
                        let duration = object["duration"]?.numberValue ?? 5
                        let visible: Bool = {
                            if case .bool(let value) = object["visible"] { return value }
                            return true
                        }()

                        HStack(spacing: 8) {
                            Button {
                                selectedLayerID = id
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: iconForLayer(type))
                                        .foregroundStyle(selectedLayerID == id ? Color(red: 0.35, green: 0.83, blue: 0.73) : .white.opacity(0.55))
                                        .frame(width: 22)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(name)
                                            .font(.system(size: 11, weight: .medium))
                                            .lineLimit(1)
                                        Text(String(format: "%.2fs · %.2fs", start, duration))
                                            .font(.system(size: 9, weight: .regular, design: .monospaced))
                                            .foregroundStyle(.white.opacity(0.35))
                                    }
                                }
                            }
                            .buttonStyle(.plain)

                            Spacer(minLength: 4)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(type == "audio" ? Color.orange.opacity(0.28) : Color(red: 0.20, green: 0.49, blue: 0.44))
                                .frame(width: CGFloat(max(44, min(190, duration * 24))), height: 25)
                                .overlay(alignment: .leading) {
                                    Text(name.uppercased())
                                        .font(.system(size: 8, weight: .bold))
                                        .lineLimit(1)
                                        .foregroundStyle(.white.opacity(0.82))
                                        .padding(.horizontal, 8)
                                }

                            Button {
                                setLayerVisibility(id, visible: !visible)
                            } label: {
                                Image(systemName: visible ? "eye" : "eye.slash")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.45))
                                    .frame(width: 24, height: 28)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            .white.opacity(selectedLayerID == id ? 0.09 : 0.035),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    selectedLayerID == id ? Color(red: 0.35, green: 0.83, blue: 0.73).opacity(0.45) : .clear,
                                    lineWidth: 1
                                )
                        }
                        .contextMenu {
                            Button {
                                duplicateLayer(id)
                            } label: {
                                Label("Duplicate", systemImage: "plus.square.on.square")
                            }
                            Button(role: .destructive) {
                                deleteLayer(id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
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
            if let importedProjectDirectory {
                Text(importedProjectDirectory.lastPathComponent)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
                    .lineLimit(2)
            }
        }
        .padding(16)
        .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
    }

    private var toolBar: some View {
        HStack(spacing: 0) {
            Button(action: addTextLayer) {
                VStack(spacing: 6) {
                    Image(systemName: "textformat")
                        .font(.system(size: 17, weight: .medium))
                    Text("Add Text")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.78))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            tool("keyframes", title: "Keyframes")
            tool("slider.horizontal.3", title: "Controls")
            tool("sparkles", title: "Effects")
            tool("film", title: "Export")
        }
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(Color.black.opacity(0.28))
    }


    private func handleProjectImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importAlert = error.localizedDescription
        case .success(let urls):
            guard let sourceURL = urls.first else { return }
            let hasAccess = sourceURL.startAccessingSecurityScopedResource()
            Task {
                do {
                    let destination = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                        .appendingPathComponent("Vexel/Projects", isDirectory: true)
                    let imported = try await Task.detached(priority: .userInitiated) {
                        if sourceURL.pathExtension.lowercased() == "vexelproj" {
                            let loaded = try VexelProjectArchive().open(from: sourceURL, into: destination)
                            return (loaded.project, loaded.projectDirectory, "Vexel", loaded.importedFileCount)
                        }
                        let loaded = try KnsprojArchiveImporter().importProject(from: sourceURL, into: destination)
                        return (loaded.project, loaded.projectDirectory, "Kinesis v\(loaded.sourceVersion)", loaded.importedAssetCount)
                    }.value
                    project = imported.0
                    timelineEngine = TimelineEngine(project: imported.0)
                    selectedLayerID = nil
                    importedProjectDirectory = imported.1
                    importAlert = "Imported \(project.title) from \(imported.2). \(imported.3) media files copied."
                } catch {
                    importAlert = error.localizedDescription
                }
                if hasAccess {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
            }
        }
    }



    private func iconForLayer(_ type: String) -> String {
        switch type {
        case "text": return "textformat"
        case "shape": return "square"
        case "image": return "photo"
        case "video": return "film"
        case "audio": return "waveform"
        case "group": return "folder"
        case "camera": return "camera"
        case "light": return "lightbulb"
        case "null": return "dot.scope"
        case "model3d", "object3d": return "cube"
        default: return "square.stack"
        }
    }

    private func addTextLayer() {
        let id = "text_\(UUID().uuidString.prefix(8).lowercased())"
        let layer = JSONValue.object([
            "id": .string(id),
            "type": .string("text"),
            "name": .string("Text Layer"),
            "start": .number(0),
            "duration": .number(5),
            "text": .object([
                "content": .string("Text"),
                "fontSize": .number(96),
                "color": .string("#FFFFFF")
            ])
        ])
        Task {
            do {
                project = try await timelineEngine.addLayer(layer)
                selectedLayerID = id
            } catch {
                importAlert = error.localizedDescription
            }
        }
    }

    private func undoTimeline() {
        Task {
            project = await timelineEngine.undo()
        }
    }

    private func setLayerVisibility(_ id: String, visible: Bool) {
        Task {
            do {
                project = try await timelineEngine.setVisibility(id, visible: visible)
            } catch {
                importAlert = error.localizedDescription
            }
        }
    }

    private func duplicateLayer(_ id: String) {
        Task {
            do {
                project = try await timelineEngine.duplicateLayer(id)
            } catch {
                importAlert = error.localizedDescription
            }
        }
    }

    private func deleteLayer(_ id: String) {
        Task {
            do {
                project = try await timelineEngine.deleteLayers([id])
                if selectedLayerID == id { selectedLayerID = nil }
            } catch {
                importAlert = error.localizedDescription
            }
        }
    }

    private func saveCurrentProject() {
        let snapshot = project
        let assetRoot = importedProjectDirectory
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Vexel/WorkingAssets", isDirectory: true)
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let projectFolder = documents.appendingPathComponent("Vexel Projects", isDirectory: true)
        let invalidCharacters = CharacterSet(charactersIn: "/:")
        let baseName = snapshot.title.components(separatedBy: invalidCharacters).joined(separator: "-")
        let fileName = (baseName.isEmpty ? "Untitled" : baseName) + ".vexelproj"
        let destination = projectFolder.appendingPathComponent(fileName)

        Task {
            do {
                try await Task.detached(priority: .utility) {
                    try VexelProjectArchive().save(snapshot, assetsDirectory: assetRoot, to: destination)
                }.value
                shareURL = destination
            } catch {
                importAlert = error.localizedDescription
            }
        }
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
