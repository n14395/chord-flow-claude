import AVFoundation
import Foundation
import ChordFlowShared

private final class ActiveNoteStore {
    private let lock = NSLock()
    private var notes: Set<UInt8> = []

    func noteOn(_ note: UInt8) {
        lock.lock()
        notes.insert(note)
        lock.unlock()
    }

    func noteOff(_ note: UInt8) {
        lock.lock()
        notes.remove(note)
        lock.unlock()
    }

    func clear() {
        lock.lock()
        notes.removeAll()
        lock.unlock()
    }

    func snapshot() -> [UInt8] {
        lock.lock()
        let current = Array(notes)
        lock.unlock()
        return current
    }
}

@MainActor
final class ProgressionPlaybackEngine {
    var onPlaybackStateChange: ((Bool) -> Void)?

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

        onPlaybackStateChange?(true)

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

        let finish = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.noteStore.clear()
            Task { @MainActor in
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
            let notes = noteStore.snapshot()
            guard !notes.isEmpty else { return noErr }

            let frequencies = notes.map { note -> Double in
                440.0 * pow(2.0, Double(Int(note) - 69) / 12.0)
            }
            let frameTotal = Int(frameCount)
            let channelTotal = max(1, bufferCount)
            let gain = Float(0.2 / Double(max(1, frequencies.count)))

            for frame in 0..<frameTotal {
                var sample = Float(0)
                for hz in frequencies {
                    let angle = (2.0 * Double.pi * hz * sampleClock) / format.sampleRate
                    sample += Float(sin(angle))
                }
                sample *= gain
                sampleClock += 1

                for channel in 0..<channelTotal {
                    guard let mData = buffers[channel].mData else { continue }
                    let channelData = mData.assumingMemoryBound(to: Float.self)
                    channelData[frame] = sample
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
