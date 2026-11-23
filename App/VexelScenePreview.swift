import SwiftUI
import UIKit
import AVFoundation
import VexelCore

struct VexelScenePreview: View {
    let project: VexelProjectItem
    let time: Double
    @State private var images: [String: UIImage] = [:]
    @State private var videoFrames: [String: UIImage] = [:]

    private var document: ProjectDocument? {
        guard let data = project.documentJSON?.data(using: .utf8) else { return nil }
        return try? ProjectDocument(data: data)
    }

    private var assetURLs: [String: URL] {
        guard let document, let root = project.assetsDirectory else { return [:] }
        return Dictionary(
            (document.fields["assets"]?.arrayValue ?? []).compactMap { value -> (String, URL)? in
                guard let asset = value.objectValue,
                      let id = asset["id"]?.stringValue,
                      let path = asset["path"]?.stringValue else { return nil }
                return (id, URL(fileURLWithPath: root).appendingPathComponent(path))
            },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private var assetSignature: String {
        assetURLs.map { "\($0.key):\($0.value.path)" }.sorted().joined(separator: "|")
    }

    private var videoFrameKey: String {
        let fps = document?.fields["composition"]?.objectValue?["fps"]?.numberValue ?? 30
        return "\(Int((time * min(fps, 15)).rounded()))|\(assetSignature)"
    }

    var body: some View {
        GeometryReader { geometry in
            if let document {
                Canvas(opaque: true, colorMode: .nonLinear) { context, size in
                    let scene = SceneEvaluator.evaluate(document, at: time)
                    let fit = min(size.width / CGFloat(scene.width), size.height / CGFloat(scene.height))
                    let canvasWidth = CGFloat(scene.width) * fit
                    let canvasHeight = CGFloat(scene.height) * fit
                    let origin = CGPoint(x: (size.width - canvasWidth) / 2, y: (size.height - canvasHeight) / 2)
                    context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(VexelPalette.preview))
                    context.fill(
                        Path(CGRect(origin: origin, size: CGSize(width: canvasWidth, height: canvasHeight))),
                        with: .color(Self.color(scene.background))
                    )
                    context.translateBy(x: origin.x, y: origin.y)
                    context.scaleBy(x: fit, y: fit)
                    for layer in scene.layers {
                        Self.draw(layer, scene: scene, images: images, videoFrames: videoFrames, in: &context)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityLabel("Composition preview at \(time, format: .number.precision(.fractionLength(2))) seconds")
            } else {
                VexelEmptyState(symbol: "exclamationmark.triangle", title: "Preview unavailable", detail: "The project document could not be decoded.")
            }
        }
        .task(id: assetSignature) {
            var loaded: [String: UIImage] = [:]
            for (id, url) in assetURLs {
                guard let image = UIImage(contentsOfFile: url.path) else { continue }
                loaded[id] = image
            }
            images = loaded
        }
        .task(id: videoFrameKey) {
            guard let document else { videoFrames = [:]; return }
            let scene = SceneEvaluator.evaluate(document, at: time)
            let requests = scene.layers.compactMap { layer -> (String, URL, Double)? in
                guard layer.type == "video",
                      let id = layer.assetID,
                      let url = assetURLs[id] else { return nil }
                return (id, url, layer.localTime)
            }
            let decoded = await Task.detached(priority: .userInitiated) {
                var frames: [String: Data] = [:]
                for (id, url, seconds) in requests {
                    let asset = AVURLAsset(url: url)
                    let generator = AVAssetImageGenerator(asset: asset)
                    generator.appliesPreferredTrackTransform = true
                    generator.maximumSize = CGSize(width: 1280, height: 1280)
                    generator.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 30)
                    generator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 30)
                    guard let image = try? generator.copyCGImage(
                        at: CMTime(seconds: max(0, seconds), preferredTimescale: 600),
                        actualTime: nil
                    ) else { continue }
                    let data = UIImage(cgImage: image).jpegData(compressionQuality: 0.86)
                    if let data { frames[id] = data }
                }
                return frames
            }.value
            guard !Task.isCancelled else { return }
            videoFrames = decoded.compactMapValues { UIImage(data: $0) }
        }
    }

    private static func draw(
        _ layer: EvaluatedLayer,
        scene: FrameScene,
        images: [String: UIImage],
        videoFrames: [String: UIImage],
        in context: inout GraphicsContext
    ) {
        context.drawLayer { layerContext in
            layerContext.opacity = layer.opacity
            layerContext.translateBy(
                x: CGFloat(Double(scene.width) / 2 + layer.position.x),
                y: CGFloat(Double(scene.height) / 2 + layer.position.y)
            )
            layerContext.rotate(by: .degrees(layer.rotationDegrees))
            layerContext.scaleBy(x: CGFloat(layer.scale.x), y: CGFloat(layer.scale.y))

            let rect = CGRect(
                x: CGFloat(-layer.size.x / 2),
                y: CGFloat(-layer.size.y / 2),
                width: CGFloat(max(0, layer.size.x)),
                height: CGFloat(max(0, layer.size.y))
            )
            let color = color(layer.fillColor ?? "#55CDBE")

            if layer.type == "text" {
                let content = layer.text ?? layer.name
                let text = Text(content)
                    .font(.system(size: max(1, layer.fontSize ?? 64), weight: .medium))
                    .foregroundColor(color)
                layerContext.draw(text, at: .zero, anchor: .center)
            } else if layer.type == "image" {
                if let assetID = layer.assetID, let image = images[assetID], let cgImage = image.cgImage {
                    let resolved = layerContext.resolve(Image(uiImage: image))
                    layerContext.draw(resolved, in: rect)
                } else {
                    layerContext.fill(Path(roundedRect: rect, cornerRadius: 12), with: .color(Color.white.opacity(0.08)))
                    layerContext.stroke(Path(roundedRect: rect, cornerRadius: 12), with: .color(VexelPalette.secondary), lineWidth: 2)
                    let text = Text("IMAGE SOURCE")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(VexelPalette.soft)
                    layerContext.draw(text, at: .zero, anchor: .center)
                }
            } else if layer.type == "video" {
                if let assetID = layer.assetID, let image = videoFrames[assetID], let cgImage = image.cgImage {
                    let resolved = layerContext.resolve(Image(decorative: cgImage, scale: image.scale))
                    layerContext.draw(resolved, in: rect)
                } else {
                    layerContext.fill(Path(roundedRect: rect, cornerRadius: 12), with: .color(Color.white.opacity(0.08)))
                    layerContext.stroke(Path(roundedRect: rect, cornerRadius: 12), with: .color(VexelPalette.secondary), lineWidth: 2)
                    let text = Text("VIDEO SOURCE")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(VexelPalette.soft)
                    layerContext.draw(text, at: .zero, anchor: .center)
                }
            } else if layer.type == "object3d" || layer.type == "model3d" {
                let text = Text("3D OBJECT")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(VexelPalette.amber)
                layerContext.draw(text, at: .zero, anchor: .center)
            } else {
                let path: Path
                switch layer.shapeKind?.lowercased() {
                case "ellipse", "circle", "oval":
                    path = Path(ellipseIn: rect)
                case "line":
                    var line = Path()
                    line.move(to: CGPoint(x: rect.minX, y: 0))
                    line.addLine(to: CGPoint(x: rect.maxX, y: 0))
                    path = line
                default:
                    path = Path(roundedRect: rect, cornerRadius: layer.shapeKind == "roundedRectangle" ? 24 : 0)
                }
                if layer.shapeKind == "line" {
                    layerContext.stroke(path, with: .color(color), lineWidth: 5)
                } else {
                    layerContext.fill(path, with: .color(color))
                }
            }
        }
    }

    private static func color(_ value: String) -> Color {
        let normalized = value.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard let hex = UInt64(normalized, radix: 16) else { return VexelPalette.accent }
        if normalized.count == 8 {
            return Color(
                .sRGB,
                red: Double((hex >> 24) & 0xFF) / 255,
                green: Double((hex >> 16) & 0xFF) / 255,
                blue: Double((hex >> 8) & 0xFF) / 255,
                opacity: Double(hex & 0xFF) / 255
            )
        }
        guard normalized.count == 6 else { return VexelPalette.accent }
        return Color(hex: UInt32(hex))
    }
}
