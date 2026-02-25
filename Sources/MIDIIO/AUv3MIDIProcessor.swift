import Foundation
import ChordFlowModels

public enum AUParameterID: UInt32, CaseIterable, Sendable {
    case tonic = 0
    case mode = 1
    case tension = 2
    case pattern = 3
    case swing = 4
    case humanize = 5
}

public struct AUParameterState: Sendable, Equatable {
    public var tonic: NoteName
    public var mode: ScaleMode
    public var tension: Double
    public var pattern: PatternPreset
    public var swing: Double
    public var humanize: Double

    public init(
        tonic: NoteName = .c,
        mode: ScaleMode = .major,
        tension: Double = 0.35,
        pattern: PatternPreset = .block,
        swing: Double = 0,
        humanize: Double = 0.1
    ) {
        self.tonic = tonic
        self.mode = mode
        self.tension = min(max(tension, 0), 1)
        self.pattern = pattern
        self.swing = min(max(swing, 0), 1)
        self.humanize = min(max(humanize, 0), 1)
    }
}

public struct AUv3MIDIProcessor: Sendable {
    public var parameterState: AUParameterState
    private let mapper = AUv3TimestampMapper()

    public init(parameterState: AUParameterState = AUParameterState()) {
        self.parameterState = parameterState
    }

    public func mapEventTicksToHostSampleTime(
        events: [MIDINoteEvent],
        ppq: Int,
        context: TransportContext
    ) -> [Int64] {
        events.map { mapper.sampleTime(for: $0.startTick, ppq: ppq, context: context) }
    }
}

public struct StandaloneTransportClock: Sendable {
    public private(set) var tempo: Double
    public private(set) var isRunning: Bool
    public private(set) var beatPosition: Double

    public init(tempo: Double = 120) {
        self.tempo = tempo
        self.isRunning = false
        self.beatPosition = 0
    }

    public mutating func start() { isRunning = true }
    public mutating func stop() { isRunning = false }
    public mutating func setTempo(_ bpm: Double) { tempo = min(max(bpm, 20), 300) }

    public mutating func advance(seconds: Double) {
        guard isRunning else { return }
        beatPosition += (seconds / 60.0) * tempo
    }
}
