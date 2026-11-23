import SwiftUI

enum VexelPalette {
    static let background = Color(hex: 0x06050E)
    static let bar = Color(hex: 0x0E0C1A)
    static let sheet = Color(hex: 0x12102A)
    static let card = Color(hex: 0x14112B)
    static let field = Color(hex: 0x1C1840)
    static let line = Color(hex: 0x2C2650)
    static let text = Color(hex: 0xF1EEFF)
    static let soft = Color(hex: 0xB9B4D6)
    static let secondary = Color(hex: 0x8F88B8)
    static let accent = Color(hex: 0xC084FC)
    static let teal = Color(hex: 0x4FD1C5)
    static let pink = Color(hex: 0xFF6B8B)
    static let amber = Color(hex: 0xFFC857)
    static let blue = Color(hex: 0x5EA8FF)
    static let preview = Color(hex: 0x0E1016)
    static let lane = Color(hex: 0x14112B)
    static let clipAudio = Color(hex: 0xC2385E)
    static let clipText = Color(hex: 0x6D45E8)
}

extension Color {
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
