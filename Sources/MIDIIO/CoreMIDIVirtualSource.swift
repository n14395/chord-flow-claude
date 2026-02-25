import Foundation
import ChordFlowModels

#if canImport(CoreMIDI)
import CoreMIDI

public final class CoreMIDIVirtualSource: MIDIOutputBackend {
    private var client = MIDIClientRef()
    private var source = MIDIEndpointRef()

    public init(name: String = "ChordFlow Virtual Out") throws {
        let statusClient = MIDIClientCreateWithBlock(name as CFString, &client) { _ in }
        guard statusClient == noErr else { throw MIDIOutputError.unavailable }
        let statusSource = MIDISourceCreate(client, name as CFString, &source)
        guard statusSource == noErr else { throw MIDIOutputError.unavailable }
    }

    deinit {
        MIDIEndpointDispose(source)
        MIDIClientDispose(client)
    }

    public func send(events: [MIDINoteEvent], context: TransportContext) throws {
        var packetList = MIDIPacketList(numPackets: 0, packet: MIDIPacket())
        withUnsafeMutablePointer(to: &packetList) { ptr in
            var packet = MIDIPacketListInit(ptr)
            for event in events {
                var onData: [UInt8] = [0x90 | event.channel, event.note, event.velocity]
                packet = MIDIPacketListAdd(ptr, 1024, packet, 0, onData.count, &onData)
                var offData: [UInt8] = [0x80 | event.channel, event.note, 0]
                let beatDuration = Double(event.durationTicks) / 960.0
                let secs = beatDuration * 60.0 / context.tempo
                let timestamp = MIDITimeStamp(secs * 1_000_000_000)
                packet = MIDIPacketListAdd(ptr, 1024, packet, timestamp, offData.count, &offData)
            }
            MIDIReceived(source, ptr)
        }
    }
}
#else
public final class CoreMIDIVirtualSource: MIDIOutputBackend {
    public init(name: String = "ChordFlow Virtual Out") throws {
        throw MIDIOutputError.unavailable
    }

    public func send(events: [MIDINoteEvent], context: TransportContext) throws {
        throw MIDIOutputError.unavailable
    }
}
#endif
