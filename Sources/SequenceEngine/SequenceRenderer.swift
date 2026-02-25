import Foundation
import ChordFlowModels
import CoreTheory

public struct GrooveSettings: Sendable, Equatable {
    public var swing: Double
    public var humanizeTimingTicks: Int
    public var humanizeVelocity: UInt8

    public init(swing: Double = 0, humanizeTimingTicks: Int = 0, humanizeVelocity: UInt8 = 0) {
        self.swing = min(max(swing, 0), 0.8)
        self.humanizeTimingTicks = max(0, humanizeTimingTicks)
        self.humanizeVelocity = min(humanizeVelocity, 32)
    }
}

public struct SequenceRenderConfig: Sendable, Equatable {
    public var ppq: Int
    public var groove: GrooveSettings

    public init(ppq: Int = 960, groove: GrooveSettings = GrooveSettings()) {
        self.ppq = max(120, ppq)
        self.groove = groove
    }
}

public struct SequenceRenderer: Sendable {
    public init() {}

    public func render(blocks: [SequenceBlock], config: SequenceRenderConfig = SequenceRenderConfig()) -> [MIDINoteEvent] {
        let sortedBlocks = blocks.sorted {
            if $0.barStart == $1.barStart {
                return $0.beatStart < $1.beatStart
            }
            return $0.barStart < $1.barStart
        }

        var events: [MIDINoteEvent] = []
        for block in sortedBlocks {
            events.append(contentsOf: renderBlock(block, config: config))
        }
        return events.sorted { $0.startTick < $1.startTick }
    }

    private func renderBlock(_ block: SequenceBlock, config: SequenceRenderConfig) -> [MIDINoteEvent] {
        let beatOffset = (Double(block.barStart) * 4.0) + block.beatStart
        let startTick = Int(beatOffset * Double(config.ppq))
        let durationTicks = Int(block.lengthBeats * Double(config.ppq))

        let chordTones = TheoryEngine.chordTones(block.chordToken)
        let velocities = velocityPlan(count: chordTones.count, profile: block.velocityProfile, humanize: config.groove.humanizeVelocity)

        switch block.patternPreset {
        case .block:
            return chordTones.enumerated().map { idx, note in
                MIDINoteEvent(
                    note: note,
                    velocity: velocities[idx],
                    startTick: applySwing(startTick, config: config, beatOffset: beatOffset),
                    durationTicks: durationTicks
                )
            }
        case .arpUp, .arpDown:
            let ordered: [UInt8] = block.patternPreset == .arpUp ? chordTones : chordTones.reversed()
            let step = max(1, durationTicks / max(1, ordered.count))
            return ordered.enumerated().map { idx, note in
                MIDINoteEvent(
                    note: note,
                    velocity: velocities[min(idx, velocities.count - 1)],
                    startTick: applySwing(startTick + idx * step, config: config, beatOffset: beatOffset),
                    durationTicks: max(1, step)
                )
            }
        case .strum:
            let strumGap = max(2, config.ppq / 32)
            return chordTones.enumerated().map { idx, note in
                MIDINoteEvent(
                    note: note,
                    velocity: velocities[idx],
                    startTick: applySwing(startTick + idx * strumGap, config: config, beatOffset: beatOffset),
                    durationTicks: max(1, durationTicks - idx * strumGap)
                )
            }
        }
    }

    private func velocityPlan(count: Int, profile: VelocityProfile, humanize: UInt8) -> [UInt8] {
        guard count > 0 else { return [] }
        return (0..<count).map { index in
            let offset = Int(profile.variation) * (index % 2 == 0 ? 1 : -1)
            let human = Int(humanize) * ((index % 3) - 1)
            let value = Int(profile.base) + offset + human
            return UInt8(max(1, min(127, value)))
        }
    }

    private func applySwing(_ tick: Int, config: SequenceRenderConfig, beatOffset: Double) -> Int {
        let beatFraction = beatOffset - floor(beatOffset)
        let isOffBeat = beatFraction >= 0.5 && beatFraction < 1.0
        let swingOffset = isOffBeat ? Int(Double(config.ppq / 2) * config.groove.swing) : 0
        return max(0, tick + swingOffset + config.groove.humanizeTimingTicks)
    }
}
