import SwiftUI
import UniformTypeIdentifiers
import ChordFlowShared

// MARK: - File Document Wrapper

struct ChordFlowDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.chordFlowProject, .json] }
    static var writableContentTypes: [UTType] { [.chordFlowProject] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let fileData = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        data = fileData
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Output Screen

struct OutputScreen: View {
    @ObservedObject var vm: AppViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showSaveAlert = false
    @State private var saveProjectName = ""
    @State private var showOpenPicker = false
    @State private var showSavePicker = false
    @State private var showShareSheet = false
    @State private var shareURL: URL?
    @State private var exportDocument: ChordFlowDocument?
    @State private var deleteConfirmFileName: String?

    private var defaultFileName: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HHmm"
        return "ChordFlow-\(f.string(from: Date()))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CFSpacing.spacious) {
                // Project save/load + saved projects (top section)
                sectionHeader("PROJECT", icon: "doc.badge.gearshape")
                if sizeClass == .regular {
                    HStack(alignment: .top, spacing: CFSpacing.standard) {
                        projectCard
                        recentProjectsList
                    }
                } else {
                    projectCard
                    recentProjectsList
                }

                // Live Routing section
                sectionHeader("LIVE ROUTING", icon: "antenna.radiowaves.left.and.right")
                liveRoutingCard

                // MIDI export
                sectionHeader("MIDI EXPORT", icon: "pianokeys")
                midiExportCard
                    .frame(maxWidth: 480)

                // Reference info (full cards)
                sectionHeader("REFERENCE", icon: "info.circle")
                if sizeClass == .regular {
                    HStack(alignment: .top, spacing: CFSpacing.standard) {
                        auv3StatusCard
                        transportCard
                    }
                } else {
                    auv3StatusCard
                    transportCard
                }

                // Status
                if !vm.status.isEmpty && vm.status != "Ready" {
                    Text(vm.status)
                        .font(.cfBody)
                        .foregroundStyle(Color.cfTextSecondary)
                        .padding(.horizontal, CFSpacing.standard)
                }
            }
            .padding(.horizontal, CFSpacing.spacious)
            .padding(.top, CFSpacing.standard)
            .padding(.bottom, CFSpacing.page)
        }
        .background(Color.cfBackground.ignoresSafeArea())
        .alert("Save Project", isPresented: $showSaveAlert) {
            TextField("Project name", text: $saveProjectName)
            Button("Save") {
                guard !saveProjectName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                vm.saveProjectAs(name: saveProjectName)
                saveProjectName = ""
            }
            Button("Cancel", role: .cancel) { saveProjectName = "" }
        } message: {
            Text("Enter a name for this project")
        }
        .fileImporter(
            isPresented: $showOpenPicker,
            allowedContentTypes: [.chordFlowProject, .json],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                vm.loadProject(from: url)
            }
        }
        .fileExporter(
            isPresented: $showSavePicker,
            document: exportDocument,
            contentType: .chordFlowProject,
            defaultFilename: defaultFileName
        ) { result in
            switch result {
            case .success(let url):
                vm.status = "Saved: \(url.lastPathComponent)"
                vm.refreshSavedProjects()
            case .failure(let error):
                vm.status = "Save failed: \(error.localizedDescription)"
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                ShareSheet(url: url)
            }
        }
        .alert("Delete Project", isPresented: Binding(
            get: { deleteConfirmFileName != nil },
            set: { if !$0 { deleteConfirmFileName = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let name = deleteConfirmFileName {
                    vm.deleteProject(fileName: name)
                    deleteConfirmFileName = nil
                }
            }
            Button("Cancel", role: .cancel) { deleteConfirmFileName = nil }
        } message: {
            Text("Are you sure you want to delete \"\(deleteConfirmFileName ?? "")\"? This cannot be undone.")
        }
        .onAppear {
            vm.refreshSavedProjects()
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: CFSpacing.tight) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.cfTextTertiary)
            Text(title)
                .font(.cfCaption)
                .foregroundStyle(Color.cfTextTertiary)
        }
        .padding(.top, CFSpacing.tight)
    }

    // MARK: - Project Card

    private var projectCard: some View {
        VStack(alignment: .leading, spacing: CFSpacing.compact) {
            // Header with summary
            HStack(spacing: CFSpacing.compact) {
                Image(systemName: "doc.badge.gearshape")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.cfTonic)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: CFRadius.button)
                            .fill(Color.cfTonic.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("This Project")
                        .font(.cfHeading)
                        .foregroundStyle(Color.cfTextPrimary)

                    HStack(spacing: CFSpacing.compact) {
                        summaryBadge(vm.keyDisplayName, icon: "tuningfork")
                        summaryBadge("\(vm.barCount) bars", icon: "music.note.list")
                        summaryBadge("\(Int(vm.project.tempo.rounded())) BPM", icon: "metronome")
                    }
                }

                Spacer()

                // Mini progression strip
                if !vm.project.blocks.isEmpty {
                    HStack(spacing: 2) {
                        ForEach(Array(vm.project.blocks.prefix(8).enumerated()), id: \.element.id) { index, block in
                            let fn = vm.harmonicFunction(forBlockAt: index)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(fn.color.opacity(0.4))
                                .frame(width: 12, height: 24)
                        }
                    }
                }
            }

            Text("Save and reload full progressions. Includes key, tempo, blocks, patterns, and extensions.")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(Color.cfTextTertiary)

            Spacer(minLength: 0)

            // Primary row: Save To... and Open
            HStack(spacing: CFSpacing.compact) {
                Button {
                    if let data = vm.encodeProjectData() {
                        exportDocument = ChordFlowDocument(data: data)
                        showSavePicker = true
                    }
                } label: {
                    VStack(spacing: CFSpacing.micro) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 16))
                        Text("Save To...")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(Color.cfBase)
                    .frame(maxWidth: .infinity, minHeight: 62)
                    .background(
                        RoundedRectangle(cornerRadius: CFRadius.button)
                            .fill(Color.cfTonic)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    showOpenPicker = true
                } label: {
                    VStack(spacing: CFSpacing.micro) {
                        Image(systemName: "folder")
                            .font(.system(size: 16))
                        Text("Open...")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(Color.cfTonic)
                    .frame(maxWidth: .infinity, minHeight: 62)
                    .background(
                        RoundedRectangle(cornerRadius: CFRadius.button)
                            .fill(Color.cfTonic.opacity(0.12))
                            .strokeBorder(Color.cfTonic, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    saveProjectName = defaultFileName
                    showSaveAlert = true
                } label: {
                    VStack(spacing: CFSpacing.micro) {
                        Image(systemName: "tray.and.arrow.down")
                            .font(.system(size: 16))
                        Text("Quick Save")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(Color.cfTextSecondary)
                    .frame(maxWidth: .infinity, minHeight: 62)
                    .background(
                        RoundedRectangle(cornerRadius: CFRadius.button)
                            .fill(Color.cfSurface)
                            .strokeBorder(Color.cfBorder, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    vm.exportProject()
                    let url = URL.documentsDirectory.appending(path: "ChordFlow-Project.\(AppViewModel.projectExtension)")
                    if FileManager.default.fileExists(atPath: url.path) {
                        shareURL = url
                        showShareSheet = true
                    }
                } label: {
                    VStack(spacing: CFSpacing.micro) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16))
                        Text("Share")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(Color.cfTextSecondary)
                    .frame(maxWidth: .infinity, minHeight: 62)
                    .background(
                        RoundedRectangle(cornerRadius: CFRadius.button)
                            .fill(Color.cfSurface)
                            .strokeBorder(Color.cfBorder, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(CFSpacing.standard)
        .background(
            RoundedRectangle(cornerRadius: CFRadius.card)
                .fill(Color.cfSurface)
                .strokeBorder(Color.cfBorder, lineWidth: 1)
        )
    }

    private func summaryBadge(_ text: String, icon: String) -> some View {
        HStack(spacing: CFSpacing.micro) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.cfCaption)
        }
        .foregroundStyle(Color.cfTextSecondary)
    }

    // MARK: - Saved Projects

    private var recentProjectsList: some View {
        VStack(alignment: .leading, spacing: CFSpacing.tight) {
            HStack {
                Text("Recently Saved")
                    .font(.cfChordSymbol)
                    .foregroundStyle(Color.cfTextPrimary)

                Spacer()

                Button {
                    showOpenPicker = true
                } label: {
                    HStack(spacing: CFSpacing.micro) {
                        Image(systemName: "folder")
                            .font(.system(size: 11))
                        Text("Open...")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(Color.cfTonic)
                }
                .buttonStyle(.plain)
            }

            if vm.savedProjects.isEmpty {
                Spacer(minLength: 0)
                HStack {
                    Spacer()
                    VStack(spacing: CFSpacing.tight) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.cfTextTertiary)
                        Text("No saved projects yet")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(Color.cfTextTertiary)
                    }
                    Spacer()
                }
                Spacer(minLength: 0)
            } else {
                ForEach(Array(vm.savedProjects.prefix(3))) { project in
                    savedProjectRow(project)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(CFSpacing.standard)
        .background(
            RoundedRectangle(cornerRadius: CFRadius.card)
                .fill(Color.cfSurface)
                .strokeBorder(Color.cfBorder, lineWidth: 1)
        )
    }

    private func savedProjectRow(_ project: AppViewModel.SavedProject) -> some View {
        HStack(spacing: CFSpacing.compact) {
            Image(systemName: project.fileName.hasSuffix(".chordflow") ? "doc.badge.gearshape" : "doc.text")
                .font(.system(size: 16))
                .foregroundStyle(project.fileName.hasSuffix(".chordflow") ? Color.cfTonic : Color.cfTextTertiary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(project.fileName)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.cfTextPrimary)
                    .lineLimit(1)
                HStack(spacing: CFSpacing.tight) {
                    Text(project.key)
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.cfTextTertiary)
                    Text("\(project.blockCount) blocks")
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.cfTextTertiary)
                    Text(project.date, style: .relative)
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.cfTextTertiary)
                }
            }

            Spacer()

            Button {
                let url = URL.documentsDirectory.appending(path: project.fileName)
                vm.loadProject(from: url)
            } label: {
                Text("Load")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.cfTonic)
                    .padding(.horizontal, CFSpacing.compact)
                    .padding(.vertical, CFSpacing.tight)
                    .background(
                        RoundedRectangle(cornerRadius: CFRadius.button)
                            .fill(Color.cfTonic.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)

            Button {
                deleteConfirmFileName = project.fileName
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.cfDestructive.opacity(0.7))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, CFSpacing.compact)
        .padding(.horizontal, CFSpacing.compact)
        .background(
            RoundedRectangle(cornerRadius: CFRadius.button)
                .fill(Color.cfElevated)
        )
    }

    // MARK: - MIDI Export Card

    private var midiExportCard: some View {
        VStack(alignment: .leading, spacing: CFSpacing.compact) {
            Text("Standard MIDI for any DAW. Includes tempo, time signature, voicings, and patterns.")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(Color.cfTextTertiary)

            HStack(spacing: CFSpacing.compact) {
                Button {
                    vm.exportMIDI()
                } label: {
                    HStack(spacing: CFSpacing.micro) {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 12))
                        Text("Export .mid")
                    }
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.cfBase)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(
                        RoundedRectangle(cornerRadius: CFRadius.button)
                            .fill(Color.cfTonic)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    vm.exportMIDI()
                    let url = URL.documentsDirectory.appending(path: "ChordFlow-Export.mid")
                    if FileManager.default.fileExists(atPath: url.path) {
                        shareURL = url
                        showShareSheet = true
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.cfTextSecondary)
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: CFRadius.button)
                                .fill(Color.cfSurface)
                                .strokeBorder(Color.cfBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(CFSpacing.standard)
        .background(
            RoundedRectangle(cornerRadius: CFRadius.card)
                .fill(Color.cfSurface)
                .strokeBorder(Color.cfBorder, lineWidth: 1)
        )
    }

    // MARK: - Live Routing Card (text left, toggle right, channel strip below)

    private var liveRoutingCard: some View {
        VStack(alignment: .leading, spacing: CFSpacing.compact) {
            // Top row: description left, toggle right
            HStack(alignment: .top, spacing: CFSpacing.standard) {
                // Left: icon, title, status text
                VStack(alignment: .leading, spacing: CFSpacing.compact) {
                    HStack(spacing: CFSpacing.compact) {
                        Image(systemName: "cable.connector")
                            .font(.system(size: 22))
                            .foregroundStyle(vm.midiOutputEnabled ? Color.cfSubdominant : Color.cfTextTertiary)
                            .frame(width: 40, height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: CFRadius.button)
                                    .fill((vm.midiOutputEnabled ? Color.cfSubdominant : Color.cfTextTertiary).opacity(0.12))
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text("CoreMIDI Output")
                                .font(.cfChordSymbol)
                                .foregroundStyle(Color.cfTextPrimary)
                            Text(vm.midiOutputEnabled ? "Active" : "Inactive")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(vm.midiOutputEnabled ? Color.cfSubdominant : Color.cfTextTertiary)
                        }
                    }

                    if vm.midiOutputEnabled {
                        HStack(spacing: CFSpacing.micro) {
                            statusDot(color: .cfSubdominant)
                            Text("Source: \(vm.midiOutput.sourceName)")
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                .foregroundStyle(Color.cfTextSecondary)
                        }

                        Text("Other apps can receive MIDI from \"\(vm.midiOutput.sourceName)\" when you play or preview chords.")
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(Color.cfTextTertiary)
                    } else if let error = vm.midiOutput.lastError {
                        HStack(spacing: CFSpacing.micro) {
                            statusDot(color: .cfDestructive)
                            Text(error)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color.cfDestructive)
                        }
                    } else {
                        Text("Enable to broadcast MIDI notes to other apps and hardware via CoreMIDI virtual port.")
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(Color.cfTextTertiary)
                    }
                }

                // Right: toggle
                Toggle("", isOn: Binding(
                    get: { vm.midiOutputEnabled },
                    set: { _ in vm.toggleMIDIOutput() }
                ))
                .tint(Color.cfSubdominant)
                .labelsHidden()
            }

            // Divider
            Rectangle()
                .fill(Color.cfBorder)
                .frame(height: 1)

            // Channel grid: 2 rows of 8
            VStack(alignment: .leading, spacing: CFSpacing.micro) {
                HStack(spacing: CFSpacing.tight) {
                    Image(systemName: "number")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.cfDominant)
                    Text("Channel \(vm.midiChannel + 1)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.cfDominant)
                }

                channelGrid
            }
        }
        .padding(CFSpacing.standard)
        .frame(maxWidth: 560)
        .background(
            RoundedRectangle(cornerRadius: CFRadius.card)
                .fill(Color.cfSurface)
                .strokeBorder(vm.midiOutputEnabled ? Color.cfSubdominant.opacity(0.3) : Color.cfBorder, lineWidth: 1)
        )
    }

    private var channelGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: CFSpacing.micro), count: 8), spacing: CFSpacing.micro) {
            ForEach(0..<16) { ch in
                let isSelected = vm.midiChannel == UInt8(ch)
                Button {
                    vm.midiChannel = UInt8(ch)
                } label: {
                    Text("\(ch + 1)")
                        .font(.system(size: 12, weight: isSelected ? .bold : .regular, design: .monospaced))
                        .foregroundStyle(isSelected ? Color.cfBase : Color.cfTextSecondary)
                        .frame(maxWidth: .infinity, minHeight: 30)
                        .background(
                            RoundedRectangle(cornerRadius: CFRadius.small)
                                .fill(isSelected ? Color.cfDominant : Color.cfElevated)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - AUv3 Status Card

    private var auv3StatusCard: some View {
        VStack(alignment: .leading, spacing: CFSpacing.compact) {
            HStack(spacing: CFSpacing.compact) {
                Image(systemName: "puzzlepiece.extension")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.cfTonic)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: CFRadius.button)
                            .fill(Color.cfTonic.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("AUv3 MIDI FX")
                        .font(.cfChordSymbol)
                        .foregroundStyle(Color.cfTextPrimary)
                    Text("Available")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.cfTonic)
                }
            }

            VStack(alignment: .leading, spacing: CFSpacing.tight) {
                infoRow(label: "Type", value: "MIDI Effect (aumi)")
                infoRow(label: "Manufacturer", value: "NWF1")
                infoRow(label: "SubType", value: "chrd")
                infoRow(label: "Parameters", value: "6 (Tonic, Mode, Tension, Pattern, Swing, Humanize)")
            }

            Text("Load \"ChordFlow MIDI FX\" as an Audio Unit in Logic Pro, AUM, GarageBand, or any compatible host.")
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(Color.cfTextTertiary)
        }
        .padding(CFSpacing.standard)
        .background(
            RoundedRectangle(cornerRadius: CFRadius.card)
                .fill(Color.cfSurface)
                .strokeBorder(Color.cfBorder, lineWidth: 1)
        )
    }

    // MARK: - Transport Card

    private var transportCard: some View {
        VStack(alignment: .leading, spacing: CFSpacing.compact) {
            HStack(spacing: CFSpacing.compact) {
                Image(systemName: "clock.arrow.2.circlepath")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.cfBorrowed)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: CFRadius.button)
                            .fill(Color.cfBorrowed.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Transport & Clock")
                        .font(.cfChordSymbol)
                        .foregroundStyle(Color.cfTextPrimary)
                    Text("Standalone")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.cfBorrowed)
                }
            }

            VStack(alignment: .leading, spacing: CFSpacing.tight) {
                infoRow(label: "Mode", value: "Internal clock")
                infoRow(label: "Tempo", value: "\(Int(vm.project.tempo.rounded())) BPM")
                infoRow(label: "Time Sig", value: "4/4")
                infoRow(label: "Status", value: vm.isPlaying ? "Playing" : "Stopped")
            }

            Text("In standalone mode, ChordFlow drives its own clock. When loaded as an AUv3, the host provides transport and tempo.")
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(Color.cfTextTertiary)
        }
        .padding(CFSpacing.standard)
        .background(
            RoundedRectangle(cornerRadius: CFRadius.card)
                .fill(Color.cfSurface)
                .strokeBorder(Color.cfBorder, lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color.cfTextTertiary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(Color.cfTextSecondary)
        }
    }

    private func statusDot(color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
