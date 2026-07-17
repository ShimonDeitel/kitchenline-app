import SwiftUI

@main
struct KitchenlineApp: App {
    @StateObject private var store: Store
    @StateObject private var appModel: AppModel

    init() {
        _store = StateObject(wrappedValue: Store())
        _appModel = StateObject(wrappedValue: AppModel())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(appModel)
        }
    }
}
