import UIKit

/// Thin wrapper over UIKit feedback generators. Used sparingly — calm means
/// restraint. Main-actor isolated because the generators touch UIKit.
@MainActor
public enum Haptics {

    /// Light tap — card flip, each grade tap.
    public static func softTap() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred()
    }

    /// Success notification — a deck finishes generating, a study session ends.
    public static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}
