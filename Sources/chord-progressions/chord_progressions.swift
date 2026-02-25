import Foundation
import ChordFlowModels
import CoreTheory
import SuggestionEngine
import SequenceEngine
import MIDIIO
import Persistence

@main
struct ChordFlowCLI {
    static func main() throws {
        let key = KeyContext(tonic: .c, mode: .major)
        let project = ProjectDocument(
            keyContext: key,
            routingConfig: RoutingConfig(outputMode: .virtualMIDI, clockMode: .internalTransport)
        )

        let suggestionEngine = HarmonicSuggestionEngine()
        let request = SuggestionRequest(keyContext: key, styleProfile: .pop)
        let suggestions = suggestionEngine.suggest(request, limit: 4)

        print("Top chord suggestions for \(key.tonic.display(preference: .sharps)) \(key.mode.rawValue):")
        for result in suggestions {
            print("- \(result.chordToken.symbol(preference: .sharps)) [\(Int(result.confidence * 100))%]")
        }

        let blocks = suggestions.enumerated().map { idx, suggestion in
            SequenceBlock(
                barStart: idx,
                beatStart: 0,
                lengthBeats: 4,
                chordToken: suggestion.chordToken,
                patternPreset: idx % 2 == 0 ? .block : .arpUp
            )
        }

        let renderer = SequenceRenderer()
        let events = renderer.render(
            blocks: blocks,
            config: SequenceRenderConfig(
                ppq: 960,
                groove: GrooveSettings(swing: 0.15, humanizeTimingTicks: 0, humanizeVelocity: 4)
            )
        )

        let exporter = MIDIFileExporter()
        let midiData = exporter.export(events: events, ppq: 960)
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("demo-progression.mid")
        try midiData.write(to: url)
        print("Exported demo MIDI: \(url.path)")

        let store = ProjectStore()
        var withBlocks = project
        withBlocks.blocks = blocks
        let projectData = try store.encode(withBlocks)
        try projectData.write(to: URL(fileURLWithPath: "demo-project.json"))
        print("Exported project JSON: demo-project.json")

        let backend = LoggingMIDIBackend()
        try backend.send(events: events, context: TransportContext(tempo: project.tempo))
    }
}
