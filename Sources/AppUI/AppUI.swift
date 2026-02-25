import Foundation
import ChordFlowModels
import SuggestionEngine
import SequenceEngine
import MIDIIO
import Persistence

#if canImport(SwiftUI)
import SwiftUI

@MainActor
public final class ChordFlowViewModel: ObservableObject {
    @Published public var project: ProjectDocument
    @Published public var suggestions: [SuggestionResult] = []
    @Published public var groove = GrooveSettings()

    private let suggestionEngine = HarmonicSuggestionEngine()
    private let renderer = SequenceRenderer()

    public init(project: ProjectDocument = ProjectDocument(keyContext: KeyContext(tonic: .c, mode: .major))) {
        self.project = project
        refreshSuggestions()
    }

    public func refreshSuggestions(previous: ChordToken? = nil) {
        let request = SuggestionRequest(
            keyContext: project.keyContext,
            previousChord: previous,
            melodyHint: nil,
            tensionLevel: 0.4,
            styleProfile: .pop
        )
        suggestions = suggestionEngine.suggest(request)
    }

    public func addSuggestion(_ result: SuggestionResult) {
        let block = SequenceBlock(
            barStart: project.blocks.count,
            beatStart: 0,
            lengthBeats: 4,
            chordToken: result.chordToken,
            patternPreset: .block
        )
        project.blocks.append(block)
        refreshSuggestions(previous: result.chordToken)
    }

    public func renderPreview(ppq: Int = 960) -> [MIDINoteEvent] {
        renderer.render(
            blocks: project.blocks,
            config: SequenceRenderConfig(ppq: ppq, groove: groove)
        )
    }
}

public struct ChordFlowRootView: View {
    @StateObject private var vm = ChordFlowViewModel()

    public init() {}

    public var body: some View {
        TabView {
            SuggestView(vm: vm)
                .tabItem { Label("Suggest", systemImage: "sparkles") }
            ArrangeView(vm: vm)
                .tabItem { Label("Arrange", systemImage: "square.grid.3x1.folder.badge.plus") }
            RouteView(vm: vm)
                .tabItem { Label("Route", systemImage: "dot.radiowaves.left.and.right") }
            SettingsView(vm: vm)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

private struct SuggestView: View {
    @ObservedObject var vm: ChordFlowViewModel

    var body: some View {
        NavigationStack {
            List(vm.suggestions, id: \ .chordToken) { suggestion in
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.chordToken.symbol(preference: vm.project.keyContext.accidentalPreference))
                        .font(.headline)
                    Text(suggestion.reasons.joined(separator: " • "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture { vm.addSuggestion(suggestion) }
            }
            .navigationTitle("Suggest")
        }
    }
}

private struct ArrangeView: View {
    @ObservedObject var vm: ChordFlowViewModel

    var body: some View {
        NavigationStack {
            List(vm.project.blocks) { block in
                HStack {
                    Text("Bar \(block.barStart + 1)")
                    Spacer()
                    Text(block.chordToken.symbol(preference: vm.project.keyContext.accidentalPreference))
                    Text(block.patternPreset.rawValue)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Arrange")
        }
    }
}

private struct RouteView: View {
    @ObservedObject var vm: ChordFlowViewModel

    var body: some View {
        NavigationStack {
            Form {
                Picker("Output", selection: $vm.project.routingConfig.outputMode) {
                    ForEach(OutputMode.allCases, id: \ .self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                Picker("Clock", selection: $vm.project.routingConfig.clockMode) {
                    ForEach(ClockMode.allCases, id: \ .self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                Text("Rendered events: \(vm.renderPreview().count)")
            }
            .navigationTitle("Route")
        }
    }
}

private struct SettingsView: View {
    @ObservedObject var vm: ChordFlowViewModel

    var body: some View {
        NavigationStack {
            Form {
                Picker("Tonic", selection: $vm.project.keyContext.tonic) {
                    ForEach(NoteName.allCases, id: \ .self) { note in
                        Text(note.display(preference: vm.project.keyContext.accidentalPreference)).tag(note)
                    }
                }
                Picker("Mode", selection: $vm.project.keyContext.mode) {
                    ForEach(ScaleMode.allCases, id: \ .self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                Slider(value: $vm.groove.swing, in: 0...0.8) {
                    Text("Swing")
                }
                Text("Swing: \(Int(vm.groove.swing * 100))%")
            }
            .navigationTitle("Settings")
            .onChange(of: vm.project.keyContext) { _, _ in vm.refreshSuggestions() }
        }
    }
}

#else
public struct ChordFlowRootView {
    public init() {}
}
#endif
