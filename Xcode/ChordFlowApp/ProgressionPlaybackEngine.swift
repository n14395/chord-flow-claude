import AVFoundation
import Foundation
import ChordFlowShared

private final class ActiveNoteStore {
    private struct Voice {
        var startedAt: TimeInterval
        var releasedAt: TimeInterval?
    }

    private let lock = NSLock()
    private var voices: [UInt8: Voice] = [:]

    func noteOn(_ note: UInt8) {
        let now = CFAbsoluteTimeGetCurrent()
        lock.lock()
        voices[note] = Voice(startedAt: now, releasedAt: nil)
        lock.unlock()
    }

    func noteOff(_ note: UInt8) {
        let now = CFAbsoluteTimeGetCurrent()
        lock.lock()
        if var voice = voices[note] {
            voice.releasedAt = now
            voices[note] = voice
        }
        lock.unlock()
    }

    func clear() {
        lock.lock()
        voices.removeAll()
        lock.unlock()
    }

    func snapshot(now: TimeInterval) -> [(note: UInt8, startedAt: TimeInterval, releasedAt: TimeInterval?)] {
        lock.lock()
        voices = voices.filter { _, voice in
            guard let releasedAt = voice.releasedAt else { return true }
            return now - releasedAt < 1.2
        }
        let current = voices.map { key, value in
            (note: key, startedAt: value.startedAt, releasedAt: value.releasedAt)
        }
        lock.unlock()
        return current
    }
}

@MainActor
final class ProgressionPlaybackEngine {
    var onPlaybackStateChange: ((Bool) -> Void)?

    // Timing info exposed for UI playhead
    private(set) var startTime: CFAbsoluteTime = 0
    private(set) var duration: Double = 0

    /// Returns 0...1 progress fraction, or 0 when not playing.
    var progress: Double {
        guard duration > 0 else { return 0 }
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        return min(max(elapsed / duration, 0), 1)
    }

    private let audioEngine = AVAudioEngine()
    private let noteStore = ActiveNoteStore()
    private let schedulerQueue = DispatchQueue(label: "com.nwf.chordflow.playback", qos: .userInitiated)
    private var scheduledItems: [DispatchWorkItem] = []
    private var sourceNode: AVAudioSourceNode?
    private var prepared = false

    func play(events: [CFMIDIEvent], tempo: Double, ppq: Int = ChordFlowEngine.ppq) {
        stop()
        guard !events.isEmpty else { return }
        prepareAudioIfNeeded()
        guard audioEngine.isRunning else { return }

        let secondsPerTick = 60.0 / max(1.0, tempo) / Double(max(1, ppq))
        var longestEnd: Double = 0

        for event in events {
            let note = event.data1
            let onTime = max(0, Double(event.startTick) * secondsPerTick)
            let offTime = max(0, Double(event.startTick + event.durationTicks) * secondsPerTick)
            longestEnd = max(longestEnd, offTime)

            let noteOn = DispatchWorkItem { [weak self] in
                self?.noteStore.noteOn(note)
            }
            let noteOff = DispatchWorkItem { [weak self] in
                self?.noteStore.noteOff(note)
            }
            scheduledItems.append(noteOn)
            scheduledItems.append(noteOff)
            schedulerQueue.asyncAfter(deadline: .now() + onTime, execute: noteOn)
            schedulerQueue.asyncAfter(deadline: .now() + offTime, execute: noteOff)
        }

        // Store timing info before firing state change
        startTime = CFAbsoluteTimeGetCurrent()
        duration = longestEnd

        onPlaybackStateChange?(true)

        let finish = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.noteStore.clear()
            Task { @MainActor in
                self.duration = 0
                self.onPlaybackStateChange?(false)
            }
        }
        scheduledItems.append(finish)
        schedulerQueue.asyncAfter(deadline: .now() + longestEnd + 0.05, execute: finish)
    }

    func stop() {
        for item in scheduledItems {
            item.cancel()
        }
        scheduledItems.removeAll()
        noteStore.clear()
        duration = 0
        onPlaybackStateChange?(false)
    }

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

        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        var sampleClock: Double = 0
        let source = AVAudioSourceNode { [weak noteStore] _, _, frameCount, audioBufferList -> OSStatus in
            let bufferCount = Int(audioBufferList.pointee.mNumberBuffers)
            let firstBufferPtr = withUnsafeMutablePointer(to: &audioBufferList.pointee.mBuffers) { $0 }
            let buffers = UnsafeMutableBufferPointer(start: firstBufferPtr, count: bufferCount)

            for buffer in buffers {
                if let mData = buffer.mData {
                    memset(mData, 0, Int(buffer.mDataByteSize))
                }
            }

            guard let noteStore else { return noErr }
            let bufferStartTime = CFAbsoluteTimeGetCurrent()
            let voices = noteStore.snapshot(now: bufferStartTime)
            guard !voices.isEmpty else { return noErr }

            let frameTotal = Int(frameCount)
            let channelTotal = max(1, bufferCount)
            let gain = 0.24 / sqrt(Double(max(1, voices.count)))

            for frame in 0..<frameTotal {
                let now = bufferStartTime + (Double(frame) / format.sampleRate)
                var sample = 0.0

                for voice in voices {
                    let hz = 440.0 * pow(2.0, Double(Int(voice.note) - 69) / 12.0)
                    let angle = (2.0 * Double.pi * hz * sampleClock) / format.sampleRate

                    let age = max(0, now - voice.startedAt)
                    let attack = min(1.0, age / 0.008)
                    let decay = 0.22 + 0.78 * exp(-age * 3.2)
                    let release: Double
                    if let releasedAt = voice.releasedAt {
                        release = exp(-max(0, now - releasedAt) * 18.0)
                    } else {
                        release = 1.0
                    }
                    let envelope = attack * decay * release
                    if envelope < 0.0001 { continue }

                    let brightness = exp(-age * 6.5)
                    let timbre = sin(angle)
                        + (0.45 * brightness * sin(angle * 2.01))
                        + (0.22 * brightness * sin(angle * 3.98))
                        + (0.12 * brightness * sin(angle * 6.02))

                    sample += timbre * envelope
                }

                let mixed = Float(max(-1.0, min(1.0, sample * gain)))
                sampleClock += 1

                for channel in 0..<channelTotal {
                    guard let mData = buffers[channel].mData else { continue }
                    let channelData = mData.assumingMemoryBound(to: Float.self)
                    channelData[frame] = mixed
                }
            }

            return noErr
        }

        sourceNode = source
        audioEngine.attach(source)
        audioEngine.connect(source, to: audioEngine.mainMixerNode, format: format)
        audioEngine.mainMixerNode.outputVolume = 0.8
        try? audioEngine.start()
        prepared = true
    }
}
