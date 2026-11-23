import SwiftUI
import VexelCore

struct VexelScenePreview: View {
    let project: VexelProjectItem
    let time: Double

    private var document: ProjectDocument? {
        guard let data = project.documentJSON?.data(using: .utf8) else { return nil }
        return try? ProjectDocument(data: data)
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
                        Self.draw(layer, scene: scene, in: &context)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityLabel("Composition preview at \(time, format: .number.precision(.fractionLength(2))) seconds")
            } else {
                VexelEmptyState(symbol: "exclamationmark.triangle", title: "Preview unavailable", detail: "The project document could not be decoded.")
            }
        }
    }

    private static func draw(_ layer: EvaluatedLayer, scene: FrameScene, in context: inout GraphicsContext) {
        context.drawLayer { layerContext in
            layerContext.opacity = layer.opacity
            layerContext.translateBy(
                x: Double(scene.width) / 2 + layer.position.x,
                y: Double(scene.height) / 2 + layer.position.y
            )
            layerContext.rotate(by: .degrees(layer.rotationDegrees))
            layerContext.scaleBy(x: layer.scale.x, y: layer.scale.y)

            let rect = CGRect(
                x: -layer.size.x / 2,
                y: -layer.size.y / 2,
                width: max(0, layer.size.x),
                height: max(0, layer.size.y)
            )
            let color = color(layer.fillColor ?? "#55CDBE")

            if layer.type == "text" {
                let content = layer.text ?? layer.name
                let text = Text(content)
                    .font(.system(size: max(1, layer.fontSize ?? 64), weight: .medium))
                    .foregroundColor(color)
                layerContext.draw(text, at: .zero, anchor: .center)
            } else if layer.type == "image" || layer.type == "video" {
                layerContext.fill(Path(roundedRect: rect, cornerRadius: 12), with: .color(Color.white.opacity(0.08)))
                layerContext.stroke(Path(roundedRect: rect, cornerRadius: 12), with: .color(VexelPalette.secondary), lineWidth: 2)
                let text = Text(layer.type == "video" ? "VIDEO SOURCE" : "IMAGE SOURCE")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(VexelPalette.soft)
                layerContext.draw(text, at: .zero, anchor: .center)
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
        guard normalized.count == 6, let hex = UInt32(normalized, radix: 16) else {
            return VexelPalette.accent
        }
        return Color(hex: hex)
    }
}
