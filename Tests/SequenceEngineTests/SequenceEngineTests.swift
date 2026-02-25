import Testing
import SequenceEngine
import ChordFlowModels

struct SequenceEngineTests {
    @Test
    func deterministicRenderForSameInput() {
        let blocks = [
            SequenceBlock(barStart: 0, beatStart: 0, lengthBeats: 4, chordToken: ChordToken(root: .c, quality: .major), patternPreset: .block),
            SequenceBlock(barStart: 1, beatStart: 0, lengthBeats: 4, chordToken: ChordToken(root: .g, quality: .major), patternPreset: .arpUp)
        ]

        let renderer = SequenceRenderer()
        let config = SequenceRenderConfig(ppq: 960, groove: GrooveSettings(swing: 0.1, humanizeTimingTicks: 0, humanizeVelocity: 2))

        let first = renderer.render(blocks: blocks, config: config)
        let second = renderer.render(blocks: blocks, config: config)

        #expect(first == second)
    }
}
