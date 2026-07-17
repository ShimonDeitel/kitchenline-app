import SwiftUI

struct RootView: View {
    @AppStorage("kitchenline.theme") private var themeRaw = AppTheme.system.rawValue
    @State private var showSettings = false

    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
                    .navigationTitle("Kitchenline")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { settingsToolbar }
            }
            .tabItem { Label("Home", systemImage: "house") }

            NavigationStack {
                DrillLibraryView()
                    .navigationTitle("Drills")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { settingsToolbar }
            }
            .tabItem { Label("Drills", systemImage: "circle.dashed") }

            NavigationStack {
                SkillTrackerView()
                    .navigationTitle("Skills")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { settingsToolbar }
            }
            .tabItem { Label("Skills", systemImage: "hexagon") }

            NavigationStack {
                PracticePlanView()
                    .toolbar { settingsToolbar }
            }
            .tabItem { Label("Plan", systemImage: "calendar.badge.clock") }
        }
        .tint(KLColor.courtSurface)
        .preferredColorScheme(AppTheme(rawValue: themeRaw)?.colorScheme)
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    @ToolbarContentBuilder
    private var settingsToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                Haptics.tap()
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel("Settings")
        }
    }
}
