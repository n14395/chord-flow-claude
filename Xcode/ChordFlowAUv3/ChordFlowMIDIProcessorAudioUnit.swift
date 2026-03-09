import AudioToolbox
import AVFoundation
import ChordFlowShared

private enum ParamAddress: AUParameterAddress {
    case tonic = 0
    case mode = 1
    case tension = 2
    case pattern = 3
    case swing = 4
    case humanize = 5
}

public final class ChordFlowMIDIProcessorAudioUnit: AUAudioUnit {
    private var inputBus: AUAudioUnitBus!
    private var outputBus: AUAudioUnitBus!
    private var outputBussesInternal: AUAudioUnitBusArray!
    private var inputBussesInternal: AUAudioUnitBusArray!

    private(set) var parameterTreeInternal: AUParameterTree!

    private(set) var tonicParameter: AUParameter!
    private(set) var modeParameter: AUParameter!
    private(set) var tensionParameter: AUParameter!
    private(set) var patternParameter: AUParameter!
    private(set) var swingParameter: AUParameter!
    private(set) var humanizeParameter: AUParameter!

    // Render-thread state
    private var lastChordBeat: Int = -1
    private var wasPlaying: Bool = false
    private var activeNotes: [UInt8] = []
    private var lastBeatPosition: Double = -1
    private var renderCallCount: Int = 0

    // Debug state readable from UI
    var debugHasMusicalContext: Bool { musicalContextBlock != nil }
    var debugHasTransport: Bool { transportStateBlock != nil }
    var debugHasMidiOut: Bool { midiOutputEventBlock != nil }
    var debugRenderCount: Int { renderCallCount }
    var debugIsPlaying: Bool { wasPlaying }
    var debugBeatPosition: Double { lastBeatPosition }
    var debugChordCount: Int { cachedChords.count }

    // Backing storage for parameter values (avoids infinite recursion via implementorValueProvider)
    private var tonicValue: AUValue = 0
    private var modeValue: AUValue = 0
    private var tensionValue: AUValue = 0.2
    private var patternValue: AUValue = 0
    private var swingValue: AUValue = 0.1
    private var humanizeValue: AUValue = 0.1

    // Chord cache (auto-generated from parameters when no user progression exists)
    private var cachedChords: [[UInt8]] = []
    private var lastTonic: Int = -1
    private var lastMode: Int = -1
    private var lastTensionBucket: Int = -1

    // User-built progression (set from the UI via updateProgression)
    // When non-empty, this takes priority over cachedChords.
    private var progressionChords: [[UInt8]] = []
    private var progressionBeatLengths: [Double] = []
    private var progressionPatterns: [Int] = []  // 0=block, 1=arpUp, 2=arpDown, 3=strum
    private var hasUserProgression: Bool { !progressionChords.isEmpty }

    // Pattern scheduling state: tracks which individual note within an arp/strum
    // pattern we last triggered, so we advance through them over time.
    private var patternNoteIndex: Int = -1

    // Preview note queue (UI thread writes, render thread reads and drains)
    private var previewNoteOns: [UInt8] = []
    private var previewNoteOffs: [UInt8] = []
    private var previewActiveNotes: [UInt8] = []
    private var hasPendingPreviewOn: Bool = false
    private var hasPendingPreviewOff: Bool = false

    // Individual preview note queues (for pattern-aware previews)
    // These accumulate notes without clearing previous ones.
    private var pendingIndividualOns: [UInt8] = []
    private var pendingIndividualOffs: [UInt8] = []
    private var hasPendingIndividualOn: Bool = false
    private var hasPendingIndividualOff: Bool = false

    public override var outputBusses: AUAudioUnitBusArray { outputBussesInternal }
    public override var inputBusses: AUAudioUnitBusArray { inputBussesInternal }
    public override var parameterTree: AUParameterTree? {
        get { parameterTreeInternal }
        set { parameterTreeInternal = newValue }
    }

    // Tell the host we generate MIDI so it sets midiOutputEventBlock.
    // Returning a non-empty array causes the host to provide midiOutputEventBlock.
    public override var midiOutputNames: [String] { ["ChordFlow MIDI Out"] }

    public override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = []) throws {
        try super.init(componentDescription: componentDescription, options: options)

        // Even though aumi is MIDI-only, hosts like AUM require at least one input+output bus
        // for the render cycle to run. Audio passes through untouched.
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        inputBus = try AUAudioUnitBus(format: format)
        outputBus = try AUAudioUnitBus(format: format)
        inputBussesInternal = AUAudioUnitBusArray(audioUnit: self, busType: .input, busses: [inputBus])
        outputBussesInternal = AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [outputBus])

        setupParameterTree()
        maximumFramesToRender = 4096
    }

    public override func allocateRenderResources() throws {
        // Match output format to whatever the host set on the input bus
        if let inputFormat = inputBussesInternal.count > 0 ? inputBussesInternal[0].format : nil {
            try outputBus.setFormat(inputFormat)
        }
        try super.allocateRenderResources()
        rebuildChordsIfNeeded()
    }

    public override func deallocateRenderResources() {
        super.deallocateRenderResources()
        lastChordBeat = -1
        wasPlaying = false
        lastBeatPosition = -1
        patternNoteIndex = -1
        sendActiveNotesOff()
    }

    // MARK: - Parameters

    private func setupParameterTree() {
        tonicParameter = AUParameterTree.createParameter(
            withIdentifier: "tonic",
            name: "Tonic",
            address: ParamAddress.tonic.rawValue,
            min: 0,
            max: 11,
            unit: .indexed,
            unitName: nil,
            flags: [.flag_IsWritable, .flag_IsReadable, .flag_CanRamp],
            valueStrings: CFNote.allCases.map { $0.display() },
            dependentParameters: nil
        )

        modeParameter = AUParameterTree.createParameter(
            withIdentifier: "mode",
            name: "Mode",
            address: ParamAddress.mode.rawValue,
            min: 0,
            max: Float(CFScaleMode.allCases.count - 1),
            unit: .indexed,
            unitName: nil,
            flags: [.flag_IsWritable, .flag_IsReadable],
            valueStrings: CFScaleMode.allCases.map { $0.displayName() },
            dependentParameters: nil
        )

        tensionParameter = AUParameterTree.createParameter(
            withIdentifier: "tension",
            name: "Tension",
            address: ParamAddress.tension.rawValue,
            min: 0,
            max: 1,
            unit: .generic,
            unitName: nil,
            flags: [.flag_IsWritable, .flag_IsReadable, .flag_CanRamp],
            valueStrings: nil,
            dependentParameters: nil
        )

        patternParameter = AUParameterTree.createParameter(
            withIdentifier: "pattern",
            name: "Pattern",
            address: ParamAddress.pattern.rawValue,
            min: 0,
            max: Float(CFPattern.allCases.count - 1),
            unit: .indexed,
            unitName: nil,
            flags: [.flag_IsWritable, .flag_IsReadable],
            valueStrings: CFPattern.allCases.map(\ .rawValue),
            dependentParameters: nil
        )

        swingParameter = AUParameterTree.createParameter(
            withIdentifier: "swing",
            name: "Swing",
            address: ParamAddress.swing.rawValue,
            min: 0,
            max: 0.8,
            unit: .percent,
            unitName: nil,
            flags: [.flag_IsWritable, .flag_IsReadable],
            valueStrings: nil,
            dependentParameters: nil
        )

        humanizeParameter = AUParameterTree.createParameter(
            withIdentifier: "humanize",
            name: "Humanize",
            address: ParamAddress.humanize.rawValue,
            min: 0,
            max: 1,
            unit: .percent,
            unitName: nil,
            flags: [.flag_IsWritable, .flag_IsReadable],
            valueStrings: nil,
            dependentParameters: nil
        )

        parameterTreeInternal = AUParameterTree.createTree(withChildren: [
            tonicParameter, modeParameter, tensionParameter, patternParameter, swingParameter, humanizeParameter
        ])

        parameterTreeInternal.implementorValueObserver = { [weak self] param, value in
            guard let self else { return }
            // Store into backing variable
            switch param.address {
            case ParamAddress.tonic.rawValue: self.tonicValue = value
            case ParamAddress.mode.rawValue: self.modeValue = value
            case ParamAddress.tension.rawValue: self.tensionValue = value
            case ParamAddress.pattern.rawValue: self.patternValue = value
            case ParamAddress.swing.rawValue: self.swingValue = value
            case ParamAddress.humanize.rawValue: self.humanizeValue = value
            default: break
            }
            // Trigger chord rebuild on next render cycle
            if param.address <= ParamAddress.tension.rawValue {
                self.lastTonic = -1
            }
        }
        parameterTreeInternal.implementorValueProvider = { [weak self] param in
            self?.currentValue(for: param.address) ?? 0
        }

        // Set initial parameter values (these go through the observer to populate backing storage)
        tonicParameter.value = 0
        modeParameter.value = 0
        tensionParameter.value = 0.2
        patternParameter.value = 0
        swingParameter.value = 0.1
        humanizeParameter.value = 0.1
    }

    private func currentValue(for address: AUParameterAddress) -> AUValue {
        // Read from backing storage, NOT from parameter.value, to avoid infinite recursion
        // (implementorValueProvider -> currentValue -> parameter.value -> implementorValueProvider -> ...)
        switch address {
        case ParamAddress.tonic.rawValue: tonicValue
        case ParamAddress.mode.rawValue: modeValue
        case ParamAddress.tension.rawValue: tensionValue
        case ParamAddress.pattern.rawValue: patternValue
        case ParamAddress.swing.rawValue: swingValue
        case ParamAddress.humanize.rawValue: humanizeValue
        default: 0
        }
    }

    // MARK: - User Progression

    /// Called from the UI thread to push a user-built chord progression to the render thread.
    func updateProgression(chords: [[UInt8]], beatLengths: [Double], patterns: [Int]) {
        // Simple assignment — these arrays are value types and the render thread
        // reads them non-atomically, but the worst case is a single buffer with
        // stale data, which is acceptable for a UI-driven update.
        progressionChords = chords
        progressionBeatLengths = beatLengths
        progressionPatterns = patterns
        // Reset chord beat tracking so the next render cycle picks up the new progression
        lastChordBeat = -1
        patternNoteIndex = -1
    }

    // MARK: - Preview

    /// Send a set of MIDI notes immediately via the render block's MIDI output.
    /// Notes are queued and emitted on the next render cycle. After `durationSeconds`,
    /// note-offs are automatically queued.
    func sendPreviewNotes(_ notes: [UInt8], durationSeconds: Double = 1.0) {
        // Queue note-offs for any currently previewing notes
        if !previewActiveNotes.isEmpty {
            previewNoteOffs = previewActiveNotes
            hasPendingPreviewOff = true
        }
        // Queue the new notes
        previewNoteOns = notes
        previewActiveNotes = notes
        hasPendingPreviewOn = true

        // Schedule auto note-off after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + durationSeconds) { [weak self] in
            guard let self else { return }
            // Only stop if these are still the active preview notes
            if self.previewActiveNotes == notes {
                self.stopPreview()
            }
        }
    }

    /// Immediately queue note-offs for any previewing notes.
    func stopPreview() {
        guard !previewActiveNotes.isEmpty else { return }
        previewNoteOffs = previewActiveNotes
        hasPendingPreviewOff = true
        previewActiveNotes = []
    }

    /// Queue a single note-on for the next render cycle (additive — doesn't stop other notes).
    func queuePreviewNoteOn(_ note: UInt8) {
        pendingIndividualOns.append(note)
        previewActiveNotes.append(note)
        hasPendingIndividualOn = true
    }

    /// Queue a single note-off for the next render cycle.
    func queuePreviewNoteOff(_ note: UInt8) {
        pendingIndividualOffs.append(note)
        previewActiveNotes.removeAll { $0 == note }
        hasPendingIndividualOff = true
    }

    /// Stop all preview notes and clear queues.
    func cancelAllPreviews() {
        if !previewActiveNotes.isEmpty {
            previewNoteOffs.append(contentsOf: previewActiveNotes)
            hasPendingPreviewOff = true
            previewActiveNotes = []
        }
        pendingIndividualOns.removeAll()
        pendingIndividualOffs.removeAll()
        hasPendingIndividualOn = false
        hasPendingIndividualOff = false
    }

    // MARK: - Chord Cache

    private func rebuildChordsIfNeeded() {
        let tonicIdx = Int(tonicValue.rounded())
        let modeIdx = Int(modeValue.rounded())
        let tension = Double(tensionValue)
        let tensionBucket = Int(tension * 10)

        guard tonicIdx != lastTonic || modeIdx != lastMode || tensionBucket != lastTensionBucket else { return }
        lastTonic = tonicIdx
        lastMode = modeIdx
        lastTensionBucket = tensionBucket

        let tonic = CFNote(rawValue: max(0, min(11, tonicIdx))) ?? .c
        let modes = CFScaleMode.allCases
        let mode = modes[max(0, min(modes.count - 1, modeIdx))]
        let key = CFKeyContext(tonic: tonic, mode: mode)

        let buttons = ChordFlowEngine.diatonicChords(key: key, tension: tension)
        cachedChords = buttons.filter { !$0.isBorrowed }.map { btn in
            chordTones(btn.chord)
        }
    }

    private func chordTones(_ chord: CFChord) -> [UInt8] {
        let root = chord.root.rawValue
        var intervals: [Int]
        switch chord.quality {
        case .major: intervals = [0, 4, 7]
        case .minor: intervals = [0, 3, 7]
        case .diminished: intervals = [0, 3, 6]
        case .dominant: intervals = [0, 4, 7, 10]
        }
        if chord.add7, !intervals.contains(10) { intervals.append(10) }
        if chord.add9 { intervals.append(14) }
        if chord.add11 { intervals.append(17) }
        if chord.add13 { intervals.append(21) }
        return intervals.map { UInt8(min(127, root + $0 + 60)) }
    }

    // MARK: - Render

    public override var internalRenderBlock: AUInternalRenderBlock {
        // Capture what we need — avoid capturing self directly
        let stateRef = Unmanaged.passUnretained(self)

        return { actionFlags, timestamp, frameCount, outputBusNumber, outputData, realtimeEventListHead, pullInputBlock in
            let au = stateRef.takeUnretainedValue()

            // Pull input and pass through to output (required even for aumi in some hosts)
            if let pullInputBlock {
                var pullFlags: AudioUnitRenderActionFlags = []
                _ = pullInputBlock(&pullFlags, timestamp, frameCount, outputBusNumber, outputData)
            }

            // Read host transport
            var beatPosition: Double = 0
            var isPlaying = false
            var hostIsPlaying = false
            var timeSigNum = 4
            var sampleRate: Double = 44_100

            if let ctx = au.musicalContextBlock {
                var tempo: Double = 120
                var tsNum: Double = 4
                var tsDen: Int = 4
                var bp: Double = 0
                var sampleOff: Int = 0
                var downbeat: Double = 0
                if ctx(&tempo, &tsNum, &tsDen, &bp, &sampleOff, &downbeat) {
                    beatPosition = bp
                    timeSigNum = max(1, Int(tsNum))
                    sampleRate = max(1, Double(au.outputBus.format.sampleRate))
                }
            }

            if let transport = au.transportStateBlock {
                var flags: AUHostTransportStateFlags = []
                var samplePos: Double = 0
                var cycleStart: Double = 0
                var cycleEnd: Double = 0
                if transport(&flags, &samplePos, &cycleStart, &cycleEnd) {
                    hostIsPlaying = flags.contains(.moving)
                    isPlaying = hostIsPlaying
                }
            }

            // Fallback: if transportStateBlock wasn't provided or returned false,
            // infer playing state from beat position advancing
            if !isPlaying && au.lastBeatPosition >= 0 && beatPosition != au.lastBeatPosition {
                isPlaying = true
                hostIsPlaying = true
            }

            // AUv3 follows host transport entirely — no internal clock or mute toggle.
            // isPlaying is already set from transportStateBlock / beat-advancing fallback above.

            au.lastBeatPosition = beatPosition

            au.renderCallCount += 1

            // Transport transitions
            if isPlaying && !au.wasPlaying {
                au.lastChordBeat = -1
            } else if !isPlaying && au.wasPlaying {
                au.sendActiveNotesOff()
                au.patternNoteIndex = -1
            }
            au.wasPlaying = isPlaying

            // Drain preview note queues (UI-triggered chord previews)
            if au.hasPendingPreviewOff {
                au.hasPendingPreviewOff = false
                for note in au.previewNoteOffs {
                    au.sendNoteOff(note)
                }
                au.previewNoteOffs.removeAll(keepingCapacity: true)
            }
            if au.hasPendingPreviewOn {
                au.hasPendingPreviewOn = false
                let offset = AUEventSampleTime(min(Int(frameCount) - 1, 64))
                for note in au.previewNoteOns {
                    au.sendNoteOn(note, offset: offset)
                }
                au.previewNoteOns.removeAll(keepingCapacity: true)
            }

            // Drain individual preview note queues (pattern-aware previews)
            if au.hasPendingIndividualOff {
                au.hasPendingIndividualOff = false
                for note in au.pendingIndividualOffs {
                    au.sendNoteOff(note)
                }
                au.pendingIndividualOffs.removeAll(keepingCapacity: true)
            }
            if au.hasPendingIndividualOn {
                au.hasPendingIndividualOn = false
                let offset = AUEventSampleTime(min(Int(frameCount) - 1, 64))
                for note in au.pendingIndividualOns {
                    au.sendNoteOn(note, offset: offset)
                }
                au.pendingIndividualOns.removeAll(keepingCapacity: true)
            }

            if isPlaying {
                if au.hasUserProgression {
                    // User-built progression with variable beat lengths
                    let chords = au.progressionChords
                    let lengths = au.progressionBeatLengths
                    let patterns = au.progressionPatterns
                    let chordCount = chords.count
                    guard chordCount > 0, lengths.count == chordCount else { return noErr }

                    // Compute total beats in the progression
                    let totalBeats = lengths.reduce(0, +)
                    guard totalBeats > 0 else { return noErr }

                    // Wrap beat position within the progression length
                    let wrappedBeat = beatPosition.truncatingRemainder(dividingBy: totalBeats)
                    let positiveBeat = wrappedBeat < 0 ? wrappedBeat + totalBeats : wrappedBeat

                    // Walk chord boundaries to find which chord we're in
                    var accumulated: Double = 0
                    var currentIdx = 0
                    var chordStartBeat: Double = 0
                    for i in 0..<chordCount {
                        let prevAccum = accumulated
                        accumulated += lengths[i]
                        if positiveBeat < accumulated {
                            currentIdx = i
                            chordStartBeat = prevAccum
                            break
                        }
                        if i == chordCount - 1 {
                            currentIdx = i
                            chordStartBeat = prevAccum
                        }
                    }

                    // Use a combination of wrap cycle + index to detect chord changes
                    let cycleNumber = Int(floor(beatPosition / totalBeats))
                    let chordKey = cycleNumber * 1000 + currentIdx

                    let pat = currentIdx < patterns.count ? patterns[currentIdx] : 0
                    let notes = chords[currentIdx]
                    let chordDuration = lengths[currentIdx]
                    let beatInChord = positiveBeat - chordStartBeat
                    let offset = AUEventSampleTime(min(Int(frameCount) - 1, 64))

                    if chordKey != au.lastChordBeat {
                        // Chord changed — reset state
                        au.lastChordBeat = chordKey
                        au.sendActiveNotesOff()
                        au.patternNoteIndex = -1

                        switch pat {
                        case 0:
                            // Block: all notes on at once, sustain until next chord
                            for note in notes {
                                au.sendNoteOn(note, offset: offset)
                            }
                            au.activeNotes = Array(notes)

                        case 1, 2:
                            // Arp Up / Arp Down: first note triggers immediately
                            let sorted = pat == 1
                                ? notes.sorted()           // ascending
                                : notes.sorted().reversed() // descending, Array() below
                            let orderedNotes = Array(sorted)
                            if !orderedNotes.isEmpty {
                                au.sendNoteOn(orderedNotes[0], offset: offset)
                                au.activeNotes = [orderedNotes[0]]
                                au.patternNoteIndex = 0
                            }

                        case 3:
                            // Strum: trigger first note immediately, others on subsequent renders
                            if !notes.isEmpty {
                                au.sendNoteOn(notes[0], offset: offset)
                                au.activeNotes = [notes[0]]
                                au.patternNoteIndex = 0
                            }

                        default:
                            // Unknown pattern — fall back to block
                            for note in notes {
                                au.sendNoteOn(note, offset: offset)
                            }
                            au.activeNotes = Array(notes)
                        }
                    } else {
                        // Same chord — handle arp/strum note advancement
                        switch pat {
                        case 1, 2:
                            // Arp: subdivide chord duration evenly among notes
                            let sorted = pat == 1
                                ? notes.sorted()
                                : notes.sorted().reversed()
                            let orderedNotes = Array(sorted)
                            let noteCount = orderedNotes.count
                            guard noteCount > 1 else { break }
                            let step = chordDuration / Double(noteCount)
                            let expectedIdx = min(Int(beatInChord / step), noteCount - 1)
                            if expectedIdx != au.patternNoteIndex, expectedIdx >= 0 {
                                au.sendActiveNotesOff()
                                au.sendNoteOn(orderedNotes[expectedIdx], offset: offset)
                                au.activeNotes = [orderedNotes[expectedIdx]]
                                au.patternNoteIndex = expectedIdx
                            }

                        case 3:
                            // Strum: trigger notes with ~1/32 beat gap between them
                            let strumGap = 1.0 / 32.0  // beat gap between strum notes
                            let noteCount = notes.count
                            guard noteCount > 1 else { break }
                            let expectedIdx = min(Int(beatInChord / strumGap), noteCount - 1)
                            if expectedIdx > au.patternNoteIndex, expectedIdx < noteCount {
                                // Add newly strummed notes (don't remove previous — they sustain)
                                for i in (au.patternNoteIndex + 1)...expectedIdx {
                                    au.sendNoteOn(notes[i], offset: offset)
                                    au.activeNotes.append(notes[i])
                                }
                                au.patternNoteIndex = expectedIdx
                            }

                        default:
                            break // Block pattern — nothing to advance
                        }
                    }
                } else {
                    // Fallback: auto-cycle through parameter-generated diatonic chords
                    au.rebuildChordsIfNeeded()

                    let chordLen = timeSigNum
                    let currentChordBeat = Int(floor(beatPosition / Double(chordLen)))

                    if currentChordBeat != au.lastChordBeat {
                        au.lastChordBeat = currentChordBeat
                        au.sendActiveNotesOff()
                        let chordCount = au.cachedChords.count
                        if chordCount > 0 {
                            let idx = ((currentChordBeat % chordCount) + chordCount) % chordCount
                            let notes = au.cachedChords[idx]
                            let offset = AUEventSampleTime(min(Int(frameCount) - 1, 64))
                            for note in notes {
                                au.sendNoteOn(note, offset: offset)
                            }
                            au.activeNotes = notes
                        }
                    }
                }
            }

            return noErr
        }
    }

    // MARK: - MIDI Output

    private func sendNoteOn(_ note: UInt8, offset: AUEventSampleTime) {
        guard let midiOut = midiOutputEventBlock else { return }
        let bytes: [UInt8] = [0x90, note, 100]
        bytes.withUnsafeBufferPointer { ptr in
            guard let base = ptr.baseAddress else { return }
            _ = midiOut(offset, 0, 3, base)
        }
    }

    private func sendNoteOff(_ note: UInt8) {
        guard let midiOut = midiOutputEventBlock else { return }
        let bytes: [UInt8] = [0x80, note, 0]
        bytes.withUnsafeBufferPointer { ptr in
            guard let base = ptr.baseAddress else { return }
            _ = midiOut(0, 0, 3, base)
        }
    }

    private func sendActiveNotesOff() {
        for note in activeNotes {
            sendNoteOff(note)
        }
        activeNotes.removeAll(keepingCapacity: true)
    }


}
