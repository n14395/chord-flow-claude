import SwiftUI
import ChordFlowShared

struct AUv3CircleOfFifthsView: View {
    @ObservedObject var vm: AUv3ViewModel
    var onChordTap: ((CFChord) -> Void)?

    @State private var expandedChordID: String?

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: size / 2)
            let outerR = size * 0.38
            let innerR = size * 0.20
            let borrowedR = size * 0.50

            ZStack {
                // Center glow
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

                outerNoteRing(center: center, radius: outerR)
                innerDiatonicRing(center: center, radius: innerR)
                borrowedHints(center: center, radius: borrowedR)
                centerLabel(center: center)

                // Background tap to dismiss expanded chord
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if expandedChordID != nil {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                expandedChordID = nil
                            }
                        }
                    }
                    .allowsHitTesting(expandedChordID != nil)
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
            let isKey = note == vm.tonicNote
            let nodeR: CGFloat = isKey ? 30 : 26

            ZStack {
                if isKey {
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
                    .stroke(isKey ? Color.cfTonic : Color.cfBorder, lineWidth: isKey ? 2.5 : 1.5)
                    .frame(width: nodeR * 2, height: nodeR * 2)

                Text(CircleOfFifths.displayNames[position])
                    .font(.system(size: isKey ? 22 : 18, weight: isKey ? .bold : .semibold, design: .rounded))
                    .foregroundStyle(isKey ? Color.cfTonic : noteTextColor(position: position))
            }
            .position(point)
            .onTapGesture {
                vm.setTonic(Float(noteRaw))
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
            let nodeR: CGFloat = 36
            let color = function.color
            let isExpanded = expandedChordID == button.id

            let angleRad = angleDeg * .pi / 180
            let expandOffset: CGFloat = isExpanded ? nodeR * 0.7 : 0
            let expandX = -expandOffset * CGFloat(sin(angleRad))
            let expandY = expandOffset * CGFloat(cos(angleRad))

            let plusOffset = nodeR + 20
            let plusX = plusOffset * CGFloat(sin(angleRad))
            let plusY = -plusOffset * CGFloat(cos(angleRad))

            ZStack {
                Circle()
                    .fill(color.opacity(isExpanded ? 0.25 : 0.15))
                    .frame(width: nodeR * 2, height: nodeR * 2)
                Circle()
                    .stroke(color, lineWidth: isExpanded ? 2.5 : 2)
                    .frame(width: nodeR * 2, height: nodeR * 2)

                VStack(spacing: 2) {
                    Text(button.label)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text(button.chord.symbol())
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(color)

                if isExpanded {
                    Button {
                        onChordTap?(button.chord)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            expandedChordID = nil
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(color)
                                .frame(width: 48, height: 48)
                            Image(systemName: "plus")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(Color.cfBase)
                        }
                    }
                    .buttonStyle(.plain)
                    .offset(x: plusX, y: plusY)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .position(x: point.x + expandX, y: point.y + expandY)
            .zIndex(isExpanded ? 10 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    expandedChordID = isExpanded ? nil : button.id
                }
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
            let nodeR: CGFloat = 28
            let isExpanded = expandedChordID == button.id

            let angleRad = angleDeg * .pi / 180
            let expandOffset: CGFloat = isExpanded ? nodeR * 0.7 : 0
            let expandX = -expandOffset * CGFloat(sin(angleRad))
            let expandY = expandOffset * CGFloat(cos(angleRad))

            let plusOffset = nodeR + 18
            let plusX = plusOffset * CGFloat(sin(angleRad))
            let plusY = -plusOffset * CGFloat(cos(angleRad))

            ZStack {
                Circle()
                    .fill(Color.cfBorrowed.opacity(isExpanded ? 0.15 : 0.06))
                    .frame(width: nodeR * 2, height: nodeR * 2)
                Circle()
                    .stroke(Color.cfBorrowed, style: StrokeStyle(lineWidth: isExpanded ? 2 : 1.5, dash: [4, 4]))
                    .frame(width: nodeR * 2, height: nodeR * 2)

                VStack(spacing: 1) {
                    Text(button.label)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .opacity(isExpanded ? 0.8 : 0.5)
                    Text(button.chord.root.display())
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .opacity(isExpanded ? 0.7 : 0.4)
                }
                .foregroundStyle(Color.cfBorrowed)

                if isExpanded {
                    Button {
                        onChordTap?(button.chord)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            expandedChordID = nil
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.cfBorrowed)
                                .frame(width: 48, height: 48)
                            Image(systemName: "plus")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(Color.cfBase)
                        }
                    }
                    .buttonStyle(.plain)
                    .offset(x: plusX, y: plusY)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .position(x: point.x + expandX, y: point.y + expandY)
            .zIndex(isExpanded ? 10 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    expandedChordID = isExpanded ? nil : button.id
                }
            }
        }
    }

    // MARK: - Center Label

    private func centerLabel(center: CGPoint) -> some View {
        VStack(spacing: 3) {
            Text(vm.keyDisplayName)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(Color.cfTextPrimary)
            Text("Tap to change mode")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(Color.cfTextSecondary)
        }
        .position(center)
        .onTapGesture {
            vm.showModeSheet = true
        }
    }

    private func noteTextColor(position: Int) -> Color {
        position < 6 ? Color.cfTextSecondary : Color.cfTextTertiary
    }
}
