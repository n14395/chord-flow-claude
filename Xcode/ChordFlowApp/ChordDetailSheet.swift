import SwiftUI
import ChordFlowShared

struct ChordDetailSheet: View {
    @ObservedObject var vm: AppViewModel
    let blockIndex: Int
    @Environment(\.dismiss) private var dismiss

    private var block: CFSequenceBlock? {
        vm.project.blocks.indices.contains(blockIndex) ? vm.project.blocks[blockIndex] : nil
    }

    private var function: HarmonicFunction {
        vm.harmonicFunction(forBlockAt: blockIndex)
    }

    private var color: Color { function.color }

    var body: some View {
        if let block {
            VStack(spacing: 0) {
                // Handle
                Capsule()
                    .fill(Color.cfBorder)
                    .frame(width: 48, height: 4)
                    .padding(.top, CFSpacing.compact)

                // Header
                header(block: block)

                Divider().background(Color.cfBorder)
                    .padding(.horizontal, CFSpacing.spacious)

                ScrollView {
                    VStack(alignment: .leading, spacing: CFSpacing.spacious) {
                        patternSelector(block: block)
                        lengthSelector(block: block)
                        extensionToggles(block: block)
                        voicingPreview(block: block)
                        actionButtons(block: block)
                    }
                    .padding(.horizontal, CFSpacing.spacious)
                    .padding(.bottom, CFSpacing.section)
                }
            }
            .background(Color.cfSurface.ignoresSafeArea())
        }
    }

    // MARK: - Header

    private func header(block: CFSequenceBlock) -> some View {
        HStack(spacing: CFSpacing.compact) {
            // Function color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 4, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: CFSpacing.tight) {
                    Text(block.chord.symbol())
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                    Text(vm.romanNumeral(for: block.chord))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(color.opacity(0.6))
                    // Function badge
                    Text(function.label)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(color)
                        .padding(.horizontal, CFSpacing.tight)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(color.opacity(0.12)))
                }
                let noteNames = AppViewModel.noteNames(for: block.chord).joined(separator: "  ")
                Text("Bar \(blockIndex + 1) of \(vm.barCount)  |  \(noteNames)")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.cfTextSecondary)
            }

            Spacer()

            // Close button
            Button { dismiss() } label: {
                ZStack {
                    Circle()
                        .fill(Color.cfBorder)
                        .frame(width: 28, height: 28)
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.cfTextSecondary)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, CFSpacing.spacious)
        .padding(.vertical, CFSpacing.standard)
    }

    // MARK: - Pattern Selector

    private func patternSelector(block: CFSequenceBlock) -> some View {
        VStack(alignment: .leading, spacing: CFSpacing.tight) {
            Text("PATTERN")
                .font(.cfCaption)
                .foregroundStyle(Color.cfTextSecondary)
                .textCase(.uppercase)

            HStack(spacing: CFSpacing.compact) {
                ForEach(CFPattern.allCases, id: \.self) { pattern in
                    let isSelected = block.pattern == pattern
                    Button {
                        vm.updateBlockPattern(pattern, at: blockIndex)
                    } label: {
                        VStack(spacing: 4) {
                            patternIcon(pattern)
                                .frame(height: 28)
                            Text(patternLabel(pattern))
                                .font(.system(size: 9, weight: isSelected ? .semibold : .regular, design: .rounded))
                        }
                        .foregroundStyle(isSelected ? color : Color.cfTextTertiary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isSelected ? color.opacity(0.12) : Color.cfSurface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isSelected ? color : Color.cfBorder,
                                        lineWidth: isSelected ? 1.5 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func patternIcon(_ pattern: CFPattern) -> some View {
        switch pattern {
        case .block:
            VStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 1)
                        .frame(width: 28, height: 3)
                }
            }
        case .arpUp:
            HStack(spacing: 3) {
                ForEach(0..<4, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .frame(width: 6, height: 3)
                        .offset(y: CGFloat(3 - i) * 5)
                }
            }
        case .arpDown:
            HStack(spacing: 3) {
                ForEach(0..<4, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .frame(width: 6, height: 3)
                        .offset(y: CGFloat(i) * 5)
                }
            }
        case .strum:
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { i in
                    let h = CGFloat([14, 18, 20, 18, 14][i])
                    RoundedRectangle(cornerRadius: 1)
                        .frame(width: 2, height: h)
                }
            }
        }
    }

    // MARK: - Length Selector

    private func lengthSelector(block: CFSequenceBlock) -> some View {
        VStack(alignment: .leading, spacing: CFSpacing.tight) {
            Text("LENGTH")
                .font(.cfCaption)
                .foregroundStyle(Color.cfTextSecondary)
                .textCase(.uppercase)

            HStack(spacing: CFSpacing.compact) {
                ForEach([2.0, 4.0, 8.0], id: \.self) { beats in
                    let isSelected = block.lengthBeats == beats
                    Button {
                        vm.updateBlockLength(beats, at: blockIndex)
                    } label: {
                        Text("\(Int(beats))")
                            .font(.system(size: 13, weight: isSelected ? .semibold : .medium, design: .rounded))
                            .foregroundStyle(isSelected ? color : Color.cfTextSecondary)
                            .frame(width: 64, height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(isSelected ? color.opacity(0.12) : Color.cfSurface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isSelected ? color : Color.cfBorder,
                                            lineWidth: isSelected ? 1.5 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Text("beats")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.cfTextTertiary)
            }
        }
    }

    // MARK: - Extension Toggles

    private func extensionToggles(block: CFSequenceBlock) -> some View {
        VStack(alignment: .leading, spacing: CFSpacing.tight) {
            Text("EXTENSIONS")
                .font(.cfCaption)
                .foregroundStyle(Color.cfTextSecondary)
                .textCase(.uppercase)

            HStack(spacing: CFSpacing.compact) {
                extensionToggle("7th", isActive: block.chord.add7) {
                    vm.updateBlockExtensions(add7: !block.chord.add7, add9: block.chord.add9, at: blockIndex)
                }
                extensionToggle("9th", isActive: block.chord.add9) {
                    vm.updateBlockExtensions(add7: block.chord.add7, add9: !block.chord.add9, at: blockIndex)
                }
                extensionToggle("11th", isActive: false) { }
                    .opacity(0.5)
                extensionToggle("13th", isActive: false) { }
                    .opacity(0.5)
            }
        }
    }

    private func extensionToggle(_ label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: isActive ? .semibold : .regular, design: .rounded))
                .foregroundStyle(isActive ? color : Color.cfTextTertiary)
                .frame(width: 56, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: CFRadius.button)
                        .fill(isActive ? color.opacity(0.15) : Color.cfSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CFRadius.button)
                        .stroke(isActive ? color : Color.cfBorder,
                                lineWidth: isActive ? 1.5 : 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Voicing Preview (Mini Keyboard)

    private func voicingPreview(block: CFSequenceBlock) -> some View {
        VStack(alignment: .leading, spacing: CFSpacing.tight) {
            Text("VOICING")
                .font(.cfCaption)
                .foregroundStyle(Color.cfTextSecondary)
                .textCase(.uppercase)

            MiniKeyboardView(chord: block.chord, color: color)
                .frame(height: 52)
        }
    }

    // MARK: - Action Buttons

    private func actionButtons(block: CFSequenceBlock) -> some View {
        HStack(spacing: CFSpacing.compact) {
            // Preview
            Button {
                vm.previewChord(block.chord)
            } label: {
                Text("Preview")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(color)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(color.opacity(0.12))
                            .strokeBorder(color, lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)

            // Duplicate
            Button {
                vm.duplicateBlock(at: blockIndex)
                dismiss()
            } label: {
                Text("Duplicate")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.cfTextPrimary)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.cfSurface)
                            .strokeBorder(Color.cfBorder, lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)

            // Remove
            Button {
                vm.removeBlock(at: blockIndex)
                dismiss()
            } label: {
                Text("Remove")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.cfDestructive)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.cfDestructive.opacity(0.12))
                            .strokeBorder(Color.cfDestructive, lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private func patternLabel(_ pattern: CFPattern) -> String {
        switch pattern {
        case .block: return "Block"
        case .arpUp: return "Arp Up"
        case .arpDown: return "Arp Down"
        case .strum: return "Strum"
        }
    }
}

// MARK: - Mini Keyboard View

struct MiniKeyboardView: View {
    let chord: CFChord
    let color: Color

    private let whiteKeyWidth: CGFloat = 22
    private let blackKeyWidth: CGFloat = 14

    // MIDI note numbers for chord tones
    private var activeMIDI: Set<Int> {
        Set(AppViewModel.chordTones(chord).map { Int($0) % 12 })
    }

    var body: some View {
        GeometryReader { geo in
            let availableWidth = geo.size.width
            let keyCount = 14 // C4 to D5 (one octave + 2 for context)
            let scale = min(availableWidth / (CGFloat(keyCount) * whiteKeyWidth), 1.0)

            HStack(spacing: 0) {
                ForEach(0..<keyCount, id: \.self) { i in
                    let noteInOctave = whiteKeyNotes[i % 7]
                    let isActive = activeMIDI.contains(noteInOctave)

                    ZStack(alignment: .bottom) {
                        // White key
                        RoundedRectangle(cornerRadius: 2)
                            .fill(isActive ? color.opacity(0.3) : Color.cfElevated)
                            .strokeBorder(isActive ? color : Color.cfBorder, lineWidth: 0.5)

                        if isActive {
                            Text(noteNameForPC(noteInOctave))
                                .font(.system(size: 7 * scale, weight: .semibold, design: .rounded))
                                .foregroundStyle(color)
                                .padding(.bottom, 2)
                        }
                    }
                    .frame(width: whiteKeyWidth * scale, height: geo.size.height)
                }
            }
        }
    }

    private let whiteKeyNotes = [0, 2, 4, 5, 7, 9, 11] // C D E F G A B

    private func noteNameForPC(_ pc: Int) -> String {
        ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"][pc]
    }
}
