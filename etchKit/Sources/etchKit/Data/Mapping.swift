import CoreData

/// `NSManagedObject ⇄ Flashcard/Deck` mapping. These touch managed objects, so
/// they must run inside the owning context's `perform`. They return value types.

extension CDCard {
    func toDomain() -> Flashcard {
        Flashcard(
            id: id,
            question: question,
            answer: answer,
            orderIndex: Int(orderIndex),
            review: ReviewState(
                easeFactor: easeFactor,
                intervalDays: intervalDays,
                repetitions: Int(repetitions),
                dueDate: dueDate,
                lastReviewedAt: lastReviewedAt
            )
        )
    }

    /// Apply a domain card's content + SR state onto a managed row.
    func apply(_ card: Flashcard) {
        id = card.id
        question = card.question
        answer = card.answer
        orderIndex = Int32(card.orderIndex)
        applyReview(card.review)
    }

    func applyReview(_ review: ReviewState) {
        easeFactor = review.easeFactor
        intervalDays = review.intervalDays
        repetitions = Int32(review.repetitions)
        dueDate = review.dueDate
        lastReviewedAt = review.lastReviewedAt
    }
}

extension CDDeck {
    func toDomain() -> Deck {
        let mapped = cards
            .map { $0.toDomain() }
            .sorted { $0.orderIndex < $1.orderIndex }
        return Deck(
            id: id,
            topic: topic,
            title: title,
            createdAt: createdAt,
            difficulty: Difficulty(rawValue: difficulty) ?? .medium,
            cards: mapped
        )
    }
}
