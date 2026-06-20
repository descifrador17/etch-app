import SwiftUI
import etchKit

@MainActor
@Observable
final class DeckDetailViewModel {
    private(set) var deck: Deck

    private let repository: FlashcardRepository

    init(deck: Deck, repository: FlashcardRepository) {
        self.deck = deck
        self.repository = repository
    }

    var dueCount: Int { deck.dueCount() }
    var hasDue: Bool { dueCount > 0 }

    /// Re-fetch after a study session so due counts and SR state are current.
    func refresh() async {
        if let fresh = try? await repository.deck(id: deck.id) {
            deck = fresh
        }
    }
}
