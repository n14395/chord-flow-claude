import Foundation

public enum CFNote: Int, CaseIterable, Codable {
    case c = 0, cSharp, d, dSharp, e, f, fSharp, g, gSharp, a, aSharp, b

    public func transposed(_ semitones: Int) -> CFNote {
        let next = (rawValue + semitones % 12 + 12) % 12
        return CFNote(rawValue: next) ?? .c
    }

    public func display() -> String {
        ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"][rawValue]
    }
}

public enum CFScaleMode: String, CaseIterable, Codable {
    case major
    case minor
    case ionian
    case dorian
    case phrygian
    case lydian
    case mixolydian
    case aeolian
    case locrian
    case melodicMinor
    case harmonicMinor
    case harmonicMajor
    case doubleHarmonic
    case phrygianDominant
    case lydianDominant
    case lydianAugmented
    case locrianSharp2
    case superLocrian
    case neapolitanMinor
    case neapolitanMajor
    case hungarianMinor
    case romanianMinor
    case persian
    case enigmatic

    public func displayName() -> String {
        switch self {
        case .major: return "Major"
        case .minor: return "Minor"
        case .ionian: return "Ionian"
        case .dorian: return "Dorian"
        case .phrygian: return "Phrygian"
        case .lydian: return "Lydian"
        case .mixolydian: return "Mixolydian"
        case .aeolian: return "Aeolian"
        case .locrian: return "Locrian"
        case .melodicMinor: return "Melodic Minor"
        case .harmonicMinor: return "Harmonic Minor"
        case .harmonicMajor: return "Harmonic Major"
        case .doubleHarmonic: return "Double Harmonic"
        case .phrygianDominant: return "Phrygian Dominant"
        case .lydianDominant: return "Lydian Dominant"
        case .lydianAugmented: return "Lydian Augmented"
        case .locrianSharp2: return "Locrian #2"
        case .superLocrian: return "Super Locrian"
        case .neapolitanMinor: return "Neapolitan Minor"
        case .neapolitanMajor: return "Neapolitan Major"
        case .hungarianMinor: return "Hungarian Minor"
        case .romanianMinor: return "Romanian Minor"
        case .persian: return "Persian"
        case .enigmatic: return "Enigmatic"
        }
    }
}

public enum CFBorrowedChordPreset: String, CaseIterable, Codable {
    case diatonicOnly
    case conservative
    case colorful
    case cinematic
    case jazz
    case experimental
    case everything

    public func displayName() -> String {
        switch self {
        case .diatonicOnly: return "Diatonic Only"
        case .conservative: return "Conservative"
        case .colorful: return "Colorful"
        case .cinematic: return "Cinematic"
        case .jazz: return "Jazz"
        case .experimental: return "Experimental"
        case .everything: return "Everything"
        }
    }
}

public enum CFChordQuality: String, CaseIterable, Codable {
    case major, minor, diminished, dominant
}

public enum CFPattern: String, CaseIterable, Codable {
    case block, arpUp, arpDown, strum
}

public struct CFKeyContext: Codable, Equatable {
    public var tonic: CFNote
    public var mode: CFScaleMode

    public init(tonic: CFNote = .c, mode: CFScaleMode = .major) {
        self.tonic = tonic
        self.mode = mode
    }
}

public struct CFChord: Codable, Equatable, Hashable {
    public var root: CFNote
    public var quality: CFChordQuality
    public var add7: Bool
    public var add9: Bool
    public var add11: Bool
    public var add13: Bool

    public init(root: CFNote, quality: CFChordQuality, add7: Bool = false, add9: Bool = false, add11: Bool = false, add13: Bool = false) {
        self.root = root
        self.quality = quality
        self.add7 = add7
        self.add9 = add9
        self.add11 = add11
        self.add13 = add13
    }

    public func symbol() -> String {
        let q = switch quality {
        case .major: ""
        case .minor: "m"
        case .diminished: "dim"
        case .dominant: "7"
        }
        // Show the highest extension as the chord label (e.g. Cmaj13 implies 7, 9, 11)
        let ext: String
        if add13 {
            ext = (quality != .dominant ? "13" : "13")
        } else if add11 {
            ext = (quality != .dominant ? "11" : "11")
        } else if add9 {
            ext = (add7 && quality != .dominant ? "9" : "9")
        } else if add7 && quality != .dominant {
            ext = "7"
        } else {
            ext = ""
        }
        return "\(root.display())\(q)\(ext)"
    }
}

public struct CFSuggestion: Codable, Equatable {
    public var chord: CFChord
    public var confidence: Double
    public var why: String
}

public struct CFSequenceBlock: Codable, Equatable, Identifiable {
    public var id: UUID
    public var barStart: Int
    public var beatStart: Double
    public var lengthBeats: Double
    public var chord: CFChord
    public var pattern: CFPattern
    public var octaveShift: Int

    public init(
        id: UUID = UUID(),
        barStart: Int,
        beatStart: Double,
        lengthBeats: Double,
        chord: CFChord,
        pattern: CFPattern = .block,
        octaveShift: Int = 0
    ) {
        self.id = id
        self.barStart = barStart
        self.beatStart = beatStart
        self.lengthBeats = lengthBeats
        self.chord = chord
        self.pattern = pattern
        self.octaveShift = min(max(octaveShift, -3), 3)
    }
}

public struct CFMIDIEvent: Equatable {
    public var startTick: Int
    public var durationTicks: Int
    public var status: UInt8
    public var data1: UInt8
    public var data2: UInt8
}

public struct CFChordButton: Equatable, Identifiable {
    public var id: String { label + chord.root.display() }
    public var chord: CFChord
    public var label: String       // Roman numeral, e.g. "I", "ii", "bVII"
    public var isBorrowed: Bool

    public init(chord: CFChord, label: String, isBorrowed: Bool = false) {
        self.chord = chord
        self.label = label
        self.isBorrowed = isBorrowed
    }
}

public struct CFProjectDocument: Codable, Equatable {
    public var schemaVersion: Int
    public var tempo: Double
    public var key: CFKeyContext
    public var blocks: [CFSequenceBlock]

    public init(schemaVersion: Int = 1, tempo: Double = 120, key: CFKeyContext = CFKeyContext(), blocks: [CFSequenceBlock] = []) {
        self.schemaVersion = schemaVersion
        self.tempo = tempo
        self.key = key
        self.blocks = blocks
    }
}

// MARK: - Saved Project Metadata

public struct CFSavedProject: Identifiable, Equatable {
    public var id: String { fileName }
    public var fileName: String
    public var date: Date
    public var key: String
    public var blockCount: Int

    public init(fileName: String, date: Date, key: String, blockCount: Int) {
        self.fileName = fileName
        self.date = date
        self.key = key
        self.blockCount = blockCount
    }
}

// MARK: - Shared App Group Container

public enum CFAppGroup {
    public static let identifier = "group.com.n14395.chordflow2"

    /// The shared container directory for saving/loading projects.
    /// When the App Group is registered and provisioned, both the main app and AUv3
    /// extension see the same directory. Falls back to the app's documents directory
    /// if the App Group container is unavailable.
    public static var projectsURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
            ?? URL.documentsDirectory
    }
}
