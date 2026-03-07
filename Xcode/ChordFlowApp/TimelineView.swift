import SwiftUI
import ChordFlowShared

struct TimelineView: View {
    @ObservedObject var vm: AppViewModel
    var onBlockTap: ((Int) -> Void)?

    private let blockHeight: CGFloat = 56
    private let barNumberHeight: CGFloat = 18

    var body: some View {
        VStack(alignment: .leading, spacing: CFSpacing.tight) {
            // Header
            HStack {
                Text("PROGRESSION")
                    .font(.cfCaption)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.cfTextSecondary)
                Spacer()
                if !vm.project.blocks.isEmpty {
                    Text("\(vm.barCount) bars")
                        .font(.cfCaption)
                        .foregroundStyle(Color.cfTextTertiary)
                }
            }

            if vm.project.blocks.isEmpty {
                emptyState
            } else {
                timelineContent
            }

            // Pattern indicators
            if !vm.project.blocks.isEmpty {
                patternIndicators
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.cfBase)
            .strokeBorder(Color.cfSurface, lineWidth: 1)
            .frame(height: blockHeight + barNumberHeight + 16)
            .overlay(
                Text("Tap a chord to start building")
                    .font(.cfBody)
                    .foregroundStyle(Color.cfTextTertiary)
            )
    }

    // MARK: - Timeline Content

    private var timelineContent: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    // Background with beat grid
                    beatGrid

                    // Chord blocks
                    chordBlocks

                    // Playback cursor (when playing)
                    if vm.isPlaying {
                        playbackCursor
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: vm.project.blocks.count) { _, _ in
                if let last = vm.project.blocks.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .trailing) }
                }
            }
        }
    }

    // MARK: - Beat Grid

    private var beatGrid: some View {
        let totalBeats = max(vm.totalBeats, 16)
        let beatWidth: CGFloat = 22
        let totalWidth = CGFloat(totalBeats) * beatWidth + 8

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.cfBase)
                .strokeBorder(Color.cfSurface, lineWidth: 1)
                .frame(width: totalWidth, height: blockHeight + barNumberHeight + 16)

            // Beat subdivision lines
            ForEach(0..<totalBeats, id: \.self) { beat in
                let x = CGFloat(beat) * beatWidth + 4
                let isBarLine = beat % 4 == 0 && beat > 0
                Rectangle()
                    .fill(isBarLine ? Color.cfBorder : Color.cfBackground)
                    .frame(width: isBarLine ? 1 : 0.5, height: blockHeight + barNumberHeight + 8)
                    .offset(x: x, y: 4)
            }

            // Bar numbers
            ForEach(0..<((totalBeats + 3) / 4), id: \.self) { bar in
                let centerX = (CGFloat(bar) * 4 + 2) * beatWidth + 4
                Text("\(bar + 1)")
                    .font(.system(size: 8, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.cfTextTertiary)
                    .position(x: centerX, y: 14)
            }
        }
    }

    // MARK: - Chord Blocks

    private var chordBlocks: some View {
        let beatWidth: CGFloat = 22
        return ForEach(Array(vm.project.blocks.enumerated()), id: \.element.id) { index, block in
            let function = vm.harmonicFunction(forBlockAt: index)
            let color = function.color
            let beats = Int(block.lengthBeats)
            let startBeat = vm.project.blocks[0..<index].reduce(0) { $0 + Int($1.lengthBeats) }
            let blockPad: CGFloat = 2
            let x = CGFloat(startBeat) * beatWidth + 4 + blockPad
            let width = CGFloat(beats) * beatWidth - blockPad * 2
            let isBorrowed = function == .borrowed

            ZStack(alignment: .topTrailing) {
                // Background
                RoundedRectangle(cornerRadius: CFRadius.button)
                    .fill(color.opacity(0.12))
                    .frame(width: width, height: blockHeight)
                RoundedRectangle(cornerRadius: CFRadius.button)
                    .stroke(
                        color,
                        style: isBorrowed
                            ? StrokeStyle(lineWidth: 1.5, dash: [6, 3])
                            : StrokeStyle(lineWidth: 1.5)
                    )
                    .frame(width: width, height: blockHeight)

                // Chord label (bottom half, centered)
                VStack(spacing: 2) {
                    Text(block.chord.symbol())
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(vm.romanNumeral(for: block.chord))
                        .font(.system(size: 9, weight: .regular, design: .rounded))
                        .foregroundStyle(color.opacity(0.5))
                }
                .frame(width: width, height: blockHeight)
                .padding(.top, 6)

                // Play button (top-right, top half)
                Button {
                    vm.previewBlock(block)
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(color.opacity(0.7))
                        .frame(width: width / 2, height: blockHeight / 2)
                        .background(color.opacity(0.08))
                }
                .buttonStyle(.plain)
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: CFRadius.button,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: CFRadius.button
                ))
            }
            .frame(width: width, height: blockHeight)
            .id(block.id)
            .offset(x: x, y: barNumberHeight + 8)
            .onTapGesture {
                onBlockTap?(index)
            }
            .contextMenu {
                Button(role: .destructive) {
                    vm.removeBlock(at: index)
                } label: {
                    Label("Remove", systemImage: "trash")
                }
                Button {
                    vm.duplicateBlock(at: index)
                } label: {
                    Label("Duplicate", systemImage: "doc.on.doc")
                }
            }
        }
    }

    // MARK: - Playback Cursor

    private var playbackCursor: some View {
        let beatWidth: CGFloat = 22
        let totalWidth = CGFloat(vm.totalBeats) * beatWidth
        let cursorX = 4 + vm.playbackProgress * totalWidth

        return VStack(spacing: 0) {
            Circle()
                .fill(Color.cfTonic)
                .frame(width: 6, height: 6)
            Rectangle()
                .fill(Color.cfTonic.opacity(0.9))
                .frame(width: 2, height: blockHeight + barNumberHeight)
        }
        .offset(x: cursorX, y: 4)
        .animation(.linear(duration: 1.0 / 30.0), value: vm.playbackProgress)
    }

    // MARK: - Pattern Indicators

    private var patternIndicators: some View {
        let beatWidth: CGFloat = 22
        return HStack(spacing: 0) {
            ForEach(Array(vm.project.blocks.enumerated()), id: \.element.id) { index, block in
                let function = vm.harmonicFunction(forBlockAt: index)
                let width = CGFloat(Int(block.lengthBeats)) * beatWidth - 4
                Text(patternLabel(block.pattern))
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .textCase(.uppercase)
                    .foregroundStyle(function.color.opacity(0.5))
                    .frame(width: width)
            }
        }
        .padding(.leading, 6)
    }

    private func patternLabel(_ pattern: CFPattern) -> String {
        switch pattern {
        case .block: return "Block"
        case .arpUp: return "Arp Up"
        case .arpDown: return "Arp Down"
        case .strum: return "Strum"
        }
    }
}
