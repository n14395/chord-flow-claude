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

    private var cachedTempo: Double = 120
    private var cachedBeatPosition: Double = 0
    private var cachedPlaying: Bool = false

    public override var outputBusses: AUAudioUnitBusArray { outputBussesInternal }
    public override var inputBusses: AUAudioUnitBusArray { inputBussesInternal }
    public override var parameterTree: AUParameterTree? {
        get { parameterTreeInternal }
        set { parameterTreeInternal = newValue }
    }

    public override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = []) throws {
        try super.init(componentDescription: componentDescription, options: options)

        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        outputBus = try AUAudioUnitBus(format: format)
        outputBussesInternal = AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [outputBus])
        inputBussesInternal = AUAudioUnitBusArray(audioUnit: self, busType: .input, busses: [])

        setupParameterTree()
        maximumFramesToRender = 4096
    }

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

        parameterTreeInternal.implementorValueObserver = { [weak self] parameter, value in
            self?.handleParameter(address: parameter.address, value: value)
        }
        parameterTreeInternal.implementorValueProvider = { [weak self] parameter in
            self?.currentValue(for: parameter.address) ?? 0
        }

        tonicParameter.value = 0
        modeParameter.value = 0
        tensionParameter.value = 0.35
        patternParameter.value = 0
        swingParameter.value = 0.1
        humanizeParameter.value = 0.1
    }

    private func handleParameter(address: AUParameterAddress, value: AUValue) {
        switch address {
        case ParamAddress.swing.rawValue:
            swingParameter.value = min(max(value, 0), 0.8)
        default:
            break
        }
    }

    private func currentValue(for address: AUParameterAddress) -> AUValue {
        switch address {
        case ParamAddress.tonic.rawValue: tonicParameter.value
        case ParamAddress.mode.rawValue: modeParameter.value
        case ParamAddress.tension.rawValue: tensionParameter.value
        case ParamAddress.pattern.rawValue: patternParameter.value
        case ParamAddress.swing.rawValue: swingParameter.value
        case ParamAddress.humanize.rawValue: humanizeParameter.value
        default: 0
        }
    }

    public override var internalRenderBlock: AUInternalRenderBlock {
        { [weak self] _, _, frameCount, _, outputData, _, _ in
            guard let self else { return noErr }
            self.captureHostTransport()

            if self.cachedPlaying {
                self.emitDemoChord(frameCount: frameCount)
            }

            let bufferCount = Int(outputData.pointee.mNumberBuffers)
            let firstBufferPtr = withUnsafeMutablePointer(to: &outputData.pointee.mBuffers) { $0 }
            let buffers = UnsafeMutableBufferPointer(start: firstBufferPtr, count: bufferCount)
            for i in 0..<buffers.count {
                let buffer = buffers[i]
                if let mData = buffer.mData {
                    memset(mData, 0, Int(buffer.mDataByteSize))
                }
            }
            return noErr
        }
    }

    private func emitDemoChord(frameCount: AUAudioFrameCount) {
        guard let midiOut = midiOutputEventBlock else { return }

        let chord = currentChordFromParameters()
        let tones = ChordFlowEngine.render(blocks: [
            CFSequenceBlock(barStart: 0, beatStart: 0, lengthBeats: 1, chord: chord, pattern: currentPattern())
        ], swing: Double(swingParameter.value))

        let sampleOffset = AUEventSampleTime(min(Int(frameCount - 1), 64))
        for event in tones.prefix(4) {
            let data: [UInt8] = [event.status, event.data1, 100]
            data.withUnsafeBufferPointer { ptr in
                guard let base = ptr.baseAddress else { return }
                _ = midiOut(sampleOffset, 0, 3, base)
            }
        }
    }

    private func currentChordFromParameters() -> CFChord {
        let tonicIndex = Int(tonicParameter.value.rounded())
        let tonic = CFNote(rawValue: max(0, min(11, tonicIndex))) ?? .c
        let tension = tensionParameter.value
        return CFChord(root: tonic, quality: .major, add7: tension > 0.45, add9: tension > 0.75)
    }

    private func currentPattern() -> CFPattern {
        let idx = Int(patternParameter.value.rounded())
        return CFPattern.allCases[max(0, min(CFPattern.allCases.count - 1, idx))]
    }

    public func captureHostTransport() {
        var tempo: Double = 120
        var timeSigNum: Double = 4
        var timeSigDen: Int = 4
        var beatPosition: Double = 0
        var sampleOffsetToNextBeat: Int = 0
        var measureDownbeatPosition: Double = 0

        if let musicalContextBlock {
            _ = musicalContextBlock(
                &tempo,
                &timeSigNum,
                &timeSigDen,
                &beatPosition,
                &sampleOffsetToNextBeat,
                &measureDownbeatPosition
            )
            cachedTempo = tempo
            cachedBeatPosition = beatPosition
        }

        if let transportStateBlock {
            var flags: AUHostTransportStateFlags = []
            var currentSamplePosition: Double = 0
            var cycleStartBeat: Double = 0
            var cycleEndBeat: Double = 0
            _ = transportStateBlock(&flags, &currentSamplePosition, &cycleStartBeat, &cycleEndBeat)
            cachedPlaying = flags.contains(.moving)
        }
    }

    public func latestHostSnapshot() -> (tempo: Double, beatPosition: Double, isPlaying: Bool) {
        (cachedTempo, cachedBeatPosition, cachedPlaying)
    }
}
