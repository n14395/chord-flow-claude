import SwiftUI
import ChordFlowShared

struct SuggestScreen: View {
    @ObservedObject var vm: AppViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var styleFilter: String = "All"

    private let styleFilters = ["All", "Pop", "Jazz", "Neo-Soul", "Cinematic", "Exp."]

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

                    // Suggestions panel (replaces ChordDetailPanel)
                    suggestionsPanel
                        .padding(.horizontal, CFSpacing.compact)
                }
                .padding(.top, CFSpacing.compact)
                .padding(.bottom, 100) // room for playback bar
            }

            // Playback bar (includes inline timeline)
            PlaybackBarView(vm: vm) { index in
                vm.selectedBlockIndex = vm.selectedBlockIndex == index ? nil : index
            }
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

                // Right column: Suggestions panel
                ScrollView {
                    VStack(spacing: CFSpacing.standard) {
                        suggestionsPanel
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, CFSpacing.spacious)
            .padding(.top, CFSpacing.standard)

            // Playback bar (includes inline timeline)
            PlaybackBarView(vm: vm) { index in
                vm.selectedBlockIndex = vm.selectedBlockIndex == index ? nil : index
            }
            .padding(.horizontal, CFSpacing.spacious)
            .padding(.bottom, CFSpacing.compact)
        }
    }

    // MARK: - Suggestions Panel (Right Column Content)

    private var suggestionsPanel: some View {
        VStack(alignment: .leading, spacing: CFSpacing.standard) {
            Text("Next Chord")
                .font(.cfHeading)
                .foregroundStyle(Color.cfTextPrimary)

            styleFilterPills
            suggestionList
        }
    }

    // MARK: - Controls Strip

    private var controlsStrip: some View {
        VStack(spacing: CFSpacing.tight) {
            Divider().background(Color.cfBorder)

            HStack(spacing: CFSpacing.spacious) {
                tensionSelector

                octaveSelector

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

    // MARK: - Tension Selector

    private var tensionSelector: some View {
        let levels: [(label: String, value: Double)] = [
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
                        vm.tension = level.value
                        vm.refreshChordButtons()
                        vm.refreshSuggestions()
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

    // MARK: - Style Filter Pills

    private var styleFilterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CFSpacing.tight) {
                ForEach(styleFilters, id: \.self) { filter in
                    let isActive = styleFilter == filter
                    Button {
                        styleFilter = filter
                        applyStyleFilter(filter)
                    } label: {
                        Text(filter)
                            .font(.system(size: 12, weight: isActive ? .semibold : .regular, design: .rounded))
                            .foregroundStyle(isActive ? Color.cfTonic : Color.cfTextSecondary)
                            .padding(.horizontal, CFSpacing.compact)
                            .padding(.vertical, CFSpacing.tight)
                            .background(
                                Capsule()
                                    .fill(isActive ? Color.cfTonic.opacity(0.15) : Color.cfSurface)
                                    .strokeBorder(isActive ? Color.cfTonic : Color.cfBorder,
                                                  lineWidth: isActive ? 1.5 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Suggestion List

    private var suggestionList: some View {
        VStack(spacing: CFSpacing.tight) {
            ForEach(Array(vm.suggestions.enumerated()), id: \.offset) { index, suggestion in
                let function = suggestionFunction(suggestion)
                SuggestionCardView(
                    suggestion: suggestion,
                    rank: index + 1,
                    function: function,
                    reasons: AppViewModel.reasonPills(
                        for: suggestion,
                        key: vm.project.key,
                        previous: vm.project.blocks.last?.chord
                    ),
                    isTopPick: index == 0,
                    onTap: {
                        vm.addChord(suggestion.chord)
                    },
                    onPreview: {
                        vm.previewChord(suggestion.chord)
                    }
                )
            }

            if vm.suggestions.isEmpty {
                VStack(spacing: CFSpacing.tight) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.cfTextTertiary)
                    Text("Add chords to see suggestions")
                        .font(.cfBody)
                        .foregroundStyle(Color.cfTextTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, CFSpacing.page)
            }
        }
    }

    // MARK: - Helpers

    private func applyStyleFilter(_ filter: String) {
        switch filter {
        case "Jazz":
            vm.borrowedPreset = .jazz
        case "Cinematic":
            vm.borrowedPreset = .cinematic
        case "Pop":
            vm.borrowedPreset = .conservative
        case "Neo-Soul":
            vm.borrowedPreset = .colorful
        case "Exp.":
            vm.borrowedPreset = .experimental
        default:
            break // "All" keeps current preset
        }
        vm.refreshChordButtons()
        vm.refreshSuggestions()
    }

    private func suggestionFunction(_ suggestion: CFSuggestion) -> HarmonicFunction {
        if let btn = vm.chordButtons.first(where: { $0.chord.root == suggestion.chord.root && $0.chord.quality == suggestion.chord.quality }) {
            return vm.harmonicFunction(for: btn)
        }
        return .tonic
    }
}
