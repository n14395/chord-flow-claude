import SwiftUI
import UIKit
import AudioToolbox
import ChordFlowShared

// MARK: - ViewModel

@MainActor
final class AUv3ViewModel: ObservableObject, ChordFlowViewModel {
    let audioUnit: ChordFlowMIDIProcessorAudioUnit
    private var parameterObservation: AUParameterObserverToken?
    private var debugTimer: Timer?

    // MARK: AU Parameters (synced with host)

    @Published var tonic: Float = 0
    @Published var mode: Float = 0
    @Published var tension: Float = 0.35
    @Published var pattern: Float = 0
    @Published var swing: Float = 0.1
    @Published var humanize: Float = 0.1

    // MARK: Progression State (managed locally in the AUv3 UI)

    @Published var blocks: [CFSequenceBlock] = []
    @Published var chordButtons: [CFChordButton] = []
    @Published var suggestions: [CFSuggestion] = []
    @Published var selectedBlockIndex: Int?
    @Published var defaultOctave: Int = 0
    @Published var borrowedPreset: CFBorrowedChordPreset = .jazz
    @Published var showModeSheet = false
    @Published var selectedTab: Int = 0
    @Published var styleFilter: String = "All"

    // MARK: Debug / Transport State

    @Published var debugInfo: String = "waiting..."
    @Published var isPlaying: Bool = false
    @Published var playbackProgress: Double = 0

    // MARK: Lookup Data

    private let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    private let modeList = CFScaleMode.allCases
    private let patternList = CFPattern.allCases
    let styleFilters = ["All", "Pop", "Jazz", "Neo-Soul", "Cinematic", "Exp."]

    init(audioUnit: ChordFlowMIDIProcessorAudioUnit) {
        self.audioUnit = audioUnit
        readAllParameters()
        refreshChordButtons()
        refreshSuggestions()

        parameterObservation = audioUnit.parameterTree?.token(byAddingParameterObserver: { [weak self] address, value in
            DispatchQueue.main.async {
                self?.handleExternalParameterChange(address: address, value: value)
            }
        })

        // Poll debug/transport state from the AU
        debugTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 15.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.isPlaying = self.audioUnit.debugIsPlaying
            self.playbackProgress = self.computePlaybackProgress()
            self.debugInfo = "renders=\(self.audioUnit.debugRenderCount) beat=\(String(format: "%.1f", self.audioUnit.debugBeatPosition)) playing=\(self.audioUnit.debugIsPlaying) midi=\(self.audioUnit.debugHasMidiOut) chords=\(self.audioUnit.debugChordCount)"
        }
    }

    deinit {
        debugTimer?.invalidate()
        if let token = parameterObservation {
            audioUnit.parameterTree?.removeParameterObserver(token)
        }
    }

    // MARK: - Computed Properties

    var tonicNote: CFNote {
        CFNote(rawValue: Int(tonic.rounded()) % 12) ?? .c
    }

    var scaleMode: CFScaleMode {
        let idx = Int(mode.rounded())
        return idx < modeList.count ? modeList[idx] : .major
    }

    var key: CFKeyContext {
        CFKeyContext(tonic: tonicNote, mode: scaleMode)
    }

    var tonicName: String { noteNames[Int(tonic.rounded()) % 12] }

    var modeName: String { scaleMode.displayName() }

    var keyDisplayName: String { "\(tonicName) \(modeName)" }

    var patternName: String {
        let idx = Int(pattern.rounded())
        return idx < patternList.count ? patternList[idx].rawValue : "?"
    }

    var modeCount: Float { Float(modeList.count - 1) }

    var tensionLevel: Double { Double(tension) }

    var totalBeats: Int {
        blocks.reduce(0) { $0 + Int($1.lengthBeats) }
    }

    var barCount: Int { blocks.count }

    var currentBar: Int {
        guard totalBeats > 0 else { return 1 }
        let currentBeat = playbackProgress * Double(totalBeats)
        var accumulated: Double = 0
        for (i, block) in blocks.enumerated() {
            accumulated += block.lengthBeats
            if currentBeat < accumulated { return i + 1 }
        }
        return barCount
    }

    // MARK: - ChordFlowViewModel Bridging

    var tensionValue: Double { Double(tension) }

    func setTensionValue(_ value: Double) {
        setTension(Float(value))
    }

    func setTonic(_ note: CFNote) {
        setTonic(Float(note.rawValue))
    }

    func setScaleMode(_ newMode: CFScaleMode) {
        guard let idx = CFScaleMode.allCases.firstIndex(of: newMode) else { return }
        setMode(Float(idx))
    }

    func togglePlayback() {
        // Host-controlled — no-op in AUv3
    }

    // MARK: - Read AU Parameters

    private func readAllParameters() {
        tonic = audioUnit.tonicParameter.value
        mode = audioUnit.modeParameter.value
        tension = audioUnit.tensionParameter.value
        pattern = audioUnit.patternParameter.value
        swing = audioUnit.swingParameter.value
        humanize = audioUnit.humanizeParameter.value
    }

    private func handleExternalParameterChange(address: AUParameterAddress, value: AUValue) {
        switch address {
        case 0: tonic = value
        case 1: mode = value
        case 2: tension = value
        case 3: pattern = value
        case 4: swing = value
        case 5: humanize = value
        default: break
        }
        // Key or tension changed externally — rebuild chord buttons + suggestions
        if address <= 2 {
            refreshChordButtons()
            refreshSuggestions()
        }
    }

    // MARK: - Write AU Parameters

    func setTonic(_ value: Float) {
        tonic = value
        audioUnit.tonicParameter.value = value
        refreshChordButtons()
        refreshSuggestions()
        syncProgressionToAU()
    }

    func setMode(_ value: Float) {
        mode = value
        audioUnit.modeParameter.value = value
        refreshChordButtons()
        refreshSuggestions()
        syncProgressionToAU()
    }

    func setTension(_ value: Float) {
        tension = value
        audioUnit.tensionParameter.value = value
        refreshChordButtons()
        refreshSuggestions()
        syncProgressionToAU()
    }

    func setPattern(_ value: Float) {
        pattern = value
        audioUnit.patternParameter.value = value
    }

    func setSwing(_ value: Float) {
        swing = value
        audioUnit.swingParameter.value = value
    }

    func setHumanize(_ value: Float) {
        humanize = value
        audioUnit.humanizeParameter.value = value
    }

    // MARK: - Chord Button Management

    func refreshChordButtons() {
        chordButtons = ChordFlowEngine.diatonicChords(
            key: key,
            tension: tensionLevel,
            borrowedPreset: borrowedPreset
        )
    }

    // MARK: - Suggestion Management

    func refreshSuggestions() {
        let previous = blocks.last?.chord
        suggestions = ChordFlowEngine.suggestions(
            key: key,
            previous: previous,
            tension: tensionLevel
        )
    }

    // MARK: - Preview

    func previewChord(_ chord: CFChord) {
        let notes = Self.chordTones(chord)
        audioUnit.sendPreviewNotes(notes)
    }

    func previewBlock(_ block: CFSequenceBlock) {
        let notes = Self.chordTones(block.chord)
        audioUnit.sendPreviewNotes(notes)
    }

    // MARK: - Chord Progression Management

    func addChord(_ chord: CFChord) {
        let block = CFSequenceBlock(
            barStart: blocks.count,
            beatStart: 0,
            lengthBeats: 4,
            chord: chord,
            pattern: .block,
            octaveShift: defaultOctave
        )
        blocks.append(block)
        selectedBlockIndex = blocks.count - 1
        refreshSuggestions()
        syncProgressionToAU()
    }

    func removeBlock(at index: Int) {
        guard blocks.indices.contains(index) else { return }
        blocks.remove(at: index)
        for i in blocks.indices {
            blocks[i].barStart = i
        }
        if selectedBlockIndex == index { selectedBlockIndex = nil }
        refreshSuggestions()
        syncProgressionToAU()
    }

    func moveBlock(from source: Int, to destination: Int) {
        guard source != destination,
              blocks.indices.contains(source),
              blocks.indices.contains(destination) else { return }
        let block = blocks.remove(at: source)
        blocks.insert(block, at: destination)
        for i in blocks.indices {
            blocks[i].barStart = i
        }
        if selectedBlockIndex == source {
            selectedBlockIndex = destination
        } else if let sel = selectedBlockIndex {
            if source < destination, sel > source, sel <= destination {
                selectedBlockIndex = sel - 1
            } else if source > destination, sel >= destination, sel < source {
                selectedBlockIndex = sel + 1
            }
        }
        syncProgressionToAU()
    }

    func clearProgression() {
        blocks.removeAll()
        selectedBlockIndex = nil
        refreshSuggestions()
        syncProgressionToAU()
    }

    func duplicateBlock(at index: Int) {
        guard blocks.indices.contains(index) else { return }
        var copy = blocks[index]
        copy.id = UUID()
        copy.barStart = blocks.count
        blocks.append(copy)
        refreshSuggestions()
        syncProgressionToAU()
    }

    func updateBlockPattern(_ pattern: CFPattern, at index: Int) {
        guard blocks.indices.contains(index) else { return }
        blocks[index].pattern = pattern
        syncProgressionToAU()
    }

    func updateBlockLength(_ beats: Double, at index: Int) {
        guard blocks.indices.contains(index) else { return }
        blocks[index].lengthBeats = beats
        syncProgressionToAU()
    }

    func updateBlockExtensions(add7: Bool, add9: Bool, add11: Bool = false, add13: Bool = false, at index: Int) {
        guard blocks.indices.contains(index) else { return }
        blocks[index].chord.add7 = add7
        blocks[index].chord.add9 = add9
        blocks[index].chord.add11 = add11
        blocks[index].chord.add13 = add13
        syncProgressionToAU()
    }

    func updateBlockOctave(_ shift: Int, at index: Int) {
        guard blocks.indices.contains(index) else { return }
        blocks[index].octaveShift = min(max(shift, -3), 3)
        syncProgressionToAU()
    }

    // MARK: - Style Filtering

    func applyStyleFilter(_ filter: String) {
        styleFilter = filter
        switch filter {
        case "Jazz": borrowedPreset = .jazz
        case "Cinematic": borrowedPreset = .cinematic
        case "Pop": borrowedPreset = .conservative
        case "Neo-Soul": borrowedPreset = .colorful
        case "Exp.": borrowedPreset = .experimental
        default: break
        }
        refreshChordButtons()
        refreshSuggestions()
    }

    // MARK: - Harmonic Function Resolution

    func harmonicFunction(for button: CFChordButton) -> HarmonicFunction {
        if button.isBorrowed { return .borrowed }
        let diatonic = chordButtons.filter { !$0.isBorrowed }
        guard let index = diatonic.firstIndex(where: { $0.id == button.id }) else { return .tonic }
        return HarmonicFunction.forDegree(index)
    }

    func harmonicFunction(forBlockAt index: Int) -> HarmonicFunction {
        guard blocks.indices.contains(index) else { return .tonic }
        let chord = blocks[index].chord
        if let btn = chordButtons.first(where: { $0.chord == chord }) {
            return harmonicFunction(for: btn)
        }
        if chordButtons.filter({ $0.isBorrowed }).contains(where: { $0.chord.root == chord.root && $0.chord.quality == chord.quality }) {
            return .borrowed
        }
        return .tonic
    }

    func romanNumeral(for chord: CFChord) -> String {
        if let btn = chordButtons.first(where: { $0.chord == chord }) {
            return btn.label
        }
        return "?"
    }

    func suggestionFunction(_ suggestion: CFSuggestion) -> HarmonicFunction {
        if let btn = chordButtons.first(where: { $0.chord.root == suggestion.chord.root && $0.chord.quality == suggestion.chord.quality }) {
            return harmonicFunction(for: btn)
        }
        return .tonic
    }

    // MARK: - Chord Tone Helpers

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
        return intervals.map { UInt8(root + $0 + 60) }
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

    // MARK: - AU Sync

    /// Push the current progression to the audio unit for render-thread playback.
    func syncProgressionToAU() {
        // Build the sequenced chord tones for the render block
        var chordTonesList: [[UInt8]] = []
        var beatLengths: [Double] = []
        for block in blocks {
            chordTonesList.append(Self.chordTones(block.chord))
            beatLengths.append(block.lengthBeats)
        }
        audioUnit.updateProgression(chords: chordTonesList, beatLengths: beatLengths)
    }

    private func computePlaybackProgress() -> Double {
        guard totalBeats > 0 else { return 0 }
        let beatPos = audioUnit.debugBeatPosition
        guard beatPos >= 0 else { return 0 }
        let totalBeatsDbl = Double(totalBeats)
        let progress = beatPos.truncatingRemainder(dividingBy: totalBeatsDbl) / totalBeatsDbl
        return max(0, min(1, progress))
    }
}
