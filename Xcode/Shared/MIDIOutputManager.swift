import Foundation
import CoreMIDI

public final class MIDIOutputManager {

    // MARK: - Public State

    public private(set) var isRunning = false
    public private(set) var clientName: String
    public private(set) var sourceName: String
    public private(set) var lastError: String?

    // MARK: - Private

    private var client: MIDIClientRef = 0
    private var source: MIDIEndpointRef = 0

    // MARK: - Init

    public init(clientName: String = "ChordFlow", sourceName: String = "ChordFlow Out") {
        self.clientName = clientName
        self.sourceName = sourceName
    }

    // MARK: - Setup / Teardown

    public func start() -> Bool {
        guard !isRunning else { return true }
        lastError = nil

        var status = MIDIClientCreateWithBlock(clientName as CFString, &client) { notification in
            print("[MIDIOutputManager] MIDI notification: \(notification)")
        }
        guard status == noErr else {
            lastError = "MIDIClientCreate failed: OSStatus \(status)"
            print("[MIDIOutputManager] \(lastError!)")
            return false
        }
        print("[MIDIOutputManager] MIDI client created OK (ref=\(client))")

        status = MIDISourceCreateWithProtocol(client, sourceName as CFString, ._1_0, &source)
        guard status == noErr else {
            lastError = "MIDISourceCreate failed: OSStatus \(status)"
            print("[MIDIOutputManager] \(lastError!)")
            MIDIClientDispose(client)
            client = 0
            return false
        }
        print("[MIDIOutputManager] MIDI source created OK (ref=\(source))")

        isRunning = true
        return true
    }

    public func stop() {
        guard isRunning else { return }
        MIDIEndpointDispose(source)
        MIDIClientDispose(client)
        source = 0
        client = 0
        isRunning = false
    }

    // MARK: - Send Events

    /// Sends a MIDI note-on event on the given channel (0-15).
    public func sendNoteOn(note: UInt8, velocity: UInt8, channel: UInt8 = 0) {
        guard isRunning else { return }
        let statusByte: UInt8 = 0x90 | (channel & 0x0F)
        sendMessage([statusByte, note & 0x7F, velocity & 0x7F])
    }

    /// Sends a MIDI note-off event on the given channel (0-15).
    public func sendNoteOff(note: UInt8, channel: UInt8 = 0) {
        guard isRunning else { return }
        let statusByte: UInt8 = 0x80 | (channel & 0x0F)
        sendMessage([statusByte, note & 0x7F, 0])
    }

    /// Sends a MIDI CC event on the given channel (0-15).
    public func sendCC(controller: UInt8, value: UInt8, channel: UInt8 = 0) {
        guard isRunning else { return }
        let statusByte: UInt8 = 0xB0 | (channel & 0x0F)
        sendMessage([statusByte, controller & 0x7F, value & 0x7F])
    }

    /// Sends all-notes-off (CC 123) on the given channel.
    public func sendAllNotesOff(channel: UInt8 = 0) {
        sendCC(controller: 123, value: 0, channel: channel)
    }

    // MARK: - Low Level

    private func sendMessage(_ bytes: [UInt8]) {
        guard isRunning, !bytes.isEmpty else { return }

        // Build a single UMP-wrapped MIDI 1.0 message using MIDIEventList
        var eventList = MIDIEventList()
        var packet = MIDIEventListInit(&eventList, ._1_0)

        // Convert MIDI 1.0 bytes to a UMP word
        let word: UInt32
        if bytes.count >= 3 {
            // 3-byte message: status + data1 + data2
            word = UInt32(0x20000000)  // UMP message type 0x2 (MIDI 1.0 channel voice)
                 | (UInt32(bytes[0]) << 16)
                 | (UInt32(bytes[1]) << 8)
                 | UInt32(bytes[2])
        } else if bytes.count == 2 {
            // 2-byte message
            word = UInt32(0x20000000)
                 | (UInt32(bytes[0]) << 16)
                 | (UInt32(bytes[1]) << 8)
        } else {
            return
        }

        packet = MIDIEventListAdd(&eventList, MemoryLayout<MIDIEventList>.size, packet, 0, 1, [word])

        MIDIReceivedEventList(source, &eventList)
    }

    deinit {
        stop()
    }
}
