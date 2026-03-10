#if canImport(SwiftUI)
import SwiftUI

public struct SharedSuggestionCardView: View {
    let suggestion: CFSuggestion
    let rank: Int
    let function: HarmonicFunction
    let reasons: [String]
    let isTopPick: Bool
    var onTap: (() -> Void)?
    var onPreview: (() -> Void)?

    public init(
        suggestion: CFSuggestion,
        rank: Int,
        function: HarmonicFunction,
        reasons: [String],
        isTopPick: Bool,
        onTap: (() -> Void)? = nil,
        onPreview: (() -> Void)? = nil
    ) {
        self.suggestion = suggestion
        self.rank = rank
        self.function = function
        self.reasons = reasons
        self.isTopPick = isTopPick
        self.onTap = onTap
        self.onPreview = onPreview
    }

    public var body: some View {
        let color = function.color
        let isBorrowed = function == .borrowed

        HStack(spacing: 0) {
            // Play/preview strip on the left
            Button {
                onPreview?()
            } label: {
                ZStack {
                    UnevenRoundedRectangle(
                        topLeadingRadius: CFRadius.card,
                        bottomLeadingRadius: CFRadius.card,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 0
                    )
                    .fill(color.opacity(0.6))
                    Image(systemName: "waveform")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.cfBase.opacity(0.85))
                }
                .frame(width: 36)
            }
            .buttonStyle(.plain)

            // Main card content (tappable to add chord)
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
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(
            RoundedRectangle(cornerRadius: CFRadius.card)
                .fill(Color.cfSurface)
        )
        .clipShape(RoundedRectangle(cornerRadius: CFRadius.card))
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
}
#endif
