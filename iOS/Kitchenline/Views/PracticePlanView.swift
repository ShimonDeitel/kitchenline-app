import SwiftUI

/// Pro: an AI-built weekly practice plan drawn from the player's self-rated
/// weak shots and today's available minutes (both set on the Skills tab).
/// Falls back to a deterministic hand-written plan if the proxy is
/// unreachable or its response doesn't parse.
struct PracticePlanView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var store: Store

    @State private var isLoading = false
    @State private var notice: String?
    @State private var showPaywall = false

    private let client = AIProxyClient()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if !store.isPro {
                    lockedCard
                } else {
                    summaryCard
                    generateButton
                    if let notice {
                        Text(notice).font(.footnote).foregroundStyle(KLColor.inkMuted)
                    }
                    if let plan = appModel.cachedPlan {
                        ForEach(Array(plan.days.enumerated()), id: \.offset) { _, day in
                            dayCard(day)
                        }
                    } else if !isLoading {
                        KLCard {
                            Text("Tap \"Build My Week\" to generate a plan from your weak shots and today's practice minutes.")
                                .font(.footnote).foregroundStyle(KLColor.inkMuted)
                        }
                    }
                }
            }
            .padding()
        }
        .background(KLColor.paper.ignoresSafeArea())
        .navigationTitle("Weekly Plan")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    private var lockedCard: some View {
        VStack(spacing: 16) {
            ProToolRow(
                icon: "calendar.badge.clock",
                title: "AI Weekly Practice Plan",
                subtitle: "A personalized plan from your self-rated weak shots and today's practice minutes.",
                locked: true
            ) { showPaywall = true }
            Button("Unlock Kitchenline Pro — \(store.displayPrice)/mo") { showPaywall = true }
                .pillButton(tint: KLColor.citrus, textColor: .black.opacity(0.82))
        }
    }

    private var summaryCard: some View {
        KLCard {
            KLSectionLabel(text: "Based On")
            if appModel.orderedSelectedWeakShots.isEmpty {
                Text("No weak shots selected — set some on the Skills tab for a targeted plan.")
                    .font(.footnote).foregroundStyle(KLColor.inkMuted)
            } else {
                Text(appModel.orderedSelectedWeakShots.map(\.rawValue).joined(separator: ", "))
                    .font(.footnote).foregroundStyle(KLColor.ink)
            }
            Text("\(appModel.minutesAvailable) minutes available today")
                .font(.footnote).foregroundStyle(KLColor.inkMuted)
        }
    }

    private var generateButton: some View {
        Button {
            Task { await generatePlan() }
        } label: {
            HStack {
                if isLoading { ProgressView().tint(.white) }
                Text(isLoading ? "Building…" : "Build My Week")
            }
            .frame(maxWidth: .infinity)
        }
        .pillButton(tint: KLColor.courtSurface)
        .disabled(isLoading)
    }

    private func dayCard(_ day: PracticePlanDay) -> some View {
        KLCard {
            HStack {
                Text(day.day).font(KLFont.headline(16)).foregroundStyle(KLColor.ink)
                Spacer()
                Text("\(day.minutes) min").font(.footnote).foregroundStyle(KLColor.inkMuted)
            }
            Text(day.focus).font(.footnote).foregroundStyle(KLColor.courtSurface)
            ForEach(Array(day.drills.enumerated()), id: \.offset) { _, planned in
                HStack {
                    Text(planned.drillName).font(.footnote).foregroundStyle(KLColor.ink)
                    Spacer()
                    Text("\(planned.reps) reps").font(.footnote).foregroundStyle(KLColor.inkMuted)
                }
            }
        }
    }

    private func generatePlan() async {
        isLoading = true
        notice = nil
        do {
            appModel.cachedPlan = try await client.fetchPracticePlan(
                weakShots: appModel.orderedSelectedWeakShots,
                minutesAvailable: appModel.minutesAvailable
            )
        } catch {
            notice = (error as? AIProxyClient.APIError)?.errorDescription ?? "Couldn't reach the practice coach. Showing a default plan."
            appModel.cachedPlan = FallbackPlanner.generate(
                weakShots: appModel.orderedSelectedWeakShots,
                minutesAvailable: appModel.minutesAvailable
            )
        }
        isLoading = false
    }
}
