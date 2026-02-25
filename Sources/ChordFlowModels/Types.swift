import Foundation

public enum AccidentalPreference: String, Codable, CaseIterable, Sendable {
    case sharps
    case flats
}

public enum NoteName: Int, Codable, CaseIterable, Sendable {
    case c = 0, cSharp = 1, d = 2, dSharp = 3, e = 4, f = 5, fSharp = 6, g = 7, gSharp = 8, a = 9, aSharp = 10, b = 11

    public var midiClass: Int { rawValue }

    public func display(preference: AccidentalPreference) -> String {
        switch (self, preference) {
        case (.c, _): return "C"
        case (.cSharp, .sharps): return "C#"
        case (.cSharp, .flats): return "Db"
        case (.d, _): return "D"
        case (.dSharp, .sharps): return "D#"
        case (.dSharp, .flats): return "Eb"
        case (.e, _): return "E"
        case (.f, _): return "F"
        case (.fSharp, .sharps): return "F#"
        case (.fSharp, .flats): return "Gb"
        case (.g, _): return "G"
        case (.gSharp, .sharps): return "G#"
        case (.gSharp, .flats): return "Ab"
        case (.a, _): return "A"
        case (.aSharp, .sharps): return "A#"
        case (.aSharp, .flats): return "Bb"
        case (.b, _): return "B"
        }
    }

    public func transposed(semitones: Int) -> NoteName {
        let next = (rawValue + semitones % 12 + 12) % 12
        return NoteName(rawValue: next) ?? .c
    }
}

public enum ScaleMode: String, Codable, CaseIterable, Sendable {
    case major
    case minor
    case dorian
    case mixolydian
}

public enum ChordQuality: String, Codable, CaseIterable, Sendable {
    case major
    case minor
    case diminished
    case augmented
    case dominant
    case suspended2
    case suspended4
}

public enum ChordExtension: Int, Codable, CaseIterable, Comparable, Sendable {
    case seventh = 7
    case ninth = 9
    case eleventh = 11
    case thirteenth = 13

    public static func < (lhs: ChordExtension, rhs: ChordExtension) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum ChordAlteration: String, Codable, CaseIterable, Sendable {
    case flatFifth
    case sharpFifth
    case flatNinth
    case sharpNinth
}

public struct KeyContext: Codable, Sendable, Equatable {
    public var tonic: NoteName
    public var mode: ScaleMode
    public var accidentalPreference: AccidentalPreference

    public init(tonic: NoteName, mode: ScaleMode, accidentalPreference: AccidentalPreference = .sharps) {
        self.tonic = tonic
        self.mode = mode
        self.accidentalPreference = accidentalPreference
    }
}

public struct ChordToken: Codable, Sendable, Equatable, Hashable {
    public var root: NoteName
    public var quality: ChordQuality
    public var extensions: [ChordExtension]
    public var alterations: [ChordAlteration]
    public var inversion: Int
    public var slashBass: NoteName?

    public init(
        root: NoteName,
        quality: ChordQuality,
        extensions: [ChordExtension] = [],
        alterations: [ChordAlteration] = [],
        inversion: Int = 0,
        slashBass: NoteName? = nil
    ) {
        self.root = root
        self.quality = quality
        self.extensions = extensions.sorted()
        self.alterations = alterations
        self.inversion = max(0, inversion)
        self.slashBass = slashBass
    }

    public func symbol(preference: AccidentalPreference) -> String {
        let rootText = root.display(preference: preference)
        let qualityText: String = switch quality {
        case .major: ""
        case .minor: "m"
        case .diminished: "dim"
        case .augmented: "aug"
        case .dominant: "7"
        case .suspended2: "sus2"
        case .suspended4: "sus4"
        }
        let extText = extensions
            .map { String($0.rawValue) }
            .joined(separator: "")
        let slash = slashBass.map { "/\($0.display(preference: preference))" } ?? ""
        return "\(rootText)\(qualityText)\(extText)\(slash)"
    }
}

public enum StyleProfile: String, Codable, CaseIterable, Sendable {
    case pop
    case jazz
    case neoSoul
}

public struct SuggestionRequest: Codable, Sendable, Equatable {
    public var keyContext: KeyContext
    public var previousChord: ChordToken?
    public var melodyHint: NoteName?
    public var tensionLevel: Double
    public var styleProfile: StyleProfile

    public init(
        keyContext: KeyContext,
        previousChord: ChordToken? = nil,
        melodyHint: NoteName? = nil,
        tensionLevel: Double = 0.35,
        styleProfile: StyleProfile = .pop
    ) {
        self.keyContext = keyContext
        self.previousChord = previousChord
        self.melodyHint = melodyHint
        self.tensionLevel = min(max(tensionLevel, 0), 1)
        self.styleProfile = styleProfile
    }
}

public struct SuggestionResult: Codable, Sendable, Equatable {
    public var chordToken: ChordToken
    public var confidence: Double
    public var reasons: [String]

    public init(chordToken: ChordToken, confidence: Double, reasons: [String]) {
        self.chordToken = chordToken
        self.confidence = min(max(confidence, 0), 1)
        self.reasons = reasons
    }
}

public enum PatternPreset: String, Codable, CaseIterable, Sendable {
    case block
    case arpUp
    case arpDown
    case strum
}

public struct VelocityProfile: Codable, Sendable, Equatable {
    public var base: UInt8
    public var variation: UInt8

    public init(base: UInt8 = 92, variation: UInt8 = 10) {
        self.base = min(base, 127)
        self.variation = min(variation, 64)
    }
}

public struct SequenceBlock: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var barStart: Int
    public var beatStart: Double
    public var lengthBeats: Double
    public var chordToken: ChordToken
    public var patternPreset: PatternPreset
    public var velocityProfile: VelocityProfile

    public init(
        id: UUID = UUID(),
        barStart: Int,
        beatStart: Double,
        lengthBeats: Double,
        chordToken: ChordToken,
        patternPreset: PatternPreset = .block,
        velocityProfile: VelocityProfile = VelocityProfile()
    ) {
        self.id = id
        self.barStart = max(0, barStart)
        self.beatStart = max(0, beatStart)
        self.lengthBeats = max(0.25, lengthBeats)
        self.chordToken = chordToken
        self.patternPreset = patternPreset
        self.velocityProfile = velocityProfile
    }
}

public enum OutputMode: String, Codable, CaseIterable, Sendable {
    case auv3
    case virtualMIDI
    case both
}

public enum ClockMode: String, Codable, CaseIterable, Sendable {
    case hostDriven
    case internalTransport
}

public struct RoutingConfig: Codable, Sendable, Equatable {
    public var outputMode: OutputMode
    public var midiChannelMap: [Int: Int]
    public var clockMode: ClockMode

    public init(
        outputMode: OutputMode = .virtualMIDI,
        midiChannelMap: [Int: Int] = [0: 0],
        clockMode: ClockMode = .internalTransport
    ) {
        self.outputMode = outputMode
        self.midiChannelMap = midiChannelMap
        self.clockMode = clockMode
    }
}

public struct TimeSignature: Codable, Sendable, Equatable {
    public var numerator: Int
    public var denominator: Int

    public init(numerator: Int = 4, denominator: Int = 4) {
        self.numerator = max(1, numerator)
        self.denominator = [2, 4, 8, 16].contains(denominator) ? denominator : 4
    }
}

public struct ProjectDocument: Codable, Sendable, Equatable {
    public var schemaVersion: Int
    public var tempo: Double
    public var timeSignature: TimeSignature
    public var keyContext: KeyContext
    public var blocks: [SequenceBlock]
    public var routingConfig: RoutingConfig

    public init(
        schemaVersion: Int = 1,
        tempo: Double = 120,
        timeSignature: TimeSignature = TimeSignature(),
        keyContext: KeyContext,
        blocks: [SequenceBlock] = [],
        routingConfig: RoutingConfig = RoutingConfig()
    ) {
        self.schemaVersion = schemaVersion
        self.tempo = min(max(tempo, 20), 300)
        self.timeSignature = timeSignature
        self.keyContext = keyContext
        self.blocks = blocks
        self.routingConfig = routingConfig
    }
}

public struct MIDINoteEvent: Codable, Sendable, Equatable {
    public var note: UInt8
    public var velocity: UInt8
    public var startTick: Int
    public var durationTicks: Int
    public var channel: UInt8

    public init(note: UInt8, velocity: UInt8, startTick: Int, durationTicks: Int, channel: UInt8 = 0) {
        self.note = min(note, 127)
        self.velocity = min(velocity, 127)
        self.startTick = max(0, startTick)
        self.durationTicks = max(1, durationTicks)
        self.channel = min(channel, 15)
    }
}
