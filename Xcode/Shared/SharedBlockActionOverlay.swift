#if canImport(SwiftUI)
import SwiftUI

// MARK: - Block Action Overlay
//
// In-view replacement for .contextMenu on chord blocks. Shown as a centered
// card with a dimmed backdrop that dismisses on tap. Used by both the
// standalone app and the AUv3 extension for UI consistency.

public struct SharedBlockActionOverlay<VM: ChordFlowViewModel>: View {
    @ObservedObject var vm: VM
    @Binding var blockIndex: Int?

    public init(vm: VM, blockIndex: Binding<Int?>) {
        self._vm = ObservedObject(wrappedValue: vm)
        self._blockIndex = blockIndex
    }

    public var body: some View {
        if let idx = blockIndex, vm.blocks.indices.contains(idx) {
            overlayContent(index: idx)
        }
    }

    private func overlayContent(index: Int) -> some View {
        let block = vm.blocks[index]
        let function = vm.harmonicFunction(forBlockAt: index)
        let color = function.color

        return ZStack {
            // Dismiss backdrop
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                // Header
                Text(block.chord.symbol())
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(color)
                    .padding(.vertical, CFSpacing.compact)

                Divider().background(Color.cfBorder)

                actionButton(label: "Preview", icon: "play.fill", color: .cfTextPrimary) {
                    vm.previewBlock(block)
                }

                Divider().background(Color.cfBorder)

                actionButton(label: "Duplicate", icon: "doc.on.doc", color: .cfTextPrimary) {
                    vm.duplicateBlock(at: index)
                }

                Divider().background(Color.cfBorder)

                actionButton(label: "Remove", icon: "trash", color: .cfDestructive) {
                    vm.removeBlock(at: index)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: CFRadius.card)
                    .fill(Color.cfSurface)
                    .strokeBorder(color.opacity(0.4), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: CFRadius.card))
            .frame(width: 200)
            .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 8)
        }
        .transition(.opacity)
    }

    private func actionButton(
        label: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
            dismiss()
        } label: {
            Label(label, systemImage: icon)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, CFSpacing.standard)
                .padding(.vertical, CFSpacing.compact)
        }
        .buttonStyle(.plain)
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.15)) {
            blockIndex = nil
        }
    }
}
#endif
