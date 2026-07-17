import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var working = false
    @State private var restoreMessage: String?

    private let benefits: [(String, String, String)] = [
        ("calendar.badge.clock", "AI weekly practice plan", "Built from your self-rated weak shots and today's available minutes — real drills from the library, sequenced for you."),
        ("sparkles", "Ghost-rally mode", "An AI-generated opponent dot animates to specific court positions tailored to the exact shot you're drilling."),
    ]

    var body: some View {
        ZStack {
            KLColor.paper.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 8) {
                        Image(systemName: "circle.dashed")
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundStyle(KLColor.citrus)
                        Text("Kitchenline Pro").font(KLFont.display(28))
                            .foregroundStyle(KLColor.ink)
                        Text("\(store.displayPrice) / month. Cancel anytime.")
                            .font(.subheadline).foregroundStyle(KLColor.inkMuted)
                    }
                    .padding(.top, 28)

                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(benefits, id: \.0) { item in
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: item.0)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(KLColor.courtSurface)
                                    .frame(width: 26)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.1).font(KLFont.headline(16))
                                        .foregroundStyle(KLColor.ink)
                                    Text(item.2).font(.subheadline).foregroundStyle(KLColor.inkMuted)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .padding(16)
                    .background(KLColor.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(KLColor.hairline, lineWidth: 1))
                    .padding(.horizontal)

                    VStack(spacing: 12) {
                        Button {
                            Task { await buy() }
                        } label: {
                            HStack {
                                if working { ProgressView().tint(.black.opacity(0.7)) }
                                Text(working ? "Starting…" : "Start Kitchenline Pro · \(store.displayPrice)/mo")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .pillButton(tint: KLColor.citrus, textColor: .black.opacity(0.82))
                        .accessibilityIdentifier("paywall-subscribe")
                        .disabled(working)

                        Button("Restore Purchase") { Task { await restore() } }
                            .font(.subheadline).tint(KLColor.inkMuted)

                        if let restoreMessage {
                            Text(restoreMessage).font(.footnote).foregroundStyle(KLColor.inkMuted)
                        }

                        Text("Auto-renewable subscription, billed monthly to your Apple ID. Manage or cancel anytime in Settings.")
                            .font(.footnote).foregroundStyle(KLColor.inkMuted)
                            .multilineTextAlignment(.center).padding(.top, 4)
                    }
                    .padding(.horizontal).padding(.bottom, 30)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill").font(.title2)
                    .foregroundStyle(KLColor.inkMuted).padding()
            }
            .accessibilityLabel("Close")
            .accessibilityIdentifier("paywall-close")
        }
        .onChange(of: store.isPro) { _, newValue in if newValue { dismiss() } }
    }

    private func buy() async {
        working = true
        let ok = await store.purchase()
        working = false
        if ok { Haptics.success(); dismiss() }
    }

    private func restore() async {
        await store.restore()
        if store.isPro { Haptics.success(); dismiss() }
        else { restoreMessage = "No previous purchase found on this Apple ID." }
    }
}
