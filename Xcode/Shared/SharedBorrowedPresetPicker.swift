#if canImport(SwiftUI)
import SwiftUI

// MARK: - Borrowed Preset Picker
//
// Tap-to-toggle pill that expands an option list above the button.
// Avoids SwiftUI `Menu` which presents in a separate UIWindow and doesn't
// receive touches reliably inside AUv3 host apps. Used by both the
// standalone app and the AUv3 extension for UI consistency.

public struct SharedBorrowedPresetPicker<VM: ChordFlowViewModel>: View {
    @ObservedObject var vm: VM
    @Binding var isExpanded: Bool

    public init(vm: VM, isExpanded: Binding<Bool>) {
        self._vm = ObservedObject(wrappedValue: vm)
        self._isExpanded = isExpanded
    }

    public var body: some View {
        VStack(spacing: CFSpacing.micro) {
            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            } label: {
                Text(vm.borrowedPreset.displayName())
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.cfBorrowed)
                    .padding(.horizontal, CFSpacing.compact)
                    .padding(.vertical, CFSpacing.tight)
                    .background(
                        Capsule()
                            .fill(Color.cfBorrowed.opacity(0.15))
                            .strokeBorder(Color.cfBorrowed, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .overlay(alignment: .bottom) {
                if isExpanded {
                    pickerList
                        .offset(y: -34)
                        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .bottom)))
                }
            }

            Text("BORROWED")
                .font(.system(size: 8, weight: .medium, design: .rounded))
                .foregroundStyle(Color.cfTextTertiary)
        }
        .zIndex(isExpanded ? 10 : 0)
    }

    private var pickerList: some View {
        VStack(spacing: 2) {
            ForEach(CFBorrowedChordPreset.allCases, id: \.self) { preset in
                let isActive = vm.borrowedPreset == preset
                Button {
                    vm.borrowedPreset = preset
                    vm.refreshChordButtons()
                    vm.refreshSuggestions()
                    withAnimation(.easeOut(duration: 0.15)) {
                        isExpanded = false
                    }
                } label: {
                    Text(preset.displayName())
                        .font(.system(size: 10, weight: isActive ? .bold : .medium, design: .rounded))
                        .foregroundStyle(isActive ? Color.cfBorrowed : Color.cfTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, CFSpacing.tight)
                        .background(
                            RoundedRectangle(cornerRadius: CFRadius.small)
                                .fill(isActive ? Color.cfBorrowed.opacity(0.15) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(CFSpacing.tight)
        .frame(width: 140)
        .background(
            RoundedRectangle(cornerRadius: CFRadius.button)
                .fill(Color.cfSurface)
                .strokeBorder(Color.cfBorrowed.opacity(0.5), lineWidth: 1)
                .shadow(color: .black.opacity(0.3), radius: 8, y: -4)
        )
    }
}

// MARK: - Dismiss-on-outside-tap modifier

extension View {
    /// Dismisses the borrowed-preset picker when the user taps anywhere outside
    /// the picker list. Apply this to the root view of screens that contain a
    /// `SharedBorrowedPresetPicker`. Uses `.simultaneousGesture` so that other
    /// interactive controls (buttons, knobs, etc.) continue to work normally.
    public func dismissBorrowedPicker(isExpanded: Binding<Bool>) -> some View {
        self.simultaneousGesture(
            TapGesture().onEnded {
                if isExpanded.wrappedValue {
                    withAnimation(.easeOut(duration: 0.15)) {
                        isExpanded.wrappedValue = false
                    }
                }
            }
        )
    }
}
#endif
