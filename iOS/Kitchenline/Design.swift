import SwiftUI

/// Court identity: deep blue-green court paint + a sage-tinted kitchen zone,
/// with **one** vivid citrus-yellow accent (the ball color) reserved for the
/// ball itself, locked "in" arcs, and the Pro call-to-action. Unlike Vantage's
/// sharp-cornered drafting-table chrome elsewhere in this batch, Kitchenline's
/// app chrome uses soft rounded cards and a rounded display font — the court
/// diagram itself is the only place with literal straight-line geometry, and
/// its line weight is a bold painted stripe (3-4pt) rather than a 1pt hairline.
enum KLColor {
    static let paper = Color(light: Color(hex: 0xF3F8F6), dark: Color(hex: 0x0A1615))
    static let panel = Color(light: Color(hex: 0xE6F1EC), dark: Color(hex: 0x11211F))
    static let panelAlt = Color(light: Color(hex: 0xDCEDE6), dark: Color(hex: 0x162A27))
    static let ink = Color(light: Color(hex: 0x122421), dark: Color(hex: 0xEAF6F1))
    static let inkMuted = Color(light: Color(hex: 0x51695F), dark: Color(hex: 0x9CB7AC))
    static let hairline = Color(light: Color(hex: 0xC3DBD2), dark: Color(hex: 0x24413B))

    /// Court "paint" — deliberately stable across themes since it represents a
    /// physical playing surface, not app chrome.
    static let courtSurface = Color(hex: 0x0F6E63)
    static let courtSurfaceEdge = Color(hex: 0x0B5348)
    static let kitchenTint = Color(hex: 0x2E9683)
    static let courtLine = Color.white.opacity(0.94)
    static let net = Color(hex: 0x0B211D)

    /// The single vivid accent — a citrus pickleball-yellow. Reserved for the
    /// ball, locked/completed rep arcs, and the Pro CTA.
    static let citrus = Color(hex: 0xD8E23A)
    static let citrusDim = Color(hex: 0xD8E23A).opacity(0.35)

    /// A muted marker for a missed ("out") rep — never the citrus accent.
    static let miss = Color(hex: 0x9AA9A2)
}

enum KLFont {
    static func display(_ size: CGFloat = 30) -> Font { .system(size: size, weight: .bold, design: .rounded) }
    static func headline(_ size: CGFloat = 17) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
    static func value(_ size: CGFloat = 20) -> Font { .system(size: size, weight: .bold, design: .rounded) }
    static func body(_ size: CGFloat = 15) -> Font { .system(size: size, weight: .regular) }
    static func caption(_ size: CGFloat = 12) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }

    init(light: Color, dark: Color) {
        self.init(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

/// The primary rounded card container — soft corners, hairline border. The
/// deliberate opposite of Vantage's sharp 0-radius drafting panels.
struct KLCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KLColor.panel)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(KLColor.hairline, lineWidth: 1)
            )
    }
}

struct KLSectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(KLFont.caption())
            .tracking(1.4)
            .foregroundStyle(KLColor.inkMuted)
    }
}

/// Primary CTA — a full pill shape, citrus when the action is the AI/Pro
/// call-to-action, court-teal otherwise.
struct PillButtonStyle: ButtonStyle {
    var filled: Bool = true
    var tint: Color = KLColor.courtSurface
    var textColor: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(KLFont.headline())
            .foregroundStyle(filled ? textColor : tint)
            .padding(.vertical, 14)
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity)
            .background(filled ? tint : Color.clear)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(tint, lineWidth: filled ? 0 : 1.5))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension View {
    func pillButton(filled: Bool = true, tint: Color = KLColor.courtSurface, textColor: Color = .white) -> some View {
        buttonStyle(PillButtonStyle(filled: filled, tint: tint, textColor: textColor))
    }
}

/// A rounded tag chip used for the self-rated weak-shot picker.
struct TagChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(KLFont.caption(13))
                .foregroundStyle(selected ? Color.black.opacity(0.82) : KLColor.ink)
                .padding(.vertical, 9)
                .padding(.horizontal, 14)
                .background(selected ? KLColor.citrus : KLColor.panelAlt)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(selected ? Color.clear : KLColor.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// A 1-5 self-rating control, drawn as filled paddle glyphs rather than
/// generic stars — reinforces the sport-specific identity even in a small
/// rating control.
struct SkillRatingView: View {
    let rating: Int
    let onChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...5, id: \.self) { level in
                Image(systemName: level <= rating ? "hexagon.fill" : "hexagon")
                    .font(.system(size: 18))
                    .foregroundStyle(level <= rating ? KLColor.courtSurface : KLColor.hairline)
                    .onTapGesture {
                        Haptics.click()
                        onChange(level)
                    }
            }
        }
    }
}
