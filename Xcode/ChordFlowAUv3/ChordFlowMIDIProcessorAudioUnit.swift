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

    // Backing storage for parameter values (avoids infinite recursion via implementorValueProvider)
    private var tonicValue: AUValue = 0
    private var modeValue: AUValue = 0
    private var tensionValue: AUValue = 0.35
    private var patternValue: AUValue = 0
    private var swingValue: AUValue = 0.1
    private var humanizeValue: AUValue = 0.1

    // Chord cache
    private var cachedChords: [[UInt8]] = []
    private var lastTonic: Int = -1
    private var lastMode: Int = -1
    private var lastTensionBucket: Int = -1

    public override var outputBusses: AUAudioUnitBusArray { outputBussesInternal }
    public override var inputBusses: AUAudioUnitBusArray { inputBussesInternal }
    public override var parameterTree: AUParameterTree? {
        get { parameterTreeInternal }
        set { parameterTreeInternal = newValue }
    }

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
        tensionParameter.value = 0.35
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
            var timeSigNum = 4

            if let ctx = au.musicalContextBlock {
                var tempo: Double = 120
                var tsNum: Double = 4
                var tsDen: Int = 4
                var bp: Double = 0
                var sampleOff: Int = 0
                var downbeat: Double = 0
                _ = ctx(&tempo, &tsNum, &tsDen, &bp, &sampleOff, &downbeat)
                beatPosition = bp
                timeSigNum = max(1, Int(tsNum))
            }

            if let transport = au.transportStateBlock {
                var flags: AUHostTransportStateFlags = []
                var samplePos: Double = 0
                var cycleStart: Double = 0
                var cycleEnd: Double = 0
                _ = transport(&flags, &samplePos, &cycleStart, &cycleEnd)
                isPlaying = flags.contains(.moving)
            }

            // Transport transitions
            if isPlaying && !au.wasPlaying {
                au.lastChordBeat = -1
            } else if !isPlaying && au.wasPlaying {
                au.sendActiveNotesOff()
            }
            au.wasPlaying = isPlaying

            // Rebuild chords if parameters changed (called from render thread,
            // but only when cache is invalidated — rare, not every buffer)
            if isPlaying {
                au.rebuildChordsIfNeeded()

                let chordLen = timeSigNum
                let currentChordBeat = Int(floor(beatPosition / Double(chordLen)))

                if currentChordBeat != au.lastChordBeat {
                    au.lastChordBeat = currentChordBeat

                    // Note-off previous
                    au.sendActiveNotesOff()

                    // Note-on new chord
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

    // MARK: - Public Accessors

    public func captureHostTransport() {}

    public func latestHostSnapshot() -> (tempo: Double, beatPosition: Double, isPlaying: Bool) {
        (120, 0, false)
    }
}
