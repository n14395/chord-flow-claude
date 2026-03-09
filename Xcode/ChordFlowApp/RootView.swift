import SwiftUI
import ChordFlowShared

// MARK: - Root View

struct RootView: View {
    @StateObject private var vm = AppViewModel()
    @State private var selectedTab = 0
    @State private var contextMenuBlockIndex: Int?
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        VStack(spacing: 0) {
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

                OutputScreen(vm: vm)
                    .tabItem {
                        Label("Output", systemImage: "arrow.up.forward.square")
                    }
                    .tag(2)
            }
            .tint(Color.cfTonic)

            // Shared playback bar — single instance for Compose + Suggest tabs
            if selectedTab != 2 {
                PlaybackBarView(
                    vm: vm,
                    onBlockTap: { index in
                        vm.selectedBlockIndex = vm.selectedBlockIndex == index ? nil : index
                    },
                    onBlockLongPress: { index in
                        contextMenuBlockIndex = index
                    }
                )
                .padding(.horizontal, sizeClass == .regular ? CFSpacing.spacious : CFSpacing.compact)
                .padding(.bottom, CFSpacing.tight)
            }
        }
        .overlay {
            SharedBlockActionOverlay(vm: vm, blockIndex: $contextMenuBlockIndex)
        }
        .preferredColorScheme(.dark)
        .onOpenURL { url in
            vm.loadProject(from: url)
            selectedTab = 0 // Switch to Compose after loading
        }
    }
}
