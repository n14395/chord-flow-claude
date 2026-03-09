import SwiftUI
import UniformTypeIdentifiers
import ChordFlowShared

// MARK: - Output Screen

struct OutputScreen: View {
    @ObservedObject var vm: AppViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass
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
        ScrollView {
            VStack(alignment: .leading, spacing: CFSpacing.spacious) {
                // Project save/load + saved projects (top section)
                SharedSectionHeader("PROJECT", icon: "doc.badge.gearshape")
                if sizeClass == .regular {
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
                                    let url = URL.documentsDirectory.appending(path: "ChordFlow-Project.\(AppViewModel.projectExtension)")
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
                } else {
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
                            let url = URL.documentsDirectory.appending(path: "ChordFlow-Project.\(AppViewModel.projectExtension)")
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

                    SharedRecentProjectsList(vm: vm) {
                        showAllFilesModal = true
                    }
                }

                // Live Routing section
                SharedSectionHeader("LIVE ROUTING", icon: "antenna.radiowaves.left.and.right")
                liveRoutingCard

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

                // Reference info (full cards)
                SharedSectionHeader("REFERENCE", icon: "info.circle")
                if sizeClass == .regular {
                    HStack(alignment: .top, spacing: CFSpacing.standard) {
                        SharedAUv3StatusCard()
                        SharedTransportCard(vm: vm, tempoText: "\(Int(vm.project.tempo.rounded())) BPM")
                    }
                } else {
                    SharedAUv3StatusCard()
                    SharedTransportCard(vm: vm, tempoText: "\(Int(vm.project.tempo.rounded())) BPM")
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
        .onAppear {
            vm.refreshSavedProjects()
        }
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

    // MARK: - Helpers

    private func statusDot(color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
    }
}
