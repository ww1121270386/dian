import SwiftUI

@main
struct FuelMateApp: App {
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(Theme.green)
        }
    }
}
