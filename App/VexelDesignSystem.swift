import SwiftUI
import UIKit

enum VexelPalette {
    static let background = Color.adaptive(dark: 0x080B0D, light: 0xF2F5F5)
    static let bar = Color.adaptive(dark: 0x0D1215, light: 0xFFFFFF)
    static let sheet = Color.adaptive(dark: 0x11191C, light: 0xFFFFFF)
    static let card = Color.adaptive(dark: 0x151F23, light: 0xFFFFFF)
    static let field = Color.adaptive(dark: 0x202C31, light: 0xE8EEEE)
    static let line = Color.adaptive(dark: 0x344349, light: 0xD5DEDF)
    static let text = Color.adaptive(dark: 0xF4F8F8, light: 0x142023)
    static let soft = Color.adaptive(dark: 0xB8C7CA, light: 0x405256)
    static let secondary = Color.adaptive(dark: 0x84979B, light: 0x65777B)
    static let accent = Color.adaptive(dark: 0x62E0CE, light: 0x087F73)
    static let teal = Color.adaptive(dark: 0x55CDBE, light: 0x0B8F84)
    static let pink = Color.adaptive(dark: 0xFF7894, light: 0xD42B52)
    static let amber = Color.adaptive(dark: 0xF5C66B, light: 0xA87300)
    static let blue = Color.adaptive(dark: 0x79B9FF, light: 0x2D6BC5)
    static let preview = Color(hex: 0x0B1014)
    static let lane = Color.adaptive(dark: 0x111A1E, light: 0xE7EEEE)
    static let clipAudio = Color.adaptive(dark: 0xD75B78, light: 0xC2385E)
    static let clipText = Color.adaptive(dark: 0x4D9DCE, light: 0x287BAE)
    static let highlight = Color.adaptive(dark: 0xA4F1E5, light: 0x0A8E80)
}

extension Color {
    static func adaptive(dark: UInt32, light: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .light ? light : dark
            return UIColor(red: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255, blue: CGFloat(value & 0xFF) / 255, alpha: 1)
        })
    }
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: 1)
    }
}

enum VexelMotion {
    static let navigation = Animation.spring(response: 0.48, dampingFraction: 0.88, blendDuration: 0.12)
    static let panel = Animation.spring(response: 0.38, dampingFraction: 0.82, blendDuration: 0.1)
    static let interactive = Animation.spring(response: 0.3, dampingFraction: 0.76, blendDuration: 0.08)
    static let timeline = Animation.spring(response: 0.24, dampingFraction: 0.9, blendDuration: 0.05)
}

struct VexelPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.975 : 1).opacity(configuration.isPressed ? 0.86 : 1).animation(VexelMotion.interactive, value: configuration.isPressed)
    }
}

struct VexelSectionLabel: View {
    let title: String
    var trailing: String? = nil
    var body: some View {
        HStack {
            Text(title.uppercased()).font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1.5).foregroundStyle(VexelPalette.secondary)
            Spacer()
            if let trailing { Text(trailing).font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(VexelPalette.secondary) }
        }
    }
}

struct VexelPanel<Content: View>: View {
    var padding: CGFloat = 15
    var emphasis = false
    @ViewBuilder var content: Content
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 19, style: .continuous) }
    var body: some View {
        content.padding(padding)
            .background {
                shape.fill(.ultraThinMaterial)
                shape.fill(LinearGradient(colors: [VexelPalette.card.opacity(emphasis ? 0.96 : 0.84), VexelPalette.sheet.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .overlay { shape.stroke(LinearGradient(colors: [VexelPalette.line.opacity(0.88), VexelPalette.line.opacity(0.28), VexelPalette.highlight.opacity(emphasis ? 0.24 : 0.08)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1) }
            .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
    }
}

struct VexelActionButton: View {
    let title: String
    let systemImage: String
    var prominent = false
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage).font(.system(size: 12, weight: .semibold)).foregroundStyle(prominent ? Color.black : VexelPalette.text).padding(.horizontal, 14).frame(minHeight: 40)
                .background {
                    RoundedRectangle(cornerRadius: 13, style: .continuous).fill(prominent ? VexelPalette.accent : VexelPalette.field.opacity(0.82))
                        .overlay { if prominent { RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(VexelPalette.highlight.opacity(0.4), lineWidth: 1) } }
                }
        }.buttonStyle(VexelPressStyle())
    }
}

struct VexelIconButton: View {
    let symbol: String
    var active = false
    var disabled = false
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 14, weight: .semibold)).foregroundStyle(disabled ? VexelPalette.secondary.opacity(0.35) : (active ? VexelPalette.accent : VexelPalette.soft)).frame(width: 38, height: 38)
                .background { RoundedRectangle(cornerRadius: 13, style: .continuous).fill(active ? VexelPalette.accent.opacity(0.14) : VexelPalette.field.opacity(0.7)).overlay { RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(VexelPalette.line.opacity(active ? 0.65 : 0.35), lineWidth: 1) } }
        }.buttonStyle(VexelPressStyle()).disabled(disabled).accessibilityLabel(symbol)
    }
}

struct VexelEmptyState: View {
    let symbol: String
    let title: String
    let detail: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 30, weight: .light)).foregroundStyle(VexelPalette.accent)
            Text(title).font(.system(size: 17, weight: .bold)).foregroundStyle(VexelPalette.text)
            Text(detail).font(.system(size: 12)).foregroundStyle(VexelPalette.secondary).multilineTextAlignment(.center).frame(maxWidth: 260)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension View {
    func vexelScreenBackground() -> some View {
        background {
            ZStack {
                VexelPalette.background.ignoresSafeArea()
                LinearGradient(colors: [VexelPalette.accent.opacity(0.055), .clear, VexelPalette.blue.opacity(0.025)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            }
        }
    }
}