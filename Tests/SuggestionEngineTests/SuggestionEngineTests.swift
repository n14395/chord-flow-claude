import Testing
import SuggestionEngine
import ChordFlowModels

struct SuggestionEngineTests {
    @Test
    func returnsRankedSuggestions() {
        let engine = HarmonicSuggestionEngine()
        let request = SuggestionRequest(
            keyContext: KeyContext(tonic: .c, mode: .major),
            previousChord: ChordToken(root: .g, quality: .major),
            melodyHint: .e,
            tensionLevel: 0.3,
            styleProfile: .pop
        )

        let suggestions = engine.suggest(request, limit: 5)
        #expect(!suggestions.isEmpty)
        #expect(suggestions.count == 5)
        #expect(suggestions[0].confidence >= suggestions[1].confidence)
    }
}
