import Foundation
import ChordFlowModels

public struct MIDIFileExporter: Sendable {
    public enum Format: UInt16, Sendable {
        case singleTrack = 0
        case multiTrack = 1
    }

    public init() {}

    public func export(events: [MIDINoteEvent], ppq: Int = 960, format: Format = .singleTrack) -> Data {
        let sorted = events.sorted { $0.startTick < $1.startTick }
        var track = Data()
        var cursor = 0

        for event in sorted {
            let deltaOn = max(0, event.startTick - cursor)
            track.append(variableLength(deltaOn))
            track.append(contentsOf: [0x90 | event.channel, event.note, event.velocity])
            cursor = event.startTick

            track.append(variableLength(event.durationTicks))
            track.append(contentsOf: [0x80 | event.channel, event.note, 0])
            cursor += event.durationTicks
        }

        track.append(contentsOf: [0x00, 0xFF, 0x2F, 0x00])

        var file = Data()
        file.append(contentsOf: [0x4D, 0x54, 0x68, 0x64])
        file.append(beUInt32(6))
        file.append(beUInt16(format.rawValue))
        file.append(beUInt16(1))
        file.append(beUInt16(UInt16(max(1, min(32_767, ppq)))))

        file.append(contentsOf: [0x4D, 0x54, 0x72, 0x6B])
        file.append(beUInt32(UInt32(track.count)))
        file.append(track)

        return file
    }

    private func variableLength(_ value: Int) -> Data {
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

    private func beUInt16(_ value: UInt16) -> Data {
        Data([UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)])
    }

    private func beUInt32(_ value: UInt32) -> Data {
        Data([
            UInt8((value >> 24) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF)
        ])
    }
}
