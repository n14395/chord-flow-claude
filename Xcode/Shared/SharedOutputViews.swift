#if canImport(SwiftUI)
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Custom UTType

public extension UTType {
    static let chordFlowProject = UTType(exportedAs: "com.n14395.chordflow2.project")
}

// MARK: - File Document Wrapper

public struct ChordFlowDocument: FileDocument {
    public static var readableContentTypes: [UTType] { [.chordFlowProject, .json] }
    public static var writableContentTypes: [UTType] { [.chordFlowProject] }

    public var data: Data

    public init(data: Data) {
        self.data = data
    }

    public init(configuration: ReadConfiguration) throws {
        guard let fileData = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        data = fileData
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Section Header

public struct SharedSectionHeader: View {
    private let title: String
    private let icon: String

    public init(_ title: String, icon: String) {
        self.title = title
        self.icon = icon
    }

    public var body: some View {
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
}

// MARK: - Summary Badge

public struct SharedSummaryBadge: View {
    private let text: String
    private let icon: String

    public init(_ text: String, icon: String) {
        self.text = text
        self.icon = icon
    }

    public var body: some View {
        HStack(spacing: CFSpacing.micro) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.cfCaption)
        }
        .foregroundStyle(Color.cfTextSecondary)
    }
}

// MARK: - Project Summary Header

public struct SharedProjectSummaryHeader<VM: ChordFlowViewModel>: View {
    @ObservedObject private var vm: VM

    public init(vm: VM) {
        self.vm = vm
    }

    public var body: some View {
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
                    SharedSummaryBadge(vm.keyDisplayName, icon: "tuningfork")
                    SharedSummaryBadge("\(vm.barCount) bars", icon: "music.note.list")
                }
            }

            Spacer()

            // Mini progression strip
            if !vm.blocks.isEmpty {
                HStack(spacing: 2) {
                    ForEach(Array(vm.blocks.prefix(8).enumerated()), id: \.element.id) { index, block in
                        let fn = vm.harmonicFunction(forBlockAt: index)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(fn.color.opacity(0.4))
                            .frame(width: 12, height: 24)
                    }
                }
            }
        }
    }
}

// MARK: - Project Card (Save / Open / Share)

public struct SharedProjectCard<VM: ChordFlowViewModel>: View {
    @ObservedObject private var vm: VM
    private let onSave: () -> Void
    private let onOpen: () -> Void
    private let onShare: () -> Void

    public init(vm: VM, onSave: @escaping () -> Void, onOpen: @escaping () -> Void, onShare: @escaping () -> Void) {
        self.vm = vm
        self.onSave = onSave
        self.onOpen = onOpen
        self.onShare = onShare
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CFSpacing.compact) {
            SharedProjectSummaryHeader(vm: vm)

            Text("Save and reload full progressions. Includes key, tempo, blocks, patterns, and extensions.")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(Color.cfTextTertiary)

            Spacer(minLength: 0)

            HStack(spacing: CFSpacing.compact) {
                // Save
                Button(action: onSave) {
                    VStack(spacing: CFSpacing.micro) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 16))
                        Text("Save")
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

                // Open
                Button(action: onOpen) {
                    VStack(spacing: CFSpacing.micro) {
                        Image(systemName: "folder")
                            .font(.system(size: 16))
                        Text("Open")
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

                // Share
                Button(action: onShare) {
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
}

// MARK: - Import / Export Card

public struct SharedImportExportCard: View {
    private let onImport: () -> Void
    private let onExport: () -> Void

    public init(onImport: @escaping () -> Void, onExport: @escaping () -> Void) {
        self.onImport = onImport
        self.onExport = onExport
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CFSpacing.compact) {
            Text("Import .chordflow files from the filesystem, or export for backup and sharing.")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(Color.cfTextTertiary)

            HStack(spacing: CFSpacing.compact) {
                // Import
                Button(action: onImport) {
                    VStack(spacing: CFSpacing.micro) {
                        Image(systemName: "square.and.arrow.down.on.square")
                            .font(.system(size: 16))
                        Text("Import")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(Color.cfTextSecondary)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(
                        RoundedRectangle(cornerRadius: CFRadius.button)
                            .fill(Color.cfSurface)
                            .strokeBorder(Color.cfBorder, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)

                // Export
                Button(action: onExport) {
                    VStack(spacing: CFSpacing.micro) {
                        Image(systemName: "arrow.up.doc")
                            .font(.system(size: 16))
                        Text("Export")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(Color.cfTextSecondary)
                    .frame(maxWidth: .infinity, minHeight: 52)
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
}

// MARK: - Recently Saved List

public struct SharedRecentProjectsList<VM: ChordFlowViewModel>: View {
    @ObservedObject private var vm: VM
    private let onExploreAll: () -> Void
    @State private var deleteConfirmFileName: String?

    public init(vm: VM, onExploreAll: @escaping () -> Void) {
        self.vm = vm
        self.onExploreAll = onExploreAll
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CFSpacing.tight) {
            Text("Recently Saved")
                .font(.cfChordSymbol)
                .foregroundStyle(Color.cfTextPrimary)

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
                ForEach(Array(vm.savedProjects.prefix(5))) { project in
                    sharedSavedProjectRow(project, vm: vm, deleteConfirmFileName: $deleteConfirmFileName)
                }
                Spacer(minLength: 0)
            }

            // Explore all files
            Button(action: onExploreAll) {
                HStack(spacing: CFSpacing.tight) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 12))
                    Text("Explore all files...")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                }
                .foregroundStyle(Color.cfTonic)
                .frame(maxWidth: .infinity)
                .padding(.vertical, CFSpacing.compact)
                .background(
                    RoundedRectangle(cornerRadius: CFRadius.button)
                        .fill(Color.cfTonic.opacity(0.08))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(CFSpacing.standard)
        .background(
            RoundedRectangle(cornerRadius: CFRadius.card)
                .fill(Color.cfSurface)
                .strokeBorder(Color.cfBorder, lineWidth: 1)
        )
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
    }
}

// MARK: - Saved Project Row (shared helper)

private struct sharedSavedProjectRow<VM: ChordFlowViewModel>: View {
    let project: CFSavedProject
    @ObservedObject var vm: VM
    @Binding var deleteConfirmFileName: String?

    init(_ project: CFSavedProject, vm: VM, deleteConfirmFileName: Binding<String?>) {
        self.project = project
        self.vm = vm
        self._deleteConfirmFileName = deleteConfirmFileName
    }

    var body: some View {
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
                let url = CFAppGroup.projectsURL.appending(path: project.fileName)
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
}

// MARK: - All Files Modal

public struct SharedAllFilesModal<VM: ChordFlowViewModel>: View {
    @ObservedObject private var vm: VM
    @Binding private var isPresented: Bool
    @State private var deleteConfirmFileName: String?

    public init(vm: VM, isPresented: Binding<Bool>) {
        self.vm = vm
        self._isPresented = isPresented
    }

    public var body: some View {
        NavigationStack {
            Group {
                if vm.savedProjects.isEmpty {
                    VStack(spacing: CFSpacing.standard) {
                        Spacer()
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.cfTextTertiary)
                        Text("No saved projects")
                            .font(.cfHeading)
                            .foregroundStyle(Color.cfTextSecondary)
                        Text("Use \"Save\" to save your first project.")
                            .font(.cfBody)
                            .foregroundStyle(Color.cfTextTertiary)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(vm.savedProjects) { project in
                            allFilesRow(project)
                                .listRowBackground(Color.cfElevated)
                                .listRowSeparatorTint(Color.cfBorder)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.cfBackground)
            .navigationTitle("Saved Projects")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundStyle(Color.cfTonic)
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
        }
        .onAppear {
            vm.refreshSavedProjects()
        }
    }

    private func allFilesRow(_ project: CFSavedProject) -> some View {
        HStack(spacing: CFSpacing.compact) {
            Image(systemName: project.fileName.hasSuffix(".chordflow") ? "doc.badge.gearshape" : "doc.text")
                .font(.system(size: 18))
                .foregroundStyle(project.fileName.hasSuffix(".chordflow") ? Color.cfTonic : Color.cfTextTertiary)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(project.fileName)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.cfTextPrimary)
                    .lineLimit(1)
                HStack(spacing: CFSpacing.compact) {
                    Text(project.key)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.cfTextTertiary)
                    Text("\(project.blockCount) blocks")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.cfTextTertiary)
                    Text(project.date, style: .relative)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.cfTextTertiary)
                }
            }

            Spacer()

            Button {
                let url = CFAppGroup.projectsURL.appending(path: project.fileName)
                vm.loadProject(from: url)
                isPresented = false
            } label: {
                Text("Load")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.cfBase)
                    .padding(.horizontal, CFSpacing.standard)
                    .padding(.vertical, CFSpacing.compact)
                    .background(
                        RoundedRectangle(cornerRadius: CFRadius.button)
                            .fill(Color.cfTonic)
                    )
            }
            .buttonStyle(.plain)

            Button {
                deleteConfirmFileName = project.fileName
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.cfDestructive.opacity(0.7))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, CFSpacing.tight)
    }
}

// MARK: - MIDI Export Card

public struct SharedMIDIExportCard<VM: ChordFlowViewModel>: View {
    @ObservedObject private var vm: VM
    private let onShare: (() -> Void)?

    public init(vm: VM, onShare: (() -> Void)? = nil) {
        self.vm = vm
        self.onShare = onShare
    }

    public var body: some View {
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

                if let onShare {
                    Button {
                        onShare()
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
        }
        .padding(CFSpacing.standard)
        .background(
            RoundedRectangle(cornerRadius: CFRadius.card)
                .fill(Color.cfSurface)
                .strokeBorder(Color.cfBorder, lineWidth: 1)
        )
    }
}

// MARK: - AUv3 Status Card

public struct SharedAUv3StatusCard: View {
    private let isRunning: Bool

    public init(isRunning: Bool = false) {
        self.isRunning = isRunning
    }

    private var statusText: String { isRunning ? "Running" : "Available" }
    private var statusColor: Color { isRunning ? Color.cfSubdominant : Color.cfTonic }

    public var body: some View {
        VStack(alignment: .leading, spacing: CFSpacing.compact) {
            HStack(spacing: CFSpacing.compact) {
                Image(systemName: "puzzlepiece.extension")
                    .font(.system(size: 20))
                    .foregroundStyle(statusColor)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: CFRadius.button)
                            .fill(statusColor.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("AUv3 MIDI FX")
                        .font(.cfChordSymbol)
                        .foregroundStyle(Color.cfTextPrimary)
                    Text(statusText)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(statusColor)
                }
            }

            VStack(alignment: .leading, spacing: CFSpacing.tight) {
                SharedInfoRow(label: "Type", value: "MIDI Effect (aumi)")
                SharedInfoRow(label: "Manufacturer", value: "NWF1")
                SharedInfoRow(label: "SubType", value: "chrd")
                SharedInfoRow(label: "Parameters", value: "6 (Tonic, Mode, Tension, Pattern, Swing, Humanize)")
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
}

// MARK: - Transport Card

public struct SharedTransportCard<VM: ChordFlowViewModel>: View {
    @ObservedObject private var vm: VM
    private let transportMode: String
    private let tempoText: String?

    public init(vm: VM, transportMode: String = "Internal clock", tempoText: String? = nil) {
        self.vm = vm
        self.transportMode = transportMode
        self.tempoText = tempoText
    }

    public var body: some View {
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
                    Text(transportMode == "Host" ? "Host-controlled" : "Standalone")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.cfBorrowed)
                }
            }

            VStack(alignment: .leading, spacing: CFSpacing.tight) {
                SharedInfoRow(label: "Mode", value: transportMode)
                if let tempoText {
                    SharedInfoRow(label: "Tempo", value: tempoText)
                }
                SharedInfoRow(label: "Time Sig", value: "4/4")
                SharedInfoRow(label: "Status", value: vm.isPlaying ? "Playing" : "Stopped")
            }

            Text(transportMode == "Host"
                 ? "Transport and tempo are controlled by the host application."
                 : "In standalone mode, ChordFlow drives its own clock. When loaded as an AUv3, the host provides transport and tempo.")
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
}

// MARK: - Info Row

public struct SharedInfoRow: View {
    private let label: String
    private let value: String

    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }

    public var body: some View {
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
}

// MARK: - Share Sheet

#if canImport(UIKit)
import UIKit

public struct SharedShareSheet: UIViewControllerRepresentable {
    private let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
#endif
