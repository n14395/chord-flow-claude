import AVFoundation
import Foundation
import ChordFlowShared

// MARK: - Sine-Wave Voice Timeline

/// Thread-safe timeline of note events consumed by the sine-synth render callback.
/// The main thread loads events atomically; the render thread advances and synthesises.
private final class SineTimeline {
    struct Voice {
        var startSample: Int64
        var releaseSample: Int64?
    }

    private struct NoteEvent {
        var sampleFrame: Int64
        var isNoteOn: Bool
        var note: UInt8
        var velocity: UInt8
    }

    private struct State {
        var events: [NoteEvent] = []
        var cursor: Int = 0
        var isActive: Bool = false
        var sampleClock: Int64 = 0
    }

    private let lock = NSLock()
    private var state = State()
    private var voices: [UInt8: Voice] = [:]

    func load(events: [(frame: Int64, isNoteOn: Bool, note: UInt8, velocity: UInt8)]) {
        let sorted = events.sorted { $0.frame < $1.frame }
            .map { NoteEvent(sampleFrame: $0.frame, isNoteOn: $0.isNoteOn, note: $0.note, velocity: $0.velocity) }
        lock.lock()
        state = State(events: sorted, cursor: 0, isActive: true, sampleClock: 0)
        voices.removeAll()
        lock.unlock()
    }

    func clear() {
        lock.lock()
        state = State()
        voices.removeAll()
        lock.unlock()
    }

    struct AdvanceResult {
        var voices: [UInt8: Voice]
        var bufferStartClock: Int64
    }

    func advance(frameCount: Int64) -> AdvanceResult? {
        lock.lock()
        defer { lock.unlock() }

        guard state.isActive else { return nil }

        let bufferStart = state.sampleClock
        let bufferEnd = bufferStart + frameCount

        while state.cursor < state.events.count {
            let event = state.events[state.cursor]
            guard event.sampleFrame < bufferEnd else { break }
            state.cursor += 1

            if event.isNoteOn {
                voices[event.note] = Voice(
                    startSample: max(event.sampleFrame, bufferStart),
                    releaseSample: nil
                )
            } else if var voice = voices[event.note], voice.releaseSample == nil {
                voice.releaseSample = max(event.sampleFrame, bufferStart)
                voices[event.note] = voice
            }
        }

        // Prune fully-decayed voices
        let pruneThreshold: Int64 = 66_150
        voices = voices.filter { _, v in
            guard let rel = v.releaseSample else { return true }
            return (bufferEnd - rel) < pruneThreshold
        }

        state.sampleClock = bufferEnd
        return AdvanceResult(voices: voices, bufferStartClock: bufferStart)
    }
}

// MARK: - Playback Engine

@MainActor
final class ProgressionPlaybackEngine {
    var onPlaybackStateChange: ((Bool) -> Void)?

    // Timing info exposed for UI playhead
    private(set) var startTime: CFAbsoluteTime = 0
    private(set) var duration: Double = 0

    /// Returns 0-1 progress fraction, or 0 when not playing.
    var progress: Double {
        guard duration > 0 else { return 0 }
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        return min(max(elapsed / duration, 0), 1)
    }

    // Audio graph
    private let audioEngine = AVAudioEngine()
    private let sampler = AVAudioUnitSampler()
    private let reverb = AVAudioUnitReverb()

    // Scheduling
    private let schedulerQueue = DispatchQueue(label: "com.nwf.chordflow.playback", qos: .userInteractive)

    // Sampler path: high-frequency polling timer + sorted event list
    private var samplerTimer: DispatchSourceTimer?
    private var samplerEvents: [(absTime: Double, isNoteOn: Bool, note: UInt8, velocity: UInt8)] = []
    private var samplerCursor = 0

    // Generation counter — prevents stale finish handlers from interfering
    private var playbackGeneration: UInt64 = 0

    // State
    private var prepared = false
    private var useSampler = false
    private var hwSampleRate: Double = 44_100

    // Active notes (sampler path, for stop-all)
    private var activeNotes = Set<UInt8>()

    // Sine-wave timeline + source node
    private let sineTimeline = SineTimeline()
    private var sourceNode: AVAudioSourceNode?

    // MARK: - Play

    func play(events: [CFMIDIEvent], tempo: Double, ppq: Int = ChordFlowEngine.ppq) {
        stop()
        guard !events.isEmpty else { return }
        prepareAudioIfNeeded()
        guard audioEngine.isRunning else { return }

        playbackGeneration &+= 1
        let gen = playbackGeneration

        let secondsPerTick = 60.0 / max(1.0, tempo) / Double(max(1, ppq))
        var longestEnd: Double = 0

        // Capture startTime before scheduling so event timestamps and progress share the same epoch
        startTime = CFAbsoluteTimeGetCurrent()

        if useSampler {
            scheduleSamplerEvents(events: events, secondsPerTick: secondsPerTick, longestEnd: &longestEnd)
        } else {
            scheduleSineEvents(events: events, secondsPerTick: secondsPerTick, longestEnd: &longestEnd)
        }

        duration = longestEnd
        onPlaybackStateChange?(true)

        // For the sine path, schedule a finish timer (sampler path finishes via its own timer)
        if !useSampler {
            scheduleFinishTimer(delay: longestEnd + 0.05, generation: gen)
        }
    }

    // MARK: - Sampler Scheduling (DispatchSourceTimer)

    private func scheduleSamplerEvents(events: [CFMIDIEvent], secondsPerTick: Double, longestEnd: inout Double) {
        // Build sorted event list with absolute wall-clock timestamps.
        // startTime is set by play() before calling this method, so events and progress share the same epoch.
        let baseTime = startTime
        var list: [(absTime: Double, isNoteOn: Bool, note: UInt8, velocity: UInt8)] = []
        list.reserveCapacity(events.count * 2)

        for event in events {
            let onTime = max(0, Double(event.startTick) * secondsPerTick)
            let offTime = max(0, Double(event.startTick + event.durationTicks) * secondsPerTick)
            longestEnd = max(longestEnd, offTime)
            list.append((baseTime + onTime, true, event.data1, event.data2))
            list.append((baseTime + offTime, false, event.data1, 0))
        }

        list.sort { $0.absTime < $1.absTime }
        samplerEvents = list
        samplerCursor = 0

        // Start a 1ms polling timer on the scheduler queue
        let gen = playbackGeneration
        let timer = DispatchSource.makeTimerSource(queue: schedulerQueue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(1), leeway: .microseconds(100))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let now = CFAbsoluteTimeGetCurrent()

            // Fire all events whose time has arrived
            while self.samplerCursor < self.samplerEvents.count {
                let ev = self.samplerEvents[self.samplerCursor]
                guard ev.absTime <= now else { break }
                self.samplerCursor += 1

                if ev.isNoteOn {
                    self.sampler.startNote(ev.note, withVelocity: ev.velocity, onChannel: 0)
                    self.activeNotes.insert(ev.note)
                } else {
                    self.sampler.stopNote(ev.note, onChannel: 0)
                    self.activeNotes.remove(ev.note)
                }
            }

            // All events consumed — end playback
            if self.samplerCursor >= self.samplerEvents.count {
                timer.cancel()
                Task { @MainActor [weak self] in
                    guard let self, self.playbackGeneration == gen else { return }
                    self.stop()
                }
            }
        }
        timer.resume()
        samplerTimer = timer
    }

    // MARK: - Sine Scheduling (render-callback timeline)

    private func scheduleSineEvents(events: [CFMIDIEvent], secondsPerTick: Double, longestEnd: inout Double) {
        var timeline: [(frame: Int64, isNoteOn: Bool, note: UInt8, velocity: UInt8)] = []
        timeline.reserveCapacity(events.count * 2)

        for event in events {
            let onSec = max(0, Double(event.startTick) * secondsPerTick)
            let offSec = max(0, Double(event.startTick + event.durationTicks) * secondsPerTick)
            longestEnd = max(longestEnd, offSec)

            timeline.append((Int64(onSec * hwSampleRate), true, event.data1, event.data2))
            timeline.append((Int64(offSec * hwSampleRate), false, event.data1, 0))
        }

        sineTimeline.load(events: timeline)
    }

    /// Runs the timeline for progress tracking but produces no audio.
    func playSilent(events: [CFMIDIEvent], tempo: Double, ppq: Int = ChordFlowEngine.ppq) {
        stop()
        guard !events.isEmpty else { return }

        playbackGeneration &+= 1
        let gen = playbackGeneration

        let secondsPerTick = 60.0 / max(1.0, tempo) / Double(max(1, ppq))
        var longestEnd: Double = 0
        for event in events {
            let offTime = max(0, Double(event.startTick + event.durationTicks) * secondsPerTick)
            longestEnd = max(longestEnd, offTime)
        }

        startTime = CFAbsoluteTimeGetCurrent()
        duration = longestEnd
        onPlaybackStateChange?(true)

        scheduleFinishTimer(delay: longestEnd + 0.05, generation: gen)
    }

    // MARK: - Finish Timer (sine path + playSilent)

    private var finishTimer: DispatchSourceTimer?

    private func scheduleFinishTimer(delay: Double, generation: UInt64) {
        let timer = DispatchSource.makeTimerSource(queue: schedulerQueue)
        timer.schedule(deadline: .now() + delay)
        timer.setEventHandler { [weak self] in
            timer.cancel()
            Task { @MainActor [weak self] in
                guard let self, self.playbackGeneration == generation else { return }
                self.stop()
            }
        }
        timer.resume()
        finishTimer = timer
    }

    // MARK: - Stop

    func stop() {
        // Cancel timers
        samplerTimer?.cancel()
        samplerTimer = nil
        finishTimer?.cancel()
        finishTimer = nil
        samplerEvents.removeAll()
        samplerCursor = 0

        // Silence sampler
        if useSampler {
            for note in activeNotes {
                sampler.stopNote(note, onChannel: 0)
            }
            activeNotes.removeAll()
        }

        // Silence sine synth
        sineTimeline.clear()

        duration = 0
        onPlaybackStateChange?(false)
    }

    // MARK: - Audio Setup

    private func prepareAudioIfNeeded() {
        guard !prepared else {
            if !audioEngine.isRunning {
                try? audioEngine.start()
            }
            return
        }

        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.mixWithOthers])
        try? session.setActive(true)
        #endif

        let outputRate = audioEngine.outputNode.outputFormat(forBus: 0).sampleRate
        hwSampleRate = outputRate > 0 ? outputRate : 44_100

        if configureSamplerChain() {
            useSampler = true
        } else {
            configureSineFallback()
            useSampler = false
        }

        audioEngine.mainMixerNode.outputVolume = 0.8
        try? audioEngine.start()
        prepared = true
    }

    // MARK: - Sampler Configuration

    private func configureSamplerChain() -> Bool {
        audioEngine.attach(sampler)
        audioEngine.attach(reverb)

        reverb.loadFactoryPreset(.mediumHall)
        reverb.wetDryMix = 30

        let format = audioEngine.mainMixerNode.outputFormat(forBus: 0)
        audioEngine.connect(sampler, to: reverb, format: format)
        audioEngine.connect(reverb, to: audioEngine.mainMixerNode, format: format)

        if loadSoundFont() {
            return true
        }

        audioEngine.disconnectNodeOutput(sampler)
        audioEngine.disconnectNodeOutput(reverb)
        audioEngine.detach(sampler)
        audioEngine.detach(reverb)
        return false
    }

    private func loadSoundFont() -> Bool {
        if let bundled = Bundle.main.urls(forResourcesWithExtension: "sf2", subdirectory: nil) {
            for url in bundled {
                if loadBank(at: url) { return true }
            }
        }

        #if os(macOS)
        let systemDLS = URL(fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls")
        if FileManager.default.fileExists(atPath: systemDLS.path) {
            if loadBank(at: systemDLS) { return true }
        }
        #endif

        return false
    }

    private func loadBank(at url: URL) -> Bool {
        do {
            try sampler.loadSoundBankInstrument(
                at: url,
                program: 0,
                bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                bankLSB: 0
            )
            return true
        } catch {
            return false
        }
    }

    // MARK: - Sine-Wave Fallback

    private func configureSineFallback() {
        let sampleRate = hwSampleRate
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!

        let chorusRate = 1.7
        let chorusDepthCents = 8.0

        let timeline = self.sineTimeline
        var globalClock: Double = 0

        let source = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let bufferCount = Int(audioBufferList.pointee.mNumberBuffers)
            let firstBufferPtr = withUnsafeMutablePointer(to: &audioBufferList.pointee.mBuffers) { $0 }
            let buffers = UnsafeMutableBufferPointer(start: firstBufferPtr, count: bufferCount)
            let isStereo = bufferCount >= 2

            for buffer in buffers {
                if let mData = buffer.mData {
                    memset(mData, 0, Int(buffer.mDataByteSize))
                }
            }

            guard let result = timeline.advance(frameCount: Int64(frameCount)) else {
                globalClock += Double(frameCount)
                return noErr
            }
            let voices = result.voices
            guard !voices.isEmpty else {
                globalClock += Double(frameCount)
                return noErr
            }

            let frameTotal = Int(frameCount)
            let gain = 0.22 / sqrt(Double(max(1, voices.count)))
            let bufferStartClock = result.bufferStartClock

            for frame in 0..<frameTotal {
                let currentFrame = bufferStartClock + Int64(frame)
                let clock = globalClock + Double(frame)
                var sampleL = 0.0
                var sampleR = 0.0

                for (note, voice) in voices {
                    let ageSamples = Double(currentFrame - voice.startSample)
                    guard ageSamples >= 0 else { continue }
                    let age = ageSamples / sampleRate

                    // Envelope: fast attack, dual-stage decay
                    let attack = min(1.0, age / 0.006)
                    let body = 0.60 * exp(-age * 2.5)
                    let tail = 0.40 * exp(-age * 0.6)
                    let release: Double
                    if let relSample = voice.releaseSample {
                        let relAge = Double(currentFrame - relSample) / sampleRate
                        guard relAge < 1.5 else { continue }
                        release = exp(-max(0, relAge) * 5.0)
                    } else {
                        release = 1.0
                    }
                    let envelope = attack * (body + tail) * release
                    if envelope < 0.0001 { continue }

                    let hz = 440.0 * pow(2.0, Double(Int(note) - 69) / 12.0)
                    let angle = (2.0 * .pi * hz * clock) / sampleRate

                    let lfoPhase = 2.0 * .pi * chorusRate * clock / sampleRate
                    let lfoL = sin(lfoPhase)
                    let lfoR = sin(lfoPhase + 1.9)
                    let detuneL = pow(2.0, (chorusDepthCents * lfoL) / 1200.0)
                    let detuneR = pow(2.0, (chorusDepthCents * lfoR) / 1200.0)

                    let bright1 = exp(-age * 4.0)
                    let bright2 = exp(-age * 7.0)

                    let angleL = angle * detuneL
                    let timbreL = sin(angleL)
                        + (0.48 * bright1 * sin(angleL * 2.003))
                        + (0.30 * bright1 * sin(angleL * 2.998))
                        + (0.22 * bright2 * sin(angleL * 4.009))
                        + (0.14 * bright2 * sin(angleL * 5.002))
                        + (0.08 * bright2 * sin(angleL * 6.013))
                        + (0.04 * bright2 * sin(angleL * 7.997))
                        + (0.025 * bright2 * sin(angleL * 10.05))

                    let angleR = angle * detuneR
                    let timbreR = sin(angleR)
                        + (0.48 * bright1 * sin(angleR * 2.003))
                        + (0.30 * bright1 * sin(angleR * 2.998))
                        + (0.22 * bright2 * sin(angleR * 4.009))
                        + (0.14 * bright2 * sin(angleR * 5.002))
                        + (0.08 * bright2 * sin(angleR * 6.013))
                        + (0.04 * bright2 * sin(angleR * 7.997))
                        + (0.025 * bright2 * sin(angleR * 10.05))

                    let pan = 0.5 + 0.2 * sin(Double(note) * 0.73)
                    sampleL += timbreL * envelope * (1.0 - pan * 0.4)
                    sampleR += timbreR * envelope * (0.6 + pan * 0.4)
                }

                let mixedL = Float(max(-1.0, min(1.0, sampleL * gain)))
                let mixedR = Float(max(-1.0, min(1.0, sampleR * gain)))

                if isStereo {
                    if let mData = buffers[0].mData {
                        mData.assumingMemoryBound(to: Float.self)[frame] = mixedL
                    }
                    if let mData = buffers[1].mData {
                        mData.assumingMemoryBound(to: Float.self)[frame] = mixedR
                    }
                } else {
                    let mono = (mixedL + mixedR) * 0.5
                    if let mData = buffers[0].mData {
                        mData.assumingMemoryBound(to: Float.self)[frame] = mono
                    }
                }
            }

            globalClock += Double(frameCount)
            return noErr
        }

        sourceNode = source
        audioEngine.attach(source)
        audioEngine.connect(source, to: audioEngine.mainMixerNode, format: format)
    }
}
