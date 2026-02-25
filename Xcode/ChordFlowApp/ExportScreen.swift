import SwiftUI
import ChordFlowShared

struct ExportScreen: View {
    @ObservedObject var vm: AppViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass

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

                // Recent exports
                recentExports

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
        }
    }

    // MARK: - JSON Export Card

    private var jsonExportCard: some View {
        exportCard(
            icon: "curlybraces",
            title: "Project JSON",
            description: "Save and reload full progression. Includes key, tempo, blocks, patterns, and extensions.",
            primaryAction: "Save Project",
            secondaryAction: "Share"
        ) {
            vm.exportProject()
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
        action: @escaping () -> Void
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

                Button {} label: {
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

    // MARK: - Recent Exports

    private var recentExports: some View {
        VStack(alignment: .leading, spacing: CFSpacing.tight) {
            Text("RECENT EXPORTS")
                .font(.cfCaption)
                .foregroundStyle(Color.cfTextSecondary)
                .textCase(.uppercase)

            // Static placeholder rows matching the design
            recentExportRow(
                name: "C-Major-Progression.mid",
                type: "MIDI",
                date: "Today"
            )
            recentExportRow(
                name: "ChordFlow-Project.json",
                type: "JSON",
                date: "Today"
            )
        }
    }

    private func recentExportRow(name: String, type: String, date: String) -> some View {
        HStack {
            Image(systemName: type == "MIDI" ? "pianokeys" : "doc.text")
                .font(.system(size: 14))
                .foregroundStyle(Color.cfTextTertiary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.cfTextPrimary)
                Text(date)
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.cfTextTertiary)
            }

            Spacer()

            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 12))
                .foregroundStyle(Color.cfTextTertiary)
        }
        .padding(.vertical, CFSpacing.tight)
        .padding(.horizontal, CFSpacing.compact)
        .background(
            RoundedRectangle(cornerRadius: CFRadius.button)
                .fill(Color.cfSurface)
        )
    }
}
