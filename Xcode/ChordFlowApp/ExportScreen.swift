import SwiftUI
import UniformTypeIdentifiers
import ChordFlowShared

struct ExportScreen: View {
    @ObservedObject var vm: AppViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showSaveAlert = false
    @State private var saveProjectName = ""
    @State private var showFilePicker = false
    @State private var showShareSheet = false
    @State private var shareURL: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CFSpacing.spacious) {
                // Project summary card
                projectSummary

                // Export format cards
                if sizeClass == .regular {
                    // iPad: 3-column grid
                    HStack(alignment: .top, spacing: CFSpacing.standard) {
                        midiExportCard
                        jsonExportCard
                        auv3Card
                    }
                } else {
                    // iPhone: stacked
                    midiExportCard
                    jsonExportCard
                    auv3Card
                }

                // Saved projects
                savedProjectsList

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
            isPresented: $showFilePicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                vm.loadProject(from: url)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                ShareSheet(url: url)
            }
        }
        .onAppear {
            vm.refreshSavedProjects()
        }
    }

    // MARK: - Project Summary

    private var projectSummary: some View {
        HStack {
            VStack(alignment: .leading, spacing: CFSpacing.micro) {
                Text(vm.keyDisplayName)
                    .font(.cfHeading)
                    .foregroundStyle(Color.cfTextPrimary)

                HStack(spacing: CFSpacing.compact) {
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

    // MARK: - MIDI Export Card

    private var midiExportCard: some View {
        exportCard(
            icon: "pianokeys",
            title: "MIDI File",
            description: "Standard MIDI .mid for any DAW. Includes tempo, time signature, voicings, and patterns.",
            primaryAction: "Export MIDI",
            secondaryAction: "Share"
        ) {
            vm.exportMIDI()
        } shareAction: {
            vm.exportMIDI()
            let url = URL.documentsDirectory.appending(path: "ChordFlow-Export.mid")
            if FileManager.default.fileExists(atPath: url.path) {
                shareURL = url
                showShareSheet = true
            }
        }
    }

    // MARK: - JSON Export Card

    private var jsonExportCard: some View {
        exportCard(
            icon: "curlybraces",
            title: "Project JSON",
            description: "Save and reload full progression. Includes key, tempo, blocks, patterns, and extensions.",
            primaryAction: "Save As...",
            secondaryAction: "Share"
        ) {
            saveProjectName = vm.keyDisplayName.replacingOccurrences(of: " ", with: "-")
            showSaveAlert = true
        } shareAction: {
            vm.exportProject()
            let url = URL.documentsDirectory.appending(path: "ChordFlow-Project.json")
            if FileManager.default.fileExists(atPath: url.path) {
                shareURL = url
                showShareSheet = true
            }
        }
    }

    // MARK: - AUv3 Card

    private var auv3Card: some View {
        VStack(alignment: .leading, spacing: CFSpacing.compact) {
            HStack(spacing: CFSpacing.compact) {
                Image(systemName: "puzzlepiece.extension")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.cfDominant)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: CFRadius.button)
                            .fill(Color.cfDominant.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("AUv3 MIDI FX")
                        .font(.cfChordSymbol)
                        .foregroundStyle(Color.cfTextPrimary)
                    Text("Plugin for GarageBand, Logic, AUM")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.cfTextSecondary)
                }
            }

            Text("Real-time MIDI generation with 6 automatable parameters. Use as an Audio Unit plugin in any compatible host.")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(Color.cfTextTertiary)

            HStack(spacing: CFSpacing.compact) {
                Button {} label: {
                    Text("Configure AUv3")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.cfDominant)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(
                            RoundedRectangle(cornerRadius: CFRadius.button)
                                .fill(Color.cfDominant.opacity(0.12))
                                .strokeBorder(Color.cfDominant, lineWidth: 1)
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

    // MARK: - Export Card Template

    private func exportCard(
        icon: String,
        title: String,
        description: String,
        primaryAction: String,
        secondaryAction: String,
        action: @escaping () -> Void,
        shareAction: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: CFSpacing.compact) {
            HStack(spacing: CFSpacing.compact) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(Color.cfTonic)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: CFRadius.button)
                            .fill(Color.cfTonic.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.cfChordSymbol)
                        .foregroundStyle(Color.cfTextPrimary)
                }
            }

            Text(description)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(Color.cfTextTertiary)

            HStack(spacing: CFSpacing.compact) {
                Button(action: action) {
                    Text(primaryAction)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.cfBase)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(
                            RoundedRectangle(cornerRadius: CFRadius.button)
                                .fill(Color.cfTonic)
                        )
                }
                .buttonStyle(.plain)

                Button(action: shareAction) {
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

    // MARK: - Saved Projects

    private var savedProjectsList: some View {
        VStack(alignment: .leading, spacing: CFSpacing.tight) {
            HStack {
                Text("SAVED PROJECTS")
                    .font(.cfCaption)
                    .foregroundStyle(Color.cfTextSecondary)
                    .textCase(.uppercase)

                Spacer()

                Button {
                    showFilePicker = true
                } label: {
                    HStack(spacing: CFSpacing.micro) {
                        Image(systemName: "folder")
                            .font(.system(size: 11))
                        Text("Import")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(Color.cfTonic)
                }
                .buttonStyle(.plain)
            }

            if vm.savedProjects.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: CFSpacing.tight) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.cfTextTertiary)
                        Text("No saved projects yet")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(Color.cfTextTertiary)
                        Text("Use \"Save As...\" above to save your progression")
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(Color.cfTextTertiary.opacity(0.7))
                    }
                    .padding(.vertical, CFSpacing.spacious)
                    Spacer()
                }
            } else {
                ForEach(vm.savedProjects) { project in
                    savedProjectRow(project)
                }
            }
        }
    }

    private func savedProjectRow(_ project: AppViewModel.SavedProject) -> some View {
        HStack {
            Image(systemName: "doc.text")
                .font(.system(size: 14))
                .foregroundStyle(Color.cfTextTertiary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 1) {
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
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.cfTonic)
                    .padding(.horizontal, CFSpacing.tight)
                    .padding(.vertical, CFSpacing.micro)
                    .background(
                        RoundedRectangle(cornerRadius: CFRadius.small)
                            .fill(Color.cfTonic.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)

            Button {
                vm.deleteProject(fileName: project.fileName)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.cfDestructive.opacity(0.7))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, CFSpacing.tight)
        .padding(.horizontal, CFSpacing.compact)
        .background(
            RoundedRectangle(cornerRadius: CFRadius.button)
                .fill(Color.cfSurface)
        )
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
