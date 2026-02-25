import SwiftUI

// MARK: - Harmonic Function

enum HarmonicFunction {
    case tonic
    case dominant
    case subdominant
    case borrowed

    var color: Color {
        switch self {
        case .tonic: return .cfTonic
        case .dominant: return .cfDominant
        case .subdominant: return .cfSubdominant
        case .borrowed: return .cfBorrowed
        }
    }

    var label: String {
        switch self {
        case .tonic: return "Tonic"
        case .dominant: return "Dominant"
        case .subdominant: return "Subdominant"
        case .borrowed: return "Borrowed"
        }
    }

    static func forDegree(_ degree: Int) -> HarmonicFunction {
        switch degree {
        case 0, 2, 5: return .tonic          // I, iii, vi
        case 1, 3:    return .subdominant     // ii, IV
        case 4, 6:    return .dominant         // V, vii°
        default:       return .tonic
        }
    }
}

// MARK: - Design Colors

extension Color {
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

extension Font {
    static let cfDisplay = Font.system(size: 28, weight: .bold, design: .rounded)
    static let cfHeading = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let cfChordSymbol = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let cfBody = Font.system(size: 15, weight: .regular, design: .rounded)
    static let cfCaption = Font.system(size: 12, weight: .medium, design: .rounded)
    static let cfMono = Font.system(size: 14, weight: .medium, design: .monospaced)
}

// MARK: - Spacing

enum CFSpacing {
    static let micro: CGFloat = 4
    static let tight: CGFloat = 8
    static let compact: CGFloat = 12
    static let standard: CGFloat = 16
    static let spacious: CGFloat = 24
    static let section: CGFloat = 32
    static let page: CGFloat = 48
}

// MARK: - Corner Radius

enum CFRadius {
    static let small: CGFloat = 4
    static let button: CGFloat = 8
    static let card: CGFloat = 12
    static let full: CGFloat = 999
}

// MARK: - Circle of Fifths Layout

enum CircleOfFifths {
    /// Notes in circle-of-fifths order, starting at 12 o'clock.
    static let notes: [Int] = [0, 7, 2, 9, 4, 11, 6, 1, 8, 3, 10, 5]

    /// Display names using enharmonic convention suitable for the circle.
    static let displayNames = ["C", "G", "D", "A", "E", "B", "F#", "Db", "Ab", "Eb", "Bb", "F"]

    /// Returns the circle-of-fifths position (0-11, 0=top) for a given note raw value.
    static func position(for noteRaw: Int) -> Int {
        (noteRaw * 7) % 12
    }

    /// Returns the angle in degrees (clockwise from top) for a given circle position.
    static func angle(for position: Int) -> Double {
        Double(position) * 30.0
    }

    /// Returns the point on a circle at the given angle (degrees, clockwise from top).
    static func point(center: CGPoint, radius: CGFloat, angleDegrees: Double) -> CGPoint {
        let rad = angleDegrees * .pi / 180
        return CGPoint(
            x: center.x + radius * CGFloat(sin(rad)),
            y: center.y - radius * CGFloat(cos(rad))
        )
    }
}
