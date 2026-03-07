import SwiftUI

struct PlaybackBarView: View {
    @ObservedObject var vm: AppViewModel
    var onBlockTap: ((Int) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            if vm.isPlaying {
                GeometryReader { geo in
                    let barWidth = geo.size.width * vm.playbackProgress
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color.cfSurface)
                            .frame(height: 3)
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color.cfTonic.opacity(0.7))
                            .frame(width: barWidth, height: 3)
                        Circle()
                            .fill(Color.cfTonic)
                            .frame(width: 10, height: 10)
                            .offset(x: barWidth - 5)
                    }
                    .animation(.linear(duration: 1.0 / 30.0), value: vm.playbackProgress)
                }
                .frame(height: 10)
                .padding(.horizontal, CFSpacing.spacious)
                .padding(.top, CFSpacing.tight)
            }

            // Main bar
            HStack(spacing: CFSpacing.compact) {
                // Play / Stop button
                Button {
                    vm.togglePlayback()
                } label: {
                    ZStack {
                        Circle()
                            .fill(vm.isPlaying ? Color.cfDestructive : Color.cfTonic)
                            .frame(width: 44, height: 44)
                        if vm.isPlaying {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.cfTextPrimary)
                                .frame(width: 18, height: 18)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Color.cfBase)
                                .offset(x: 2) // visual centering
                        }
                    }
                }
                .buttonStyle(.plain)

                // Status text
                VStack(alignment: .leading, spacing: 1) {
                    Text(vm.isPlaying ? "Playing" : "Ready")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(vm.isPlaying ? Color.cfTonic : Color.cfTextPrimary)
                    Text(statusDetail)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.cfTextSecondary)
                }
                .fixedSize(horizontal: true, vertical: false)

                // Inline timeline (replaces Spacer + BPM)
                TimelineView(vm: vm, onBlockTap: onBlockTap)
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
        if vm.project.blocks.isEmpty {
            return "No chords"
        }
        if vm.isPlaying {
            return "Bar \(vm.currentBar) of \(vm.barCount)  |  \(vm.totalBeats) beats"
        }
        return "\(vm.barCount) chords  |  \(vm.totalBeats) beats"
    }
}
