#if canImport(SwiftUI)
import SwiftUI

// MARK: - Harmonic Function

public enum HarmonicFunction {
    case tonic
    case dominant
    case subdominant
    case borrowed

    public var color: Color {
        switch self {
        case .tonic: return .cfTonic
        case .dominant: return .cfDominant
        case .subdominant: return .cfSubdominant
        case .borrowed: return .cfBorrowed
        }
    }

    public var label: String {
        switch self {
        case .tonic: return "Tonic"
        case .dominant: return "Dominant"
        case .subdominant: return "Subdominant"
        case .borrowed: return "Borrowed"
        }
    }

    public static func forDegree(_ degree: Int) -> HarmonicFunction {
        switch degree {
        case 0, 2, 5: return .tonic          // I, iii, vi
        case 1, 3:    return .subdominant     // ii, IV
        case 4, 6:    return .dominant         // V, vii°
        default:       return .tonic
        }
    }
}

// MARK: - Design Colors

public extension Color {
    // Background tiers
    static let cfBase = Color(hex: 0x0E0F1D)
    static let cfBackground = Color(hex: 0x1A1B2E)
    static let cfSurface = Color(hex: 0x252740)
    static let cfElevated = Color(hex: 0x2F3152)
    static let cfBorder = Color(hex: 0x3A3D5C)

    // Text
    static let cfTextPrimary = Color(hex: 0xF0F0F5)
    static let cfTextSecondary = Color(hex: 0x8B8DA3)
    static let cfTextTertiary = Color(hex: 0x6B6D82)

    // Harmonic function
    static let cfTonic = Color(hex: 0xF5A623)
    static let cfDominant = Color(hex: 0x4A90D9)
    static let cfSubdominant = Color(hex: 0x7ED321)
    static let cfBorrowed = Color(hex: 0xD94A8C)

    // Semantic
    static let cfDestructive = Color(hex: 0xE8435A)

    init(hex: UInt, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

// MARK: - Typography

public extension Font {
    static let cfDisplay = Font.system(size: 28, weight: .bold, design: .rounded)
    static let cfHeading = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let cfChordSymbol = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let cfBody = Font.system(size: 15, weight: .regular, design: .rounded)
    static let cfCaption = Font.system(size: 12, weight: .medium, design: .rounded)
    static let cfMono = Font.system(size: 14, weight: .medium, design: .monospaced)
}

// MARK: - Spacing

public enum CFSpacing {
    public static let micro: CGFloat = 4
    public static let tight: CGFloat = 8
    public static let compact: CGFloat = 12
    public static let standard: CGFloat = 16
    public static let spacious: CGFloat = 24
    public static let section: CGFloat = 32
    public static let page: CGFloat = 48
}

// MARK: - Corner Radius

public enum CFRadius {
    public static let small: CGFloat = 4
    public static let button: CGFloat = 8
    public static let card: CGFloat = 12
    public static let full: CGFloat = 999
}

// MARK: - Circle of Fifths Layout

public enum CircleOfFifths {
    /// Notes in circle-of-fifths order, starting at 12 o'clock.
    public static let notes: [Int] = [0, 7, 2, 9, 4, 11, 6, 1, 8, 3, 10, 5]

    /// Display names using enharmonic convention suitable for the circle.
    public static let displayNames = ["C", "G", "D", "A", "E", "B", "F#", "Db", "Ab", "Eb", "Bb", "F"]

    /// Returns the circle-of-fifths position (0-11, 0=top) for a given note raw value.
    public static func position(for noteRaw: Int) -> Int {
        (noteRaw * 7) % 12
    }

    /// Returns the angle in degrees (clockwise from top) for a given circle position.
    public static func angle(for position: Int) -> Double {
        Double(position) * 30.0
    }

    /// Returns the point on a circle at the given angle (degrees, clockwise from top).
    public static func point(center: CGPoint, radius: CGFloat, angleDegrees: Double) -> CGPoint {
        let rad = angleDegrees * .pi / 180
        return CGPoint(
            x: center.x + radius * CGFloat(sin(rad)),
            y: center.y - radius * CGFloat(cos(rad))
        )
    }
}

// MARK: - Flow Layout (used for borrowed preset pills on iPad)

public struct FlowLayout: Layout {
    public var spacing: CGFloat

    public init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sv.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
#endif
