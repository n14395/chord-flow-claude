#if canImport(SwiftUI)
import SwiftUI

/// Protocol that unifies `AppViewModel` and `AUv3ViewModel` so that shared views
/// (CircleOfFifthsView, TimelineView, PlaybackBarView, ChordDetailPanel, etc.)
/// can work with either ViewModel without duplicating code.
@MainActor
public protocol ChordFlowViewModel: ObservableObject {
    // MARK: - Blocks & Key

    var blocks: [CFSequenceBlock] { get }
    var key: CFKeyContext { get }

    /// Set the tonic note (e.g. from outer ring tap). Implementations should also
    /// refresh chord buttons and suggestions.
    func setTonic(_ note: CFNote)

    /// Set the scale mode. Implementations should also refresh chord buttons and suggestions.
    func setScaleMode(_ mode: CFScaleMode)

    // MARK: - Chord Buttons & Suggestions

    var chordButtons: [CFChordButton] { get }
    var suggestions: [CFSuggestion] { get }
    func refreshChordButtons()
    func refreshSuggestions()

    // MARK: - Selection & UI State

    var selectedBlockIndex: Int? { get set }
    var showModeSheet: Bool { get set }
    var defaultOctave: Int { get set }
    var borrowedPreset: CFBorrowedChordPreset { get set }

    // MARK: - Playback State

    var isPlaying: Bool { get }
    var playbackProgress: Double { get }
    var totalBeats: Int { get }
    var barCount: Int { get }
    var currentBar: Int { get }

    /// Toggle playback on/off. In AUv3 this may be a no-op (host-controlled).
    func togglePlayback()

    // MARK: - Tension

    /// The current tension level as a Double (0...1).
    var tensionValue: Double { get }

    /// Set tension. Implementations should refresh chord buttons and suggestions.
    func setTensionValue(_ value: Double)

    // MARK: - Chord Progression Mutations

    func addChord(_ chord: CFChord)
    func removeBlock(at index: Int)
    func moveBlock(from source: Int, to destination: Int)
    func duplicateBlock(at index: Int)
    func updateBlockPattern(_ pattern: CFPattern, at index: Int)
    func updateBlockLength(_ beats: Double, at index: Int)
    func updateBlockExtensions(add7: Bool, add9: Bool, add11: Bool, add13: Bool, at index: Int)
    func updateBlockOctave(_ shift: Int, at index: Int)

    // MARK: - Preview / Audition

    func previewChord(_ chord: CFChord)
    func previewBlock(_ block: CFSequenceBlock)

    // MARK: - Harmonic Analysis

    func harmonicFunction(for button: CFChordButton) -> HarmonicFunction
    func harmonicFunction(forBlockAt index: Int) -> HarmonicFunction
    func romanNumeral(for chord: CFChord) -> String

    // MARK: - Static Helpers (provided via default implementations)

    static func chordTones(_ chord: CFChord) -> [UInt8]
    static func noteNames(for chord: CFChord) -> [String]
    static func reasonPills(for suggestion: CFSuggestion, key: CFKeyContext, previous: CFChord?) -> [String]
}

// MARK: - Default Implementations

public extension ChordFlowViewModel {
    static func chordTones(_ chord: CFChord) -> [UInt8] {
        let root = chord.root.rawValue
        var intervals: [Int] = switch chord.quality {
        case .major: [0, 4, 7]
        case .minor: [0, 3, 7]
        case .diminished: [0, 3, 6]
        case .dominant: [0, 4, 7, 10]
        }
        if chord.add7, !intervals.contains(10) { intervals.append(10) }
        if chord.add9 { intervals.append(14) }
        if chord.add11 { intervals.append(17) }
        if chord.add13 { intervals.append(21) }
        return intervals.map { UInt8(min(127, root + $0 + 60)) }
    }

    static func noteNames(for chord: CFChord) -> [String] {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        return chordTones(chord).map { names[Int($0) % 12] }
    }

    static func reasonPills(for suggestion: CFSuggestion, key: CFKeyContext, previous: CFChord?) -> [String] {
        var pills: [String] = []
        let chord = suggestion.chord
        if chord.root == key.tonic { pills.append("Strong resolution") }
        if let prev = previous {
            let dist = min(abs(chord.root.rawValue - prev.root.rawValue),
                           12 - abs(chord.root.rawValue - prev.root.rawValue))
            if dist <= 2 { pills.append("Smooth voice leading") }
            if dist == 5 || dist == 7 { pills.append("Circle-of-fifths motion") }
        }
        if chord.add13 { pills.append("Rich thirteenth") }
        else if chord.add11 { pills.append("Eleventh color") }
        else if chord.add9 { pills.append("Extended color") }
        else if chord.add7 { pills.append("Seventh color") }
        if suggestion.confidence > 0.8 { pills.append("Top resolution") }
        else if suggestion.confidence > 0.6 { pills.append("Voice leading") }
        if pills.isEmpty { pills.append("Harmonic variety") }
        return Array(pills.prefix(3))
    }
}
#endif
