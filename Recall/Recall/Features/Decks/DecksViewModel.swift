import SwiftUI
import RecallKit

@MainActor
@Observable
final class DecksViewModel {
    private(set) var decks: [Deck] = []
    private(set) var hasLoaded = false

    private let repository: FlashcardRepository
    private var observation: Task<Void, Never>?

    init(repository: FlashcardRepository) {
        self.repository = repository
    }

    /// Subscribe to the repository's decks stream. Yields the current set
    /// immediately and again after every mutation.
    func start() {
        guard observation == nil else { return }
        observation = Task {
            for await decks in repository.decksStream() {
                self.decks = decks
                self.hasLoaded = true
            }
        }
    }

    func delete(_ deck: Deck) {
        Task { try? await repository.deleteDeck(id: deck.id) }
    }

    func delete(at offsets: IndexSet) {
        for index in offsets {
            delete(decks[index])
        }
    }
}
