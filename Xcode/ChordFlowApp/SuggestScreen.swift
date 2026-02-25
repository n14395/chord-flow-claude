import SwiftUI
import ChordFlowShared

struct SuggestScreen: View {
    @ObservedObject var vm: AppViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var styleFilter: String = "All"

    private let styleFilters = ["All", "Pop", "Jazz", "Neo-Soul", "Cinematic", "Exp."]

    var body: some View {
        if sizeClass == .regular {
            iPadLayout
        } else {
            iPhoneLayout
        }
    }

    // MARK: - iPhone Layout

    private var iPhoneLayout: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: CFSpacing.standard) {
                    // Header
                    Text("Next Chord")
                        .font(.cfHeading)
                        .foregroundStyle(Color.cfTextPrimary)
                        .padding(.horizontal, CFSpacing.spacious)

                    // Context strip
                    contextStrip
                        .padding(.horizontal, CFSpacing.spacious)

                    // Style filters
                    styleFilterPills
                        .padding(.horizontal, CFSpacing.spacious)

                    // Suggestion cards
                    suggestionList
                        .padding(.horizontal, CFSpacing.compact)
                }
                .padding(.top, CFSpacing.standard)
                .padding(.bottom, CFSpacing.page)
            }
        }
        .background(Color.cfBackground.ignoresSafeArea())
    }

    // MARK: - iPad Layout

    private var iPadLayout: some View {
        HStack(alignment: .top, spacing: CFSpacing.spacious) {
            // Left: Circle of Fifths
            VStack {
                CircleOfFifthsView(vm: vm) { chord in
                    vm.addChord(chord)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, CFSpacing.standard)

            // Right: Suggestions
            ScrollView {
                VStack(alignment: .leading, spacing: CFSpacing.standard) {
                    Text("Next Chord")
                        .font(.cfHeading)
                        .foregroundStyle(Color.cfTextPrimary)

                    contextStrip
                    styleFilterPills
                    suggestionList
                }
                .padding(.top, CFSpacing.standard)
                .padding(.trailing, CFSpacing.spacious)
                .padding(.bottom, CFSpacing.page)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.leading, CFSpacing.spacious)
        .background(Color.cfBackground.ignoresSafeArea())
    }

    // MARK: - Context Strip

    private var contextStrip: some View {
        VStack(alignment: .leading, spacing: CFSpacing.tight) {
            if vm.project.blocks.isEmpty {
                Text("No chords yet -- add some to get suggestions")
                    .font(.cfBody)
                    .foregroundStyle(Color.cfTextTertiary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: CFSpacing.tight) {
                        ForEach(Array(vm.project.blocks.enumerated()), id: \.element.id) { index, block in
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

                            if index < vm.project.blocks.count - 1 {
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
                ForEach(styleFilters, id: \.self) { filter in
                    let isActive = styleFilter == filter
                    Button {
                        styleFilter = filter
                        applyStyleFilter(filter)
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
                let function = suggestionFunction(suggestion)
                SuggestionCardView(
                    suggestion: suggestion,
                    rank: index + 1,
                    function: function,
                    reasons: AppViewModel.reasonPills(
                        for: suggestion,
                        key: vm.project.key,
                        previous: vm.project.blocks.last?.chord
                    ),
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

    // MARK: - Helpers

    private func applyStyleFilter(_ filter: String) {
        // Style filtering changes the borrowed preset to match the style flavor
        switch filter {
        case "Jazz":
            vm.borrowedPreset = .jazz
        case "Cinematic":
            vm.borrowedPreset = .cinematic
        case "Pop":
            vm.borrowedPreset = .conservative
        case "Neo-Soul":
            vm.borrowedPreset = .colorful
        case "Exp.":
            vm.borrowedPreset = .experimental
        default:
            break // "All" keeps current preset
        }
        vm.refreshChordButtons()
        vm.refreshSuggestions()
    }

    private func suggestionFunction(_ suggestion: CFSuggestion) -> HarmonicFunction {
        if let btn = vm.chordButtons.first(where: { $0.chord.root == suggestion.chord.root && $0.chord.quality == suggestion.chord.quality }) {
            return vm.harmonicFunction(for: btn)
        }
        return .tonic
    }
}
