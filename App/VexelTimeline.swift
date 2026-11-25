import SwiftUI

struct VexelTimelineTrack: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var start: Double
    var duration: Double
    var kind: Kind
    var visible: Bool
    var locked: Bool
    var isGroup: Bool
    var isExpanded: Bool
    var children: [VexelTimelineTrack]
    var keyframes: [Double]
    var effects: [String]
    var sourceID: String?
    var sourceType: String?
    var sourceJSON: String?

    enum Kind: String, Codable, Hashable {
        case visual
        case text
        case audio
        case group
        case rendered3D
    }

    init(
        id: UUID = UUID(),
        name: String,
        start: Double = 0,
        duration: Double,
        kind: Kind = .visual,
        visible: Bool = true,
        locked: Bool = false,
        isGroup: Bool = false,
        isExpanded: Bool = false,
        children: [VexelTimelineTrack] = [],
        keyframes: [Double] = [],
        effects: [String] = [],
        sourceID: String? = nil,
        sourceType: String? = nil,
        sourceJSON: String? = nil
    ) {
        self.id = id
        self.name = name
        self.start = start
        self.duration = duration
        self.kind = kind
        self.visible = visible
        self.locked = locked
        self.isGroup = isGroup
        self.isExpanded = isExpanded
        self.children = children
        self.keyframes = keyframes
        self.effects = effects
        self.sourceID = sourceID
        self.sourceType = sourceType
        self.sourceJSON = sourceJSON
    }
}

struct VexelTimelinePanel: View {
    @Binding var tracks: [VexelTimelineTrack]
    @Binding var currentTime: Double
    @Binding var markers: [VexelMarker]
    @Binding var selectedTrackID: UUID?
    let duration: Double
    let fps: Int
    var compact = false
    let onMarkerEdit: (VexelMarker) -> Void
    let onNotice: (String) -> Void
    let onGraph: () -> Void
    let onTrackTimingCommit: (UUID, Double, Double) -> Void
    let onTrackVisibilityChange: (UUID, Bool) -> Void
    let onTrackLockChange: (UUID, Bool) -> Void
    let onEditBegan: () -> Void
    let onEditEnded: () -> Void

    @State private var zoom: CGFloat = 72
    @State private var pinchStartZoom: CGFloat?
    @State private var showMarkerEditor = false

    private let rulerHeight: CGFloat = 34
    private let rowHeight: CGFloat = 44
    private let headerWidth: CGFloat = 116
    private let minimumZoom: CGFloat = 8
    private let maximumZoom: CGFloat = 2000

    private var contentWidth: CGFloat { max(320, CGFloat(duration) * zoom + 32) }
    private var timelineHeight: CGFloat {
        let natural = rulerHeight + CGFloat(visibleRowCount) * rowHeight + CGFloat(max(visibleRowCount, 1)) * 3
        return compact ? min(84, max(72, natural)) : min(210, max(112, natural))
    }

    private var snapPoints: [Double] {
        func collect(_ values: [VexelTimelineTrack], offset: Double = 0) -> [Double] {
            values.flatMap { track in
                let start = offset + track.start
                return [start, start + track.duration] + collect(track.children, offset: start)
            }
        }
        return [0, duration, currentTime] + markers.map(\.time) + collect(tracks)
    }

    private var visibleRowCount: Int {
        func count(_ values: [VexelTimelineTrack]) -> Int {
            values.reduce(0) { total, track in
                total + 1 + (track.isGroup && track.isExpanded ? count(track.children) : 0)
            }
        }
        return count(tracks)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 5 : 8) {
            HStack {
                VexelSectionLabel(title: "Timeline", trailing: "\(visibleRowCount) TRACKS · \(markers.count) MARKERS")
                Spacer()
                Button {
                    onEditBegan()
                    let marker = VexelMarker(time: currentTime)
                    markers.append(marker)
                    onEditEnded()
                    onMarkerEdit(marker)
                } label: {
                    Label("Marker", systemImage: "flag")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(VexelPalette.accent)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("timeline.marker.add")
                Button(action: onGraph) {
                    Label("Graph", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(VexelPalette.accent)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("timeline.graph")
            }

            if tracks.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "timeline.selection").foregroundStyle(VexelPalette.secondary)
                    Text("Add a layer to create a timeline track.")
                        .font(.system(size: 10)).foregroundStyle(VexelPalette.secondary)
                    Spacer()
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(VexelPalette.lane, in: RoundedRectangle(cornerRadius: 9))
            } else {
                GeometryReader { geometry in
                    let timelineWidth = max(contentWidth, geometry.size.width - headerWidth)
                    let totalWidth = headerWidth + timelineWidth
                    ScrollView([.horizontal, .vertical], showsIndicators: true) {
                        ZStack(alignment: .topLeading) {
                            VStack(spacing: 3) {
                                HStack(spacing: 0) {
                                    Text("LAYERS")
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .tracking(0.8)
                                        .foregroundStyle(VexelPalette.secondary)
                                        .frame(width: headerWidth, height: rulerHeight, alignment: .leading)
                                        .padding(.leading, 8)
                                    ruler(width: timelineWidth)
                                }
                                ForEach($tracks) { $track in
                                    VexelTimelineTrackRow(
                                        track: $track,
                                        depth: 0,
                                        width: timelineWidth,
                                        zoom: zoom,
                                        compositionDuration: duration,
                                        containerOffset: 0,
                                        containerDuration: duration,
                                        fps: fps,
                                        snapPoints: snapPoints,
                                        selectedTrackID: $selectedTrackID,
                                        onSelect: { name in
                                            onNotice("Selected \(name).")
                                        },
                                        onMarkerEdit: onMarkerEdit,
                                        onTrackTimingCommit: onTrackTimingCommit,
                                        onTrackVisibilityChange: onTrackVisibilityChange,
                                        onTrackLockChange: onTrackLockChange,
                                        onEditBegan: onEditBegan,
                                        onEditEnded: onEditEnded
                                    )
                                }
                            }
                            Rectangle()
                                .fill(VexelPalette.accent)
                                .frame(width: 1.5, height: rulerHeight + CGFloat(visibleRowCount) * rowHeight + CGFloat(max(visibleRowCount, 1)) * 3)
                                .offset(x: headerWidth + CGFloat(currentTime) * zoom, y: 0)
                                .allowsHitTesting(false)
                        }
                        .frame(width: totalWidth, alignment: .topLeading)
                        .simultaneousGesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    if pinchStartZoom == nil { pinchStartZoom = zoom }
                                    zoom = min(maximumZoom, max(minimumZoom, (pinchStartZoom ?? zoom) * value))
                                }
                                .onEnded { _ in pinchStartZoom = nil }
                        )
                    }
                }
                .frame(height: timelineHeight)
                if !compact {
                    HStack {
                        Text("PINCH TO ZOOM")
                        Spacer()
                        Text("\(zoom, specifier: "%.0f") PX/S")
                        Text("·")
                        Text("\(currentTime, specifier: "%.2f") S")
                    }
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(VexelPalette.secondary)
                }
            }
        }
        .padding(.horizontal, compact ? 8 : 14)
        .padding(.vertical, compact ? 4 : 10)
        .background(VexelPalette.sheet)
        .accessibilityIdentifier("editor.timeline")
    }

    private func ruler(width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, size in
                let majorInterval = tickInterval(for: zoom)
                let minorInterval = majorInterval / 4
                var time = 0.0
                while time <= duration + 0.0001 {
                    let x = CGFloat(time) * zoom
                    let major = abs(time / majorInterval - (time / majorInterval).rounded()) < 0.0001
                    var line = Path()
                    line.move(to: CGPoint(x: x, y: size.height))
                    line.addLine(to: CGPoint(x: x, y: major ? 17 : 25))
                    context.stroke(line, with: .color(VexelPalette.line), lineWidth: 1)
                    if major {
                        context.draw(
                            Text(timeLabel(time))
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(VexelPalette.secondary),
                            at: CGPoint(x: x + 4, y: 8),
                            anchor: .leading
                        )
                    }
                    time += minorInterval
                }
                var end = Path()
                end.move(to: CGPoint(x: CGFloat(duration) * zoom, y: 0))
                end.addLine(to: CGPoint(x: CGFloat(duration) * zoom, y: size.height))
                context.stroke(end, with: .color(VexelPalette.pink.opacity(0.7)), lineWidth: 1.5)
            }
            .frame(width: width, height: rulerHeight)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        currentTime = min(duration, max(0, Double(value.location.x / zoom)))
                    }
            )

            ForEach(markers) { marker in
                Button { onMarkerEdit(marker) } label: {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(markerColor(marker.color))
                        .frame(width: 18, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .offset(x: CGFloat(marker.time) * zoom - 8, y: 11)
            }
        }
        .frame(width: width, height: rulerHeight)
        .background(VexelPalette.bar.opacity(0.65), in: RoundedRectangle(cornerRadius: 5))
    }

    private func tickInterval(for scale: CGFloat) -> Double {
        let options: [Double] = [1.0 / Double(max(fps, 1)), 0.1, 0.25, 0.5, 1, 2, 5, 10, 15, 30, 60]
        return options.first(where: { CGFloat($0) * scale >= 56 }) ?? 120
    }

    private func timeLabel(_ value: Double) -> String {
        abs(value - value.rounded()) < 0.0001 ? "\(Int(value))s" : String(format: "%.1fs", value)
    }

    private func markerColor(_ value: String) -> Color {
        switch value.lowercased() {
        case "pink", "red": return VexelPalette.pink
        case "amber", "yellow": return VexelPalette.amber
        case "blue": return VexelPalette.blue
        default: return VexelPalette.teal
        }
    }
}

private struct VexelTimelineTrackRow: View {
    @Binding var track: VexelTimelineTrack
    let depth: Int
    let width: CGFloat
    let zoom: CGFloat
    let compositionDuration: Double
    let containerOffset: Double
    let containerDuration: Double
    let fps: Int
    let snapPoints: [Double]
    @Binding var selectedTrackID: UUID?
    let onSelect: (String) -> Void
    let onMarkerEdit: (VexelMarker) -> Void
    let onTrackTimingCommit: (UUID, Double, Double) -> Void
    let onTrackVisibilityChange: (UUID, Bool) -> Void
    let onTrackLockChange: (UUID, Bool) -> Void
    let onEditBegan: () -> Void
    let onEditEnded: () -> Void

    @State private var moveOrigin: Double?
    @State private var trimOrigin: (start: Double, duration: Double)?
    private let headerWidth: CGFloat = 116

    private var clipColor: Color {
        switch track.kind {
        case .audio: return VexelPalette.clipAudio
        case .text: return VexelPalette.clipText
        case .group: return VexelPalette.blue
        case .rendered3D: return VexelPalette.amber
        case .visual: return VexelPalette.teal
        }
    }

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 0) {
                trackHeader
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(VexelPalette.lane.opacity(0.85))
                        .frame(height: 39)
                    HStack(spacing: 0) {
                        Color.clear.frame(width: CGFloat(containerOffset + track.start) * zoom)
                        clip
                        Spacer(minLength: 0)
                    }
                    .frame(width: width, height: 39, alignment: .leading)
                }
                .frame(width: width, height: 42)
            }
            .frame(width: headerWidth + width, height: 42)

            if track.isGroup && track.isExpanded {
                ForEach($track.children) { $child in
                    VexelTimelineTrackRow(
                        track: $child,
                        depth: depth + 1,
                        width: width,
                        zoom: zoom,
                        compositionDuration: compositionDuration,
                        containerOffset: containerOffset + track.start,
                        containerDuration: track.duration,
                        fps: fps,
                        snapPoints: snapPoints,
                        selectedTrackID: $selectedTrackID,
                        onSelect: onSelect,
                        onMarkerEdit: onMarkerEdit,
                        onTrackTimingCommit: onTrackTimingCommit,
                        onTrackVisibilityChange: onTrackVisibilityChange,
                        onTrackLockChange: onTrackLockChange,
                        onEditBegan: onEditBegan,
                        onEditEnded: onEditEnded
                    )
                }
            }
        }
    }

    private var trackHeader: some View {
        HStack(spacing: 4) {
            if track.isGroup {
                Button { track.isExpanded.toggle() } label: {
                    Image(systemName: track.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .frame(width: 12, height: 24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(track.isExpanded ? "Collapse group" : "Expand group")
            }
            RoundedRectangle(cornerRadius: 2)
                .fill(clipColor)
                .frame(width: 3, height: 18)
            Button {
                selectedTrackID = track.id
                onSelect(track.name)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: track.kind == .audio ? "waveform" : (track.kind == .text ? "textformat" : (track.isGroup ? "folder" : "square")))
                        .font(.system(size: 9, weight: .bold))
                    Text(track.name)
                        .font(.system(size: 8, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select \(track.name)")
            .accessibilityIdentifier("timeline.layer.select.\(track.id.uuidString)")
            Button {
                onEditBegan()
                onTrackVisibilityChange(track.id, !track.visible)
                onEditEnded()
            } label: {
                Image(systemName: track.visible ? "eye" : "eye.slash")
                    .font(.system(size: 8))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(track.visible ? "Hide \(track.name)" : "Show \(track.name)")
            .accessibilityIdentifier("timeline.layer.visibility.\(track.id.uuidString)")
            Button {
                onEditBegan()
                onTrackLockChange(track.id, !track.locked)
                onEditEnded()
            } label: {
                Image(systemName: track.locked ? "lock.fill" : "lock.open")
                    .font(.system(size: 8))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(track.locked ? "Unlock \(track.name)" : "Lock \(track.name)")
            .accessibilityIdentifier("timeline.layer.lock.\(track.id.uuidString)")
        }
        .foregroundStyle(VexelPalette.soft)
        .padding(.leading, CGFloat(depth) * 7 + 6)
        .padding(.trailing, 5)
        .frame(width: headerWidth, height: 42)
        .background(selectedTrackID == track.id ? VexelPalette.accent.opacity(0.12) : VexelPalette.lane.opacity(0.7))
        .overlay(alignment: .trailing) {
            Rectangle().fill(VexelPalette.line.opacity(0.5)).frame(width: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private var clip: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(clipColor.opacity(track.visible ? 0.82 : 0.24))
            .frame(width: max(72, CGFloat(track.duration) * zoom), height: 28)
            .overlay(alignment: .leading) {
                Rectangle().fill(.white.opacity(0.8)).frame(width: 4, height: 18).clipShape(Capsule())
                    .gesture(trimStartGesture)
            }
            .overlay(alignment: .trailing) {
                Rectangle().fill(.white.opacity(0.8)).frame(width: 4, height: 18).clipShape(Capsule())
                    .gesture(trimEndGesture)
            }
            .overlay(alignment: .topLeading) {
                ForEach(track.keyframes.filter { $0.isFinite && $0 >= 0 && $0 <= track.duration }, id: \.self) { time in
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundStyle(.white.opacity(0.95))
                        .offset(x: CGFloat(time) * zoom + 7, y: 4)
                        .accessibilityHidden(true)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(selectedTrackID == track.id ? VexelPalette.accent : .clear, lineWidth: 1.5))
            .contentShape(Rectangle())
            .gesture(moveGesture)
            .opacity(track.locked ? 0.62 : 1)
            .accessibilityLabel("\(track.name) timeline clip")
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard !track.locked else { return }
                if moveOrigin == nil {
                    moveOrigin = track.start
                    onEditBegan()
                }
                let proposed = (moveOrigin ?? track.start) + Double(value.translation.width / zoom)
                let absolute = snapped(containerOffset + proposed) - containerOffset
                track.start = absolute.clamped(to: 0...(max(0, containerDuration - track.duration)))
            }
             .onEnded { _ in
                if moveOrigin != nil {
                    onTrackTimingCommit(track.id, track.start, track.duration)
                    onEditEnded()
                }
                moveOrigin = nil
            }
    }

    private var trimStartGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                guard !track.locked else { return }
                if trimOrigin == nil {
                    trimOrigin = (track.start, track.duration)
                    onEditBegan()
                }
                guard let origin = trimOrigin else { return }
                let delta = Double(value.translation.width / zoom)
                let proposedAbsolute = snapped(containerOffset + origin.start + delta)
                let newStart = (proposedAbsolute - containerOffset).clamped(to: 0...(origin.start + origin.duration - 1 / Double(max(fps, 1))))
                track.start = newStart
                track.duration = origin.duration - (newStart - origin.start)
            }
             .onEnded { _ in
                if trimOrigin != nil {
                    onTrackTimingCommit(track.id, track.start, track.duration)
                    onEditEnded()
                }
                trimOrigin = nil
            }
    }

    private var trimEndGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                guard !track.locked else { return }
                if trimOrigin == nil {
                    trimOrigin = (track.start, track.duration)
                    onEditBegan()
                }
                guard let origin = trimOrigin else { return }
                let proposed = origin.duration + Double(value.translation.width / zoom)
                track.duration = max(1 / Double(max(fps, 1)), min(containerDuration - origin.start, proposed))
            }
            .onEnded { _ in
                if trimOrigin != nil {
                    onTrackTimingCommit(track.id, track.start, track.duration)
                    onEditEnded()
                }
                trimOrigin = nil
            }
    }

    private func snapped(_ value: Double) -> Double {
        let frame = (value * Double(max(fps, 1))).rounded() / Double(max(fps, 1))
        let tolerance = Double(8 / zoom)
        if let candidate = snapPoints.min(by: { abs($0 - frame) < abs($1 - frame) }),
           abs(candidate - frame) <= tolerance {
            return candidate
        }
        return frame
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
