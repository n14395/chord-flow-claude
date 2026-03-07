import SwiftUI
import ChordFlowShared

// MARK: - Root View

struct RootView: View {
    @StateObject private var vm = AppViewModel()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ComposeScreen(vm: vm)
                .tabItem {
                    Label("Compose", systemImage: "circle.circle")
                }
                .tag(0)

            SuggestScreen(vm: vm)
                .tabItem {
                    Label("Suggest", systemImage: "lightbulb")
                }
                .tag(1)

            ExportScreen(vm: vm)
                .tabItem {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .tag(2)
        }
        .tint(Color.cfTonic)
        .preferredColorScheme(.dark)
    }
}
