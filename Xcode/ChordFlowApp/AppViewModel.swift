import SwiftUI
import Combine
import ChordFlowShared

@MainActor
final class AppViewModel: ObservableObject {

    // MARK: - Published State

    @Published var project = CFProjectDocument()
    @Published var chordButtons: [CFChordButton] = []
    @Published var tension: Double = 0.6
    @Published var borrowedPreset: CFBorrowedChordPreset = .jazz
    @Published var swing: Double = 0.2
    @Published var isPlaying = false
    @Published var isPreviewing = false
    @Published var playbackProgress: Double = 0
    @Published var status = "Ready"
    @Published var selectedBlockIndex: Int?
    @Published var suggestions: [CFSuggestion] = []
    @Published var showModeSheet = false

    // MARK: - Private

    private let playbackEngine = ProgressionPlaybackEngine()
    private let previewEngine = ProgressionPlaybackEngine()
    private var progressTimer: AnyCancellable?

    // MARK: - Init

    init() {
        playbackEngine.onPlaybackStateChange = { [weak self] playing in
            guard let self else { return }
            self.isPlaying = playing
            if playing {
                self.startProgressTimer()
            } else {
                self.stopProgressTimer()
                self.status = "Ready"
            }
        }
        previewEngine.onPlaybackStateChange = { [weak self] playing in
            self?.isPreviewing = playing
        }
        refreshChordButtons()
        refreshSuggestions()
    }

    // MARK: - Progress Timer

    private func startProgressTimer() {
        playbackProgress = 0
        progressTimer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.playbackProgress = self.playbackEngine.progress
            }
    }

    private func stopProgressTimer() {
        progressTimer?.cancel()
        progressTimer = nil
        playbackProgress = 0
    }

    // MARK: - Chord Management

    func refreshChordButtons() {
        chordButtons = ChordFlowEngine.diatonicChords(
            key: project.key,
            tension: tension,
            borrowedPreset: borrowedPreset
        )
    }

    func addChord(_ chord: CFChord) {
        let block = CFSequenceBlock(
            barStart: project.blocks.count,
            beatStart: 0,
            lengthBeats: 4,
            chord: chord,
            pattern: .block
        )
        project.blocks.append(block)
        refreshSuggestions()
    }

    func removeBlock(at index: Int) {
        guard project.blocks.indices.contains(index) else { return }
        project.blocks.remove(at: index)
        for i in project.blocks.indices {
            project.blocks[i].barStart = i
        }
        if selectedBlockIndex == index { selectedBlockIndex = nil }
        refreshSuggestions()
    }

    func clearProgression() {
        project.blocks.removeAll()
        selectedBlockIndex = nil
        refreshSuggestions()
    }

    func duplicateBlock(at index: Int) {
        guard project.blocks.indices.contains(index) else { return }
        var copy = project.blocks[index]
        copy.id = UUID()
        copy.barStart = project.blocks.count
        project.blocks.append(copy)
        refreshSuggestions()
    }

    func updateBlockPattern(_ pattern: CFPattern, at index: Int) {
        guard project.blocks.indices.contains(index) else { return }
        project.blocks[index].pattern = pattern
    }

    func updateBlockLength(_ beats: Double, at index: Int) {
        guard project.blocks.indices.contains(index) else { return }
        project.blocks[index].lengthBeats = beats
    }

    func updateBlockExtensions(add7: Bool, add9: Bool, at index: Int) {
        guard project.blocks.indices.contains(index) else { return }
        project.blocks[index].chord.add7 = add7
        project.blocks[index].chord.add9 = add9
    }

    // MARK: - Suggestions

    func refreshSuggestions() {
        let previous = project.blocks.last?.chord
        suggestions = ChordFlowEngine.suggestions(
            key: project.key,
            previous: previous,
            tension: tension
        )
    }

    // MARK: - Playback

    func previewChord(_ chord: CFChord) {
        let block = CFSequenceBlock(
            barStart: 0, beatStart: 0, lengthBeats: 2,
            chord: chord, pattern: .block
        )
        let events = ChordFlowEngine.render(blocks: [block], swing: 0)
        previewEngine.play(events: events, tempo: project.tempo)
    }

    func togglePlayback() {
        if isPlaying {
            playbackEngine.stop()
            status = "Ready"
            return
        }
        guard !project.blocks.isEmpty else {
            status = "Add chords to play"
            return
        }
        let events = ChordFlowEngine.render(blocks: project.blocks, swing: swing)
        playbackEngine.play(events: events, tempo: project.tempo)
        status = "Playing \(project.blocks.count) chord(s) at \(Int(project.tempo.rounded())) BPM"
    }

    // MARK: - Export

    func exportMIDI() {
        let events = ChordFlowEngine.render(blocks: project.blocks, swing: swing)
        let data = MIDIFileWriter.export(events: events)
        let url = URL.documentsDirectory.appending(path: "ChordFlow-Export.mid")
        do {
            try data.write(to: url)
            status = "Exported: \(url.lastPathComponent)"
        } catch {
            status = "Export failed: \(error.localizedDescription)"
        }
    }

    func exportProject() {
        let url = URL.documentsDirectory.appending(path: "ChordFlow-Project.json")
        do {
            try ChordFlowEngine.encodeProject(project).write(to: url)
            status = "Exported: \(url.lastPathComponent)"
        } catch {
            status = "Export failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Computed Helpers

    var totalBeats: Int {
        project.blocks.reduce(0) { $0 + Int($1.lengthBeats) }
    }

    var barCount: Int {
        project.blocks.count
    }

    var keyDisplayName: String {
        "\(project.key.tonic.display()) \(project.key.mode.displayName())"
    }

    var currentBar: Int {
        guard totalBeats > 0 else { return 1 }
        let currentBeat = playbackProgress * Double(totalBeats)
        var accumulated: Double = 0
        for (i, block) in project.blocks.enumerated() {
            accumulated += block.lengthBeats
            if currentBeat < accumulated { return i + 1 }
        }
        return barCount
    }

    // MARK: - Harmonic Function Resolution

    func harmonicFunction(for button: CFChordButton) -> HarmonicFunction {
        if button.isBorrowed { return .borrowed }
        let diatonic = chordButtons.filter { !$0.isBorrowed }
        guard let index = diatonic.firstIndex(where: { $0.id == button.id }) else { return .tonic }
        return HarmonicFunction.forDegree(index)
    }

    func harmonicFunction(forBlockAt index: Int) -> HarmonicFunction {
        guard project.blocks.indices.contains(index) else { return .tonic }
        let chord = project.blocks[index].chord
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
        return intervals.map { UInt8(root + $0 + 60) }
    }

    static func noteNames(for chord: CFChord) -> [String] {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        return chordTones(chord).map { names[Int($0) % 12] }
    }

    // MARK: - Suggestion Reason Pills

    static func reasonPills(for suggestion: CFSuggestion, key: CFKeyContext, previous: CFChord?) -> [String] {
        var pills: [String] = []
        let chord = suggestion.chord

        // Resolution strength
        if chord.root == key.tonic {
            pills.append("Strong resolution")
        }

        // Voice leading proximity
        if let prev = previous {
            let dist = min(abs(chord.root.rawValue - prev.root.rawValue),
                           12 - abs(chord.root.rawValue - prev.root.rawValue))
            if dist <= 2 {
                pills.append("Smooth voice leading")
            }
            if dist == 5 || dist == 7 {
                pills.append("Circle-of-fifths motion")
            }
        }

        // Extensions
        if chord.add9 {
            pills.append("Extended color")
        } else if chord.add7 {
            pills.append("Seventh color")
        }

        // Confidence
        if suggestion.confidence > 0.8 {
            pills.append("Top resolution")
        } else if suggestion.confidence > 0.6 {
            pills.append("Voice leading")
        }

        if pills.isEmpty {
            pills.append("Harmonic variety")
        }
        return Array(pills.prefix(3))
    }
}
