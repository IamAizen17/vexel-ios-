import SwiftUI
import UniformTypeIdentifiers
import VexelCore

struct VexelProjectItem: Identifiable, Hashable {
    let id: UUID
    var title: String
    var width: Int
    var height: Int
    var fps: Int
    var duration: Double
    var modified: Date
    var layerNames: [String]

    init(title: String, width: Int = 1080, height: Int = 1920, fps: Int = 30, duration: Double = 10) {
        self.id = UUID()
        self.title = title
        self.width = width
        self.height = height
        self.fps = fps
        self.duration = duration
        self.modified = Date()
        self.layerNames = []
    }
}

enum HomeDestination: String, CaseIterable {
    case projects = "Projects"
    case presets = "Presets"
    case settings = "Settings"

    var symbol: String {
        switch self {
        case .projects: return "square.stack.3d.up"
        case .presets: return "rectangle.grid.2x2"
        case .settings: return "slider.horizontal.3"
        }
    }
}

struct VexelRootView: View {
    @AppStorage("vexel.onboarding.complete") private var onboardingComplete = false
    @State private var activeProject: VexelProjectItem?
    @State private var projects: [VexelProjectItem] = [
        VexelProjectItem(title: "Untitled Composition"),
        VexelProjectItem(title: "Motion Study 01", width: 1920, height: 1080, fps: 60, duration: 8)
    ]

    var body: some View {
        Group {
            if !onboardingComplete {
                VexelOnboardingView {
                    onboardingComplete = true
                }
            } else if let project = activeProject {
                VexelEditorWorkspace(
                    project: project,
                    onClose: { activeProject = nil },
                    onProjectChange: { updated in
                        if let index = projects.firstIndex(where: { $0.id == updated.id }) {
                            projects[index] = updated
                        }
                    }
                )
            } else {
                VexelHomeView(
                    projects: $projects,
                    onOpen: { activeProject = $0 }
                )
            }
        }
        .preferredColorScheme(.dark)
        .tint(VexelPalette.accent)
    }
}

struct VexelOnboardingView: View {
    let onComplete: () -> Void
    @State private var page = 0

    private let slides: [(String, String, String)] = [
        ("square.stack.3d.up", "Motion without limits", "Build layered 2D and 3D compositions with a timeline designed for precision."),
        ("waveform.path", "Animate every detail", "Keyframes, curves, effects, masks and audio tools work together in one workspace."),
        ("square.and.arrow.up", "Create. Refine. Export.", "Bring your media in, shape the motion, and prepare a clean final render.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("VEXEL").font(.system(size: 15, weight: .black, design: .rounded)).tracking(3)
                Spacer()
                Text("INTRODUCTION").font(.system(size: 9, weight: .bold)).tracking(1.5).foregroundStyle(VexelPalette.secondary)
            }
            .foregroundStyle(VexelPalette.text)
            .padding(22)

            Spacer()
            Image(systemName: slides[page].0)
                .font(.system(size: 62, weight: .ultraLight))
                .foregroundStyle(VexelPalette.accent)
                .frame(width: 150, height: 150)
                .background(VexelPalette.card, in: RoundedRectangle(cornerRadius: 34))
                .overlay(RoundedRectangle(cornerRadius: 34).stroke(VexelPalette.line, lineWidth: 1))
            Text(slides[page].1)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(VexelPalette.text)
                .multilineTextAlignment(.center)
                .padding(.top, 28)
            Text(slides[page].2)
                .font(.system(size: 14))
                .foregroundStyle(VexelPalette.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .frame(maxWidth: 310)
                .padding(.top, 10)
            Spacer()

            HStack(spacing: 7) {
                ForEach(0..<slides.count, id: \.self) { index in
                    Capsule().fill(index == page ? VexelPalette.accent : VexelPalette.line)
                        .frame(width: index == page ? 24 : 7, height: 6)
                }
            }
            .padding(.bottom, 22)

            Button {
                if page == slides.count - 1 { onComplete() } else { page += 1 }
            } label: {
                HStack {
                    Text(page == slides.count - 1 ? "Start creating" : "Continue")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.black)
                .padding(.horizontal, 18)
                .frame(height: 52)
                .background(VexelPalette.accent, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 22)
            .padding(.bottom, 28)
        }
        .vexelScreenBackground()
    }
}

struct VexelHomeView: View {
    @Binding var projects: [VexelProjectItem]
    let onOpen: (VexelProjectItem) -> Void

    @State private var destination: HomeDestination = .projects
    @State private var showingNewProject = false
    @State private var showingPlugins = false
    @State private var deletingProject: VexelProjectItem?
    @State private var showingImporter = false
    @State private var notice: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Group {
                switch destination {
                case .projects: projectsPage
                case .presets: presetsPage
                case .settings: VexelSettingsPage(onPlugins: { showingPlugins = true })
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            bottomNavigation
        }
        .vexelScreenBackground()
        .sheet(isPresented: $showingNewProject) {
            NewProjectSheet { project in
                projects.insert(project, at: 0)
                showingNewProject = false
                onOpen(project)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingPlugins) {
            VexelPluginsPage()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .fileImporter(isPresented: Binding(
            get: { showingImporter },
            set: { showingImporter = $0 }
        ), allowedContentTypes: [.data, .item], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let project = VexelProjectItem(title: url.deletingPathExtension().lastPathComponent)
                projects.insert(project, at: 0)
                notice = "Imported file selected. The .knsproj parser will be connected in the project-format milestone."
            case .failure(let error):
                notice = error.localizedDescription
            }
        }
        .alert("Project action", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button("OK", role: .cancel) { notice = nil }
        } message: { Text(notice ?? "") }
        .confirmationDialog("Delete project?", item: $deletingProject) { project in
            Button("Delete", role: .destructive) {
                projects.removeAll { $0.id == project.id }
            }
        } message: { project in
            Text("Delete \(project.title)? This cannot be undone.")
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("VEXEL").font(.system(size: 16, weight: .black, design: .rounded)).tracking(2.8)
                    .foregroundStyle(VexelPalette.text)
                Text("MOTION WORKSPACE").font(.system(size: 9, weight: .bold)).tracking(1.5)
                    .foregroundStyle(VexelPalette.secondary)
            }
            Spacer()
            VexelIconButton(symbol: "bell") { notice = "Notifications will be available when project sync is implemented." }
            VexelIconButton(symbol: "plus", active: true) { showingNewProject = true }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    private var projectsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Your workspace").font(.system(size: 23, weight: .bold, design: .rounded)).foregroundStyle(VexelPalette.text)
                        Text("\(projects.count) compositions").font(.system(size: 12)).foregroundStyle(VexelPalette.secondary)
                    }
                    Spacer()
                    Button { showingImporter = true } label: {
                        Label("Import", systemImage: "square.and.arrow.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(VexelPalette.soft)
                            .padding(.horizontal, 12).frame(height: 34)
                            .background(VexelPalette.field, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Button { showingNewProject = true } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "plus").font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.black).frame(width: 42, height: 42)
                            .background(VexelPalette.accent, in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Create composition").font(.system(size: 14, weight: .bold)).foregroundStyle(VexelPalette.text)
                            Text("Start from a blank canvas or preset").font(.system(size: 11)).foregroundStyle(VexelPalette.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right").foregroundStyle(VexelPalette.secondary)
                    }
                    .padding(14)
                    .background(VexelPalette.card, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(VexelPalette.line, lineWidth: 1))
                }
                .buttonStyle(.plain)

                VexelSectionLabel(title: "Recent projects", trailing: "SORT: RECENT")
                if projects.isEmpty {
                    VexelEmptyState(symbol: "square.stack.3d.up", title: "No projects yet", detail: "Create a composition to start building your first animation.")
                        .frame(height: 220)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(projects) { project in
                            ProjectCard(project: project, onOpen: { onOpen(project) }, onDuplicate: {
                                var copy = project
                                copy = VexelProjectItem(title: project.title + " Copy", width: project.width, height: project.height, fps: project.fps, duration: project.duration)
                                projects.insert(copy, at: 0)
                            }, onDelete: { deletingProject = project })
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 22)
        }
    }

    private var presetsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Start with a preset").font(.system(size: 23, weight: .bold, design: .rounded)).foregroundStyle(VexelPalette.text)
                    Text("Choose a canvas format and frame rate.").font(.system(size: 12)).foregroundStyle(VexelPalette.secondary)
                }
                ForEach(ProjectPreset.all) { preset in
                    Button {
                        let project = VexelProjectItem(title: preset.name, width: preset.width, height: preset.height, fps: preset.fps, duration: preset.duration)
                        projects.insert(project, at: 0)
                        onOpen(project)
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 9).fill(VexelPalette.field)
                                RoundedRectangle(cornerRadius: 3).stroke(VexelPalette.accent.opacity(0.8), lineWidth: 1.2)
                                    .frame(width: preset.width > preset.height ? 43 : 24, height: preset.width > preset.height ? 24 : 39)
                            }
                            .frame(width: 60, height: 60)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(preset.name).font(.system(size: 13, weight: .bold)).foregroundStyle(VexelPalette.text)
                                Text("\(preset.width) × \(preset.height) · \(preset.fps) FPS · \(Int(preset.duration)) sec")
                                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(VexelPalette.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right").foregroundStyle(VexelPalette.accent)
                        }
                        .padding(12)
                        .background(VexelPalette.card, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
        }
    }

    private var bottomNavigation: some View {
        HStack(spacing: 0) {
            ForEach(HomeDestination.allCases, id: \.self) { item in
                Button { destination = item } label: {
                    VStack(spacing: 5) {
                        Image(systemName: item.symbol).font(.system(size: 17, weight: .semibold))
                        Text(item.rawValue).font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(destination == item ? VexelPalette.accent : VexelPalette.secondary)
                    .frame(maxWidth: .infinity).frame(height: 58)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 7)
        .background(VexelPalette.bar)
        .overlay(alignment: .top) { Rectangle().fill(VexelPalette.line).frame(height: 1) }
    }
}

private struct ProjectCard: View {
    let project: VexelProjectItem
    let onOpen: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    @State private var menu = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onOpen) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(VexelPalette.preview)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(VexelPalette.field)
                        .frame(width: project.width > project.height ? 48 : 28, height: project.width > project.height ? 28 : 48)
                        .overlay(Text("V").font(.system(size: 12, weight: .black)).foregroundStyle(VexelPalette.accent))
                }
                .frame(width: 66, height: 66)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 5) {
                Text(project.title).font(.system(size: 13, weight: .bold)).foregroundStyle(VexelPalette.text).lineLimit(1)
                Text("\(project.width) × \(project.height) · \(project.fps) FPS")
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(VexelPalette.secondary)
                Text(project.modified.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 10)).foregroundStyle(VexelPalette.secondary)
            }
            Spacer(minLength: 0)
            Menu {
                Button(action: onOpen) { Label("Open", systemImage: "arrow.up.right.square") }
                Button(action: onDuplicate) { Label("Duplicate", systemImage: "plus.square.on.square") }
                Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 16, weight: .bold))
                    .foregroundStyle(VexelPalette.secondary).frame(width: 34, height: 44)
            }
        }
        .padding(10)
        .background(VexelPalette.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(VexelPalette.line.opacity(0.7), lineWidth: 1))
    }
}

private struct ProjectPreset: Identifiable {
    let id = UUID()
    let name: String
    let width: Int
    let height: Int
    let fps: Int
    let duration: Double
    static let all = [
        ProjectPreset(name: "Portrait video", width: 1080, height: 1920, fps: 30, duration: 15),
        ProjectPreset(name: "Landscape video", width: 1920, height: 1080, fps: 30, duration: 30),
        ProjectPreset(name: "Square social", width: 1080, height: 1080, fps: 30, duration: 15),
        ProjectPreset(name: "Cinematic 4K", width: 3840, height: 2160, fps: 24, duration: 30),
        ProjectPreset(name: "High frame rate", width: 1920, height: 1080, fps: 60, duration: 15)
    ]
}

private struct NewProjectSheet: View {
    let onCreate: (VexelProjectItem) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = "Untitled Composition"
    @State private var width = 1080.0
    @State private var height = 1920.0
    @State private var fps = 30.0
    @State private var duration = 10.0

    var body: some View {
        NavigationStack {
            Form {
                Section("Composition") {
                    TextField("Project name", text: $title)
                    HStack {
                        numericField("Width", value: $width)
                        numericField("Height", value: $height)
                    }
                    Picker("Frame rate", selection: $fps) {
                        ForEach([24.0, 25.0, 30.0, 50.0, 60.0, 120.0], id: \.self) { Text("\(Int($0)) FPS").tag($0) }
                    }
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text("\(Int(duration)) sec").foregroundStyle(.secondary)
                    }
                    Slider(value: $duration, in: 1...120, step: 1)
                }
                Section("Canvas presets") {
                    ForEach(ProjectPreset.all) { preset in
                        Button(preset.name) {
                            width = Double(preset.width); height = Double(preset.height); fps = Double(preset.fps); duration = preset.duration
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(VexelPalette.background)
            .navigationTitle("New composition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(VexelProjectItem(title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Composition" : title, width: Int(width), height: Int(height), fps: Int(fps), duration: duration))
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func numericField(_ label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(label, value: value, format: .number).keyboardType(.numberPad)
        }
    }
}

struct VexelSettingsPage: View {
    let onPlugins: () -> Void
    @AppStorage("vexel.showLayerNames") private var showLayerNames = true
    @AppStorage("vexel.autoKeyframe") private var autoKeyframe = false
    @AppStorage("vexel.useProxies") private var useProxies = true
    @AppStorage("vexel.mirrorProjects") private var mirrorProjects = true
    @AppStorage("vexel.previewQuality") private var previewQuality = 1.0
    @AppStorage("vexel.theme") private var theme = "dark"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Settings").font(.system(size: 23, weight: .bold, design: .rounded)).foregroundStyle(VexelPalette.text)
                    Text("Configure your editing workspace").font(.system(size: 12)).foregroundStyle(VexelPalette.secondary)
                }
                settingsGroup("APPEARANCE") {
                    settingRow("Theme", detail: "Dark workspace", symbol: "moon.stars") {
                        Picker("Theme", selection: $theme) {
                            Text("Dark").tag("dark"); Text("Light").tag("light"); Text("System").tag("system")
                        }.pickerStyle(.menu).tint(VexelPalette.accent)
                    }
                }
                settingsGroup("EDITOR") {
                    settingToggle("Show layer names", detail: "Display names on timeline clips", symbol: "text.alignleft", value: $showLayerNames)
                    settingToggle("Auto keyframe", detail: "Record keyframes while adjusting transforms", symbol: "diamond", value: $autoKeyframe)
                }
                settingsGroup("PERFORMANCE") {
                    settingToggle("Use video proxies", detail: "Use lightweight media during preview", symbol: "film", value: $useProxies)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Label("3D preview quality", systemImage: "cube"); Spacer(); Text(["Low", "Medium", "High"][Int(previewQuality)]).foregroundStyle(VexelPalette.secondary) }
                        Slider(value: $previewQuality, in: 0...2, step: 1).tint(VexelPalette.accent)
                    }
                    .font(.system(size: 12)).foregroundStyle(VexelPalette.text).padding(.vertical, 5)
                }
                settingsGroup("STORAGE") {
                    settingToggle("Mirror projects to Files", detail: "Keep project copies in the Files app", symbol: "folder", value: $mirrorProjects)
                }
                settingsGroup("EXTENSIONS") {
                    Button(action: onPlugins) {
                        HStack { Label("Plugin manager", systemImage: "puzzlepiece.extension"); Spacer(); Image(systemName: "chevron.right").foregroundStyle(VexelPalette.secondary) }
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(VexelPalette.text)
                    }
                }
                VexelPanel {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("VEXEL").font(.system(size: 12, weight: .black)).tracking(2).foregroundStyle(VexelPalette.text)
                            Text("iOS foundation build · 0.1.0").font(.system(size: 10)).foregroundStyle(VexelPalette.secondary)
                        }
                        Spacer()
                        Text("ABOUT").font(.system(size: 9, weight: .bold)).tracking(1.3).foregroundStyle(VexelPalette.accent)
                    }
                }
            }
            .padding(18)
        }
    }

    private func settingsGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VexelSectionLabel(title: title)
            VexelPanel(padding: 14) { VStack(alignment: .leading, spacing: 14, content: content) }
        }
    }

    private func settingToggle(_ title: String, detail: String, symbol: String, value: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).foregroundStyle(VexelPalette.accent).frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(VexelPalette.text)
                Text(detail).font(.system(size: 10)).foregroundStyle(VexelPalette.secondary)
            }
            Spacer()
            Toggle(title, isOn: value).labelsHidden().tint(VexelPalette.accent)
        }
    }

    private func settingRow<Content: View>(_ title: String, detail: String, symbol: String, @ViewBuilder trailing: () -> Content) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).foregroundStyle(VexelPalette.accent).frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(VexelPalette.text)
                Text(detail).font(.system(size: 10)).foregroundStyle(VexelPalette.secondary)
            }
            Spacer()
            trailing()
        }
    }
}

struct VexelPluginsPage: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var showingInstall = false
    private let plugins = [
        ("Motion Toolkit", "Animation helpers and presets", "sparkles", "Built-in"),
        ("3D Utilities", "Scene and model utilities", "cube.transparent", "Built-in"),
        ("Audio Tools", "Waveform and audio helpers", "waveform", "Built-in"),
        ("Community Pack", "Community extension examples", "puzzlepiece.extension", "Example")
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(VexelPalette.secondary)
                    TextField("Search plugins", text: $query).font(.system(size: 13))
                }
                .padding(12).background(VexelPalette.field, in: RoundedRectangle(cornerRadius: 10))
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(plugins.filter { query.isEmpty || $0.0.localizedCaseInsensitiveContains(query) }, id: \.0) { plugin in
                            VexelPanel {
                                HStack(spacing: 12) {
                                    Image(systemName: plugin.2).font(.system(size: 19)).foregroundStyle(VexelPalette.accent).frame(width: 38, height: 38).background(VexelPalette.field, in: RoundedRectangle(cornerRadius: 10))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(plugin.0).font(.system(size: 13, weight: .bold)).foregroundStyle(VexelPalette.text)
                                        Text(plugin.1).font(.system(size: 10)).foregroundStyle(VexelPalette.secondary)
                                    }
                                    Spacer()
                                    Text(plugin.3.uppercased()).font(.system(size: 8, weight: .bold)).tracking(1).foregroundStyle(VexelPalette.teal)
                                }
                            }
                        }
                    }
                }
                VexelActionButton(title: "Import plugin package", systemImage: "plus", prominent: true) { showingInstall = true }
                    .padding(.bottom, 8)
            }
            .padding(16)
            .background(VexelPalette.background)
            .navigationTitle("Plugins")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
            .fileImporter(isPresented: $showingInstall, allowedContentTypes: [.data, .zip], allowsMultipleSelection: false) { _ in }
        }
        .preferredColorScheme(.dark)
    }
}
