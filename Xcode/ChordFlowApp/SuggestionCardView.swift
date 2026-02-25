import SwiftUI
import ChordFlowShared

struct SuggestionCardView: View {
    let suggestion: CFSuggestion
    let rank: Int
    let function: HarmonicFunction
    let reasons: [String]
    let isTopPick: Bool
    var onTap: (() -> Void)?

    var body: some View {
        let color = function.color
        let isBorrowed = function == .borrowed

        Button(action: { onTap?() }) {
            HStack(spacing: CFSpacing.compact) {
                // Rank badge
                ZStack {
                    Circle()
                        .fill(isTopPick ? color.opacity(0.2) : Color.cfBorder)
                        .frame(width: 28, height: 28)
                    Text("\(rank)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(isTopPick ? color : Color.cfTextSecondary)
                }

                VStack(alignment: .leading, spacing: CFSpacing.micro) {
                    // Chord info
                    HStack(spacing: CFSpacing.tight) {
                        Text(suggestion.chord.symbol())
                            .font(.cfChordSymbol)
                            .foregroundStyle(color)
                        Text(function.label)
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(color.opacity(0.6))
                        Spacer()
                    }

                    // Confidence bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.cfBorder)
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(color.opacity(0.6))
                                .frame(width: geo.size.width * suggestion.confidence, height: 4)
                        }
                    }
                    .frame(height: 4)

                    // Reason pills
                    HStack(spacing: CFSpacing.micro) {
                        ForEach(reasons, id: \.self) { reason in
                            Text(reason)
                                .font(.system(size: 10, weight: .regular, design: .rounded))
                                .foregroundStyle(color)
                                .padding(.horizontal, CFSpacing.tight)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule().fill(color.opacity(0.1))
                                )
                        }
                    }
                }
            }
            .padding(CFSpacing.compact)
            .background(
                RoundedRectangle(cornerRadius: CFRadius.card)
                    .fill(Color.cfSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CFRadius.card)
                    .stroke(
                        isTopPick ? color : (isBorrowed ? color : Color.cfBorder),
                        style: isBorrowed
                            ? StrokeStyle(lineWidth: 1, dash: [6, 3])
                            : StrokeStyle(lineWidth: isTopPick ? 1.5 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Suggestion Hint Bar (compact, for compose screen)

struct SuggestionHintBar: View {
    let suggestion: CFSuggestion?
    var onTap: (() -> Void)?

    var body: some View {
        if let suggestion {
            Button(action: { onTap?() }) {
                HStack(spacing: CFSpacing.compact) {
                    // Lightbulb icon
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.cfTonic.opacity(0.6))

                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: CFSpacing.micro) {
                            Text("Next suggestion:")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.cfTextSecondary)
                            Text(suggestion.chord.symbol())
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.cfTonic)
                        }
                        Text("Tap for more suggestions")
                            .font(.system(size: 9, weight: .regular, design: .rounded))
                            .foregroundStyle(Color.cfTextTertiary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.cfTextTertiary)
                }
                .padding(.horizontal, CFSpacing.standard)
                .padding(.vertical, CFSpacing.compact)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.cfSurface)
                        .strokeBorder(Color.cfBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }
}
