import SwiftUI

/// Dashboard: today's persistent progress court (every locked-in rep from any
/// drill practiced today, accumulated as bright arcs) plus quick stats and a
/// shortcut into a few suggested drills.
struct HomeView: View {
    @EnvironmentObject private var appModel: AppModel

    private var suggestedDrills: [Drill] {
        let weakShots = appModel.orderedSelectedWeakShots
        guard !weakShots.isEmpty else {
            return Array(DrillLibrary.all.prefix(3))
        }
        var ids: [String] = []
        for shot in weakShots {
            for id in shot.recommendedDrillIDs where !ids.contains(id) {
                ids.append(id)
                if ids.count >= 4 { break }
            }
            if ids.count >= 4 { break }
        }
        return ids.compactMap { DrillLibrary.drill(id: $0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    KLSectionLabel(text: "Today's Progress")
                    CourtDiagramView(lockedArcs: appModel.lockedArcsToday)
                        .frame(maxWidth: 360)
                        .frame(maxWidth: .infinity)
                }

                HStack(spacing: 10) {
                    StatTile(value: "\(appModel.repsCompletedToday)", label: "Reps Locked In")
                    StatTile(value: "\(appModel.categoriesPracticedToday.count)/4", label: "Areas Touched")
                }

                VStack(alignment: .leading, spacing: 10) {
                    KLSectionLabel(text: appModel.orderedSelectedWeakShots.isEmpty ? "Get Started" : "Suggested For You")
                    VStack(spacing: 8) {
                        ForEach(suggestedDrills) { drill in
                            NavigationLink { DrillDetailView(drill: drill) } label: {
                                DrillRow(drill: drill)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if appModel.orderedSelectedWeakShots.isEmpty {
                    KLCard {
                        HStack(spacing: 10) {
                            Image(systemName: "target").foregroundStyle(KLColor.courtSurface)
                            Text("Rate your skills on the Skills tab to get suggestions tailored to your weak shots.")
                                .font(.footnote).foregroundStyle(KLColor.inkMuted)
                        }
                    }
                }
            }
            .padding()
        }
        .background(KLColor.paper.ignoresSafeArea())
        .onAppear { appModel.refreshDayRolloverIfNeeded() }
    }
}
