import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: Store

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("首页", systemImage: "house.fill") }
            ChargesView()
                .tabItem { Label("充电", systemImage: "bolt.fill") }
            ExpensesView()
                .tabItem { Label("费用", systemImage: "doc.text.fill") }
            MeView()
                .tabItem { Label("我的", systemImage: "person.fill") }
        }
    }
}
