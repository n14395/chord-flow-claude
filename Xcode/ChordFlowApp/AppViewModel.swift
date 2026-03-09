import SwiftUI
import Combine
import ChordFlowShared

@MainActor
final class AppViewModel: ObservableObject, ChordFlowViewModel {

    // MARK: - Published State

    @Published var project = CFProjectDocument()
    @Published var chordButtons: [CFChordButton] = []
    @Published var tension: Double = 0.2
    @Published var defaultOctave: Int = 0
    @Published var borrowedPreset: CFBorrowedChordPreset = .jazz
    @Published var isPlaying = false
    @Published var isPreviewing = false
    @Published var playbackProgress: Double = 0
    @Published var status = "Ready"
    @Published var selectedBlockIndex: Int?
    @Published var suggestions: [CFSuggestion] = []
    @Published var showModeSheet = false
    @Published var midiOutputEnabled = false

    // MARK: - Private

    private let playbackEngine = ProgressionPlaybackEngine()
    private let previewEngine = ProgressionPlaybackEngine()
    private var progressTimer: AnyCancellable?
    private var autoSaveCancellable: AnyCancellable?
    let midiOutput = MIDIOutputManager()
    @Published var midiChannel: UInt8 = 0

    // MARK: - Persistence

    private static let autoSaveFileName = "ChordFlow-AutoSave.json"
    @Published var savedProjects: [SavedProject] = []

    struct SavedProject: Identifiable, Equatable {
        var id: String { fileName }
        var fileName: String
        var date: Date
        var key: String
        var blockCount: Int
    }

    private static var autoSaveURL: URL {
        URL.documentsDirectory.appending(path: autoSaveFileName)
    }

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
        loadAutoSave()
        refreshChordButtons()
        refreshSuggestions()
        refreshSavedProjects()

        // Debounced auto-save on any project change (tempo/key via bindings)
        autoSaveCancellable = $project
            .dropFirst()
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.autoSave()
            }
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

    // MARK: - ChordFlowViewModel Bridging

    var blocks: [CFSequenceBlock] {
        get { project.blocks }
        set { project.blocks = newValue }
    }

    var key: CFKeyContext { project.key }

    var tensionValue: Double { tension }

    func setTensionValue(_ value: Double) {
        tension = value
        refreshChordButtons()
        refreshSuggestions()
    }

    func setTonic(_ note: CFNote) {
        project.key = CFKeyContext(tonic: note, mode: project.key.mode)
        refreshChordButtons()
        refreshSuggestions()
    }

    func setScaleMode(_ mode: CFScaleMode) {
        project.key = CFKeyContext(tonic: project.key.tonic, mode: mode)
        refreshChordButtons()
        refreshSuggestions()
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
            pattern: .block,
            octaveShift: defaultOctave
        )
        project.blocks.append(block)
        selectedBlockIndex = project.blocks.count - 1
        refreshSuggestions()
        autoSave()
    }

    func removeBlock(at index: Int) {
        guard project.blocks.indices.contains(index) else { return }
        project.blocks.remove(at: index)
        for i in project.blocks.indices {
            project.blocks[i].barStart = i
        }
        if selectedBlockIndex == index { selectedBlockIndex = nil }
        refreshSuggestions()
        autoSave()
    }

    func moveBlock(from source: Int, to destination: Int) {
        guard source != destination,
              project.blocks.indices.contains(source),
              project.blocks.indices.contains(destination) else { return }
        let block = project.blocks.remove(at: source)
        project.blocks.insert(block, at: destination)
        for i in project.blocks.indices {
            project.blocks[i].barStart = i
        }
        // Keep selection tracking the moved block
        if selectedBlockIndex == source {
            selectedBlockIndex = destination
        } else if let sel = selectedBlockIndex {
            if source < destination, sel > source, sel <= destination {
                selectedBlockIndex = sel - 1
            } else if source > destination, sel >= destination, sel < source {
                selectedBlockIndex = sel + 1
            }
        }
        autoSave()
    }

    func clearProgression() {
        project.blocks.removeAll()
        selectedBlockIndex = nil
        refreshSuggestions()
        autoSave()
    }

    func duplicateBlock(at index: Int) {
        guard project.blocks.indices.contains(index) else { return }
        var copy = project.blocks[index]
        copy.id = UUID()
        copy.barStart = project.blocks.count
        project.blocks.append(copy)
        refreshSuggestions()
        autoSave()
    }

    func updateBlockPattern(_ pattern: CFPattern, at index: Int) {
        guard project.blocks.indices.contains(index) else { return }
        project.blocks[index].pattern = pattern
        autoSave()
    }

    func updateBlockLength(_ beats: Double, at index: Int) {
        guard project.blocks.indices.contains(index) else { return }
        project.blocks[index].lengthBeats = beats
        autoSave()
    }

    func updateBlockExtensions(add7: Bool, add9: Bool, add11: Bool = false, add13: Bool = false, at index: Int) {
        guard project.blocks.indices.contains(index) else { return }
        project.blocks[index].chord.add7 = add7
        project.blocks[index].chord.add9 = add9
        project.blocks[index].chord.add11 = add11
        project.blocks[index].chord.add13 = add13
        autoSave()
    }

    func updateBlockOctave(_ shift: Int, at index: Int) {
        guard project.blocks.indices.contains(index) else { return }
        project.blocks[index].octaveShift = min(max(shift, -3), 3)
        autoSave()
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
            chord: chord, pattern: .block,
            octaveShift: defaultOctave
        )
        let events = ChordFlowEngine.render(blocks: [block], swing: 0)
        if midiOutputEnabled {
            scheduleMIDIEvents(events, tempo: project.tempo)
        } else {
            previewEngine.play(events: events, tempo: project.tempo)
        }
    }

    func previewBlock(_ block: CFSequenceBlock) {
        var preview = block
        preview.barStart = 0
        preview.beatStart = 0
        let events = ChordFlowEngine.render(blocks: [preview], swing: 0)
        if midiOutputEnabled {
            scheduleMIDIEvents(events, tempo: project.tempo)
        } else {
            previewEngine.play(events: events, tempo: project.tempo)
        }
    }

    func togglePlayback() {
        if isPlaying {
            playbackEngine.stop()
            if midiOutputEnabled {
                midiOutput.sendAllNotesOff(channel: midiChannel)
            }
            status = "Ready"
            return
        }
        guard !project.blocks.isEmpty else {
            status = "Add chords to play"
            return
        }
        let sequenced = sequencedBlocks(project.blocks)
        let events = ChordFlowEngine.render(blocks: sequenced, swing: 0)

        if midiOutputEnabled {
            // MIDI-only playback: send MIDI events, use silent playback for timeline/progress
            scheduleMIDIEvents(events, tempo: project.tempo)
            playbackEngine.playSilent(events: events, tempo: project.tempo)
        } else {
            // Built-in sine-wave playback
            playbackEngine.play(events: events, tempo: project.tempo)
        }
        status = "Playing \(project.blocks.count) chord(s) at \(Int(project.tempo.rounded())) BPM"
    }

    private var midiScheduledItems: [DispatchWorkItem] = []
    private let midiSchedulerQueue = DispatchQueue(label: "com.nwf.chordflow.midi", qos: .userInitiated)

    private func scheduleMIDIEvents(_ events: [CFMIDIEvent], tempo: Double, ppq: Int = ChordFlowEngine.ppq) {
        // Cancel any previously scheduled MIDI events
        for item in midiScheduledItems { item.cancel() }
        midiScheduledItems.removeAll()

        let secondsPerTick = 60.0 / max(1.0, tempo) / Double(max(1, ppq))
        let channel = midiChannel

        for event in events {
            let note = event.data1
            let velocity = event.data2
            let onTime = max(0, Double(event.startTick) * secondsPerTick)
            let offTime = max(0, Double(event.startTick + event.durationTicks) * secondsPerTick)

            let noteOn = DispatchWorkItem { [weak self] in
                self?.midiOutput.sendNoteOn(note: note, velocity: velocity, channel: channel)
            }
            let noteOff = DispatchWorkItem { [weak self] in
                self?.midiOutput.sendNoteOff(note: note, channel: channel)
            }
            midiScheduledItems.append(noteOn)
            midiScheduledItems.append(noteOff)
            midiSchedulerQueue.asyncAfter(deadline: .now() + onTime, execute: noteOn)
            midiSchedulerQueue.asyncAfter(deadline: .now() + offTime, execute: noteOff)
        }
    }

    // MARK: - Auto Save / Load

    private func autoSave() {
        do {
            let data = try ChordFlowEngine.encodeProject(project)
            try data.write(to: Self.autoSaveURL)
        } catch {
            // Silently ignore auto-save failures
        }
    }

    private func loadAutoSave() {
        guard FileManager.default.fileExists(atPath: Self.autoSaveURL.path) else { return }
        do {
            let data = try Data(contentsOf: Self.autoSaveURL)
            project = try ChordFlowEngine.decodeProject(data)
            if project.blocks.isEmpty {
                tension = 0.2
            } else {
                let c = project.blocks.first!.chord
                if c.add13 { tension = 0.9 }
                else if c.add11 { tension = 0.75 }
                else if c.add9 { tension = 0.6 }
                else if c.add7 { tension = 0.45 }
                else { tension = 0.2 }
            }
        } catch {
            status = "Could not restore session"
        }
    }

    static let projectExtension = "chordflow"

    func saveProjectAs(name: String) {
        let safeName = name.replacingOccurrences(of: "/", with: "-")
        let url = URL.documentsDirectory.appending(path: "\(safeName).\(Self.projectExtension)")
        do {
            let data = try ChordFlowEngine.encodeProject(project)
            try data.write(to: url)
            status = "Saved: \(safeName).\(Self.projectExtension)"
            refreshSavedProjects()
        } catch {
            status = "Save failed: \(error.localizedDescription)"
        }
    }

    /// Encode the current project for use with .fileExporter
    func encodeProjectData() -> Data? {
        try? ChordFlowEngine.encodeProject(project)
    }

    func loadProject(from url: URL) {
        do {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            project = try ChordFlowEngine.decodeProject(data)
            selectedBlockIndex = nil
            refreshChordButtons()
            refreshSuggestions()
            status = "Loaded: \(url.lastPathComponent)"
        } catch {
            status = "Load failed: \(error.localizedDescription)"
        }
    }

    func deleteProject(fileName: String) {
        let url = URL.documentsDirectory.appending(path: fileName)
        try? FileManager.default.removeItem(at: url)
        refreshSavedProjects()
    }

    private static let validProjectExtensions: Set<String> = ["chordflow", "json"]

    func refreshSavedProjects() {
        let fm = FileManager.default
        let dir = URL.documentsDirectory
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            savedProjects = []
            return
        }
        savedProjects = files
            .filter { Self.validProjectExtensions.contains($0.pathExtension) && $0.lastPathComponent != Self.autoSaveFileName }
            .compactMap { url -> SavedProject? in
                guard let attrs = try? fm.attributesOfItem(atPath: url.path),
                      let date = attrs[.modificationDate] as? Date else { return nil }
                // Try to read block count and key from the file
                var keyName = "Unknown"
                var blockCount = 0
                if let data = try? Data(contentsOf: url),
                   let doc = try? ChordFlowEngine.decodeProject(data) {
                    keyName = "\(doc.key.tonic.display()) \(doc.key.mode.displayName())"
                    blockCount = doc.blocks.count
                }
                return SavedProject(fileName: url.lastPathComponent, date: date, key: keyName, blockCount: blockCount)
            }
            .sorted { $0.date > $1.date }
    }

    // MARK: - Export

    func exportMIDI() {
        let events = ChordFlowEngine.render(blocks: sequencedBlocks(project.blocks), swing: 0)
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
        let url = URL.documentsDirectory.appending(path: "ChordFlow-Project.\(Self.projectExtension)")
        do {
            try ChordFlowEngine.encodeProject(project).write(to: url)
            status = "Exported: \(url.lastPathComponent)"
        } catch {
            status = "Export failed: \(error.localizedDescription)"
        }
    }

    // MARK: - MIDI Output

    func toggleMIDIOutput() {
        if midiOutputEnabled {
            midiOutput.sendAllNotesOff(channel: midiChannel)
            midiOutput.stop()
            midiOutputEnabled = false
            status = "MIDI output disabled"
        } else {
            midiOutputEnabled = midiOutput.start()
            if midiOutputEnabled {
                status = "MIDI output: \(midiOutput.sourceName)"
            } else {
                status = "MIDI output failed: \(midiOutput.lastError ?? "unknown")"
            }
        }
    }

    // MARK: - Computed Helpers

    /// Recalculates barStart/beatStart so blocks are sequenced consecutively
    /// based on their actual lengthBeats, instead of assuming 4 beats per bar.
    private func sequencedBlocks(_ blocks: [CFSequenceBlock]) -> [CFSequenceBlock] {
        var result: [CFSequenceBlock] = []
        var currentBeat: Double = 0
        for var block in blocks {
            let bar = Int(currentBeat / 4)
            let beat = currentBeat - Double(bar * 4)
            block.barStart = bar
            block.beatStart = beat
            result.append(block)
            currentBeat += block.lengthBeats
        }
        return result
    }

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
        if chord.add11 { intervals.append(17) }
        if chord.add13 { intervals.append(21) }
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
        if chord.add13 {
            pills.append("Rich thirteenth")
        } else if chord.add11 {
            pills.append("Eleventh color")
        } else if chord.add9 {
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
