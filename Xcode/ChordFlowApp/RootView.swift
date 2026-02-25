import SwiftUI
import ChordFlowShared

// MARK: - ViewModel

@MainActor
final class AppViewModel: ObservableObject {
    @Published var project = CFProjectDocument()
    @Published var chordButtons: [CFChordButton] = []
    @Published var tension: Double = 0.35
    @Published var swing: Double = 0.1
    @Published var isPlaying = false
    @Published var isPreviewing = false
    @Published var status = "Ready"

    private let playbackEngine = ProgressionPlaybackEngine()
    private let previewEngine = ProgressionPlaybackEngine()

    init() {
        playbackEngine.onPlaybackStateChange = { [weak self] playing in
            self?.isPlaying = playing
            if !playing { self?.status = "Ready" }
        }
        previewEngine.onPlaybackStateChange = { [weak self] playing in
            self?.isPreviewing = playing
        }
        refreshChordButtons()
    }

    func refreshChordButtons() {
        chordButtons = ChordFlowEngine.diatonicChords(
            key: project.key,
            tension: tension
        )
    }

    func addChord(_ chord: CFChord) {
        let block = CFSequenceBlock(
            barStart: project.blocks.count,
            beatStart: 0,
            lengthBeats: 4,
            chord: chord,
            pattern: .block
        )
        project.blocks.append(block)
    }

    func removeBlock(at offsets: IndexSet) {
        project.blocks.remove(atOffsets: offsets)
        // Re-number bars sequentially
        for i in project.blocks.indices {
            project.blocks[i].barStart = i
        }
    }

    func removeBlock(at index: Int) {
        guard project.blocks.indices.contains(index) else { return }
        project.blocks.remove(at: index)
        for i in project.blocks.indices {
            project.blocks[i].barStart = i
        }
    }

    func clearProgression() {
        project.blocks.removeAll()
    }

    func previewChord(_ chord: CFChord) {
        let block = CFSequenceBlock(
            barStart: 0, beatStart: 0, lengthBeats: 2,
            chord: chord, pattern: .block
        )
        let events = ChordFlowEngine.render(blocks: [block], swing: 0)
        previewEngine.play(events: events, tempo: project.tempo)
    }

    func togglePlayback() {
        if isPlaying {
            playbackEngine.stop()
            status = "Ready"
            return
        }
        guard !project.blocks.isEmpty else {
            status = "Add chords to play"
            return
        }
        let events = ChordFlowEngine.render(blocks: project.blocks, swing: swing)
        playbackEngine.play(events: events, tempo: project.tempo)
        status = "Playing \(project.blocks.count) chord(s) at \(Int(project.tempo.rounded())) BPM"
    }

    func exportMIDI() {
        let events = ChordFlowEngine.render(blocks: project.blocks, swing: swing)
        let data = MIDIFileWriter.export(events: events)
        let url = URL.documentsDirectory.appending(path: "ChordFlow-Export.mid")
        do {
            try data.write(to: url)
            status = "Exported: \(url.lastPathComponent)"
        } catch {
            status = "Export failed: \(error.localizedDescription)"
        }
    }

    func exportProject() {
        let url = URL.documentsDirectory.appending(path: "ChordFlow-Project.json")
        do {
            try ChordFlowEngine.encodeProject(project).write(to: url)
            status = "Exported: \(url.lastPathComponent)"
        } catch {
            status = "Export failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Root View

struct RootView: View {
    @StateObject private var vm = AppViewModel()

    var body: some View {
        TabView {
            composeTab
                .tabItem { Label("Compose", systemImage: "pianokeys") }
            exportTab
                .tabItem { Label("Export", systemImage: "square.and.arrow.up") }
        }
    }

    // MARK: - Compose Tab (main page)

    private var composeTab: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    keySelectorSection
                    controlsSection
                    chordButtonsSection
                    progressionSection
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 80) // room for playback bar
            }

            playbackBar
        }
    }

    // MARK: Key Selector

    private var keySelectorSection: some View {
        HStack(spacing: 12) {
            // Key picker
            VStack(alignment: .leading, spacing: 4) {
                Text("KEY").font(.caption2).foregroundStyle(.secondary)
                Picker("Key", selection: $vm.project.key.tonic) {
                    ForEach(CFNote.allCases, id: \.self) { note in
                        Text(note.display()).tag(note)
                    }
                }
                .pickerStyle(.menu)
                .tint(.primary)
            }

            // Mode picker
            VStack(alignment: .leading, spacing: 4) {
                Text("MODE").font(.caption2).foregroundStyle(.secondary)
                Picker("Mode", selection: $vm.project.key.mode) {
                    ForEach(CFScaleMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue.capitalized).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .tint(.primary)
            }

            Spacer()
        }
        .onChange(of: vm.project.key) { _, _ in vm.refreshChordButtons() }
    }

    // MARK: Controls (Tension, Swing, Tempo)

    private var controlsSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tension").font(.caption2).foregroundStyle(.secondary)
                    Slider(value: $vm.tension, in: 0...1)
                        .frame(maxWidth: .infinity)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Swing").font(.caption2).foregroundStyle(.secondary)
                    Slider(value: $vm.swing, in: 0...0.8)
                        .frame(maxWidth: .infinity)
                }
            }

            HStack {
                Text("Tempo").font(.caption2).foregroundStyle(.secondary)
                Slider(value: $vm.project.tempo, in: 60...180, step: 1)
                Text("\(Int(vm.project.tempo.rounded())) BPM")
                    .font(.caption).monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .trailing)
            }
        }
        .onChange(of: vm.tension) { _, _ in vm.refreshChordButtons() }
    }

    // MARK: Chord Buttons Grid

    private var chordButtonsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Diatonic chords
            Text("DIATONIC").font(.caption2).foregroundStyle(.secondary)
            let diatonic = vm.chordButtons.filter { !$0.isBorrowed }
            chordButtonGrid(chords: diatonic, isBorrowed: false)

            // Borrowed chords
            let borrowed = vm.chordButtons.filter { $0.isBorrowed }
            if !borrowed.isEmpty {
                Text("BORROWED").font(.caption2).foregroundStyle(.secondary)
                chordButtonGrid(chords: borrowed, isBorrowed: true)
            }
        }
    }

    private func chordButtonGrid(chords: [CFChordButton], isBorrowed: Bool) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: min(chords.count, 7))
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(chords) { btn in
                chordButton(btn, isBorrowed: isBorrowed)
            }
        }
    }

    private func chordButton(_ btn: CFChordButton, isBorrowed: Bool) -> some View {
        Button {
            vm.addChord(btn.chord)
        } label: {
            VStack(spacing: 2) {
                Text(btn.label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isBorrowed ? .secondary : .primary)
                Text(btn.chord.symbol())
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isBorrowed
                          ? Color.secondary.opacity(0.1)
                          : Color.accentColor.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isBorrowed
                                  ? Color.secondary.opacity(0.2)
                                  : Color.accentColor.opacity(0.3),
                                  lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Progression Strip

    private var progressionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("PROGRESSION").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                if !vm.project.blocks.isEmpty {
                    Button("Clear") {
                        vm.clearProgression()
                    }
                    .font(.caption2)
                    .foregroundStyle(.red)
                }
            }

            if vm.project.blocks.isEmpty {
                Text("Tap a chord above to start building")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(vm.project.blocks.enumerated()), id: \.element.id) { index, block in
                                progressionChip(block: block, index: index)
                                    .id(block.id)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onChange(of: vm.project.blocks.count) { _, _ in
                        if let last = vm.project.blocks.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .trailing)
                            }
                        }
                    }
                }
            }
        }
    }

    private func progressionChip(block: CFSequenceBlock, index: Int) -> some View {
        VStack(spacing: 2) {
            Text(block.chord.symbol())
                .font(.system(.callout, design: .rounded, weight: .semibold))
            Text("Bar \(index + 1)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 64, height: 56)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.accentColor.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1)
        )
        .onTapGesture {
            vm.previewChord(block.chord)
        }
        .contextMenu {
            Button(role: .destructive) {
                vm.removeBlock(at: index)
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
        // Swipe hint: on iOS, contextMenu + long press gives delete.
        // For additional swipe-to-delete we add a custom gesture:
        .gesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onEnded { value in
                    // Swipe up to remove
                    if value.translation.height < -40 {
                        withAnimation {
                            vm.removeBlock(at: index)
                        }
                    }
                }
        )
    }

    // MARK: Playback Bar

    private var playbackBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Button {
                    vm.togglePlayback()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: vm.isPlaying ? "stop.fill" : "play.fill")
                        Text(vm.isPlaying ? "Stop" : "Play")
                            .font(.subheadline.weight(.medium))
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Spacer()

                Text(vm.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                Text("\(Int(vm.project.tempo.rounded())) BPM")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
        }
    }

    // MARK: - Export Tab

    private var exportTab: some View {
        NavigationStack {
            Form {
                Section("MIDI & Project") {
                    Button("Export MIDI File") { vm.exportMIDI() }
                    Button("Export Project JSON") { vm.exportProject() }
                }

                Section("AUv3") {
                    Text("MIDI FX available via the ChordFlow AUv3 extension")
                        .font(.subheadline)
                    Text("Inter-app routing via Virtual MIDI is handled in the extension/host")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Text(vm.status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Export")
        }
    }
}
