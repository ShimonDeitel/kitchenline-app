import SwiftUI
import UIKit

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func click() { UISelectionFeedbackGenerator().selectionChanged() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}

/// A single drill row in the library list.
struct DrillRow: View {
    let drill: Drill

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: drill.category.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(KLColor.courtSurface)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                Text(drill.name).font(KLFont.headline(15)).foregroundStyle(KLColor.ink)
                Text(drill.summary)
                    .font(.footnote)
                    .foregroundStyle(KLColor.inkMuted)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Text(drill.difficulty.rawValue)
                .font(KLFont.caption(10))
                .foregroundStyle(KLColor.inkMuted)
                .padding(.vertical, 4).padding(.horizontal, 8)
                .background(KLColor.panelAlt)
                .clipShape(Capsule())
        }
        .padding(12)
        .background(KLColor.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(KLColor.hairline, lineWidth: 1))
    }
}

/// A locked Pro feature row — tapping when not subscribed opens the paywall.
struct ProToolRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let locked: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(locked ? KLColor.inkMuted : KLColor.courtSurface)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(KLFont.headline(15)).foregroundStyle(KLColor.ink)
                    Text(subtitle).font(.footnote).foregroundStyle(KLColor.inkMuted)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: locked ? "lock.fill" : "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(KLColor.inkMuted)
            }
            .padding(14)
            .background(KLColor.panel)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(KLColor.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// A small stat tile used on the Home dashboard.
struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(KLFont.value(22)).foregroundStyle(KLColor.ink)
            Text(label.uppercased()).font(KLFont.caption(10)).tracking(1.0).foregroundStyle(KLColor.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(KLColor.panelAlt)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
