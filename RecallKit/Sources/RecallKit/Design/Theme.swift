import SwiftUI

/// The "calm" design system. Warm paper, muted ink, a single sage accent.
/// Colors resolve from the package's asset catalog so dark mode is automatic
/// and the system is fully previewable inside RecallKit.
public enum Theme {}

// MARK: - Color

public extension Theme {
    enum Palette {
        public static let surface       = Color("surface", bundle: .module)
        public static let surfaceRaised  = Color("surfaceRaised", bundle: .module)
        public static let ink            = Color("ink", bundle: .module)
        public static let inkSecondary   = Color("inkSecondary", bundle: .module)
        public static let accent         = Color("accent", bundle: .module)
        public static let hairline       = Color("hairline", bundle: .module)
    }
}

// MARK: - Typography

public extension Theme {
    /// Dynamic-Type text styles on the rounded design for warmth.
    /// Never use fixed point sizes — these scale with the user's settings.
    enum Typo {
        public static let display  = Font.system(.largeTitle, design: .rounded, weight: .semibold)
        public static let title    = Font.system(.title2,     design: .rounded, weight: .semibold)
        public static let cardFace  = Font.system(.title,      design: .rounded, weight: .medium)
        public static let body     = Font.system(.body,        design: .rounded)
        public static let caption  = Font.system(.footnote,    design: .rounded, weight: .medium)
    }
}

// MARK: - Spacing & Shape

public extension Theme {
    enum Spacing {
        public static let section: CGFloat = 24
        public static let cardInner: CGFloat = 28
        public static let interCard: CGFloat = 16
        public static let xs: CGFloat = 8
        public static let sm: CGFloat = 12
        public static let md: CGFloat = 16
    }

    enum Radius {
        public static let card: CGFloat = 28
        public static let button: CGFloat = 16
    }

    enum Shadow {
        public static let radius: CGFloat = 24
        public static let y: CGFloat = 8
        public static let opacity: Double = 0.06
    }
}
