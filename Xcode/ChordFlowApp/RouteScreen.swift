import SwiftUI
import ChordFlowShared

struct RouteScreen: View {
    @ObservedObject var vm: AppViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CFSpacing.spacious) {
                if sizeClass == .regular {
                    HStack(alignment: .top, spacing: CFSpacing.standard) {
                        VStack(spacing: CFSpacing.spacious) {
                            midiOutputCard
                            channelCard
                        }
                        .frame(maxWidth: .infinity)

                        VStack(spacing: CFSpacing.spacious) {
                            auv3StatusCard
                            transportCard
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    midiOutputCard
                    channelCard
                    auv3StatusCard
                    transportCard
                }

                connectionHints
            }
            .padding(.horizontal, CFSpacing.spacious)
            .padding(.top, CFSpacing.standard)
            .padding(.bottom, CFSpacing.page)
        }
        .background(Color.cfBackground.ignoresSafeArea())
    }

    // MARK: - MIDI Output Card

    private var midiOutputCard: some View {
        VStack(alignment: .leading, spacing: CFSpacing.compact) {
            HStack(spacing: CFSpacing.compact) {
                Image(systemName: "cable.connector")
                    .font(.system(size: 24))
                    .foregroundStyle(vm.midiOutputEnabled ? Color.cfSubdominant : Color.cfTextTertiary)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: CFRadius.button)
                            .fill((vm.midiOutputEnabled ? Color.cfSubdominant : Color.cfTextTertiary).opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Virtual MIDI Output")
                        .font(.cfChordSymbol)
                        .foregroundStyle(Color.cfTextPrimary)
                    Text(vm.midiOutputEnabled ? "Active" : "Inactive")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(vm.midiOutputEnabled ? Color.cfSubdominant : Color.cfTextTertiary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { vm.midiOutputEnabled },
                    set: { _ in vm.toggleMIDIOutput() }
                ))
                .tint(Color.cfSubdominant)
                .labelsHidden()
            }

            if vm.midiOutputEnabled {
                HStack(spacing: CFSpacing.tight) {
                    statusDot(color: .cfSubdominant)
                    Text("Source: \(vm.midiOutput.sourceName)")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.cfTextSecondary)
                }

                Text("Other apps can receive MIDI from \"\(vm.midiOutput.sourceName)\" when you play or preview chords.")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.cfTextTertiary)
            } else if let error = vm.midiOutput.lastError {
                HStack(spacing: CFSpacing.tight) {
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
        .padding(CFSpacing.standard)
        .background(
            RoundedRectangle(cornerRadius: CFRadius.card)
                .fill(Color.cfSurface)
                .strokeBorder(vm.midiOutputEnabled ? Color.cfSubdominant.opacity(0.3) : Color.cfBorder, lineWidth: 1)
        )
    }

    // MARK: - Channel Card

    private var channelCard: some View {
        VStack(alignment: .leading, spacing: CFSpacing.compact) {
            HStack(spacing: CFSpacing.compact) {
                Image(systemName: "number")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.cfDominant)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: CFRadius.button)
                            .fill(Color.cfDominant.opacity(0.12))
                    )

                Text("MIDI Channel")
                    .font(.cfChordSymbol)
                    .foregroundStyle(Color.cfTextPrimary)
            }

            channelGrid
        }
        .padding(CFSpacing.standard)
        .background(
            RoundedRectangle(cornerRadius: CFRadius.card)
                .fill(Color.cfSurface)
                .strokeBorder(Color.cfBorder, lineWidth: 1)
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
                        .font(.system(size: 13, weight: isSelected ? .bold : .regular, design: .monospaced))
                        .foregroundStyle(isSelected ? Color.cfBase : Color.cfTextSecondary)
                        .frame(maxWidth: .infinity, minHeight: 32)
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
                auv3InfoRow(label: "Type", value: "MIDI Effect (aumi)")
                auv3InfoRow(label: "Manufacturer", value: "NWF1")
                auv3InfoRow(label: "SubType", value: "chrd")
                auv3InfoRow(label: "Parameters", value: "6 (Tonic, Mode, Tension, Pattern, Swing, Humanize)")
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

    private func auv3InfoRow(label: String, value: String) -> some View {
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
                transportInfoRow(label: "Mode", value: "Internal clock")
                transportInfoRow(label: "Tempo", value: "\(Int(vm.project.tempo.rounded())) BPM")
                transportInfoRow(label: "Time Sig", value: "4/4")
                transportInfoRow(label: "Status", value: vm.isPlaying ? "Playing" : "Stopped")
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

    private func transportInfoRow(label: String, value: String) -> some View {
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

    // MARK: - Connection Hints

    private var connectionHints: some View {
        VStack(alignment: .leading, spacing: CFSpacing.tight) {
            Text("QUICK START")
                .font(.cfCaption)
                .foregroundStyle(Color.cfTextSecondary)
                .textCase(.uppercase)

            connectionHintRow(
                icon: "app.connected.to.app.below.fill",
                title: "AUM / Logic / GarageBand",
                detail: "Load ChordFlow MIDI FX as an Audio Unit on a MIDI/instrument track"
            )
            connectionHintRow(
                icon: "cable.connector",
                title: "Virtual MIDI to synth apps",
                detail: "Enable MIDI output above, then select \"ChordFlow Out\" as input in your synth app"
            )
            connectionHintRow(
                icon: "square.and.arrow.up",
                title: "Export to DAW",
                detail: "Use the Export tab to save a .mid file, then import into any DAW"
            )
        }
    }

    private func connectionHintRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: CFSpacing.compact) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.cfTextTertiary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.cfTextPrimary)
                Text(detail)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.cfTextTertiary)
            }
        }
        .padding(.vertical, CFSpacing.tight)
        .padding(.horizontal, CFSpacing.compact)
        .background(
            RoundedRectangle(cornerRadius: CFRadius.button)
                .fill(Color.cfSurface)
        )
    }

    // MARK: - Helpers

    private func statusDot(color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
    }
}
