import SwiftUI

/// Soft, spring-driven motion. No spinners, nothing harsh.
public enum Motion {
    /// Card reveals during streaming — gentle rise + fade.
    public static let gentle = Animation.spring(response: 0.5, dampingFraction: 0.85)
    /// The flashcard flip.
    public static let flip = Animation.spring(response: 0.55, dampingFraction: 0.78)
    /// Small settle after an action completes.
    public static let settle = Animation.spring(response: 0.4, dampingFraction: 0.9)

    /// Per-card stagger when a deck streams in (~60ms steps).
    public static let stagger: Double = 0.06
}
