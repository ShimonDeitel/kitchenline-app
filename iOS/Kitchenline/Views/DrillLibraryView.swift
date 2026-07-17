import SwiftUI

/// The free-tier drill library: every bundled drill, grouped by category.
struct DrillLibraryView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ForEach(DrillCategory.allCases) { category in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: category.icon).foregroundStyle(KLColor.courtSurface)
                            Text(category.rawValue).font(KLFont.headline(18)).foregroundStyle(KLColor.ink)
                            Spacer()
                            Text("\(DrillLibrary.drills(in: category).count) drills")
                                .font(.footnote).foregroundStyle(KLColor.inkMuted)
                        }
                        Text(category.blurb).font(.footnote).foregroundStyle(KLColor.inkMuted)

                        VStack(spacing: 8) {
                            ForEach(DrillLibrary.drills(in: category)) { drill in
                                NavigationLink {
                                    DrillDetailView(drill: drill)
                                } label: {
                                    DrillRow(drill: drill)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(KLColor.paper.ignoresSafeArea())
    }
}
