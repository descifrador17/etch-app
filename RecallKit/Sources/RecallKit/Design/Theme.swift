import SwiftUI

/// The terminal-native dark design system. Pure-black canvas, monospaced ink,
/// hairline borders, no shadows. Colors are code-defined so the (dark-only)
/// palette lives in one legible place. See docs/DESIGN.md.
public enum Theme {}

// MARK: - Color hex helper

public extension Color {
    /// Opaque sRGB color from a 0xRRGGBB literal.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue:  Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

// MARK: - Palette (inverted dark ladder)

public extension Theme {
    enum Palette {
        // Surfaces
        public static let surface        = Color(hex: 0x000000) // canvas — every screen bg
        public static let surfaceRaised  = Color(hex: 0x1A1A1A) // cards, inputs, elevated rows
        // Ink ladder
        public static let ink            = Color(hex: 0xFFFFFF) // headlines, card text
        public static let body           = Color(hex: 0xCCCCCC) // paragraph copy
        public static let inkSecondary   = Color(hex: 0x999999) // mute — metadata, captions
        public static let ash            = Color(hex: 0x666666) // disabled, skeleton
        // Lines
        public static let hairline       = Color.white.opacity(0.12)
        public static let hairlineStrong = Color(hex: 0x666666)
        // Accent + semantic grade ramp
        public static let accent         = Color(hex: 0x0A84FF) // Apple Blue (dark variant)
        public static let gradeAgain     = Color(hex: 0xFF453A) // red
        public static let gradeHard      = Color(hex: 0xFF9F0A) // orange
        public static let gradeGood      = Color(hex: 0xFFD60A) // yellow
        public static let gradeEasy      = Color(hex: 0x30D158) // green
    }
}

// MARK: - Typography (100% monospaced, Dynamic-Type driven)

public extension Theme {
    enum Typo {
        public static let display     = Font.system(.largeTitle, design: .monospaced, weight: .bold)
        public static let title       = Font.system(.title2,     design: .monospaced, weight: .semibold)
        public static let cardFace    = Font.system(.title,      design: .monospaced, weight: .medium)
        public static let body        = Font.system(.body,       design: .monospaced)
        public static let buttonLabel = Font.system(.body,       design: .monospaced, weight: .medium)
        public static let caption     = Font.system(.footnote,   design: .monospaced)
    }
}

// MARK: - Spacing & Shape

public extension Theme {
    enum Spacing {
        public static let section: CGFloat = 32
        public static let cardInner: CGFloat = 20
        public static let interCard: CGFloat = 12
        public static let xs: CGFloat = 8
        public static let sm: CGFloat = 12
        public static let md: CGFloat = 16
    }

    enum Radius {
        public static let card: CGFloat = 0    // sharp containers
        public static let button: CGFloat = 4  // the only rounded thing
    }

    /// Retained only until CardSurface stops consuming it (Task 2). No element
    /// in the terminal system casts a shadow.
    enum Shadow {
        public static let radius: CGFloat = 24
        public static let y: CGFloat = 8
        public static let opacity: Double = 0.06
    }
}
