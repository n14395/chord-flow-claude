import SwiftUI
import ChordFlowShared

struct CircleOfFifthsView: View {
    @ObservedObject var vm: AppViewModel
    var onChordTap: ((CFChord) -> Void)?

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: size / 2)
            let outerR = size * 0.42
            let innerR = size * 0.26
            let borrowedR = size * 0.48

            ZStack {
                // Subtle center glow
                RadialGradient(
                    colors: [Color.cfTonic.opacity(0.08), Color.clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.45
                )

                // Ring tracks
                Circle()
                    .stroke(Color.cfSurface, lineWidth: 1)
                    .frame(width: outerR * 2, height: outerR * 2)
                    .position(center)
                Circle()
                    .stroke(Color.cfSurface.opacity(0.5), style: StrokeStyle(lineWidth: 0.5, dash: [4, 6]))
                    .frame(width: innerR * 2, height: innerR * 2)
                    .position(center)

                // Outer note ring
                outerNoteRing(center: center, radius: outerR)

                // Inner diatonic chord ring
                innerDiatonicRing(center: center, radius: innerR)

                // Borrowed chord hints
                borrowedHints(center: center, radius: borrowedR)

                // Center label
                centerLabel(center: center)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Outer Note Ring

    private func outerNoteRing(center: CGPoint, radius: CGFloat) -> some View {
        ForEach(0..<12, id: \.self) { position in
            let noteRaw = CircleOfFifths.notes[position]
            let note = CFNote(rawValue: noteRaw) ?? .c
            let angleDeg = CircleOfFifths.angle(for: position)
            let point = CircleOfFifths.point(center: center, radius: radius, angleDegrees: angleDeg)
            let isKey = note == vm.project.key.tonic
            let nodeR: CGFloat = isKey ? 18 : 15

            ZStack {
                if isKey {
                    // Selected key glow
                    Circle()
                        .fill(RadialGradient(
                            colors: [Color.cfTonic.opacity(0.6), Color.clear],
                            center: .center, startRadius: 0, endRadius: nodeR * 1.6
                        ))
                        .frame(width: nodeR * 3.2, height: nodeR * 3.2)
                }

                Circle()
                    .fill(isKey ? Color.cfTonic.opacity(0.25) : Color.cfSurface)
                    .frame(width: nodeR * 2, height: nodeR * 2)
                Circle()
                    .stroke(isKey ? Color.cfTonic : Color.cfBorder, lineWidth: isKey ? 2 : 1)
                    .frame(width: nodeR * 2, height: nodeR * 2)

                Text(CircleOfFifths.displayNames[position])
                    .font(.system(size: isKey ? 13 : 11, weight: isKey ? .bold : .semibold, design: .rounded))
                    .foregroundStyle(isKey ? Color.cfTonic : noteTextColor(position: position))
            }
            .position(point)
            .onTapGesture {
                vm.project.key.tonic = note
                vm.refreshChordButtons()
                vm.refreshSuggestions()
            }
        }
    }

    // MARK: - Inner Diatonic Chord Ring

    private func innerDiatonicRing(center: CGPoint, radius: CGFloat) -> some View {
        let diatonic = vm.chordButtons.filter { !$0.isBorrowed }
        return ForEach(Array(diatonic.enumerated()), id: \.element.id) { degreeIndex, button in
            let function = HarmonicFunction.forDegree(degreeIndex)
            let notePosition = CircleOfFifths.position(for: button.chord.root.rawValue)
            let angleDeg = CircleOfFifths.angle(for: notePosition)
            let point = CircleOfFifths.point(center: center, radius: radius, angleDegrees: angleDeg)
            let nodeR: CGFloat = 22
            let color = function.color

            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: nodeR * 2, height: nodeR * 2)
                Circle()
                    .stroke(color, lineWidth: 1.5)
                    .frame(width: nodeR * 2, height: nodeR * 2)

                VStack(spacing: 1) {
                    Text(button.label)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                    Text(button.chord.symbol())
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(color)
            }
            .position(point)
            .onTapGesture {
                onChordTap?(button.chord)
            }
        }
    }

    // MARK: - Borrowed Chord Hints

    private func borrowedHints(center: CGPoint, radius: CGFloat) -> some View {
        let borrowed = vm.chordButtons.filter { $0.isBorrowed }
        return ForEach(borrowed) { button in
            let notePosition = CircleOfFifths.position(for: button.chord.root.rawValue)
            let angleDeg = CircleOfFifths.angle(for: notePosition)
            let point = CircleOfFifths.point(center: center, radius: radius, angleDegrees: angleDeg)
            let nodeR: CGFloat = 16

            ZStack {
                Circle()
                    .fill(Color.cfBorrowed.opacity(0.06))
                    .frame(width: nodeR * 2, height: nodeR * 2)
                Circle()
                    .stroke(Color.cfBorrowed, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .frame(width: nodeR * 2, height: nodeR * 2)

                VStack(spacing: 0) {
                    Text(button.label)
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .opacity(0.5)
                    Text(button.chord.root.display())
                        .font(.system(size: 7, weight: .regular, design: .rounded))
                        .opacity(0.4)
                }
                .foregroundStyle(Color.cfBorrowed)
            }
            .position(point)
            .onTapGesture {
                onChordTap?(button.chord)
            }
        }
    }

    // MARK: - Center Label

    private func centerLabel(center: CGPoint) -> some View {
        VStack(spacing: 2) {
            Text(vm.keyDisplayName)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Color.cfTextPrimary)
            Text("Tap to change mode")
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(Color.cfTextSecondary)
        }
        .position(center)
        .onTapGesture {
            vm.showModeSheet = true
        }
    }

    // MARK: - Helpers

    /// Notes closer to the key (top half) are brighter; far side is dimmer.
    private func noteTextColor(position: Int) -> Color {
        position < 6 ? Color.cfTextSecondary : Color.cfTextTertiary
    }
}
