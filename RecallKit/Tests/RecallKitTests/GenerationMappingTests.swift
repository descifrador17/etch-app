import Testing
import Foundation
@testable import RecallKit

@MainActor
@Suite("Generation streaming & mapping")
struct GenerationMappingTests {

    @Test("Mock streams progressive snapshots ending in a complete deck")
    func streamsToCompletion() async throws {
        let generator = MockGenerator(
            behavior: .stream(cards: MockGenerator.sampleCards, title: "Test"),
            stepDelay: .milliseconds(1)
        )

        var snapshots: [DeckSnapshot] = []
        for try await snapshot in generator.streamDeck(topic: "anything") {
            snapshots.append(snapshot)
        }

        // Card counts are monotonically non-decreasing.
        let counts = snapshots.map(\.cards.count)
        #expect(counts == counts.sorted())

        let final = try #require(snapshots.last)
        #expect(final.isComplete)
        #expect(final.title == "Test")
        #expect(final.cards.count == MockGenerator.sampleCards.count)
        #expect(final.cards.map(\.orderIndex) == Array(0..<MockGenerator.sampleCards.count))
    }

    @Test("Empty topic fails fast with .emptyTopic")
    func emptyTopicFails() async {
        let generator = MockGenerator(stepDelay: .milliseconds(1))
        await #expect(throws: GenerationError.emptyTopic) {
            for try await _ in generator.streamDeck(topic: "   ") {}
        }
    }

    @Test("Scripted failure propagates")
    func failurePropagates() async {
        let generator = MockGenerator(behavior: .fail(.guardrailTriggered), stepDelay: .milliseconds(1))
        await #expect(throws: GenerationError.guardrailTriggered) {
            for try await _ in generator.streamDeck(topic: "x") {}
        }
    }

    @Test("Unavailable model reports availability and fails the stream")
    func unavailablePropagates() async {
        let generator = MockGenerator(behavior: .unavailable(.appleIntelligenceNotEnabled))
        #expect(generator.availability == .unavailable(.appleIntelligenceNotEnabled))

        await #expect(throws: GenerationError.modelUnavailable(.appleIntelligenceNotEnabled)) {
            for try await _ in generator.streamDeck(topic: "x") {}
        }
    }

    @Test("Cancelling mid-stream stops before the deck completes")
    func cancellation() async throws {
        let generator = MockGenerator(stepDelay: .milliseconds(40))
        let task = Task { @MainActor () -> Bool in
            var completed = false
            // A consumer-cancelled AsyncThrowingStream resumes `next()` with nil
            // (graceful finish), so the loop ends without a thrown error.
            do {
                for try await snapshot in generator.streamDeck(topic: "x") {
                    if snapshot.isComplete { completed = true }
                }
            } catch {}
            return completed
        }
        try await Task.sleep(for: .milliseconds(70))   // a couple of cards in
        task.cancel()
        let completed = await task.value
        #expect(completed == false)                    // partial discarded, never completed
    }
}
