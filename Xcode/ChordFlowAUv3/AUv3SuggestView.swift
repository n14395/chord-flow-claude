import SwiftUI
import ChordFlowShared

struct AUv3SuggestView: View {
    @ObservedObject var vm: AUv3ViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CFSpacing.standard) {
                Text("Next Chord")
                    .font(.cfHeading)
                    .foregroundStyle(Color.cfTextPrimary)
                    .padding(.horizontal, CFSpacing.spacious)

                contextStrip
                    .padding(.horizontal, CFSpacing.spacious)

                styleFilterPills
                    .padding(.horizontal, CFSpacing.spacious)

                suggestionList
                    .padding(.horizontal, CFSpacing.compact)
            }
            .padding(.top, CFSpacing.standard)
            .padding(.bottom, CFSpacing.page)
        }
    }

    // MARK: - Context Strip

    private var contextStrip: some View {
        VStack(alignment: .leading, spacing: CFSpacing.tight) {
            if vm.blocks.isEmpty {
                Text("No chords yet -- add some to get suggestions")
                    .font(.cfBody)
                    .foregroundStyle(Color.cfTextTertiary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: CFSpacing.tight) {
                        ForEach(Array(vm.blocks.enumerated()), id: \.element.id) { index, block in
                            let fn = vm.harmonicFunction(forBlockAt: index)
                            Text(block.chord.symbol())
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(fn.color)
                                .padding(.horizontal, CFSpacing.tight)
                                .padding(.vertical, CFSpacing.micro)
                                .background(
                                    RoundedRectangle(cornerRadius: CFRadius.button)
                                        .fill(fn.color.opacity(0.12))
                                )

                            if index < vm.blocks.count - 1 {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.cfTextTertiary)
                            }
                        }

                        Image(systemName: "arrow.right")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.cfTextTertiary)
                        Text("?")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.cfTextSecondary)
                            .frame(width: 32, height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: CFRadius.button)
                                    .strokeBorder(Color.cfBorder, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            )
                    }
                }
            }
        }
    }

    // MARK: - Style Filter Pills

    private var styleFilterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CFSpacing.tight) {
                ForEach(vm.styleFilters, id: \.self) { filter in
                    let isActive = vm.styleFilter == filter
                    Button {
                        vm.applyStyleFilter(filter)
                    } label: {
                        Text(filter)
                            .font(.system(size: 12, weight: isActive ? .semibold : .regular, design: .rounded))
                            .foregroundStyle(isActive ? Color.cfTonic : Color.cfTextSecondary)
                            .padding(.horizontal, CFSpacing.compact)
                            .padding(.vertical, CFSpacing.tight)
                            .background(
                                Capsule()
                                    .fill(isActive ? Color.cfTonic.opacity(0.15) : Color.cfSurface)
                                    .strokeBorder(isActive ? Color.cfTonic : Color.cfBorder,
                                                  lineWidth: isActive ? 1.5 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Suggestion List

    private var suggestionList: some View {
        VStack(spacing: CFSpacing.tight) {
            ForEach(Array(vm.suggestions.enumerated()), id: \.offset) { index, suggestion in
                let function = vm.suggestionFunction(suggestion)
                let reasons = AUv3ViewModel.reasonPills(
                    for: suggestion,
                    key: vm.key,
                    previous: vm.blocks.last?.chord
                )
                AUv3SuggestionCardView(
                    suggestion: suggestion,
                    rank: index + 1,
                    function: function,
                    reasons: reasons,
                    isTopPick: index == 0
                ) {
                    vm.addChord(suggestion.chord)
                }
            }

            if vm.suggestions.isEmpty {
                VStack(spacing: CFSpacing.tight) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.cfTextTertiary)
                    Text("Add chords to see suggestions")
                        .font(.cfBody)
                        .foregroundStyle(Color.cfTextTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, CFSpacing.page)
            }
        }
    }
}

// MARK: - Suggestion Card

struct AUv3SuggestionCardView: View {
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
                ZStack {
                    Circle()
                        .fill(isTopPick ? color.opacity(0.2) : Color.cfBorder)
                        .frame(width: 28, height: 28)
                    Text("\(rank)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(isTopPick ? color : Color.cfTextSecondary)
                }

                VStack(alignment: .leading, spacing: CFSpacing.micro) {
                    HStack(spacing: CFSpacing.tight) {
                        Text(suggestion.chord.symbol())
                            .font(.cfChordSymbol)
                            .foregroundStyle(color)
                        Text(function.label)
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(color.opacity(0.6))
                        Spacer()
                    }

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

                    HStack(spacing: CFSpacing.micro) {
                        ForEach(reasons, id: \.self) { reason in
                            Text(reason)
                                .font(.system(size: 10, weight: .regular, design: .rounded))
                                .foregroundStyle(color)
                                .padding(.horizontal, CFSpacing.tight)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(color.opacity(0.1)))
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
