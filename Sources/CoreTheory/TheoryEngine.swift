import Foundation
import ChordFlowModels

public enum TheoryEngine {
    public static func scalePitchClasses(for key: KeyContext) -> [Int] {
        let pattern: [Int] = switch key.mode {
        case .major: [0, 2, 4, 5, 7, 9, 11]
        case .minor: [0, 2, 3, 5, 7, 8, 10]
        case .dorian: [0, 2, 3, 5, 7, 9, 10]
        case .mixolydian: [0, 2, 4, 5, 7, 9, 10]
        }
        return pattern.map { (key.tonic.midiClass + $0) % 12 }
    }

    public static func diatonicTriads(for key: KeyContext) -> [ChordToken] {
        let pcs = scalePitchClasses(for: key)
        return (0..<7).map { degree in
            let root = pcs[degree]
            let third = pcs[(degree + 2) % 7]
            let fifth = pcs[(degree + 4) % 7]
            let quality = triadQuality(root: root, third: third, fifth: fifth)
            return ChordToken(root: NoteName(rawValue: root) ?? .c, quality: quality)
        }
    }

    public static func chordTones(_ token: ChordToken, octave: Int = 4) -> [UInt8] {
        let base = token.root.midiClass
        var intervals: [Int] = switch token.quality {
        case .major: [0, 4, 7]
        case .minor: [0, 3, 7]
        case .diminished: [0, 3, 6]
        case .augmented: [0, 4, 8]
        case .dominant: [0, 4, 7, 10]
        case .suspended2: [0, 2, 7]
        case .suspended4: [0, 5, 7]
        }

        for ext in token.extensions {
            switch ext {
            case .seventh:
                if !intervals.contains(10) && !intervals.contains(11) { intervals.append(10) }
            case .ninth:
                intervals.append(14)
            case .eleventh:
                intervals.append(17)
            case .thirteenth:
                intervals.append(21)
            }
        }

        for alteration in token.alterations {
            switch alteration {
            case .flatFifth:
                intervals = intervals.map { $0 == 7 ? 6 : $0 }
            case .sharpFifth:
                intervals = intervals.map { $0 == 7 ? 8 : $0 }
            case .flatNinth:
                intervals = intervals.map { $0 == 14 ? 13 : $0 }
            case .sharpNinth:
                intervals = intervals.map { $0 == 14 ? 15 : $0 }
            }
        }

        intervals.sort()
        var notes = intervals.enumerated().map { index, interval -> UInt8 in
            let inversionLift = index < token.inversion ? 12 : 0
            let value = base + interval + (octave + 1) * 12 + inversionLift
            return UInt8(max(0, min(127, value)))
        }

        if let slash = token.slashBass {
            let bass = UInt8((octave + 0) * 12 + slash.midiClass)
            notes.insert(bass, at: 0)
        }
        return notes
    }

    public static func romanFunction(chord: ChordToken, key: KeyContext) -> String {
        let pcs = scalePitchClasses(for: key)
        let index = pcs.firstIndex(of: chord.root.midiClass) ?? 0
        let numerals = ["I", "ii", "iii", "IV", "V", "vi", "vii°"]
        return numerals[index]
    }

    private static func triadQuality(root: Int, third: Int, fifth: Int) -> ChordQuality {
        let i3 = (third - root + 12) % 12
        let i5 = (fifth - root + 12) % 12
        switch (i3, i5) {
        case (4, 7): return .major
        case (3, 7): return .minor
        case (3, 6): return .diminished
        case (4, 8): return .augmented
        default: return .major
        }
    }
}
