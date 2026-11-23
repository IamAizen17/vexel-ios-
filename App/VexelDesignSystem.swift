import SwiftUI
import UIKit

enum VexelPalette {
    static let background = Color.adaptive(dark: 0x06050E, light: 0xF4F2FC)
    static let bar = Color.adaptive(dark: 0x0E0C1A, light: 0xFFFFFF)
    static let sheet = Color.adaptive(dark: 0x12102A, light: 0xFFFFFF)
    static let card = Color.adaptive(dark: 0x14112B, light: 0xE9E5F7)
    static let field = Color.adaptive(dark: 0x1C1840, light: 0xEEEAFB)
    static let line = Color.adaptive(dark: 0x2C2650, light: 0xD3CCEB)
    static let text = Color.adaptive(dark: 0xF1EEFF, light: 0x1A1530)
    static let soft = Color.adaptive(dark: 0xB9B4D6, light: 0x4A4468)
    static let secondary = Color.adaptive(dark: 0x8F88B8, light: 0x666085)
    static let accent = Color.adaptive(dark: 0xC084FC, light: 0x7C3AED)
    static let teal = Color.adaptive(dark: 0x4FD1C5, light: 0x0B8F84)
    static let pink = Color.adaptive(dark: 0xFF6B8B, light: 0xD42B52)
    static let amber = Color.adaptive(dark: 0xFFC857, light: 0xC98A00)
    static let blue = Color.adaptive(dark: 0x5EA8FF, light: 0x2D6BC5)
    static let preview = Color(hex: 0x0E1016)
    static let lane = Color(hex: 0x14112B)
    static let clipAudio = Color.adaptive(dark: 0xC2385E, light: 0xC2385E)
    static let clipText = Color.adaptive(dark: 0x6D45E8, light: 0x5B3FD6)
}

extension Color {

    static func adaptive(dark: UInt32, light: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .light ? light : dark
            return UIColor(
                red: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255,
                alpha: 1
            )
        })
    }

    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

struct VexelSectionLabel: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.7)
                .foregroundStyle(VexelPalette.secondary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(VexelPalette.secondary)
            }
        }
    }
}

struct VexelPanel<Content: View>: View {
    var padding: CGFloat = 14
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(VexelPalette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(VexelPalette.line.opacity(0.75), lineWidth: 1))
    }
}

struct VexelActionButton: View {
    let title: String
    let systemImage: String
    var prominent = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(prominent ? Color.black : VexelPalette.text)
                .padding(.horizontal, 13)
                .frame(height: 38)
                .background(prominent ? VexelPalette.accent : VexelPalette.field, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

struct VexelIconButton: View {
    let symbol: String
    var active = false
    var disabled = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(disabled ? VexelPalette.secondary.opacity(0.35) : (active ? VexelPalette.accent : VexelPalette.soft))
                .frame(width: 36, height: 36)
                .background(active ? VexelPalette.accent.opacity(0.13) : VexelPalette.field.opacity(0.65), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

struct VexelEmptyState: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(VexelPalette.accent)
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(VexelPalette.text)
            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(VexelPalette.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension View {
    func vexelScreenBackground() -> some View {
        background(VexelPalette.background.ignoresSafeArea())
    }
}
