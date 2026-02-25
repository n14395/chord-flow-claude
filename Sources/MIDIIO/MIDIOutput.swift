import Foundation
import ChordFlowModels

public struct TransportContext: Sendable, Equatable {
    public var tempo: Double
    public var sampleRate: Double
    public var hostBeatPosition: Double?

    public init(tempo: Double = 120, sampleRate: Double = 48_000, hostBeatPosition: Double? = nil) {
        self.tempo = tempo
        self.sampleRate = sampleRate
        self.hostBeatPosition = hostBeatPosition
    }
}

public protocol MIDIOutputBackend {
    func send(events: [MIDINoteEvent], context: TransportContext) throws
}

public enum MIDIOutputError: Error {
    case unavailable
    case invalidEvent
}

public struct AUv3TimestampMapper: Sendable {
    public init() {}

    public func sampleTime(for eventTick: Int, ppq: Int, context: TransportContext) -> Int64 {
        let beats = Double(eventTick) / Double(ppq)
        let seconds = beats * (60.0 / context.tempo)
        return Int64(seconds * context.sampleRate)
    }
}

public struct LoggingMIDIBackend: MIDIOutputBackend {
    public init() {}

    public func send(events: [MIDINoteEvent], context: TransportContext) throws {
        let preview = events.prefix(6).map { "n\($0.note)@\($0.startTick)" }.joined(separator: ",")
        print("[MIDI] events=\(events.count) tempo=\(context.tempo) preview=\(preview)")
    }
}
