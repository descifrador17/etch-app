import Foundation

/// Abstraction over flashcard generation. ViewModels depend on this, so the app
/// builds and previews without a capable device (inject `MockGenerator`).
/// Main-actor isolated: conformers (`FlashcardGenerator`) drive non-`Sendable`
/// `LanguageModelSession`s, and every consumer is a `@MainActor` ViewModel.
@MainActor
public protocol FlashcardGenerating: Sendable {
    /// Synchronous capability check for gating UI.
    var availability: GeneratorAvailability { get }

    /// Warm the model so first-token latency is low. Best-effort, non-throwing.
    func prewarm()

    /// Streams progressively-more-complete deck snapshots. The final value is
    /// the complete deck, marked `isComplete`.
    func streamDeck(topic: String) -> AsyncThrowingStream<DeckSnapshot, Error>
}

public enum GeneratorAvailability: Equatable, Sendable {
    case available
    case unavailable(GenerationError.UnavailableReason)
}

/// A progressively-filled view of the deck for streaming UI.
public struct DeckSnapshot: Sendable, Equatable {
    public var title: String?
    public var cards: [Flashcard]   // grows as generation proceeds
    public var isComplete: Bool

    public init(title: String? = nil, cards: [Flashcard] = [], isComplete: Bool = false) {
        self.title = title
        self.cards = cards
        self.isComplete = isComplete
    }
}
