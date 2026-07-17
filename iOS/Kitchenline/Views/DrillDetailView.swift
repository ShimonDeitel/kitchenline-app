import SwiftUI

/// One drill's practice flow: run a rep (the ball animates its flight across
/// the kitchen line), mark it "In" or "Out", and repeat for the drill's rep
/// count. Every "In" locks that rep's arc onto the Home tab's daily progress
/// tracker. Pro subscribers can enable ghost-rally mode, which asks the AI
/// proxy for a short opponent-movement sequence tailored to this exact drill
/// and animates it alongside the ball.
struct DrillDetailView: View {
    let drill: Drill

    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var store: Store

    @State private var repIndex = 0
    @State private var correctCount = 0
    @State private var missCount = 0
    @State private var activeRep: ActiveRepAnimation?
    @State private var awaitingResult = false
    @State private var ghostEnabled = false
    @State private var ghostWaypoints: [GhostWaypoint] = []
    @State private var loadingGhost = false
    @State private var showPaywall = false
    @State private var aiNotice: String?

    private let client = AIProxyClient()
    private let repDuration: Double = 1.15

    private var totalReps: Int { drill.defaultReps }
    private var isComplete: Bool { repIndex >= totalReps }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                CourtDiagramView(activeRep: activeRep, showGhost: ghostEnabled && ghostWaypoints.count >= 2)
                    .frame(maxWidth: 340)
                    .padding(.top, 4)
                    .shadow(color: .black.opacity(0.15), radius: 10, y: 6)

                progressHeader

                actionArea

                if store.isPro {
                    ghostToggleCard
                } else {
                    ProToolRow(
                        icon: "sparkles",
                        title: "Ghost-Rally Mode",
                        subtitle: "Animate an AI-generated opponent moving to specific court spots for this exact drill.",
                        locked: true
                    ) { showPaywall = true }
                }

                if let aiNotice {
                    Text(aiNotice).font(.footnote).foregroundStyle(KLColor.inkMuted)
                        .multilineTextAlignment(.center)
                }

                cuesCard
            }
            .padding()
        }
        .background(KLColor.paper.ignoresSafeArea())
        .navigationTitle(drill.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    // MARK: Sections

    private var progressHeader: some View {
        HStack(spacing: 10) {
            StatTile(value: isComplete ? "\(totalReps)/\(totalReps)" : "\(repIndex)/\(totalReps)", label: "Reps")
            StatTile(value: "\(correctCount)", label: "In")
            StatTile(value: "\(missCount)", label: "Out")
        }
    }

    @ViewBuilder
    private var actionArea: some View {
        if awaitingResult {
            HStack(spacing: 12) {
                Button("Out") { markResult(correct: false) }
                    .pillButton(filled: false, tint: KLColor.miss)
                Button("In") { markResult(correct: true) }
                    .pillButton(tint: KLColor.citrus, textColor: .black.opacity(0.82))
            }
        } else if isComplete {
            doneCard
        } else {
            Button {
                startRep()
            } label: {
                Text(repIndex == 0 ? "Run Rep 1" : "Run Rep \(repIndex + 1)")
            }
            .pillButton(tint: KLColor.courtSurface)
        }
    }

    private var doneCard: some View {
        KLCard {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(KLColor.citrus)
                Text("Drill complete — \(correctCount) of \(totalReps) locked in.")
                    .font(KLFont.headline(15)).foregroundStyle(KLColor.ink)
            }
            Button("Practice Again") { resetSession() }
                .pillButton(filled: false, tint: KLColor.courtSurface)
        }
    }

    private var ghostToggleCard: some View {
        KLCard {
            Toggle(isOn: Binding(
                get: { ghostEnabled },
                set: { newValue in
                    ghostEnabled = newValue
                    if newValue, ghostWaypoints.isEmpty { Task { await loadGhostRally() } }
                }
            )) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles").foregroundStyle(KLColor.courtSurface)
                    Text("Ghost-Rally Mode").font(KLFont.headline(15)).foregroundStyle(KLColor.ink)
                }
            }
            .tint(KLColor.courtSurface)

            if loadingGhost {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Building the opponent sequence…").font(.footnote).foregroundStyle(KLColor.inkMuted)
                }
            } else {
                Text("An AI-generated opponent dot moves to court positions tailored to \(drill.name.lowercased()).")
                    .font(.footnote).foregroundStyle(KLColor.inkMuted)
            }
        }
    }

    private var cuesCard: some View {
        KLCard {
            KLSectionLabel(text: "Coaching Cues")
            Text(drill.summary).font(KLFont.body()).foregroundStyle(KLColor.ink)
            ForEach(drill.cues, id: \.self) { cue in
                HStack(alignment: .top, spacing: 8) {
                    Circle().fill(KLColor.courtSurface).frame(width: 5, height: 5).padding(.top, 6)
                    Text(cue).font(.footnote).foregroundStyle(KLColor.inkMuted)
                }
            }
        }
    }

    // MARK: Actions

    private func startRep() {
        let path = drill.path(forRep: repIndex)
        activeRep = ActiveRepAnimation(
            origin: path.origin,
            target: path.target,
            startDate: Date(),
            duration: repDuration,
            ghostWaypoints: (ghostEnabled && ghostWaypoints.count >= 2) ? ghostWaypoints : []
        )
        Haptics.soft()
        Task {
            try? await Task.sleep(nanoseconds: UInt64(repDuration * 1_000_000_000))
            await MainActor.run { awaitingResult = true }
        }
    }

    private func markResult(correct: Bool) {
        if correct {
            correctCount += 1
            let path = drill.path(forRep: repIndex)
            appModel.recordRep(category: drill.category, origin: path.origin, target: path.target)
            Haptics.success()
        } else {
            missCount += 1
            Haptics.warning()
        }
        repIndex += 1
        awaitingResult = false
        activeRep = nil
    }

    private func resetSession() {
        repIndex = 0
        correctCount = 0
        missCount = 0
        activeRep = nil
        awaitingResult = false
    }

    private func loadGhostRally() async {
        loadingGhost = true
        aiNotice = nil
        do {
            ghostWaypoints = try await client.fetchGhostRally(for: drill)
        } catch {
            aiNotice = (error as? AIProxyClient.APIError)?.errorDescription ?? "Couldn't reach the practice coach. Showing a default sequence."
            ghostWaypoints = FallbackPlanner.ghostWaypoints(for: drill)
        }
        loadingGhost = false
    }
}
