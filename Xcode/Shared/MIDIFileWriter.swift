import Foundation

public enum MIDIFileWriter {
    public static func export(events: [CFMIDIEvent], ppq: Int = ChordFlowEngine.ppq) -> Data {
        let sorted = events.sorted { $0.startTick < $1.startTick }
        var track = Data()
        var cursor = 0

        for event in sorted {
            track.append(variableLength(max(0, event.startTick - cursor)))
            track.append(contentsOf: [event.status, event.data1, event.data2])
            cursor = event.startTick

            track.append(variableLength(max(1, event.durationTicks)))
            track.append(contentsOf: [0x80, event.data1, 0])
            cursor += event.durationTicks
        }

        track.append(contentsOf: [0x00, 0xFF, 0x2F, 0x00])

        var data = Data()
        data.append(contentsOf: [0x4D, 0x54, 0x68, 0x64])
        data.append(be32(6))
        data.append(be16(0))
        data.append(be16(1))
        data.append(be16(UInt16(ppq)))
        data.append(contentsOf: [0x4D, 0x54, 0x72, 0x6B])
        data.append(be32(UInt32(track.count)))
        data.append(track)
        return data
    }

    private static func variableLength(_ value: Int) -> Data {
        var buffer = [UInt8](repeating: 0, count: 5)
        var index = 4
        buffer[index] = UInt8(value & 0x7F)
        var current = value >> 7
        while current > 0 {
            index -= 1
            buffer[index] = UInt8((current & 0x7F) | 0x80)
            current >>= 7
        }
        return Data(buffer[index...4])
    }

    private static func be16(_ v: UInt16) -> Data {
        Data([UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)])
    }

    private static func be32(_ v: UInt32) -> Data {
        Data([UInt8((v >> 24) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)])
    }
}
