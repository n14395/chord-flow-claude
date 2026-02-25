import SwiftUI

struct KnobView: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double?
    let label: String
    let color: Color
    let formatValue: (Double) -> String

    private let arcSweep: Double = 270
    private let arcStartDeg: Double = 135 // SwiftUI degrees (0 = 3 o'clock)

    init(
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        step: Double? = nil,
        label: String,
        color: Color,
        format: @escaping (Double) -> String = { String(format: "%.1f", $0) }
    ) {
        self._value = value
        self.range = range
        self.step = step
        self.label = label
        self.color = color
        self.formatValue = format
    }

    private var normalized: Double {
        (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    var body: some View {
        VStack(spacing: CFSpacing.tight) {
            GeometryReader { geo in
                let size = min(geo.size.width, geo.size.height)
                let center = CGPoint(x: geo.size.width / 2, y: size / 2)
                let radius = size / 2 - 4

                ZStack {
                    // Background circle
                    Circle()
                        .fill(Color.cfSurface)
                        .stroke(Color.cfBorder, lineWidth: 1.5)
                        .frame(width: radius * 2, height: radius * 2)

                    // Track arc (full, dim)
                    ArcShape(startAngle: arcStartDeg, sweepAngle: arcSweep)
                        .stroke(Color.cfBorder, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: (radius - 6) * 2, height: (radius - 6) * 2)

                    // Filled arc
                    ArcShape(startAngle: arcStartDeg, sweepAngle: arcSweep * normalized)
                        .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: (radius - 6) * 2, height: (radius - 6) * 2)

                    // Dot indicator at end of filled arc
                    let dotAngle = arcStartDeg + normalized * arcSweep
                    let dotPoint = arcPoint(center: center, radius: radius - 6, angleDeg: dotAngle)
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                        .position(dotPoint)

                    // Value text
                    Text(formatValue(value))
                        .font(.system(size: radius * 0.42, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.cfTextPrimary)
                        .position(center)
                }
                .contentShape(Circle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            updateValue(from: drag.location, center: center, radius: radius - 6)
                        }
                )
            }
            .aspectRatio(1, contentMode: .fit)

            Text(label)
                .font(.cfCaption)
                .textCase(.uppercase)
                .foregroundStyle(Color.cfTextSecondary)
        }
    }

    // MARK: - Helpers

    private func arcPoint(center: CGPoint, radius: CGFloat, angleDeg: Double) -> CGPoint {
        let rad = angleDeg * .pi / 180
        return CGPoint(
            x: center.x + radius * CGFloat(cos(rad)),
            y: center.y + radius * CGFloat(sin(rad))
        )
    }

    private func updateValue(from location: CGPoint, center: CGPoint, radius: CGFloat) {
        let dx = location.x - center.x
        let dy = location.y - center.y
        var angle = atan2(dy, dx) * 180 / .pi // -180...180, 0 = right
        if angle < 0 { angle += 360 }

        // Distance from arc start going clockwise (counterclockwise in math = clockwise on screen)
        var distFromStart = angle - arcStartDeg
        if distFromStart < 0 { distFromStart += 360 }

        // Dead zone: anything past the sweep is clamped
        guard distFromStart <= arcSweep + 30 else { return } // small tolerance past end
        let clamped = min(max(distFromStart / arcSweep, 0), 1)

        var newValue = range.lowerBound + clamped * (range.upperBound - range.lowerBound)
        if let step {
            newValue = (newValue / step).rounded() * step
        }
        value = min(max(newValue, range.lowerBound), range.upperBound)
    }
}

// MARK: - Arc Shape

private struct ArcShape: Shape {
    let startAngle: Double
    let sweepAngle: Double

    func path(in rect: CGRect) -> Path {
        guard sweepAngle > 0.1 else { return Path() }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startAngle),
            endAngle: .degrees(startAngle + sweepAngle),
            clockwise: false
        )
        return path
    }
}
