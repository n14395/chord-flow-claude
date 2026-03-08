import SwiftUI
import ChordFlowShared

struct AUv3SuggestView: View {
    @ObservedObject var vm: AUv3ViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: CFSpacing.standard) {
            Text("Next Chord")
                .font(.cfHeading)
                .foregroundStyle(Color.cfTextPrimary)

            styleFilterPills
            suggestionList
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
                SharedSuggestionCardView(
                    suggestion: suggestion,
                    rank: index + 1,
                    function: function,
                    reasons: reasons,
                    isTopPick: index == 0,
                    onTap: {
                        vm.addChord(suggestion.chord)
                    },
                    onPreview: {
                        vm.previewChord(suggestion.chord)
                    }
                )
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
