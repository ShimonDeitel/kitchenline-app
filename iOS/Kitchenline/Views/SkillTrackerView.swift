import SwiftUI

/// Self-rated skill tracker: a 1-5 rating per broad category, plus a
/// granular weak-shot picker. Both are free-tier — this screen is what feeds
/// the Pro AI weekly plan on the Plan tab, but rating your own game doesn't
/// require a subscription.
struct SkillTrackerView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    KLSectionLabel(text: "Rate Your Game")
                    Text("A quick self-assessment — no AI, just you being honest about where you stand.")
                        .font(.footnote).foregroundStyle(KLColor.inkMuted)
                    VStack(spacing: 10) {
                        ForEach(DrillCategory.allCases) { category in
                            KLCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(category.rawValue).font(KLFont.headline(15)).foregroundStyle(KLColor.ink)
                                        Text(category.blurb).font(.caption).foregroundStyle(KLColor.inkMuted)
                                    }
                                    Spacer()
                                    SkillRatingView(rating: appModel.rating(for: category)) { level in
                                        appModel.setRating(level, for: category)
                                    }
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    KLSectionLabel(text: "Weak Shots")
                    Text("Pick the shots giving you trouble — the AI weekly plan on the Plan tab uses these.")
                        .font(.footnote).foregroundStyle(KLColor.inkMuted)
                    FlowChips(tags: WeakShotTag.allCases, isSelected: appModel.isWeakShotSelected, onTap: appModel.toggleWeakShot)
                }

                VStack(alignment: .leading, spacing: 10) {
                    KLSectionLabel(text: "Practice Minutes Today")
                    KLCard {
                        Stepper(value: $appModel.minutesAvailable, in: 10...120, step: 5) {
                            Text("\(appModel.minutesAvailable) minutes").font(KLFont.value(18)).foregroundStyle(KLColor.ink)
                        }
                    }
                }
            }
            .padding()
        }
        .background(KLColor.paper.ignoresSafeArea())
    }
}

/// A simple wrapping chip layout for the weak-shot tag picker.
struct FlowChips: View {
    let tags: [WeakShotTag]
    let isSelected: (WeakShotTag) -> Bool
    let onTap: (WeakShotTag) -> Void

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(tags) { tag in
                TagChip(title: tag.rawValue, selected: isSelected(tag)) { onTap(tag) }
            }
        }
    }
}
