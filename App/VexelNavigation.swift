import SwiftUI
import UniformTypeIdentifiers
import VexelCore
import VexelArchive

struct VexelProjectItem: Identifiable, Hashable, Codable {
    var id: UUID
    var title: String
    var width: Int
    var height: Int
    var fps: Int
    var sourceFPS: Double?
    var duration: Double
    var modified: Date
    var layerNames: [String]
    var timelineTracks: [VexelTimelineTrack]
    var markers: [VexelMarker]
    var documentJSON: String?
    var assetsDirectory: String?

    init(title: String, width: Int = 1080, height: Int = 1920, fps: Int = 30, duration: Double = 10) {
        self.id = UUID()
        self.title = title
        self.width = width
        self.height = height
        self.fps = fps
        self.sourceFPS = nil
        self.duration = duration
        self.modified = Date()
        self.layerNames = []
        self.timelineTracks = []
        self.markers = []
        self.documentJSON = nil
        self.assetsDirectory = nil
        self.synchronizeDocument()
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("vexel.onboarding.complete") private var onboardingComplete = false
    @AppStorage("vexel.theme") private var theme = "dark"

    private var navigationAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.15) : VexelMotion.navigation
    }

    private var navigationTransition: AnyTransition {
        reduceMotion ? .opacity : .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .trailing).combined(with: .opacity)
        )
    }
    @State private var activeProject: VexelProjectItem?
    @State private var projects: [VexelProjectItem] = []
    @State private var persistenceError: String?

    var body: some View {
        Group {
            if !onboardingComplete {
                VexelOnboardingView {
                    withAnimation(navigationAnimation) { onboardingComplete = true }
                }
                 .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.985)))
            } else if let project = activeProject {
                VexelEditorWorkspace(
                    project: project,
                    onClose: { withAnimation(navigationAnimation) { activeProject = nil } },
                    onProjectChange: { updated in
                        if let index = projects.firstIndex(where: { $0.id == updated.id }) {
                            projects[index] = updated
                        }
                    }
                )
                 .transition(navigationTransition)
            } else {
                VexelHomeView(
                    projects: $projects,
                    onOpen: { project in withAnimation(navigationAnimation) { activeProject = project } }
                )
                 .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
            }
        }
         .animation(navigationAnimation, value: activeProject?.id)
        .animation(navigationAnimation, value: onboardingComplete)
        .task {
            do { projects = try VexelProjectStore.load() }
            catch { persistenceError = "Could not load saved projects: \(error.localizedDescription)" }
        }
        .onChange(of: projects) { updated in
            do { try VexelProjectStore.save(updated); persistenceError = nil }
            catch { persistenceError = "Could not save projects: \(error.localizedDescription)" }
        }
        .alert("Project storage", isPresented: Binding(get: { persistenceError != nil }, set: { if !$0 { persistenceError = nil } })) {
            Button("OK", role: .cancel) { persistenceError = nil }
        } message: { Text(persistenceError ?? "") }
        .preferredColorScheme(theme == "system" ? nil : (theme == "light" ? .light : .dark))
        .tint(VexelPalette.accent)
    }
}

struct VexelOnboardingView: View {
    let onComplete: () -> Void
    @State private var page = 0
    @AppStorage("vexel.theme") private var theme = "dark"
    @AppStorage("vexel.language") private var language = "system"

    private let slides: [(String, String, String)] = [
        ("square.stack.3d.up", "Motion without limits", "Build layered 2D and 3D compositions with a timeline designed for precision."),
        ("waveform.path", "Animate every detail", "Keyframes, curves, effects, masks and audio tools work together in one workspace."),
        ("curlybraces", "Expressions and control", "Create repeatable motion with keyframes, easing and procedural expressions."),
        ("slider.horizontal.3", "Make it yours", "Choose your interface language and appearance before entering the workspace.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("VEXEL").font(.system(size: 15, weight: .black, design: .rounded)).tracking(3)
                Spacer()
                Button("Skip", action: onComplete)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VexelPalette.secondary)
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

            if page == 3 {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("LANGUAGE").font(.system(size: 9, weight: .bold)).tracking(1.3).foregroundStyle(VexelPalette.secondary)
                        Picker("Language", selection: $language) {
                            Text("System").tag("system")
                            Text("English").tag("en")
                            Text("Português").tag("pt")
                        }.pickerStyle(.segmented)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("APPEARANCE").font(.system(size: 9, weight: .bold)).tracking(1.3).foregroundStyle(VexelPalette.secondary)
                        Picker("Appearance", selection: $theme) {
                            Text("Dark").tag("dark")
                            Text("Light").tag("light")
                            Text("System").tag("system")
                        }.pickerStyle(.segmented)
                    }
                }
                .padding(16)
                .background(VexelPalette.card, in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 22)
                .padding(.top, 20)
            }
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

private struct PendingVexelImport: Identifiable {
    let id = UUID()
    let project: VexelProjectItem
    let sourceName: String
    let unsupportedFeatures: [VexelUnsupportedFeature]
}

private struct VexelImportReviewSheet: View {
    let pending: PendingVexelImport
    let onCancel: () -> Void
    let onImport: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(pending.project.title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(VexelPalette.text)
                    Text("\(pending.project.width) × \(pending.project.height) · \(pending.project.fps) FPS · \(pending.project.timelineTracks.count) top-level tracks")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(VexelPalette.secondary)
                }

                HStack(spacing: 8) {
                    Image(systemName: pending.unsupportedFeatures.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(pending.unsupportedFeatures.isEmpty ? VexelPalette.accent : VexelPalette.amber)
                    Text(pending.unsupportedFeatures.isEmpty
                         ? "No known unsupported features detected."
                         : "\(pending.unsupportedFeatures.count) features are preserved but are not fully supported by the current editor.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VexelPalette.text)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(VexelPalette.card, in: RoundedRectangle(cornerRadius: 12))

                if !pending.unsupportedFeatures.isEmpty {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(pending.unsupportedFeatures.enumerated()), id: \.offset) { _, feature in
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(feature.feature)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(VexelPalette.text)
                                    Text(feature.path)
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(VexelPalette.accent)
                                    Text(feature.reason)
                                        .font(.system(size: 10))
                                        .foregroundStyle(VexelPalette.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(VexelPalette.field, in: RoundedRectangle(cornerRadius: 9))
                            }
                        }
                    }
                } else {
                    Spacer(minLength: 0)
                }

                HStack(spacing: 10) {
                    Button("Cancel", action: onCancel)
                        .buttonStyle(.bordered)
                    Button("Import project", action: onImport)
                        .buttonStyle(.borderedProminent)
                        .tint(VexelPalette.accent)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(18)
            .background(VexelPalette.background)
            .navigationTitle("Import review")
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled(true)
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
    @State private var pendingImport: PendingVexelImport?
    @State private var notice: String?
    @State private var sharingProjectURL: URL?

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
        ), allowedContentTypes: [.vexelProject, .zip, .data], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                do {
                    let projectID = UUID()
                    let assetsURL = try VexelProjectStore.assetsDirectory(for: projectID)
                    do {
                        let payload = try ZIPProjectArchive().read(from: url, extractingAssetsTo: assetsURL)
                        var imported = VexelProjectItem(document: payload.project)
                        imported.id = projectID
                        imported.assetsDirectory = assetsURL.path
                        _ = try imported.makeProjectDocument()
                        pendingImport = PendingVexelImport(
                            project: imported,
                            sourceName: url.lastPathComponent,
                            unsupportedFeatures: VexelProjectImporter.compatibilityReport(for: payload.project)
                        )
                    } catch {
                        try? FileManager.default.removeItem(at: assetsURL)
                        throw error
                    }
                } catch {
                    notice = "Import failed: \(error.localizedDescription)"
                }
            case .failure(let error):
                notice = error.localizedDescription
            }
        }
        .sheet(item: $pendingImport) { pending in
            VexelImportReviewSheet(
                pending: pending,
                onCancel: {
                    try? VexelProjectStore.deleteAssets(for: pending.project)
                    pendingImport = nil
                },
                onImport: {
                    var updatedProjects = projects
                    updatedProjects.insert(pending.project, at: 0)
                    do {
                        try VexelProjectStore.save(updatedProjects)
                        projects = updatedProjects
                        notice = "Imported \(pending.project.title) from \(pending.sourceName)."
                    } catch {
                        try? VexelProjectStore.deleteAssets(for: pending.project)
                        notice = "Import failed: \(error.localizedDescription)"
                    }
                    pendingImport = nil
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: Binding(get: { sharingProjectURL != nil }, set: { if !$0 { sharingProjectURL = nil } })) {
            VStack(spacing: 16) {
                Text("Project archive ready").font(.system(size: 18, weight: .bold))
                if let sharingProjectURL {
                    ShareLink(item: sharingProjectURL) {
                        Label("Share Vexel project", systemImage: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.black)
                            .padding(.horizontal, 18).frame(height: 46)
                            .background(VexelPalette.accent, in: Capsule())
                    }
                }
                Button("Done") { sharingProjectURL = nil }.foregroundStyle(VexelPalette.secondary)
            }
            .padding(24).presentationDetents([.medium])
        }
        .alert("Project action", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button("OK", role: .cancel) { notice = nil }
        } message: { Text(notice ?? "") }
        .confirmationDialog(
            "Delete project?",
            isPresented: Binding(get: { deletingProject != nil }, set: { if !$0 { deletingProject = nil } }),
            titleVisibility: .visible,
            presenting: deletingProject
        ) { project in
            Button("Delete", role: .destructive) {
                let updatedProjects = projects.filter { $0.id != project.id }
                do {
                    try VexelProjectStore.save(updatedProjects)
                    projects = updatedProjects
                    do {
                        try VexelProjectStore.deleteAssets(for: project)
                    } catch {
                        notice = "Project was deleted, but its assets could not be removed: \(error.localizedDescription)"
                    }
                } catch {
                    notice = "Could not delete project because the project library could not be saved: \(error.localizedDescription)"
                }
                deletingProject = nil
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
                .accessibilityIdentifier("home.createProject")
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    private var projectsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Your workspace")
                            .font(.system(size: 25, weight: .bold, design: .rounded))
                            .foregroundStyle(VexelPalette.text)
                        Text("\(projects.count) compositions")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(VexelPalette.secondary)
                    }
                    Spacer()
                    Button { showingImporter = true } label: {
                        Label("Import", systemImage: "square.and.arrow.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(VexelPalette.soft)
                            .padding(.horizontal, 12).frame(height: 36)
                            .background(VexelPalette.field, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home.import")
                }

                Button { showingNewProject = true } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(LinearGradient(
                                colors: [VexelPalette.card, VexelPalette.preview],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 9) {
                                Text("NEW COMPOSITION")
                                    .font(.system(size: 8, weight: .black))
                                    .tracking(1.8)
                                    .foregroundStyle(VexelPalette.accent)
                                Text("Make something
move.")
                                    .font(.system(size: 21, weight: .bold, design: .rounded))
                                    .multilineTextAlignment(.leading)
                                    .foregroundStyle(VexelPalette.text)
                                HStack(spacing: 6) {
                                    Text("Start creating")
                                    Image(systemName: "arrow.up.right")
                                }
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.black)
                                .padding(.horizontal, 12).frame(height: 30)
                                .background(VexelPalette.accent, in: Capsule())
                            }
                            Spacer(minLength: 0)
                            ZStack {
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(VexelPalette.field.opacity(0.8))
                                    .frame(width: 100, height: 116)
                                    .rotationEffect(.degrees(8))
                                RoundedRectangle(cornerRadius: 11)
                                    .fill(VexelPalette.preview)
                                    .frame(width: 86, height: 104)
                                    .overlay {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 5)
                                                .stroke(VexelPalette.accent.opacity(0.8), lineWidth: 1.2)
                                                .frame(width: 50, height: 68)
                                            Circle().fill(VexelPalette.accent)
                                                .frame(width: 16, height: 16)
                                                .offset(x: 12, y: -18)
                                            Image(systemName: "waveform.path")
                                                .font(.system(size: 19, weight: .medium))
                                                .foregroundStyle(VexelPalette.soft)
                                        }
                                    }
                            }
                        }
                        .padding(18)
                    }
                    .frame(minHeight: 154)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(VexelPalette.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.createProject.featured")

                HStack {
                    VexelSectionLabel(title: "Recent projects", trailing: "LATEST FIRST")
                    Spacer()
                    Text("PROJECT LIBRARY")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(VexelPalette.secondary)
                }

                if projects.isEmpty {
                    VexelEmptyState(symbol: "square.stack.3d.up", title: "No projects yet", detail: "Create a composition to start building your first animation.")
                        .frame(height: 220)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 270), spacing: 12)], spacing: 12) {
                        ForEach(projects) { project in
                            ProjectCard(project: project, onOpen: { onOpen(project) }, onDuplicate: {
                                do {
                                    projects = try VexelProjectStore.duplicate(project, addingTo: projects)
                                } catch {
                                    notice = "Could not duplicate project: \(error.localizedDescription)"
                                }
                            }, onDelete: { deletingProject = project }, onExport: {
                                do {
                                    let document = try project.makeProjectDocument()
                                    let safeTitle = project.title
                                        .replacingOccurrences(of: "/", with: "-")
                                        .replacingOccurrences(of: "\\", with: "-")
                                        .trimmingCharacters(in: .whitespacesAndNewlines)
                                    let destination = FileManager.default.temporaryDirectory
                                        .appendingPathComponent("\(safeTitle.isEmpty ? "Untitled" : safeTitle).vexelproj")
                                    let assets = project.assetsDirectory.map(URL.init(fileURLWithPath:))
                                    try ZIPProjectArchive().write(document, assetsDirectory: assets, to: destination)
                                    sharingProjectURL = destination
                                } catch {
                                    notice = "Export failed: \(error.localizedDescription)"
                                }
                            })
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
    }

    private var presetsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Start with a preset")
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                        .foregroundStyle(VexelPalette.text)
                    Text("Choose a canvas format and frame rate.")
                        .font(.system(size: 12))
                        .foregroundStyle(VexelPalette.secondary)
                }
                VexelSectionLabel(title: "CANVAS FORMATS", trailing: "\(ProjectPreset.all.count) PRESETS")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 154), spacing: 12)], spacing: 12) {
                    ForEach(ProjectPreset.all) { preset in
                        Button {
                            let project = VexelProjectItem(title: preset.name, width: preset.width, height: preset.height, fps: preset.fps, duration: preset.duration)
                            projects.insert(project, at: 0)
                            onOpen(project)
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12).fill(VexelPalette.preview)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(VexelPalette.field)
                                        .frame(width: preset.width > preset.height ? 92 : (preset.width == preset.height ? 70 : 48),
                                               height: preset.width > preset.height ? 52 : (preset.width == preset.height ? 70 : 82))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 3)
                                                .stroke(VexelPalette.accent, lineWidth: 1.2)
                                                .padding(5)
                                        }
                                    Image(systemName: "plus")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(VexelPalette.accent)
                                }
                                .frame(height: 126)
                                Text(preset.name)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(VexelPalette.text)
                                    .lineLimit(1)
                                Text("\(preset.width) × \(preset.height)")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(VexelPalette.secondary)
                                HStack {
                                    Text("\(preset.fps) FPS · \(Int(preset.duration)) sec")
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .foregroundStyle(VexelPalette.accent)
                                }
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(VexelPalette.soft)
                            }
                            .padding(11)
                            .background(VexelPalette.card, in: RoundedRectangle(cornerRadius: 15))
                            .overlay(RoundedRectangle(cornerRadius: 15).stroke(VexelPalette.line, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("preset.\(preset.name.lowercased().replacingOccurrences(of: " ", with: "-"))")
                    }
                }
            }
            .padding(18)
            .padding(.bottom, 24)
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
                .accessibilityIdentifier("home.tab.\(item.rawValue.lowercased())")
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
    let onExport: () -> Void

    private var stageSize: CGSize {
        if project.width > project.height { return CGSize(width: 108, height: 62) }
        if project.width == project.height { return CGSize(width: 78, height: 78) }
        return CGSize(width: 58, height: 88)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Button(action: onOpen) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 12).fill(VexelPalette.preview)
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("VEXEL PROJECT")
                                .font(.system(size: 7, weight: .black, design: .monospaced))
                                .tracking(1.2)
                            Spacer()
                            Text(project.modified.formatted(date: .abbreviated, time: .omitted).uppercased())
                                .font(.system(size: 7, weight: .semibold, design: .monospaced))
                        }
                        .foregroundStyle(VexelPalette.secondary)
                        Spacer()
                        HStack {
                            Spacer()
                            RoundedRectangle(cornerRadius: 5)
                                .fill(VexelPalette.field)
                                .frame(width: stageSize.width, height: stageSize.height)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(VexelPalette.accent.opacity(0.85), lineWidth: 1)
                                        .padding(6)
                                    Text("V")
                                        .font(.system(size: 17, weight: .black, design: .rounded))
                                        .foregroundStyle(VexelPalette.accent)
                                }
                            Spacer()
                        }
                        Spacer()
                        HStack(spacing: 5) {
                            Circle().fill(VexelPalette.accent).frame(width: 5, height: 5)
                            Text("EDITABLE COMPOSITION")
                                .font(.system(size: 7, weight: .bold, design: .monospaced))
                                .tracking(0.8)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(VexelPalette.soft)
                    }
                    .padding(12)
                }
                .frame(height: 154)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("project.open.\(project.id.uuidString)")

            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(VexelPalette.text)
                        .lineLimit(1)
                    Text("\(project.width) × \(project.height) · \(project.fps) FPS")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(VexelPalette.secondary)
                }
                Spacer(minLength: 0)
                Menu {
                    Button(action: onOpen) { Label("Open", systemImage: "arrow.up.right.square") }
                    Button(action: onDuplicate) { Label("Duplicate", systemImage: "plus.square.on.square") }
                    Button(action: onExport) { Label("Export project", systemImage: "square.and.arrow.up") }
                    Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(VexelPalette.secondary)
                        .frame(width: 32, height: 34)
                        .background(VexelPalette.field, in: Circle())
                }
                .accessibilityIdentifier("project.actions.\(project.id.uuidString)")
            }
            Text("Modified \(project.modified.formatted(date: .abbreviated, time: .shortened))")
                .font(.system(size: 9))
                .foregroundStyle(VexelPalette.secondary)
        }
        .padding(11)
        .background(VexelPalette.card, in: RoundedRectangle(cornerRadius: 17))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(VexelPalette.line, lineWidth: 1))
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
                    TextField("Project name", text: $title).accessibilityIdentifier("newProject.name")
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
                        .accessibilityIdentifier("preset.\(preset.name.lowercased().replacingOccurrences(of: " ", with: "-"))")
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
                    .accessibilityIdentifier("newProject.create")
                }
            }
        }
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
    @AppStorage("vexel.previewScale") private var previewScale = 1.0
    @AppStorage("vexel.theme") private var theme = "dark"
    @AppStorage("vexel.language") private var language = "system"
    @AppStorage("vexel.safeSnapshots") private var safeSnapshots = true
    @AppStorage("vexel.savedEasings") private var savedEasingsData = "[]"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Settings").font(.system(size: 23, weight: .bold, design: .rounded)).foregroundStyle(VexelPalette.text)
                    Text("Configure your editing workspace").font(.system(size: 12)).foregroundStyle(VexelPalette.secondary)
                }
                settingsGroup("APPEARANCE") {
                    settingRow("Theme", detail: theme.capitalized + " appearance", symbol: "moon.stars") {
                        Picker("Theme", selection: $theme) {
                            Text("Dark").tag("dark"); Text("Light").tag("light"); Text("System").tag("system")
                        }.pickerStyle(.menu).tint(VexelPalette.accent)
                    }
                    settingRow("Language", detail: language == "system" ? "Follow device language" : (language == "pt" ? "Português" : "English"), symbol: "globe") {
                        Picker("Language", selection: $language) {
                            Text("System").tag("system"); Text("English").tag("en"); Text("Português").tag("pt")
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
                    settingRow("Preview scale", detail: "\(Int(previewScale * 100))% of display size", symbol: "viewfinder") {
                        Picker("Preview scale", selection: $previewScale) {
                            Text("100%").tag(1.0)
                            Text("50%").tag(0.5)
                            Text("25%").tag(0.25)
                        }.pickerStyle(.menu).tint(VexelPalette.accent)
                    }
                }
                settingsGroup("STORAGE & SAFETY") {
                    settingToggle("Mirror projects to Files", detail: "Keep project copies in the Files app", symbol: "folder", value: $mirrorProjects)
                    settingToggle("Recovery snapshots", detail: "Keep periodic recovery copies while editing", symbol: "clock.arrow.circlepath", value: $safeSnapshots)
                }
                settingsGroup("SAVED CURVES") {
                    if savedCurves.isEmpty {
                        Text("No saved curves yet. Save a Bézier curve from the curve editor.")
                            .font(.system(size: 10)).foregroundStyle(VexelPalette.secondary)
                    } else {
                        ForEach(savedCurves) { curve in
                            HStack(spacing: 8) {
                                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                                    .foregroundStyle(VexelPalette.accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(curve.name).font(.system(size: 11, weight: .semibold)).foregroundStyle(VexelPalette.text)
                                    Text("Cubic Bézier").font(.system(size: 9)).foregroundStyle(VexelPalette.secondary)
                                }
                                Spacer()
                                Button(role: .destructive) { deleteSavedCurve(curve.id) } label: {
                                    Image(systemName: "trash").font(.system(size: 11))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                settingsGroup("INFORMATION") {
                    settingRow("Project format", detail: ".vexelproj · native project", symbol: "doc.zipper") {
                        Text("v1").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(VexelPalette.secondary)
                    }
                    settingRow("Third-party licenses", detail: "Open-source notices and attributions", symbol: "text.book.closed") {
                        Text("GPL-3.0").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(VexelPalette.secondary)
                    }
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

    private var savedCurves: [VexelSavedEasing] {
        guard let data = savedEasingsData.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([VexelSavedEasing].self, from: data)) ?? []
    }

    private func deleteSavedCurve(_ id: UUID) {
        let remaining = savedCurves.filter { $0.id != id }
        guard let data = try? JSONEncoder().encode(remaining) else { return }
        savedEasingsData = String(decoding: data, as: UTF8.self)
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
    }
}


private extension UTType {
    static let vexelProject = UTType(
        exportedAs: "com.ragestudios.vexel.project",
        conformingTo: .zip
    )
}
