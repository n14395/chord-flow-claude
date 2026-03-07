import SwiftUI
import ChordFlowShared

struct ComposeScreen: View {
    @ObservedObject var vm: AppViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        VStack(spacing: 0) {
            if sizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .background(Color.cfBackground.ignoresSafeArea())
        .sheet(isPresented: $vm.showModeSheet) {
            modePickerSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.cfSurface)
        }
    }

    // MARK: - iPhone Layout

    private var iPhoneLayout: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: CFSpacing.standard) {
                    // Circle of Fifths
                    CircleOfFifthsView(vm: vm) { chord in
                        vm.addChord(chord)
                    }
                    .padding(.horizontal, CFSpacing.spacious)

                    // Controls strip
                    controlsStrip
                        .padding(.horizontal, CFSpacing.spacious)

                    // Timeline
                    TimelineView(vm: vm) { index in
                        vm.selectedBlockIndex = vm.selectedBlockIndex == index ? nil : index
                    }
                    .padding(.horizontal, CFSpacing.compact)

                    // Chord detail panel
                    ChordDetailPanel(vm: vm)
                        .padding(.horizontal, CFSpacing.compact)
                }
                .padding(.top, CFSpacing.compact)
                .padding(.bottom, 100) // room for playback bar
            }

            // Playback bar
            PlaybackBarView(vm: vm)
                .padding(.horizontal, CFSpacing.compact)
                .padding(.bottom, CFSpacing.tight)
        }
    }

    // MARK: - iPad Layout

    private var iPadLayout: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: CFSpacing.spacious) {
                // Left column: Circle + controls
                ScrollView {
                    VStack(spacing: CFSpacing.standard) {
                        CircleOfFifthsView(vm: vm) { chord in
                            vm.addChord(chord)
                        }

                        controlsStrip

                        borrowedPresetPills
                    }
                }
                .frame(maxWidth: .infinity)

                // Right column: Timeline + chord detail
                ScrollView {
                    VStack(spacing: CFSpacing.standard) {
                        TimelineView(vm: vm) { index in
                            vm.selectedBlockIndex = vm.selectedBlockIndex == index ? nil : index
                        }

                        ChordDetailPanel(vm: vm)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, CFSpacing.spacious)
            .padding(.top, CFSpacing.standard)

            PlaybackBarView(vm: vm)
                .padding(.horizontal, CFSpacing.spacious)
                .padding(.bottom, CFSpacing.compact)
        }
    }

    // MARK: - Controls Strip

    private var controlsStrip: some View {
        VStack(spacing: CFSpacing.tight) {
            Divider().background(Color.cfBorder)

            HStack(spacing: CFSpacing.spacious) {
                KnobView(
                    value: $vm.tension,
                    in: 0...1,
                    label: "Tension",
                    color: .cfTonic
                )
                .frame(width: 72, height: 90)
                .onChange(of: vm.tension) { _, _ in
                    vm.refreshChordButtons()
                    vm.refreshSuggestions()
                }

                KnobView(
                    value: $vm.swing,
                    in: 0...0.8,
                    label: "Swing",
                    color: .cfDominant
                )
                .frame(width: 72, height: 90)

                KnobView(
                    value: $vm.project.tempo,
                    in: 60...180,
                    step: 1,
                    label: "BPM",
                    color: .cfSubdominant,
                    format: { "\(Int($0.rounded()))" }
                )
                .frame(width: 72, height: 90)

                if sizeClass != .regular {
                    borrowedPresetPill
                }
            }
        }
    }

    // MARK: - Borrowed Preset

    private var borrowedPresetPill: some View {
        VStack(spacing: CFSpacing.micro) {
            Menu {
                ForEach(CFBorrowedChordPreset.allCases, id: \.self) { preset in
                    Button(preset.displayName()) {
                        vm.borrowedPreset = preset
                        vm.refreshChordButtons()
                    }
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

            Text("BORROWED")
                .font(.system(size: 8, weight: .medium, design: .rounded))
                .foregroundStyle(Color.cfTextTertiary)
        }
    }

    private var borrowedPresetPills: some View {
        VStack(alignment: .leading, spacing: CFSpacing.tight) {
            Text("BORROWED PRESET")
                .font(.cfCaption)
                .foregroundStyle(Color.cfTextSecondary)
                .textCase(.uppercase)

            let presets: [CFBorrowedChordPreset] = [.diatonicOnly, .jazz, .cinematic, .experimental, .everything]
            FlowLayout(spacing: CFSpacing.tight) {
                ForEach(presets, id: \.self) { preset in
                    let isActive = vm.borrowedPreset == preset
                    Button {
                        vm.borrowedPreset = preset
                        vm.refreshChordButtons()
                    } label: {
                        Text(preset.displayName())
                            .font(.system(size: 11, weight: isActive ? .semibold : .regular, design: .rounded))
                            .foregroundStyle(isActive ? Color.cfBorrowed : Color.cfTextSecondary)
                            .padding(.horizontal, CFSpacing.compact)
                            .padding(.vertical, CFSpacing.tight)
                            .background(
                                Capsule()
                                    .fill(isActive ? Color.cfBorrowed.opacity(0.2) : Color.cfSurface)
                                    .strokeBorder(isActive ? Color.cfBorrowed : Color.cfBorder,
                                                  lineWidth: isActive ? 1.5 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Mode Picker Sheet

    private var modePickerSheet: some View {
        NavigationStack {
            List {
                ForEach(CFScaleMode.allCases, id: \.self) { mode in
                    Button {
                        vm.project.key.mode = mode
                        vm.refreshChordButtons()
                        vm.refreshSuggestions()
                        vm.showModeSheet = false
                    } label: {
                        HStack {
                            Text(mode.displayName())
                                .font(.cfBody)
                                .foregroundStyle(Color.cfTextPrimary)
                            Spacer()
                            if vm.project.key.mode == mode {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.cfTonic)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.cfSurface)
            .navigationTitle("Scale Mode")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

}

// MARK: - Int Identifiable for sheet binding

extension Int: @retroactive Identifiable {
    public var id: Int { self }
}

// MARK: - Simple Flow Layout

struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}
