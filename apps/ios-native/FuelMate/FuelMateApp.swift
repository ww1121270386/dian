import SwiftUI

@main
struct FuelMateApp: App {
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environment(\.locale, Locale(identifier: "zh_Hans_CN"))
                .environment(\.calendar, Calendar(identifier: .gregorian))
                .tint(Theme.green)
        }
    }
}
