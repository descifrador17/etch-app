import Testing
@testable import etchKit

@Suite("Difficulty")
struct DifficultyTests {
    @Test("Cases and raw values are stable")
    func rawValues() {
        #expect(Difficulty.allCases == [.easy, .medium, .hard, .ultra])
        #expect(Difficulty(rawValue: "ultra") == .ultra)
        #expect(Difficulty(rawValue: "nope") == nil)
    }

    @Test("Deck defaults to medium difficulty")
    func deckDefault() {
        let deck = Deck(topic: "t", title: "t", cards: [])
        #expect(deck.difficulty == .medium)
    }
}
