import Foundation

public enum ChordFlowEngine {
    public static let ppq = 960

    public static func suggestions(key: CFKeyContext, previous: CFChord? = nil, tension: Double = 0.35) -> [CFSuggestion] {
        let degrees = diatonicTriads(key: key)
        let borrowed: [CFChord] = key.mode == .major
            ? [CFChord(root: key.tonic.transposed(10), quality: .major), CFChord(root: key.tonic.transposed(5), quality: .minor)]
            : []

        let candidates = unique(degrees + borrowed)
        return candidates.map { chord in
            var score = 0.5
            if degrees.contains(where: { $0.root == chord.root }) { score += 0.2 }
            if let previous {
                let distance = abs(previous.root.rawValue - chord.root.rawValue)
                score += max(0, 0.18 - Double(distance) / 24.0)
            }
            if tension > 0.55 {
                if chord.quality == .dominant { score += 0.06 }
            }
            let adjusted = CFChord(root: chord.root, quality: chord.quality, add7: tension > 0.4, add9: tension > 0.7)
            return CFSuggestion(chord: adjusted, confidence: min(score, 1), why: reason(for: adjusted, key: key))
        }
        .sorted { $0.confidence > $1.confidence }
    }

    // MARK: - Fixed Chord Buttons (Suggester-style)

    /// Returns all 7 diatonic chords + common borrowed chords as tappable button models.
    /// Tension controls add7/add9 extensions.
    public static func diatonicChords(
        key: CFKeyContext,
        tension: Double = 0.35,
        borrowedPreset: CFBorrowedChordPreset = .colorful
    ) -> [CFChordButton] {
        let triads = diatonicTriads(key: key)
        let numerals = romanNumerals(for: triads)
        var buttons: [CFChordButton] = triads.enumerated().map { idx, chord in
            let adjusted = CFChord(
                root: chord.root, quality: chord.quality,
                add7: tension > 0.4, add9: tension > 0.7
            )
            return CFChordButton(chord: adjusted, label: numerals[idx], isBorrowed: false)
        }

        // Add borrowed / modal interchange chords
        let borrowed = borrowedChords(key: key, tension: tension, preset: borrowedPreset)
        buttons.append(contentsOf: borrowed)

        return buttons
    }

    /// Common borrowed chords (modal interchange) for a given key.
    private static func borrowedChords(
        key: CFKeyContext,
        tension: Double,
        preset: CFBorrowedChordPreset
    ) -> [CFChordButton] {
        let apply7 = tension > 0.4
        let apply9 = tension > 0.7
        let make: (BorrowedSeed) -> CFChordButton = { seed in
            CFChordButton(
                chord: CFChord(root: key.tonic.transposed(seed.offset), quality: seed.quality, add7: apply7, add9: apply9),
                label: seed.label,
                isBorrowed: true
            )
        }

        let colorful = colorfulBorrowedSeeds(for: key.mode)
        let cinematic = [
            BorrowedSeed(offset: 8, quality: .major, label: "bVI"),
            BorrowedSeed(offset: 10, quality: .major, label: "bVII"),
            BorrowedSeed(offset: 5, quality: .minor, label: "iv"),
            BorrowedSeed(offset: 3, quality: .major, label: "bIII"),
            BorrowedSeed(offset: 1, quality: .major, label: "bII"),
        ]
        let jazz = [
            BorrowedSeed(offset: 2, quality: .minor, label: "ii"),
            BorrowedSeed(offset: 7, quality: .dominant, label: "V7"),
            BorrowedSeed(offset: 5, quality: .major, label: "IV"),
            BorrowedSeed(offset: 1, quality: .dominant, label: "bII7"),
            BorrowedSeed(offset: 10, quality: .dominant, label: "bVII7"),
        ]
        let experimental = [
            BorrowedSeed(offset: 1, quality: .major, label: "bII"),
            BorrowedSeed(offset: 6, quality: .diminished, label: "#iv°"),
            BorrowedSeed(offset: 11, quality: .major, label: "VII"),
            BorrowedSeed(offset: 8, quality: .minor, label: "bvi"),
            BorrowedSeed(offset: 4, quality: .minor, label: "iii"),
        ]

        let seeds: [BorrowedSeed] = switch preset {
        case .diatonicOnly:
            []
        case .conservative:
            Array(colorful.prefix(2))
        case .colorful:
            colorful
        case .cinematic:
            uniqueSeeds(cinematic + colorful).prefix(4).map { $0 }
        case .jazz:
            uniqueSeeds(jazz + colorful).prefix(5).map { $0 }
        case .experimental:
            uniqueSeeds(colorful + experimental).prefix(6).map { $0 }
        case .everything:
            uniqueSeeds(colorful + cinematic + jazz + experimental)
        }

        return seeds.map(make)
    }

    private struct BorrowedSeed: Hashable {
        let offset: Int
        let quality: CFChordQuality
        let label: String
    }

    private static func uniqueSeeds(_ seeds: [BorrowedSeed]) -> [BorrowedSeed] {
        var seen = Set<BorrowedSeed>()
        var out: [BorrowedSeed] = []
        for seed in seeds where !seen.contains(seed) {
            seen.insert(seed)
            out.append(seed)
        }
        return out
    }

    private static func colorfulBorrowedSeeds(for mode: CFScaleMode) -> [BorrowedSeed] {
        switch mode {
        case .major:
            return [
                BorrowedSeed(offset: 10, quality: .major, label: "bVII"),
                BorrowedSeed(offset: 5, quality: .minor, label: "iv"),
                BorrowedSeed(offset: 8, quality: .major, label: "bVI"),
                BorrowedSeed(offset: 3, quality: .major, label: "bIII"),
            ]
        case .ionian:
            return [
                BorrowedSeed(offset: 10, quality: .major, label: "bVII"),
                BorrowedSeed(offset: 5, quality: .minor, label: "iv"),
                BorrowedSeed(offset: 8, quality: .major, label: "bVI"),
            ]
        case .minor, .aeolian:
            return [
                BorrowedSeed(offset: 7, quality: .major, label: "V"),
                BorrowedSeed(offset: 5, quality: .major, label: "IV"),
                BorrowedSeed(offset: 0, quality: .major, label: "I"),
            ]
        case .dorian:
            return [
                BorrowedSeed(offset: 10, quality: .major, label: "bVII"),
                BorrowedSeed(offset: 8, quality: .major, label: "bVI"),
                BorrowedSeed(offset: 3, quality: .major, label: "bIII"),
            ]
        case .mixolydian:
            return [
                BorrowedSeed(offset: 5, quality: .minor, label: "iv"),
                BorrowedSeed(offset: 10, quality: .major, label: "bVII"),
                BorrowedSeed(offset: 3, quality: .major, label: "bIII"),
            ]
        case .phrygian:
            return [
                BorrowedSeed(offset: 1, quality: .major, label: "bII"),
                BorrowedSeed(offset: 7, quality: .major, label: "V"),
                BorrowedSeed(offset: 10, quality: .major, label: "bVII"),
            ]
        case .lydian:
            return [
                BorrowedSeed(offset: 5, quality: .minor, label: "iv"),
                BorrowedSeed(offset: 10, quality: .major, label: "bVII"),
                BorrowedSeed(offset: 3, quality: .major, label: "bIII"),
            ]
        case .locrian:
            return [
                BorrowedSeed(offset: 0, quality: .minor, label: "i"),
                BorrowedSeed(offset: 5, quality: .minor, label: "iv"),
                BorrowedSeed(offset: 10, quality: .major, label: "bVII"),
            ]
        case .melodicMinor:
            return [
                BorrowedSeed(offset: 7, quality: .major, label: "V"),
                BorrowedSeed(offset: 5, quality: .major, label: "IV"),
                BorrowedSeed(offset: 10, quality: .major, label: "bVII"),
            ]
        case .harmonicMinor:
            return [
                BorrowedSeed(offset: 5, quality: .major, label: "IV"),
                BorrowedSeed(offset: 10, quality: .major, label: "bVII"),
                BorrowedSeed(offset: 8, quality: .major, label: "bVI"),
            ]
        case .harmonicMajor:
            return [
                BorrowedSeed(offset: 5, quality: .minor, label: "iv"),
                BorrowedSeed(offset: 8, quality: .major, label: "bVI"),
                BorrowedSeed(offset: 3, quality: .major, label: "bIII"),
            ]
        case .doubleHarmonic:
            return [
                BorrowedSeed(offset: 3, quality: .major, label: "bIII"),
                BorrowedSeed(offset: 8, quality: .major, label: "bVI"),
                BorrowedSeed(offset: 10, quality: .major, label: "bVII"),
            ]
        case .phrygianDominant:
            return [
                BorrowedSeed(offset: 1, quality: .major, label: "bII"),
                BorrowedSeed(offset: 5, quality: .minor, label: "iv"),
                BorrowedSeed(offset: 10, quality: .major, label: "bVII"),
            ]
        case .lydianDominant:
            return [
                BorrowedSeed(offset: 5, quality: .minor, label: "iv"),
                BorrowedSeed(offset: 10, quality: .major, label: "bVII"),
                BorrowedSeed(offset: 3, quality: .major, label: "bIII"),
            ]
        case .lydianAugmented:
            return [
                BorrowedSeed(offset: 5, quality: .minor, label: "iv"),
                BorrowedSeed(offset: 7, quality: .minor, label: "v"),
                BorrowedSeed(offset: 10, quality: .major, label: "bVII"),
            ]
        case .locrianSharp2:
            return [
                BorrowedSeed(offset: 7, quality: .major, label: "V"),
                BorrowedSeed(offset: 8, quality: .major, label: "bVI"),
                BorrowedSeed(offset: 3, quality: .major, label: "bIII"),
            ]
        case .superLocrian:
            return [
                BorrowedSeed(offset: 0, quality: .minor, label: "i"),
                BorrowedSeed(offset: 1, quality: .major, label: "bII"),
                BorrowedSeed(offset: 8, quality: .major, label: "bVI"),
            ]
        case .neapolitanMinor:
            return [
                BorrowedSeed(offset: 7, quality: .major, label: "V"),
                BorrowedSeed(offset: 5, quality: .minor, label: "iv"),
                BorrowedSeed(offset: 8, quality: .major, label: "bVI"),
            ]
        case .neapolitanMajor:
            return [
                BorrowedSeed(offset: 7, quality: .major, label: "V"),
                BorrowedSeed(offset: 5, quality: .major, label: "IV"),
                BorrowedSeed(offset: 8, quality: .major, label: "bVI"),
            ]
        case .hungarianMinor:
            return [
                BorrowedSeed(offset: 1, quality: .major, label: "bII"),
                BorrowedSeed(offset: 5, quality: .major, label: "IV"),
                BorrowedSeed(offset: 10, quality: .major, label: "bVII"),
            ]
        case .romanianMinor:
            return [
                BorrowedSeed(offset: 1, quality: .major, label: "bII"),
                BorrowedSeed(offset: 5, quality: .major, label: "IV"),
                BorrowedSeed(offset: 8, quality: .major, label: "bVI"),
            ]
        case .persian:
            return [
                BorrowedSeed(offset: 3, quality: .major, label: "III"),
                BorrowedSeed(offset: 5, quality: .minor, label: "iv"),
                BorrowedSeed(offset: 10, quality: .major, label: "bVII"),
            ]
        case .enigmatic:
            return [
                BorrowedSeed(offset: 5, quality: .minor, label: "iv"),
                BorrowedSeed(offset: 3, quality: .major, label: "bIII"),
                BorrowedSeed(offset: 10, quality: .major, label: "bVII"),
            ]
        }
    }

    // MARK: - Rendering

    public static func render(blocks: [CFSequenceBlock], swing: Double = 0.0) -> [CFMIDIEvent] {
        let ordered = blocks.sorted {
            if $0.barStart == $1.barStart { return $0.beatStart < $1.beatStart }
            return $0.barStart < $1.barStart
        }

        var events: [CFMIDIEvent] = []
        for block in ordered {
            let startBeat = Double(block.barStart * 4) + block.beatStart
            let startTick = Int(startBeat * Double(ppq))
            let duration = Int(block.lengthBeats * Double(ppq))
            let rawTones = chordTones(block.chord)
            let tones = rawTones.map { UInt8(min(max(Int($0) + block.octaveShift * 12, 0), 127)) }
            switch block.pattern {
            case .block:
                for tone in tones {
                    events.append(noteOnOff(note: tone, startTick: applySwing(startTick, beat: startBeat, swing: swing), duration: duration))
                }
            case .arpUp, .arpDown:
                let orderedTones = block.pattern == .arpUp ? tones : tones.reversed()
                let step = max(1, duration / max(1, orderedTones.count))
                for (idx, tone) in orderedTones.enumerated() {
                    events.append(noteOnOff(note: tone, startTick: startTick + idx * step, duration: step))
                }
            case .strum:
                let gap = max(2, ppq / 32)
                for (idx, tone) in tones.enumerated() {
                    events.append(noteOnOff(note: tone, startTick: startTick + idx * gap, duration: max(1, duration - idx * gap)))
                }
            }
        }
        return events.sorted { $0.startTick < $1.startTick }
    }

    public static func encodeProject(_ project: CFProjectDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(project)
    }

    private static func scale(for key: CFKeyContext) -> [Int] {
        let pattern: [Int] = switch key.mode {
        case .major: [0, 2, 4, 5, 7, 9, 11]
        case .minor: [0, 2, 3, 5, 7, 8, 10]
        case .ionian: [0, 2, 4, 5, 7, 9, 11]
        case .dorian: [0, 2, 3, 5, 7, 9, 10]
        case .phrygian: [0, 1, 3, 5, 7, 8, 10]
        case .lydian: [0, 2, 4, 6, 7, 9, 11]
        case .mixolydian: [0, 2, 4, 5, 7, 9, 10]
        case .aeolian: [0, 2, 3, 5, 7, 8, 10]
        case .locrian: [0, 1, 3, 5, 6, 8, 10]
        case .melodicMinor: [0, 2, 3, 5, 7, 9, 11]
        case .harmonicMinor: [0, 2, 3, 5, 7, 8, 11]
        case .harmonicMajor: [0, 2, 4, 5, 7, 8, 11]
        case .doubleHarmonic: [0, 1, 4, 5, 7, 8, 11]
        case .phrygianDominant: [0, 1, 4, 5, 7, 8, 10]
        case .lydianDominant: [0, 2, 4, 6, 7, 9, 10]
        case .lydianAugmented: [0, 2, 4, 6, 8, 9, 11]
        case .locrianSharp2: [0, 2, 3, 5, 6, 8, 10]
        case .superLocrian: [0, 1, 3, 4, 6, 8, 10]
        case .neapolitanMinor: [0, 1, 3, 5, 7, 8, 11]
        case .neapolitanMajor: [0, 1, 3, 5, 7, 9, 11]
        case .hungarianMinor: [0, 2, 3, 6, 7, 8, 11]
        case .romanianMinor: [0, 2, 3, 6, 7, 9, 10]
        case .persian: [0, 1, 4, 5, 6, 8, 11]
        case .enigmatic: [0, 1, 4, 6, 8, 10, 11]
        }
        return pattern.map { (key.tonic.rawValue + $0) % 12 }
    }

    private static func romanNumerals(for triads: [CFChord]) -> [String] {
        let degrees = ["I", "II", "III", "IV", "V", "VI", "VII"]
        return triads.enumerated().map { idx, chord in
            let degree = idx < degrees.count ? degrees[idx] : "I"
            return switch chord.quality {
            case .major: degree
            case .minor: degree.lowercased()
            case .diminished: degree.lowercased() + "°"
            case .dominant: degree + "7"
            }
        }
    }

    private static func diatonicTriads(key: CFKeyContext) -> [CFChord] {
        let pcs = scale(for: key)
        return (0..<7).map { degree in
            let root = pcs[degree]
            let third = pcs[(degree + 2) % 7]
            let fifth = pcs[(degree + 4) % 7]
            let i3 = (third - root + 12) % 12
            let i5 = (fifth - root + 12) % 12
            let quality: CFChordQuality = switch (i3, i5) {
            case (4, 7): .major
            case (3, 7): .minor
            case (3, 6): .diminished
            default: .major
            }
            return CFChord(root: CFNote(rawValue: root) ?? .c, quality: quality)
        }
    }

    private static func chordTones(_ chord: CFChord) -> [UInt8] {
        let root = chord.root.rawValue
        var intervals: [Int] = switch chord.quality {
        case .major: [0, 4, 7]
        case .minor: [0, 3, 7]
        case .diminished: [0, 3, 6]
        case .dominant: [0, 4, 7, 10]
        }
        if chord.add7, !intervals.contains(10) { intervals.append(10) }
        if chord.add9 { intervals.append(14) }
        return intervals.map { UInt8(root + $0 + 60) }
    }

    private static func noteOnOff(note: UInt8, startTick: Int, duration: Int) -> CFMIDIEvent {
        CFMIDIEvent(startTick: startTick, durationTicks: duration, status: 0x90, data1: note, data2: 100)
    }

    private static func applySwing(_ tick: Int, beat: Double, swing: Double) -> Int {
        let beatFraction = beat - floor(beat)
        if beatFraction >= 0.5 { return tick + Int(Double(ppq / 2) * max(0, min(0.8, swing))) }
        return tick
    }

    private static func unique(_ chords: [CFChord]) -> [CFChord] {
        var set = Set<CFChord>()
        var out: [CFChord] = []
        for chord in chords where !set.contains(chord) {
            set.insert(chord)
            out.append(chord)
        }
        return out
    }

    private static func reason(for chord: CFChord, key: CFKeyContext) -> String {
        let function = romanFunction(chord: chord, key: key)
        let color = chord.add9 ? "extended color" : (chord.add7 ? "classic seventh color" : "stable triad")
        return "\(function) function with \(color)"
    }

    private static func romanFunction(chord: CFChord, key: CFKeyContext) -> String {
        let pcs = scale(for: key)
        let idx = pcs.firstIndex(of: chord.root.rawValue) ?? 0
        return ["I", "ii", "iii", "IV", "V", "vi", "vii°"][idx]
    }
}
