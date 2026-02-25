import Testing
import CoreTheory
import ChordFlowModels

struct CoreTheoryTests {
    @Test
    func majorScalePitchClasses() {
        let key = KeyContext(tonic: .c, mode: .major)
        #expect(TheoryEngine.scalePitchClasses(for: key) == [0, 2, 4, 5, 7, 9, 11])
    }

    @Test
    func chordToneExtensionsAndInversion() {
        let chord = ChordToken(root: .c, quality: .major, extensions: [.seventh, .ninth], inversion: 1)
        let tones = TheoryEngine.chordTones(chord)
        #expect(tones.count >= 4)
        #expect(tones.contains(74))
        #expect(tones.contains(72))
    }
}
