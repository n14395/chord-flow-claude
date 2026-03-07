import SwiftUI
import ChordFlowShared

// MARK: - Main AUv3 View

struct AUv3View: View {
    @ObservedObject var vm: AUv3ViewModel

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

            // Playback bar
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
        ScrollView {
            VStack(spacing: CFSpacing.standard) {
                AUv3CircleOfFifthsView(vm: vm) { chord in
                    vm.addChord(chord)
                }
                .padding(.horizontal, CFSpacing.spacious)

                controlsStrip
                    .padding(.horizontal, CFSpacing.spacious)

                AUv3TimelineView(vm: vm) { index in
                    vm.selectedBlockIndex = vm.selectedBlockIndex == index ? nil : index
                }
                .padding(.horizontal, CFSpacing.compact)

                AUv3ChordDetailPanel(vm: vm)
                    .padding(.horizontal, CFSpacing.compact)
            }
            .padding(.top, CFSpacing.compact)
            .padding(.bottom, CFSpacing.spacious)
        }
    }

    // MARK: - Suggest Tab

    private var suggestTab: some View {
        AUv3SuggestView(vm: vm)
    }

    // MARK: - Controls Strip

    private var controlsStrip: some View {
        VStack(spacing: CFSpacing.tight) {
            Divider().background(Color.cfBorder)

            HStack(spacing: CFSpacing.spacious) {
                tensionSelector
                octaveSelector
                borrowedPresetPill
            }
        }
    }

    // MARK: - Tension Selector

    private var tensionSelector: some View {
        let levels: [(label: String, value: Float)] = [
            ("Triads", 0.2),
            ("7ths", 0.5),
            ("9ths", 0.8),
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

    // MARK: - Playback Bar

    private var playbackBar: some View {
        VStack(spacing: 0) {
            if vm.isPlaying {
                GeometryReader { geo in
                    let barWidth = geo.size.width * vm.playbackProgress
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color.cfSurface)
                            .frame(height: 3)
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color.cfTonic.opacity(0.7))
                            .frame(width: barWidth, height: 3)
                        Circle()
                            .fill(Color.cfTonic)
                            .frame(width: 10, height: 10)
                            .offset(x: barWidth - 5)
                    }
                    .animation(.linear(duration: 1.0 / 15.0), value: vm.playbackProgress)
                }
                .frame(height: 10)
                .padding(.horizontal, CFSpacing.spacious)
                .padding(.top, CFSpacing.tight)
            }

            HStack(spacing: CFSpacing.standard) {
                // Transport status indicator
                ZStack {
                    Circle()
                        .fill(vm.isPlaying ? Color.cfTonic : Color.cfSurface)
                        .frame(width: 32, height: 32)
                    if vm.isPlaying {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.cfBase)
                            .frame(width: 12, height: 12)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.cfTextTertiary)
                            .offset(x: 1)
                    }
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(vm.isPlaying ? "Playing" : "Ready")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(vm.isPlaying ? Color.cfTonic : Color.cfTextPrimary)
                    Text(statusDetail)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.cfTextSecondary)
                }

                Spacer()

                // Clear button
                if !vm.blocks.isEmpty {
                    Button {
                        vm.clearProgression()
                    } label: {
                        Text("Clear")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.cfDestructive)
                            .padding(.horizontal, CFSpacing.tight)
                            .padding(.vertical, CFSpacing.micro)
                            .background(
                                Capsule()
                                    .fill(Color.cfDestructive.opacity(0.12))
                                    .strokeBorder(Color.cfDestructive.opacity(0.5), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
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
                        let idx = CFScaleMode.allCases.firstIndex(of: scaleMode) ?? 0
                        vm.setMode(Float(idx))
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
