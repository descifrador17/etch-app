import Testing
import Foundation
@testable import RecallKit

@MainActor
@Suite("CoreDataFlashcardRepository")
struct RepositoryTests {

    private func makeRepo() -> CoreDataFlashcardRepository {
        CoreDataFlashcardRepository(stack: CoreDataStack(inMemory: true))
    }

    private func sampleCards() -> [Flashcard] {
        [
            Flashcard(question: "Q1", answer: "A1", orderIndex: 0),
            Flashcard(question: "Q2", answer: "A2", orderIndex: 1),
            Flashcard(question: "Q3", answer: "A3", orderIndex: 2),
        ]
    }

    @Test("Create persists a deck and returns it with ordered cards")
    func createAndReturn() async throws {
        let repo = makeRepo()
        let deck = try await repo.createDeck(topic: "Krebs cycle", title: "Krebs Cycle", cards: sampleCards())

        #expect(deck.topic == "Krebs cycle")
        #expect(deck.title == "Krebs Cycle")
        #expect(deck.cards.count == 3)
        #expect(deck.cards.map(\.orderIndex) == [0, 1, 2])
        #expect(deck.cards.map(\.question) == ["Q1", "Q2", "Q3"])
    }

    @Test("allDecks returns saved decks")
    func fetchAll() async throws {
        let repo = makeRepo()
        _ = try await repo.createDeck(topic: "A", title: "A", cards: sampleCards())
        _ = try await repo.createDeck(topic: "B", title: "B", cards: sampleCards())

        let decks = try await repo.allDecks()
        #expect(decks.count == 2)
    }

    @Test("deck(id:) round-trips a specific deck")
    func fetchByID() async throws {
        let repo = makeRepo()
        let created = try await repo.createDeck(topic: "Swift actors", title: "Actors", cards: sampleCards())

        let fetched = try await repo.deck(id: created.id)
        #expect(fetched?.id == created.id)
        #expect(fetched?.cards.count == 3)
    }

    @Test("updateReviewState persists SR fields")
    func updateReview() async throws {
        let repo = makeRepo()
        let deck = try await repo.createDeck(topic: "T", title: "T", cards: sampleCards())
        let card = try #require(deck.cards.first)

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let graded = SpacedRepetitionScheduler.next(card.review, grade: .good, now: now)
        try await repo.updateReviewState(cardID: card.id, state: graded)

        let reloaded = try #require(try await repo.deck(id: deck.id))
        let reloadedCard = try #require(reloaded.cards.first { $0.id == card.id })
        #expect(reloadedCard.review.repetitions == 1)
        #expect(reloadedCard.review.intervalDays == 1)
        #expect(reloadedCard.review.dueDate == graded.dueDate)
        #expect(reloadedCard.review.lastReviewedAt == now)
    }

    @Test("delete removes the deck and cascades to its cards")
    func deleteCascades() async throws {
        let repo = makeRepo()
        let deck = try await repo.createDeck(topic: "T", title: "T", cards: sampleCards())

        try await repo.deleteDeck(id: deck.id)

        let decks = try await repo.allDecks()
        #expect(decks.isEmpty)
        let gone = try await repo.deck(id: deck.id)
        #expect(gone == nil)
    }

    @Test("decksStream emits an initial snapshot and updates after a write")
    func streamObserves() async throws {
        let repo = makeRepo()
        _ = try await repo.createDeck(topic: "first", title: "first", cards: sampleCards())

        var iterator = repo.decksStream().makeAsyncIterator()
        let initial = await iterator.next()
        #expect(initial?.count == 1)

        _ = try await repo.createDeck(topic: "second", title: "second", cards: sampleCards())
        let afterWrite = await iterator.next()
        #expect(afterWrite?.count == 2)
    }
}
