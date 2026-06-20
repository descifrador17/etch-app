import Foundation

/// A single study card. Pure value type — this is what the AI layer emits and
/// what crosses every actor boundary. `NSManagedObject` never escapes the repo.
public struct Flashcard: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var question: String
    public var answer: String
    public var orderIndex: Int
    public var review: ReviewState

    public init(
        id: UUID = UUID(),
        question: String,
        answer: String,
        orderIndex: Int,
        review: ReviewState = .new
    ) {
        self.id = id
        self.question = question
        self.answer = answer
        self.orderIndex = orderIndex
        self.review = review
    }
}
