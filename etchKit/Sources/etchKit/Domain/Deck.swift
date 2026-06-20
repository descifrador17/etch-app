import Foundation

/// A persisted deck of flashcards. Value type returned by the repository.
public struct Deck: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var topic: String
    public var title: String
    public var createdAt: Date
    public var difficulty: Difficulty
    public var cards: [Flashcard]

    public init(
        id: UUID = UUID(),
        topic: String,
        title: String,
        createdAt: Date = .now,
        difficulty: Difficulty = .medium,
        cards: [Flashcard]
    ) {
        self.id = id
        self.topic = topic
        self.title = title
        self.createdAt = createdAt
        self.difficulty = difficulty
        self.cards = cards
    }

    /// Count of cards due for review as of `now`. Drives the due badge.
    public func dueCount(asOf now: Date = .now) -> Int {
        cards.filter { $0.review.dueDate <= now }.count
    }
}
