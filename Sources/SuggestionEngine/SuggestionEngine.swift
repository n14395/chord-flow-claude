import Foundation
import ChordFlowModels
import CoreTheory

public struct HarmonicSuggestionEngine: Sendable {
    public init() {}

    public func suggest(_ request: SuggestionRequest, limit: Int = 8) -> [SuggestionResult] {
        let base = TheoryEngine.diatonicTriads(for: request.keyContext)
        let borrowed = modalInterchangeCandidates(for: request.keyContext)
        let allCandidates = (base + borrowed).uniqued()

        let results = allCandidates.map { token -> SuggestionResult in
            let score = score(token, request: request)
            let reasons = explain(token, request: request, score: score)
            return SuggestionResult(chordToken: token, confidence: score, reasons: reasons)
        }

        return results
            .sorted { $0.confidence > $1.confidence }
            .prefix(max(1, limit))
            .map { $0 }
    }

    private func modalInterchangeCandidates(for key: KeyContext) -> [ChordToken] {
        guard key.mode == .major else { return [] }
        let flatVII = ChordToken(root: key.tonic.transposed(semitones: 10), quality: .major)
        let minorIV = ChordToken(root: key.tonic.transposed(semitones: 5), quality: .minor)
        let flatVI = ChordToken(root: key.tonic.transposed(semitones: 8), quality: .major)
        return [flatVII, minorIV, flatVI]
    }

    private func score(_ token: ChordToken, request: SuggestionRequest) -> Double {
        var score = 0.45

        let diatonicSet = Set(TheoryEngine.diatonicTriads(for: request.keyContext).map(\ .root.midiClass))
        if diatonicSet.contains(token.root.midiClass) {
            score += 0.2
        } else {
            score += 0.07
        }

        if let previous = request.previousChord {
            score += max(0, 0.2 - voiceLeadingCost(previous: previous, next: token))
        }

        if let melody = request.melodyHint {
            let tones = TheoryEngine.chordTones(token).map { Int($0 % 12) }
            if tones.contains(melody.midiClass) {
                score += 0.1
            }
        }

        score += tensionAdjustment(token: token, request: request)
        score += styleAdjustment(token: token, profile: request.styleProfile)

        return min(max(score, 0), 1)
    }

    private func voiceLeadingCost(previous: ChordToken, next: ChordToken) -> Double {
        let previousTones = TheoryEngine.chordTones(previous).map(Int.init)
        let nextTones = TheoryEngine.chordTones(next).map(Int.init)
        let minDistance = nextTones.map { nt in
            previousTones.map { abs(($0 % 12) - (nt % 12)) }.min() ?? 6
        }.reduce(0, +)
        return Double(minDistance) / Double(max(1, nextTones.count * 12))
    }

    private func tensionAdjustment(token: ChordToken, request: SuggestionRequest) -> Double {
        let tension = request.tensionLevel
        let extensionWeight = Double(token.extensions.count) * 0.06
        if tension >= 0.6 {
            return extensionWeight + (token.quality == .dominant ? 0.04 : 0)
        }
        return extensionWeight * -0.5
    }

    private func styleAdjustment(token: ChordToken, profile: StyleProfile) -> Double {
        switch profile {
        case .pop:
            return token.quality == .major || token.quality == .minor ? 0.05 : 0.01
        case .jazz:
            return token.quality == .dominant || token.extensions.contains(.seventh) ? 0.08 : 0.02
        case .neoSoul:
            return token.extensions.contains(.ninth) ? 0.1 : 0.03
        }
    }

    private func explain(_ token: ChordToken, request: SuggestionRequest, score: Double) -> [String] {
        var reasons: [String] = []
        reasons.append("Function: \(TheoryEngine.romanFunction(chord: token, key: request.keyContext))")
        if token.extensions.isEmpty {
            reasons.append("Simple voicing keeps movement clear")
        } else {
            reasons.append("Extensions add color for tension level \(Int(request.tensionLevel * 100))")
        }
        if let previous = request.previousChord {
            let cost = voiceLeadingCost(previous: previous, next: token)
            reasons.append(cost < 0.1 ? "Smooth voice leading" : "Contrast from previous chord")
        }
        reasons.append("Confidence \(Int(score * 100))%")
        return reasons
    }
}

private extension Array where Element == ChordToken {
    func uniqued() -> [ChordToken] {
        var seen = Set<ChordToken>()
        var output: [ChordToken] = []
        for value in self where !seen.contains(value) {
            seen.insert(value)
            output.append(value)
        }
        return output
    }
}
