import SwiftUI
import ChordFlowShared

struct ComposeScreen: View {
    @ObservedObject var vm: AppViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showBorrowedPicker = false

    var body: some View {
        VStack(spacing: 0) {
            if sizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .background(Color.cfBackground.ignoresSafeArea())
        .dismissBorrowedPicker(isExpanded: $showBorrowedPicker)
        .sheet(isPresented: $vm.showModeSheet) {
            modePickerSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.cfSurface)
        }
    }

    // MARK: - iPhone Layout

    private var iPhoneLayout: some View {
        ScrollView {
            VStack(spacing: CFSpacing.standard) {
                // Circle of Fifths
                SharedCircleOfFifthsView(vm: vm) { chord in
                    vm.addChord(chord)
                }
                .padding(.horizontal, CFSpacing.spacious)

                // Controls strip
                controlsStrip
                    .padding(.horizontal, CFSpacing.spacious)

                // Chord detail panel
                SharedChordDetailPanel(vm: vm)
                    .padding(.horizontal, CFSpacing.compact)
            }
            .padding(.top, CFSpacing.compact)
        }
    }

    // MARK: - iPad Layout

    private var iPadLayout: some View {
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

    // MARK: - Controls Strip

    private var controlsStrip: some View {
        VStack(spacing: CFSpacing.tight) {
            Divider().background(Color.cfBorder)

            HStack(spacing: CFSpacing.spacious) {
                tensionSelector

                octaveSelector

                SharedBorrowedPresetPicker(vm: vm, isExpanded: $showBorrowedPicker)

                KnobView(
                    value: $vm.project.tempo,
                    in: 60...180,
                    step: 1,
                    label: "BPM",
                    color: .cfSubdominant,
                    format: { "\(Int($0.rounded()))" }
                )
                .frame(width: 72, height: 90)
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

    // MARK: - Mode Picker Sheet

    private var modePickerSheet: some View {
        NavigationStack {
            List {
                ForEach(CFScaleMode.allCases, id: \.self) { mode in
                    Button {
                        vm.setScaleMode(mode)
                        vm.showModeSheet = false
                    } label: {
                        HStack {
                            Text(mode.displayName())
                                .font(.cfBody)
                                .foregroundStyle(Color.cfTextPrimary)
                            Spacer()
                            if vm.key.mode == mode {
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

// FlowLayout is now in ChordFlowShared/DesignTokens.swift
