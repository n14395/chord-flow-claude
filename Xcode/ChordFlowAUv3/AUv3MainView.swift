import SwiftUI
import UniformTypeIdentifiers
import ChordFlowShared

// MARK: - Main AUv3 View

struct AUv3View: View {
    @ObservedObject var vm: AUv3ViewModel
    @State private var showBorrowedPicker = false
    @State private var contextMenuBlockIndex: Int?

    // Output tab state
    @State private var showSaveAlert = false
    @State private var saveProjectName = ""
    @State private var showImportPicker = false
    @State private var showExportPicker = false
    @State private var showShareSheet = false
    @State private var shareURL: URL?
    @State private var exportDocument: ChordFlowDocument?
    @State private var showAllFilesModal = false

    private var defaultFileName: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HHmm"
        return "ChordFlow-\(f.string(from: Date()))"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            tabBar

            // Tab content
            Group {
                switch vm.selectedTab {
                case 0: composeTab
                case 1: suggestTab
                case 2: outputTab
                default: composeTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Playback bar with inline timeline (hidden on Output tab)
            if vm.selectedTab != 2 {
                playbackBar
                    .padding(.horizontal, CFSpacing.compact)
                    .padding(.bottom, CFSpacing.tight)

                // Debug info
                Text(vm.debugInfo)
                    .font(.system(size: 8, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.cfTextTertiary.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, CFSpacing.compact)
                    .padding(.bottom, CFSpacing.micro)
            }
        }
        .background(Color.cfBackground.ignoresSafeArea())
        .dismissBorrowedPicker(isExpanded: $showBorrowedPicker)
        .overlay {
            SharedBlockActionOverlay(vm: vm, blockIndex: $contextMenuBlockIndex)
        }
        .sheet(isPresented: $vm.showModeSheet) {
            modePickerSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.cfSurface)
        }
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
            isPresented: $showImportPicker,
            allowedContentTypes: [.chordFlowProject, .json],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                vm.loadProject(from: url)
            }
        }
        .fileExporter(
            isPresented: $showExportPicker,
            document: exportDocument,
            contentType: .chordFlowProject,
            defaultFilename: defaultFileName
        ) { result in
            switch result {
            case .success(let url):
                vm.status = "Exported: \(url.lastPathComponent)"
            case .failure(let error):
                vm.status = "Export failed: \(error.localizedDescription)"
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                SharedShareSheet(url: url)
            }
        }
        .sheet(isPresented: $showAllFilesModal) {
            SharedAllFilesModal(vm: vm, isPresented: $showAllFilesModal)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.cfBackground)
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: CFSpacing.tight) {
            tabButton(title: "Compose", tag: 0)
            tabButton(title: "Suggest", tag: 1)
            tabButton(title: "Files", tag: 2)
        }
        .padding(3)
        .background(
            Capsule()
                .fill(Color.cfSurface)
                .strokeBorder(Color.cfBorder.opacity(0.6), lineWidth: 1)
        )
        .padding(.horizontal, CFSpacing.spacious)
        .padding(.vertical, CFSpacing.compact)
    }

    private func tabButton(title: String, tag: Int) -> some View {
        let isSelected = vm.selectedTab == tag
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                vm.selectedTab = tag
            }
        } label: {
            Text(title)
                .font(.system(size: 15, weight: isSelected ? .semibold : .regular, design: .rounded))
                .foregroundStyle(isSelected ? Color.cfTonic : Color.cfTextTertiary)
                .padding(.horizontal, CFSpacing.spacious)
                .padding(.vertical, CFSpacing.compact)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.cfElevated : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Compose Tab

    private var composeTab: some View {
        HStack(alignment: .top, spacing: CFSpacing.spacious) {
            // Left column: Circle + controls
            ScrollView {
                VStack(spacing: CFSpacing.standard) {
                    SharedCircleOfFifthsView(vm: vm) { chord in
                        vm.addChord(chord)
                    }

                    controlsStrip
                }
                .padding(.bottom, CFSpacing.standard)
            }
            .frame(maxWidth: .infinity)

            // Right column: Chord detail
            ScrollView {
                VStack(spacing: CFSpacing.standard) {
                    SharedChordDetailPanel(vm: vm)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, CFSpacing.spacious)
        .padding(.top, CFSpacing.standard)
    }

    // MARK: - Suggest Tab

    private var suggestTab: some View {
        HStack(alignment: .top, spacing: CFSpacing.spacious) {
            // Left column: Circle + controls
            ScrollView {
                VStack(spacing: CFSpacing.standard) {
                    SharedCircleOfFifthsView(vm: vm) { chord in
                        vm.addChord(chord)
                    }

                    controlsStrip
                }
                .padding(.bottom, CFSpacing.standard)
            }
            .frame(maxWidth: .infinity)

            // Right column: Suggestions panel
            ScrollView {
                VStack(spacing: CFSpacing.standard) {
                    AUv3SuggestView(vm: vm)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, CFSpacing.spacious)
        .padding(.top, CFSpacing.standard)
    }

    // MARK: - Output Tab

    private var outputTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CFSpacing.spacious) {
                // Project section
                SharedSectionHeader("PROJECT", icon: "doc.badge.gearshape")
                HStack(alignment: .top, spacing: CFSpacing.standard) {
                    // Left column: Project card + Import/Export card
                    VStack(spacing: CFSpacing.standard) {
                        SharedProjectCard(
                            vm: vm,
                            onSave: {
                                saveProjectName = defaultFileName
                                showSaveAlert = true
                            },
                            onOpen: {
                                showAllFilesModal = true
                            },
                            onShare: {
                                vm.exportProject()
                                let url = URL.documentsDirectory.appending(path: "ChordFlow-Project.\(AUv3ViewModel.projectExtension)")
                                if FileManager.default.fileExists(atPath: url.path) {
                                    shareURL = url
                                    showShareSheet = true
                                }
                            }
                        )

                        SharedImportExportCard(
                            onImport: { showImportPicker = true },
                            onExport: {
                                if let data = vm.encodeProjectData() {
                                    exportDocument = ChordFlowDocument(data: data)
                                    showExportPicker = true
                                }
                            }
                        )
                    }

                    // Right column: Recently saved (5 items)
                    SharedRecentProjectsList(vm: vm) {
                        showAllFilesModal = true
                    }
                }

                // MIDI export
                SharedSectionHeader("MIDI EXPORT", icon: "pianokeys")
                SharedMIDIExportCard(vm: vm) {
                    vm.exportMIDI()
                    let url = URL.documentsDirectory.appending(path: "ChordFlow-Export.mid")
                    if FileManager.default.fileExists(atPath: url.path) {
                        shareURL = url
                        showShareSheet = true
                    }
                }
                .frame(maxWidth: 480)

                // Reference
                SharedSectionHeader("REFERENCE", icon: "info.circle")
                HStack(alignment: .top, spacing: CFSpacing.standard) {
                    SharedAUv3StatusCard(isRunning: true)
                    SharedTransportCard(vm: vm, transportMode: "Host")
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
        .background(Color.cfBackground)
        .onAppear {
            vm.refreshSavedProjects()
        }
    }

    // MARK: - Controls Strip

    private var controlsStrip: some View {
        VStack(spacing: CFSpacing.tight) {
            Divider().background(Color.cfBorder)

            HStack(spacing: CFSpacing.spacious) {
                tensionSelector
                octaveSelector
                SharedBorrowedPresetPicker(vm: vm, isExpanded: $showBorrowedPicker)
            }
        }
    }

    // MARK: - Tension Selector

    private var tensionSelector: some View {
        let levels: [(label: String, value: Float)] = [
            ("Triads", 0.2),
            ("7ths", 0.45),
            ("9ths", 0.6),
            ("11ths", 0.75),
            ("13ths", 0.9),
        ]

        return VStack(spacing: CFSpacing.micro) {
            HStack(spacing: CFSpacing.tight) {
                ForEach(levels, id: \.label) { level in
                    let isSelected = vm.tension == level.value
                    Button {
                        vm.setTension(level.value)
                    } label: {
                        Text(level.label)
                            .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                            .foregroundStyle(isSelected ? Color.cfTonic : Color.cfTextTertiary)
                            .padding(.horizontal, CFSpacing.compact)
                            .padding(.vertical, CFSpacing.tight)
                            .background(
                                RoundedRectangle(cornerRadius: CFRadius.button)
                                    .fill(isSelected ? Color.cfTonic.opacity(0.15) : Color.cfSurface)
                                    .strokeBorder(isSelected ? Color.cfTonic : Color.cfBorder,
                                                  lineWidth: isSelected ? 1.5 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("TENSION")
                .font(.system(size: 8, weight: .medium, design: .rounded))
                .foregroundStyle(Color.cfTextTertiary)
        }
    }

    // MARK: - Octave Selector

    private var octaveSelector: some View {
        VStack(spacing: CFSpacing.micro) {
            HStack(spacing: CFSpacing.tight) {
                Button {
                    vm.defaultOctave = max(vm.defaultOctave - 1, -3)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.cfDominant)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: CFRadius.button)
                                .fill(Color.cfDominant.opacity(0.08))
                                .strokeBorder(Color.cfDominant.opacity(0.5), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(vm.defaultOctave <= -3)

                Text(vm.defaultOctave == 0 ? "0" : (vm.defaultOctave > 0 ? "+\(vm.defaultOctave)" : "\(vm.defaultOctave)"))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.cfDominant)
                    .frame(width: 32)

                Button {
                    vm.defaultOctave = min(vm.defaultOctave + 1, 3)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.cfDominant)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: CFRadius.button)
                                .fill(Color.cfDominant.opacity(0.08))
                                .strokeBorder(Color.cfDominant.opacity(0.5), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(vm.defaultOctave >= 3)
            }

            Text("OCTAVE")
                .font(.system(size: 8, weight: .medium, design: .rounded))
                .foregroundStyle(Color.cfTextTertiary)
        }
    }

    // MARK: - Playback Bar (with inline timeline)

    private var playbackBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: CFSpacing.compact) {
                // Transport indicator (follows host)
                ZStack {
                    Circle()
                        .fill(vm.isPlaying ? Color.cfTonic : Color.cfSurface)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .strokeBorder(vm.isPlaying ? Color.cfTonic : Color.cfBorder, lineWidth: 1)
                        )
                    if vm.isPlaying {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.cfBase)
                            .offset(x: 1)
                    } else {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.cfTextTertiary)
                    }
                }

                // Status text
                VStack(alignment: .leading, spacing: 1) {
                    Text(vm.isPlaying ? "Playing" : "Stopped")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(vm.isPlaying ? Color.cfTonic : Color.cfTextSecondary)
                    Text(statusDetail)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.cfTextSecondary)
                }
                .fixedSize(horizontal: true, vertical: false)

                // Inline timeline
                SharedTimelineView(
                    vm: vm,
                    onBlockTap: { index in
                        vm.selectedBlockIndex = vm.selectedBlockIndex == index ? nil : index
                    },
                    onBlockLongPress: { index in
                        contextMenuBlockIndex = index
                    }
                )
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, CFSpacing.spacious)
            .padding(.vertical, CFSpacing.compact)
        }
        .background(
            RoundedRectangle(cornerRadius: CFRadius.card)
                .fill(Color.cfSurface)
                .strokeBorder(
                    vm.isPlaying ? Color.cfTonic.opacity(0.5) : Color.cfBorder,
                    lineWidth: vm.isPlaying ? 1.5 : 1
                )
        )
    }

    private var statusDetail: String {
        if vm.blocks.isEmpty {
            return "No chords"
        }
        if vm.isPlaying {
            return "Bar \(vm.currentBar) of \(vm.barCount)  |  \(vm.totalBeats) beats"
        }
        return "\(vm.barCount) chords  |  \(vm.totalBeats) beats"
    }

    // MARK: - Mode Picker Sheet

    private var modePickerSheet: some View {
        NavigationStack {
            List {
                ForEach(CFScaleMode.allCases, id: \.self) { scaleMode in
                    Button {
                        vm.setScaleMode(scaleMode)
                        vm.showModeSheet = false
                    } label: {
                        HStack {
                            Text(scaleMode.displayName())
                                .font(.cfBody)
                                .foregroundStyle(Color.cfTextPrimary)
                            Spacer()
                            if vm.scaleMode == scaleMode {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.cfTonic)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.cfSurface)
            .navigationTitle("Scale Mode")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
