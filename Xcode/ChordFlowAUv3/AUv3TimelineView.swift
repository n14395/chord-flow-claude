import SwiftUI
import ChordFlowShared

struct AUv3TimelineView: View {
    @ObservedObject var vm: AUv3ViewModel
    var onBlockTap: ((Int) -> Void)?

    private let blockHeight: CGFloat = 56
    private let barNumberHeight: CGFloat = 18
    private let barsBeforeScroll = 6
    private let gridPadding: CGFloat = 8

    @State private var draggingBlockID: UUID?
    @State private var dragOffset: CGFloat = 0
    @State private var dragSwapAccumulator: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: CFSpacing.tight) {
            HStack {
                Text("PROGRESSION")
                    .font(.cfCaption)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.cfTextSecondary)
                Spacer()
                if !vm.blocks.isEmpty {
                    Text("\(vm.barCount) bars")
                        .font(.cfCaption)
                        .foregroundStyle(Color.cfTextTertiary)
                }
            }

            if vm.blocks.isEmpty {
                emptyState
            } else {
                GeometryReader { geo in
                    let beatWidth = beatWidth(for: geo.size.width)
                    timelineContent(beatWidth: beatWidth)
                }
                .frame(height: blockHeight + barNumberHeight + 24)
            }

            if !vm.blocks.isEmpty {
                GeometryReader { geo in
                    let beatWidth = beatWidth(for: geo.size.width)
                    patternIndicators(beatWidth: beatWidth)
                }
                .frame(height: 14)
            }
        }
    }

    private func beatWidth(for availableWidth: CGFloat) -> CGFloat {
        let targetBeats = CGFloat(barsBeforeScroll * 4)
        return max(16, (availableWidth - gridPadding) / targetBeats)
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

    private func timelineContent(beatWidth: CGFloat) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    beatGrid(beatWidth: beatWidth)
                    chordBlocks(beatWidth: beatWidth)

                    if vm.isPlaying {
                        playbackCursor(beatWidth: beatWidth)
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollDisabled(draggingBlockID != nil)
            .onChange(of: vm.blocks.count) { oldCount, newCount in
                guard newCount > oldCount, let last = vm.blocks.last else { return }
                withAnimation { proxy.scrollTo(last.id, anchor: .trailing) }
            }
        }
    }

    // MARK: - Beat Grid

    private func beatGrid(beatWidth: CGFloat) -> some View {
        let totalBeats = max(vm.totalBeats, barsBeforeScroll * 4)
        let totalWidth = CGFloat(totalBeats) * beatWidth + gridPadding

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.cfBase)
                .strokeBorder(Color.cfSurface, lineWidth: 1)
                .frame(width: totalWidth, height: blockHeight + barNumberHeight + 16)

            ForEach(0..<totalBeats, id: \.self) { beat in
                let x = CGFloat(beat) * beatWidth + 4
                let isBarLine = beat % 4 == 0 && beat > 0
                Rectangle()
                    .fill(isBarLine ? Color.cfBorder : Color.cfBackground)
                    .frame(width: isBarLine ? 1 : 0.5, height: blockHeight + barNumberHeight + 8)
                    .offset(x: x, y: 4)
            }

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

    private func chordBlocks(beatWidth: CGFloat) -> some View {
        ForEach(Array(vm.blocks.enumerated()), id: \.element.id) { index, block in
            let function = vm.harmonicFunction(forBlockAt: index)
            let color = function.color
            let beats = Int(block.lengthBeats)
            let startBeat = vm.blocks[0..<index].reduce(0) { $0 + Int($1.lengthBeats) }
            let blockPad: CGFloat = 2
            let x = CGFloat(startBeat) * beatWidth + 4 + blockPad
            let width = CGFloat(beats) * beatWidth - blockPad * 2
            let isBorrowed = function == .borrowed
            let isDragging = draggingBlockID == block.id
            let xOffset = isDragging ? dragOffset : 0

            chordBlockView(block: block, index: index, color: color, width: width, isBorrowed: isBorrowed)
                .frame(width: width, height: blockHeight)
                .clipShape(RoundedRectangle(cornerRadius: CFRadius.button))
                .shadow(color: isDragging ? color.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
                .scaleEffect(isDragging ? 1.05 : 1.0)
                .opacity(isDragging ? 0.9 : 1.0)
                .id(block.id)
                .offset(x: x + xOffset, y: barNumberHeight + 8)
                .animation(isDragging ? nil : .interactiveSpring(response: 0.3, dampingFraction: 0.8), value: x)
                .zIndex(isDragging ? 100 : 0)
                .gesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { value in
                            if draggingBlockID == nil {
                                draggingBlockID = block.id
                                dragSwapAccumulator = 0
                            }
                            guard draggingBlockID == block.id else { return }
                            dragOffset = value.translation.width + dragSwapAccumulator
                            guard let currentIndex = vm.blocks.firstIndex(where: { $0.id == block.id }) else { return }
                            let currentStartBeat = vm.blocks[0..<currentIndex].reduce(0) { $0 + Int($1.lengthBeats) }
                            let currentX = CGFloat(currentStartBeat) * beatWidth + 4 + blockPad
                            let currentWidth = CGFloat(Int(vm.blocks[currentIndex].lengthBeats)) * beatWidth - blockPad * 2
                            let draggedCenter = currentX + currentWidth / 2 + dragOffset

                            if currentIndex > 0 {
                                let prevBeats = vm.blocks[0..<(currentIndex - 1)].reduce(0) { $0 + Int($1.lengthBeats) }
                                let prevWidth = CGFloat(Int(vm.blocks[currentIndex - 1].lengthBeats)) * beatWidth - blockPad * 2
                                let prevX = CGFloat(prevBeats) * beatWidth + 4 + blockPad
                                let prevCenter = prevX + prevWidth / 2
                                if draggedCenter < prevCenter {
                                    let prevBlockWidth = CGFloat(Int(vm.blocks[currentIndex - 1].lengthBeats)) * beatWidth
                                    vm.moveBlock(from: currentIndex, to: currentIndex - 1)
                                    dragSwapAccumulator += prevBlockWidth
                                    dragOffset = value.translation.width + dragSwapAccumulator
                                    return
                                }
                            }

                            if currentIndex < vm.blocks.count - 1 {
                                let nextStartBeat = vm.blocks[0..<(currentIndex + 1)].reduce(0) { $0 + Int($1.lengthBeats) }
                                let nextWidth = CGFloat(Int(vm.blocks[currentIndex + 1].lengthBeats)) * beatWidth - blockPad * 2
                                let nextX = CGFloat(nextStartBeat) * beatWidth + 4 + blockPad
                                let nextCenter = nextX + nextWidth / 2
                                if draggedCenter > nextCenter {
                                    let nextBlockWidth = CGFloat(Int(vm.blocks[currentIndex + 1].lengthBeats)) * beatWidth
                                    vm.moveBlock(from: currentIndex, to: currentIndex + 1)
                                    dragSwapAccumulator -= nextBlockWidth
                                    dragOffset = value.translation.width + dragSwapAccumulator
                                    return
                                }
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                dragOffset = 0
                                draggingBlockID = nil
                            }
                            dragSwapAccumulator = 0
                        }
                )
                .contextMenu {
                    Button(role: .destructive) { vm.removeBlock(at: index) } label: {
                        Label("Remove", systemImage: "trash")
                    }
                    Button { vm.duplicateBlock(at: index) } label: {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }
                }
        }
    }

    // MARK: - Chord Block View

    private func chordBlockView(block: CFSequenceBlock, index: Int, color: Color, width: CGFloat, isBorrowed: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: CFRadius.button)
                .fill(color.opacity(0.12))
            RoundedRectangle(cornerRadius: CFRadius.button)
                .stroke(color, style: isBorrowed ? StrokeStyle(lineWidth: 1.5, dash: [6, 3]) : StrokeStyle(lineWidth: 1.5))

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { onBlockTap?(index) }
                    Button {
                        // Preview not available in AUv3 context — just select
                        onBlockTap?(index)
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(color.opacity(0.7))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(color.opacity(0.08))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .frame(height: blockHeight / 2)

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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { onBlockTap?(index) }
            }
        }
    }

    // MARK: - Playback Cursor

    private func playbackCursor(beatWidth: CGFloat) -> some View {
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
        .animation(.linear(duration: 1.0 / 15.0), value: vm.playbackProgress)
    }

    // MARK: - Pattern Indicators

    private func patternIndicators(beatWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(vm.blocks.enumerated()), id: \.element.id) { index, block in
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
