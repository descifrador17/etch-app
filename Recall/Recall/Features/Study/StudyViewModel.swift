import SwiftUI
import RecallKit

@MainActor
@Observable
final class StudyViewModel {
    private(set) var queue: [Flashcard]
    private(set) var index = 0
    private(set) var showAnswer = false
    private(set) var finished = false
    private(set) var nextDue: Date?

    let total: Int

    private let repository: FlashcardRepository
    private var gradedDueDates: [Date] = []

    init(deck: Deck, repository: FlashcardRepository, now: Date = .now) {
        self.repository = repository
        let due = deck.cards
            .filter { $0.review.dueDate <= now }
            .sorted { $0.orderIndex < $1.orderIndex }
        self.queue = due
        self.total = due.count
        if due.isEmpty { finished = true }
    }

    var current: Flashcard? {
        index < queue.count ? queue[index] : nil
    }

    /// Fills as cards are completed. Re-queued "Again" cards extend the queue,
    /// so this can briefly dip — that's honest.
    var progress: Double {
        guard !queue.isEmpty else { return 1 }
        return Double(index) / Double(queue.count)
    }

    func reveal() {
        guard !showAnswer else { return }
        Haptics.softTap()
        showAnswer = true
    }

    func grade(_ grade: ReviewGrade) {
        guard let card = current else { return }
        Haptics.softTap()

        let now = Date.now
        let nextState = SpacedRepetitionScheduler.next(card.review, grade: grade, now: now)

        var updated = card
        updated.review = nextState
        Task { try? await repository.updateReviewState(cardID: card.id, state: nextState) }

        if grade == .again {
            // Resurface near the end of this session.
            queue.append(updated)
        } else {
            gradedDueDates.append(nextState.dueDate)
        }

        showAnswer = false
        index += 1
        if index >= queue.count {
            finish()
        }
    }

    private func finish() {
        finished = true
        nextDue = gradedDueDates.min()
        Haptics.success()
    }
}
