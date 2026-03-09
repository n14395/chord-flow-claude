#if canImport(SwiftUI)
import SwiftUI

public struct SharedTimelineView<VM: ChordFlowViewModel>: View {
    @ObservedObject var vm: VM
    var onBlockTap: ((Int) -> Void)?
    var onBlockLongPress: (Int) -> Void

    private let blockHeight: CGFloat = 56
    private let barNumberHeight: CGFloat = 18
    private let patternHeight: CGFloat = 14
    private let handleWidth: CGFloat = 20
    private let barsBeforeScroll: Double = 5.33
    private let gridPadding: CGFloat = 8

    // Drag state
    @State private var draggingBlockID: UUID?
    @State private var dragOffset: CGFloat = 0
    @State private var dragSwapAccumulator: CGFloat = 0
    @State private var dragStartX: CGFloat = 0

    public init(
        vm: VM,
        onBlockTap: ((Int) -> Void)? = nil,
        onBlockLongPress: @escaping (Int) -> Void
    ) {
        self._vm = ObservedObject(wrappedValue: vm)
        self.onBlockTap = onBlockTap
        self.onBlockLongPress = onBlockLongPress
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CFSpacing.tight) {
            // Header
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
                .frame(height: blockHeight + barNumberHeight + patternHeight + 28)
            }
        }
    }

    private func beatWidth(for availableWidth: CGFloat) -> CGFloat {
        let targetBeats = CGFloat(barsBeforeScroll * 4.0)
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
                VStack(spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        beatGrid(beatWidth: beatWidth)

                        scrollAnchors(beatWidth: beatWidth)

                        chordBlocks(beatWidth: beatWidth)

                        if vm.isPlaying {
                            playbackCursor(beatWidth: beatWidth)
                        }
                    }
                    .coordinateSpace(name: "timeline")
                    .padding(.vertical, 4)

                    patternIndicators(beatWidth: beatWidth)
                        .frame(height: patternHeight)
                }
            }
            .scrollDisabled(draggingBlockID != nil)
            .onChange(of: vm.blocks.count) { oldCount, newCount in
                guard newCount > oldCount else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("timeline_end", anchor: .trailing)
                    }
                }
            }
        }
    }

    private func scrollAnchors(beatWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(vm.blocks) { block in
                let beats = Int(block.lengthBeats)
                Color.clear
                    .frame(width: CGFloat(beats) * beatWidth, height: 1)
                    .id(block.id)
            }
            Color.clear
                .frame(width: 1, height: 1)
                .id("timeline_end")
        }
        .padding(.leading, 4)
    }

    // MARK: - Beat Grid

    private func beatGrid(beatWidth: CGFloat) -> some View {
        let totalBeats = max(vm.totalBeats, Int(barsBeforeScroll * 4))
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
        return ForEach(Array(vm.blocks.enumerated()), id: \.element.id) { index, block in
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

            chordBlockView(
                block: block,
                index: index,
                color: color,
                width: width,
                beatWidth: beatWidth,
                blockPad: blockPad,
                isBorrowed: isBorrowed
            )
            .frame(width: width, height: blockHeight)
            .clipShape(RoundedRectangle(cornerRadius: CFRadius.button))
            .shadow(color: isDragging ? color.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
            .scaleEffect(isDragging ? 1.05 : 1.0)
            .opacity(isDragging ? 0.9 : 1.0)
            .offset(x: x + xOffset, y: barNumberHeight + 8)
            .animation(isDragging ? nil : .interactiveSpring(response: 0.3, dampingFraction: 0.8), value: x)
            .zIndex(isDragging ? 100 : 0)
        }
    }

    private func reorderDragGesture(
        block: CFSequenceBlock,
        beatWidth: CGFloat,
        blockPad: CGFloat
    ) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .named("timeline"))
            .onChanged { value in
                if draggingBlockID == nil {
                    draggingBlockID = block.id
                    dragSwapAccumulator = 0
                    dragStartX = value.startLocation.x
                }
                guard draggingBlockID == block.id else { return }

                guard let currentIndex = vm.blocks.firstIndex(where: { $0.id == block.id }) else { return }

                let currentStartBeat = vm.blocks[0..<currentIndex].reduce(0) { $0 + Int($1.lengthBeats) }
                let currentX = CGFloat(currentStartBeat) * beatWidth + 4 + blockPad
                let currentWidth = CGFloat(Int(vm.blocks[currentIndex].lengthBeats)) * beatWidth - blockPad * 2

                dragOffset = (value.location.x - dragStartX) + dragSwapAccumulator

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
                        dragOffset = (value.location.x - dragStartX) + dragSwapAccumulator
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
                        dragOffset = (value.location.x - dragStartX) + dragSwapAccumulator
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
    }

    // MARK: - Chord Block View

    private func chordBlockView(
        block: CFSequenceBlock,
        index: Int,
        color: Color,
        width: CGFloat,
        beatWidth: CGFloat,
        blockPad: CGFloat,
        isBorrowed: Bool
    ) -> some View {
        let isDragging = draggingBlockID == block.id
        let isNarrow = Int(block.lengthBeats) == 1
        let playWidth: CGFloat = max(width * 0.28, 28)
        return ZStack {
            // Background
            RoundedRectangle(cornerRadius: CFRadius.button)
                .fill(color.opacity(0.12))
            RoundedRectangle(cornerRadius: CFRadius.button)
                .stroke(
                    color,
                    style: isBorrowed
                        ? StrokeStyle(lineWidth: 1.5, dash: [6, 3])
                        : StrokeStyle(lineWidth: 1.5)
                )

            if isNarrow {
                HStack(spacing: 0) {
                    // Drag handle
                    VStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 0.5)
                                .fill(color.opacity(0.35))
                                .frame(width: 10, height: 1.5)
                        }
                    }
                    .frame(width: handleWidth, height: blockHeight)
                    .contentShape(Rectangle())
                    .gesture(reorderDragGesture(block: block, beatWidth: beatWidth, blockPad: blockPad))

                    VStack(spacing: 0) {
                        Button {
                            guard !isDragging else { return }
                            vm.previewBlock(block)
                        } label: {
                            ZStack {
                                UnevenRoundedRectangle(
                                    topLeadingRadius: 0,
                                    bottomLeadingRadius: 0,
                                    bottomTrailingRadius: 0,
                                    topTrailingRadius: CFRadius.button
                                )
                                .fill(color.opacity(0.6))
                                Image(systemName: "waveform")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.cfBase.opacity(0.85))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: blockHeight / 2)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        VStack(spacing: 0) {
                            Text(block.chord.symbol())
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(color)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard !isDragging else { return }
                            onBlockTap?(index)
                        }
                    }
                    .modifier(BlockInteractionModifier(vm: vm, block: block, index: index, onActivate: onBlockLongPress))
                }
            } else {
                HStack(spacing: 0) {
                    // Drag handle
                    VStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 0.5)
                                .fill(color.opacity(0.35))
                                .frame(width: 10, height: 1.5)
                        }
                    }
                    .frame(width: handleWidth, height: blockHeight)
                    .contentShape(Rectangle())
                    .gesture(reorderDragGesture(block: block, beatWidth: beatWidth, blockPad: blockPad))

                    HStack(spacing: 0) {
                        VStack(spacing: 2) {
                            Text(vm.romanNumeral(for: block.chord))
                                .font(.system(size: 9, weight: .regular, design: .rounded))
                                .foregroundStyle(color.opacity(0.5))
                            Text(block.chord.symbol())
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(color)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard !isDragging else { return }
                            onBlockTap?(index)
                        }

                        Button {
                            guard !isDragging else { return }
                            vm.previewBlock(block)
                        } label: {
                            ZStack {
                                UnevenRoundedRectangle(
                                    topLeadingRadius: 0,
                                    bottomLeadingRadius: 0,
                                    bottomTrailingRadius: CFRadius.button,
                                    topTrailingRadius: CFRadius.button
                                )
                                .fill(color.opacity(0.6))
                                Image(systemName: "waveform")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color.cfBase.opacity(0.85))
                            }
                            .frame(width: playWidth, height: blockHeight)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .modifier(BlockInteractionModifier(vm: vm, block: block, index: index, onActivate: onBlockLongPress))
                }
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
        .animation(.linear(duration: 1.0 / 30.0), value: vm.playbackProgress)
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

// MARK: - Block Interaction Modifier
//
// Long-press gesture (for touch) fires the onActivate callback to show the
// custom overlay. A native .contextMenu with the same actions handles
// right-click on macOS Catalyst / iPadOS with mouse. The .contextMenu
// doesn't work in AUv3 hosts, but the long-press does — both code paths
// exist so whichever environment is active has a working interaction.

private struct BlockInteractionModifier<VM: ChordFlowViewModel>: ViewModifier {
    let vm: VM
    let block: CFSequenceBlock
    let index: Int
    let onActivate: (Int) -> Void

    func body(content: Content) -> some View {
        content
            // Long-press for touch (simultaneous so child taps still work)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.45)
                    .onEnded { _ in onActivate(index) }
            )
            // Right-click / secondary click — uses native .contextMenu which
            // works in the standalone app and Mac Catalyst but not in AUv3.
            .contextMenu {
                Button { vm.previewBlock(block) } label: {
                    Label("Preview", systemImage: "play.fill")
                }
                Button { vm.duplicateBlock(at: index) } label: {
                    Label("Duplicate", systemImage: "doc.on.doc")
                }
                Divider()
                Button(role: .destructive) { vm.removeBlock(at: index) } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
    }
}
#endif
