import SwiftUI
import ChordFlowShared

// MARK: - Main AUv3 View

struct AUv3View: View {
    @ObservedObject var vm: AUv3ViewModel
    @State private var showBorrowedPicker = false
    @State private var contextMenuBlockIndex: Int?

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            tabBar

            // Tab content
            Group {
                switch vm.selectedTab {
                case 0: composeTab
                case 1: suggestTab
                default: composeTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Playback bar with inline timeline
            playbackBar
                .padding(.horizontal, CFSpacing.compact)
                .padding(.bottom, CFSpacing.tight)

            // Debug info
            Text(vm.debugInfo)
                .font(.system(size: 8, weight: .regular, design: .monospaced))
                .foregroundStyle(Color.cfTextTertiary.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, CFSpacing.compact)
                .padding(.bottom, CFSpacing.micro)
        }
        .background(Color.cfBackground.ignoresSafeArea())
        .dismissBorrowedPicker(isExpanded: $showBorrowedPicker)
        .overlay {
            SharedBlockActionOverlay(vm: vm, blockIndex: $contextMenuBlockIndex)
        }
        .sheet(isPresented: $vm.showModeSheet) {
            modePickerSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.cfSurface)
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(title: "Compose", icon: "circle.circle", tag: 0)
            tabButton(title: "Suggest", icon: "lightbulb", tag: 1)
        }
        .background(Color.cfSurface)
    }

    private func tabButton(title: String, icon: String, tag: Int) -> some View {
        let isSelected = vm.selectedTab == tag
        return Button {
            vm.selectedTab = tag
        } label: {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
            }
            .foregroundStyle(isSelected ? Color.cfTonic : Color.cfTextTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, CFSpacing.tight)
            .background(isSelected ? Color.cfTonic.opacity(0.08) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Compose Tab

    private var composeTab: some View {
        HStack(alignment: .top, spacing: CFSpacing.spacious) {
            // Left column: Circle + controls
            ScrollView {
                VStack(spacing: CFSpacing.standard) {
                    SharedCircleOfFifthsView(vm: vm) { chord in
                        vm.addChord(chord)
                    }

                    controlsStrip
                }
            }
            .frame(maxWidth: .infinity)

            // Right column: Chord detail
            ScrollView {
                VStack(spacing: CFSpacing.standard) {
                    SharedChordDetailPanel(vm: vm)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, CFSpacing.spacious)
        .padding(.top, CFSpacing.standard)
    }

    // MARK: - Suggest Tab

    private var suggestTab: some View {
        HStack(alignment: .top, spacing: CFSpacing.spacious) {
            // Left column: Circle + controls
            ScrollView {
                VStack(spacing: CFSpacing.standard) {
                    SharedCircleOfFifthsView(vm: vm) { chord in
                        vm.addChord(chord)
                    }

                    controlsStrip
                }
            }
            .frame(maxWidth: .infinity)

            // Right column: Suggestions panel
            ScrollView {
                VStack(spacing: CFSpacing.standard) {
                    AUv3SuggestView(vm: vm)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, CFSpacing.spacious)
        .padding(.top, CFSpacing.standard)
    }

    // MARK: - Controls Strip

    private var controlsStrip: some View {
        VStack(spacing: CFSpacing.tight) {
            Divider().background(Color.cfBorder)

            HStack(spacing: CFSpacing.spacious) {
                tensionSelector
                octaveSelector
                SharedBorrowedPresetPicker(vm: vm, isExpanded: $showBorrowedPicker)
            }
        }
    }

    // MARK: - Tension Selector

    private var tensionSelector: some View {
        let levels: [(label: String, value: Float)] = [
            ("Triads", 0.2),
            ("7ths", 0.45),
            ("9ths", 0.6),
            ("11ths", 0.75),
            ("13ths", 0.9),
        ]

        return VStack(spacing: CFSpacing.micro) {
            HStack(spacing: CFSpacing.tight) {
                ForEach(levels, id: \.label) { level in
                    let isSelected = vm.tension == level.value
                    Button {
                        vm.setTension(level.value)
                    } label: {
                        Text(level.label)
                            .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                            .foregroundStyle(isSelected ? Color.cfTonic : Color.cfTextTertiary)
                            .padding(.horizontal, CFSpacing.compact)
                            .padding(.vertical, CFSpacing.tight)
                            .background(
                                RoundedRectangle(cornerRadius: CFRadius.button)
                                    .fill(isSelected ? Color.cfTonic.opacity(0.15) : Color.cfSurface)
                                    .strokeBorder(isSelected ? Color.cfTonic : Color.cfBorder,
                                                  lineWidth: isSelected ? 1.5 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("TENSION")
                .font(.system(size: 8, weight: .medium, design: .rounded))
                .foregroundStyle(Color.cfTextTertiary)
        }
    }

    // MARK: - Octave Selector

    private var octaveSelector: some View {
        VStack(spacing: CFSpacing.micro) {
            HStack(spacing: CFSpacing.tight) {
                Button {
                    vm.defaultOctave = max(vm.defaultOctave - 1, -3)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.cfDominant)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: CFRadius.button)
                                .fill(Color.cfDominant.opacity(0.08))
                                .strokeBorder(Color.cfDominant.opacity(0.5), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(vm.defaultOctave <= -3)

                Text(vm.defaultOctave == 0 ? "0" : (vm.defaultOctave > 0 ? "+\(vm.defaultOctave)" : "\(vm.defaultOctave)"))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.cfDominant)
                    .frame(width: 32)

                Button {
                    vm.defaultOctave = min(vm.defaultOctave + 1, 3)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.cfDominant)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: CFRadius.button)
                                .fill(Color.cfDominant.opacity(0.08))
                                .strokeBorder(Color.cfDominant.opacity(0.5), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(vm.defaultOctave >= 3)
            }

            Text("OCTAVE")
                .font(.system(size: 8, weight: .medium, design: .rounded))
                .foregroundStyle(Color.cfTextTertiary)
        }
    }

    // MARK: - Playback Bar (with inline timeline)

    private var playbackBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: CFSpacing.compact) {
                // Play / Stop button
                Button {
                    vm.togglePlayback()
                } label: {
                    ZStack {
                        Circle()
                            .fill(vm.isPlaying ? Color.cfDestructive : Color.cfTonic)
                            .frame(width: 44, height: 44)
                        if vm.isPlaying {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.cfTextPrimary)
                                .frame(width: 18, height: 18)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Color.cfBase)
                                .offset(x: 2)
                        }
                    }
                }
                .buttonStyle(.plain)

                // Status text
                VStack(alignment: .leading, spacing: 1) {
                    Text(vm.isPlaying ? "Playing" : "Ready")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(vm.isPlaying ? Color.cfTonic : Color.cfTextPrimary)
                    Text(statusDetail)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.cfTextSecondary)
                }
                .fixedSize(horizontal: true, vertical: false)

                // Inline timeline
                SharedTimelineView(
                    vm: vm,
                    onBlockTap: { index in
                        vm.selectedBlockIndex = vm.selectedBlockIndex == index ? nil : index
                    },
                    onBlockLongPress: { index in
                        contextMenuBlockIndex = index
                    }
                )
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, CFSpacing.spacious)
            .padding(.vertical, CFSpacing.compact)
        }
        .background(
            RoundedRectangle(cornerRadius: CFRadius.card)
                .fill(Color.cfSurface)
                .strokeBorder(
                    vm.isPlaying ? Color.cfTonic.opacity(0.5) : Color.cfBorder,
                    lineWidth: vm.isPlaying ? 1.5 : 1
                )
        )
    }

    private var statusDetail: String {
        if vm.blocks.isEmpty {
            return "No chords"
        }
        if vm.isPlaying {
            return "Bar \(vm.currentBar) of \(vm.barCount)  |  \(vm.totalBeats) beats"
        }
        return "\(vm.barCount) chords  |  \(vm.totalBeats) beats"
    }

    // MARK: - Mode Picker Sheet

    private var modePickerSheet: some View {
        NavigationStack {
            List {
                ForEach(CFScaleMode.allCases, id: \.self) { scaleMode in
                    Button {
                        vm.setScaleMode(scaleMode)
                        vm.showModeSheet = false
                    } label: {
                        HStack {
                            Text(scaleMode.displayName())
                                .font(.cfBody)
                                .foregroundStyle(Color.cfTextPrimary)
                            Spacer()
                            if vm.scaleMode == scaleMode {
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
