import SwiftUI
import ChordFlowShared

struct AUv3ChordDetailPanel: View {
    @ObservedObject var vm: AUv3ViewModel

    private var isActive: Bool { vm.selectedBlockIndex != nil }
    private var blockIndex: Int { vm.selectedBlockIndex ?? 0 }

    private var block: CFSequenceBlock? {
        guard let idx = vm.selectedBlockIndex,
              vm.blocks.indices.contains(idx) else { return nil }
        return vm.blocks[idx]
    }

    private var function: HarmonicFunction {
        guard let idx = vm.selectedBlockIndex else { return .tonic }
        return vm.harmonicFunction(forBlockAt: idx)
    }

    private var color: Color { isActive ? function.color : Color.cfTextTertiary }

    var body: some View {
        VStack(alignment: .leading, spacing: CFSpacing.standard) {
            header
            Divider().background(Color.cfBorder)
            patternSelector
            lengthSelector
            extensionToggles
            octaveSelector
            voicingPreview
            actionButtons
        }
        .padding(CFSpacing.standard)
        .background(
            RoundedRectangle(cornerRadius: CFRadius.card)
                .fill(Color.cfSurface)
                .strokeBorder(isActive ? color.opacity(0.5) : Color.cfBorder,
                              lineWidth: isActive ? 1.5 : 1)
        )
        .animation(.easeInOut(duration: 0.2), value: vm.selectedBlockIndex)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: CFSpacing.compact) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 4, height: 36)

            if let block {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: CFSpacing.tight) {
                        Text(block.chord.symbol())
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(color)
                        Text(vm.romanNumeral(for: block.chord))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(color.opacity(0.6))
                        Text(function.label)
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(color)
                            .padding(.horizontal, CFSpacing.tight)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(color.opacity(0.12)))
                    }
                    let noteNames = AUv3ViewModel.noteNames(for: block.chord).joined(separator: "  ")
                    Text("Bar \(blockIndex + 1) of \(vm.barCount)  |  \(noteNames)")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.cfTextSecondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CHORD DETAIL")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.cfTextTertiary)
                    Text("Select a chord in the progression")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.cfTextTertiary.opacity(0.6))
                }
            }

            Spacer()

            if isActive {
                Button { vm.selectedBlockIndex = nil } label: {
                    ZStack {
                        Circle().fill(Color.cfBorder).frame(width: 24, height: 24)
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.cfTextSecondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Pattern Selector

    private var patternSelector: some View {
        VStack(alignment: .leading, spacing: CFSpacing.tight) {
            Text("PATTERN")
                .font(.cfCaption)
                .foregroundStyle(isActive ? Color.cfTextSecondary : Color.cfTextTertiary)
                .textCase(.uppercase)

            HStack(spacing: CFSpacing.compact) {
                ForEach(CFPattern.allCases, id: \.self) { pattern in
                    let isSelected = block?.pattern == pattern
                    Button {
                        guard isActive else { return }
                        vm.updateBlockPattern(pattern, at: blockIndex)
                    } label: {
                        VStack(spacing: 4) {
                            patternIcon(pattern).frame(height: 24)
                            Text(patternLabel(pattern))
                                .font(.system(size: 8, weight: isSelected ? .semibold : .regular, design: .rounded))
                        }
                        .foregroundStyle(isActive && isSelected ? color : Color.cfTextTertiary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(
                            RoundedRectangle(cornerRadius: CFRadius.button)
                                .fill(isActive && isSelected ? color.opacity(0.12) : Color.cfBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: CFRadius.button)
                                .stroke(isActive && isSelected ? color : Color.cfBorder,
                                        lineWidth: isActive && isSelected ? 1.5 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!isActive)
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
                    RoundedRectangle(cornerRadius: 1).frame(width: 24, height: 3)
                }
            }
        case .arpUp:
            HStack(spacing: 3) {
                ForEach(0..<4, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1).frame(width: 5, height: 3).offset(y: CGFloat(3 - i) * 4)
                }
            }
        case .arpDown:
            HStack(spacing: 3) {
                ForEach(0..<4, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1).frame(width: 5, height: 3).offset(y: CGFloat(i) * 4)
                }
            }
        case .strum:
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { i in
                    let h = CGFloat([12, 16, 18, 16, 12][i])
                    RoundedRectangle(cornerRadius: 1).frame(width: 2, height: h)
                }
            }
        }
    }

    // MARK: - Length Selector

    private var lengthSelector: some View {
        VStack(alignment: .leading, spacing: CFSpacing.tight) {
            Text("LENGTH")
                .font(.cfCaption)
                .foregroundStyle(isActive ? Color.cfTextSecondary : Color.cfTextTertiary)
                .textCase(.uppercase)

            HStack(spacing: CFSpacing.tight) {
                ForEach([1.0, 2.0, 4.0, 8.0, 16.0], id: \.self) { beats in
                    let isSelected = block?.lengthBeats == beats
                    Button {
                        guard isActive else { return }
                        vm.updateBlockLength(beats, at: blockIndex)
                    } label: {
                        Text("\(Int(beats))")
                            .font(.system(size: 11, weight: isSelected ? .semibold : .medium, design: .rounded))
                            .foregroundStyle(isActive && isSelected ? color : Color.cfTextTertiary)
                            .frame(minWidth: 32, maxWidth: .infinity)
                            .frame(height: 34)
                            .padding(.horizontal, 4)
                            .background(
                                RoundedRectangle(cornerRadius: CFRadius.button)
                                    .fill(isActive && isSelected ? color.opacity(0.12) : Color.cfBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: CFRadius.button)
                                    .stroke(isActive && isSelected ? color : Color.cfBorder,
                                            lineWidth: isActive && isSelected ? 1.5 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!isActive)
                }

                Text("beats")
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.cfTextTertiary)
            }
        }
    }

    // MARK: - Extension Toggles

    private var extensionToggles: some View {
        VStack(alignment: .leading, spacing: CFSpacing.tight) {
            Text("TENSION")
                .font(.cfCaption)
                .foregroundStyle(isActive ? Color.cfTextSecondary : Color.cfTextTertiary)
                .textCase(.uppercase)

            HStack(spacing: CFSpacing.tight) {
                tensionPill("Triad", add7: false, add9: false, add11: false, add13: false)
                tensionPill("7th", add7: true, add9: false, add11: false, add13: false)
                tensionPill("9th", add7: true, add9: true, add11: false, add13: false)
                tensionPill("11th", add7: true, add9: true, add11: true, add13: false)
                tensionPill("13th", add7: true, add9: true, add11: true, add13: true)
            }
        }
    }

    private func tensionPill(_ label: String, add7: Bool, add9: Bool, add11: Bool, add13: Bool) -> some View {
        let isSelected = block?.chord.add7 == add7 && block?.chord.add9 == add9
            && block?.chord.add11 == add11 && block?.chord.add13 == add13
        return Button {
            guard isActive else { return }
            vm.updateBlockExtensions(add7: add7, add9: add9, add11: add11, add13: add13, at: blockIndex)
        } label: {
            Text(label)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular, design: .rounded))
                .foregroundStyle(isActive && isSelected ? color : Color.cfTextTertiary)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background(
                    RoundedRectangle(cornerRadius: CFRadius.button)
                        .fill(isActive && isSelected ? color.opacity(0.15) : Color.cfBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CFRadius.button)
                        .stroke(isActive && isSelected ? color : Color.cfBorder,
                                lineWidth: isActive && isSelected ? 1.5 : 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isActive)
    }

    // MARK: - Octave Selector

    private var octaveSelector: some View {
        VStack(alignment: .leading, spacing: CFSpacing.tight) {
            Text("OCTAVE")
                .font(.cfCaption)
                .foregroundStyle(isActive ? Color.cfTextSecondary : Color.cfTextTertiary)
                .textCase(.uppercase)

            HStack(spacing: CFSpacing.compact) {
                Button {
                    guard isActive, let block else { return }
                    vm.updateBlockOctave(block.octaveShift - 1, at: blockIndex)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isActive ? color : Color.cfTextTertiary)
                        .frame(width: 40, height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: CFRadius.button)
                                .fill(isActive ? color.opacity(0.08) : Color.cfBackground)
                                .strokeBorder(isActive ? color.opacity(0.5) : Color.cfBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!isActive || (block?.octaveShift ?? 0) <= -3)

                Text(octaveLabel)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(isActive ? color : Color.cfTextTertiary)
                    .frame(width: 48, height: 30)

                Button {
                    guard isActive, let block else { return }
                    vm.updateBlockOctave(block.octaveShift + 1, at: blockIndex)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isActive ? color : Color.cfTextTertiary)
                        .frame(width: 40, height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: CFRadius.button)
                                .fill(isActive ? color.opacity(0.08) : Color.cfBackground)
                                .strokeBorder(isActive ? color.opacity(0.5) : Color.cfBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!isActive || (block?.octaveShift ?? 0) >= 3)
            }
        }
    }

    private var octaveLabel: String {
        guard let block else { return "0" }
        let shift = block.octaveShift
        if shift == 0 { return "0" }
        return shift > 0 ? "+\(shift)" : "\(shift)"
    }

    // MARK: - Voicing Preview

    private var voicingPreview: some View {
        VStack(alignment: .leading, spacing: CFSpacing.tight) {
            Text("VOICING")
                .font(.cfCaption)
                .foregroundStyle(isActive ? Color.cfTextSecondary : Color.cfTextTertiary)
                .textCase(.uppercase)

            if let block {
                AUv3MiniKeyboardView(chord: block.chord, color: color)
                    .frame(height: 44)
            } else {
                AUv3MiniKeyboardPlaceholder()
                    .frame(height: 44)
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: CFSpacing.compact) {
            Button {
                guard isActive else { return }
                vm.duplicateBlock(at: blockIndex)
            } label: {
                Text("Duplicate")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(isActive ? Color.cfTextPrimary : Color.cfTextTertiary)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(
                        RoundedRectangle(cornerRadius: CFRadius.button)
                            .fill(Color.cfBackground)
                            .strokeBorder(isActive ? Color.cfBorder : Color.cfBorder.opacity(0.5), lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!isActive)

            Button {
                guard isActive else { return }
                let idx = blockIndex
                vm.selectedBlockIndex = nil
                vm.removeBlock(at: idx)
            } label: {
                Text("Remove")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(isActive ? Color.cfDestructive : Color.cfTextTertiary)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(
                        RoundedRectangle(cornerRadius: CFRadius.button)
                            .fill(isActive ? Color.cfDestructive.opacity(0.12) : Color.cfBackground)
                            .strokeBorder(isActive ? Color.cfDestructive : Color.cfBorder.opacity(0.5), lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!isActive)
        }
    }

    private func patternLabel(_ pattern: CFPattern) -> String {
        switch pattern {
        case .block: return "Block"
        case .arpUp: return "Arp Up"
        case .arpDown: return "Arp Down"
        case .strum: return "Strum"
        }
    }
}

// MARK: - Mini Keyboard

private struct AUv3MiniKeyboardPlaceholder: View {
    var body: some View {
        GeometryReader { geo in
            let keyCount = 14
            let keyWidth = min(geo.size.width / CGFloat(keyCount), 22.0)
            HStack(spacing: 0) {
                ForEach(0..<keyCount, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.cfElevated.opacity(0.5))
                        .strokeBorder(Color.cfBorder.opacity(0.5), lineWidth: 0.5)
                        .frame(width: keyWidth, height: geo.size.height)
                }
            }
        }
    }
}

struct AUv3MiniKeyboardView: View {
    let chord: CFChord
    let color: Color

    private let whiteKeyWidth: CGFloat = 22
    private let whiteKeyNotes = [0, 2, 4, 5, 7, 9, 11]

    private var activeMIDI: Set<Int> {
        Set(AUv3ViewModel.chordTones(chord).map { Int($0) % 12 })
    }

    var body: some View {
        GeometryReader { geo in
            let keyCount = 14
            let scale = min(geo.size.width / (CGFloat(keyCount) * whiteKeyWidth), 1.0)
            HStack(spacing: 0) {
                ForEach(0..<keyCount, id: \.self) { i in
                    let noteInOctave = whiteKeyNotes[i % 7]
                    let isActive = activeMIDI.contains(noteInOctave)
                    ZStack(alignment: .bottom) {
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

    private func noteNameForPC(_ pc: Int) -> String {
        ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"][pc]
    }
}
