import CoreData

/// Core Data-backed repository. Main-actor isolated (so it satisfies the
/// `Sendable` protocol without `@unchecked`), but every mutation runs on a
/// private background context via `perform`. Only value types cross out.
@MainActor
public final class CoreDataFlashcardRepository: FlashcardRepository {

    private let stack: CoreDataStack
    private var continuations: [UUID: AsyncStream<[Deck]>.Continuation] = [:]

    public init() {
        self.stack = .shared
    }

    /// Test/preview seam — inject an in-memory stack.
    init(stack: CoreDataStack) {
        self.stack = stack
    }

    // MARK: - Writes

    public func createDeck(topic: String, title: String, cards: [Flashcard]) async throws -> Deck {
        let context = stack.newBackgroundContext()
        let deck = try await context.perform {
            let cdDeck = NSEntityDescription.insertNewObject(forEntityName: "CDDeck", into: context) as! CDDeck
            cdDeck.id = UUID()
            cdDeck.topic = topic
            cdDeck.title = title
            cdDeck.createdAt = .now

            for (index, card) in cards.enumerated() {
                let cdCard = NSEntityDescription.insertNewObject(forEntityName: "CDCard", into: context) as! CDCard
                cdCard.apply(card)
                cdCard.orderIndex = Int32(index)
                cdCard.createdAt = .now
                cdCard.deck = cdDeck
            }

            try context.save()
            return cdDeck.toDomain()
        }
        await broadcast()
        return deck
    }

    public func deleteDeck(id: UUID) async throws {
        let context = stack.newBackgroundContext()
        try await context.perform {
            let request = CDDeck.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            guard let deck = try context.fetch(request).first else { return }
            context.delete(deck)                       // cascade deletes its cards
            try context.save()
        }
        await broadcast()
    }

    public func updateReviewState(cardID: UUID, state: ReviewState) async throws {
        let context = stack.newBackgroundContext()
        try await context.perform {
            let request = CDCard.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", cardID as CVarArg)
            request.fetchLimit = 1
            guard let card = try context.fetch(request).first else { return }
            card.applyReview(state)
            try context.save()
        }
        await broadcast()
    }

    // MARK: - Reads

    public func allDecks() async throws -> [Deck] {
        let context = stack.container.viewContext
        return try await context.perform {
            let request = CDDeck.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            return try context.fetch(request).map { $0.toDomain() }
        }
    }

    public func deck(id: UUID) async throws -> Deck? {
        let context = stack.container.viewContext
        return try await context.perform {
            let request = CDDeck.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            return try context.fetch(request).first?.toDomain()
        }
    }

    // MARK: - Observation

    public func decksStream() -> AsyncStream<[Deck]> {
        let id = UUID()
        return AsyncStream { continuation in
            continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in self?.continuations[id] = nil }
            }
            Task { @MainActor in
                let decks = (try? await self.allDecks()) ?? []
                continuation.yield(decks)
            }
        }
    }

    private func broadcast() async {
        let decks = (try? await allDecks()) ?? []
        for continuation in continuations.values {
            continuation.yield(decks)
        }
    }
}
