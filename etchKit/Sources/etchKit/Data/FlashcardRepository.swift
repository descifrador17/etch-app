import Foundation

/// The only door into persistence. ViewModels depend on this protocol, never on
/// Core Data. Every method returns `Sendable` value types — `NSManagedObject`
/// stays behind this boundary. Main-actor isolated to match its `@MainActor`
/// conformer and the `@MainActor` ViewModels that consume it; the actual Core
/// Data work hops onto a background context via `perform`.
@MainActor
public protocol FlashcardRepository: Sendable {
    func createDeck(topic: String, title: String, difficulty: Difficulty, cards: [Flashcard]) async throws -> Deck
    func allDecks() async throws -> [Deck]
    func deck(id: UUID) async throws -> Deck?
    func deleteDeck(id: UUID) async throws
    func updateReviewState(cardID: UUID, state: ReviewState) async throws

    /// Observation for the decks list. Yields the full deck set on subscribe and
    /// after every mutation.
    func decksStream() -> AsyncStream<[Deck]>
}
