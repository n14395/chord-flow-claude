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
            // Top tab bar
            tabBar

            // Tab content
            Group {
                switch selectedTab {
                case 0: ComposeScreen(vm: vm)
                case 1: SuggestScreen(vm: vm)
                case 2: OutputScreen(vm: vm)
                default: ComposeScreen(vm: vm)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

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
        .background(Color.cfBackground.ignoresSafeArea())
        .overlay {
            SharedBlockActionOverlay(vm: vm, blockIndex: $contextMenuBlockIndex)
        }
        .preferredColorScheme(.dark)
        .onOpenURL { url in
            vm.loadProject(from: url)
            selectedTab = 0 // Switch to Compose after loading
        }
    }

    // MARK: - Top Tab Bar

    private var tabBar: some View {
        HStack(spacing: CFSpacing.tight) {
            tabButton(title: "Compose", tag: 0)
            tabButton(title: "Suggest", tag: 1)
            tabButton(title: "Files", tag: 2)
        }
        .padding(3)
        .background(
            Capsule()
                .fill(Color.cfSurface)
                .strokeBorder(Color.cfBorder.opacity(0.6), lineWidth: 1)
        )
        .padding(.horizontal, CFSpacing.spacious)
        .padding(.vertical, CFSpacing.compact)
    }

    private func tabButton(title: String, tag: Int) -> some View {
        let isSelected = selectedTab == tag
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tag
            }
        } label: {
            Text(title)
                .font(.system(size: 15, weight: isSelected ? .semibold : .regular, design: .rounded))
                .foregroundStyle(isSelected ? Color.cfTonic : Color.cfTextTertiary)
                .padding(.horizontal, CFSpacing.spacious)
                .padding(.vertical, CFSpacing.compact)
                .contentShape(Capsule())
                .background(
                    Capsule()
                        .fill(isSelected ? Color.cfElevated : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }
}
