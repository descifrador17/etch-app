import Foundation

/// Scripted generator for previews, tests, and simulators without Apple
/// Intelligence. Emits progressive snapshots just like the real one.
@MainActor
public final class MockGenerator: FlashcardGenerating {

    public enum Behavior: Sendable {
        /// Stream the given cards in one at a time, then complete.
        case stream(cards: [Flashcard], title: String)
        /// Finish by throwing this error.
        case fail(GenerationError)
        /// Report the model as unavailable for the given reason.
        case unavailable(GenerationError.UnavailableReason)
    }

    private let behavior: Behavior
    private let stepDelay: Duration

    public init(
        behavior: Behavior = .stream(cards: MockGenerator.sampleCards, title: "Photosynthesis"),
        stepDelay: Duration = .milliseconds(180)
    ) {
        self.behavior = behavior
        self.stepDelay = stepDelay
    }

    public var availability: GeneratorAvailability {
        if case .unavailable(let reason) = behavior {
            .unavailable(reason)
        } else {
            .available
        }
    }

    public func prewarm() {}

    public func streamDeck(topic: String) -> AsyncThrowingStream<DeckSnapshot, Error> {
        let behavior = behavior
        let stepDelay = stepDelay
        return AsyncThrowingStream { continuation in
            let trimmed = topic.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                continuation.finish(throwing: GenerationError.emptyTopic)
                return
            }

            let task = Task {
                do {
                    switch behavior {
                    case .unavailable(let reason):
                        continuation.finish(throwing: GenerationError.modelUnavailable(reason))

                    case .fail(let error):
                        try await Task.sleep(for: stepDelay)
                        continuation.finish(throwing: error)

                    case .stream(let cards, let title):
                        // Title arrives first.
                        try await Task.sleep(for: stepDelay)
                        try Task.checkCancellation()
                        continuation.yield(DeckSnapshot(title: title, cards: [], isComplete: false))

                        // Then cards, one at a time.
                        var accumulated: [Flashcard] = []
                        for card in cards {
                            try await Task.sleep(for: stepDelay)
                            try Task.checkCancellation()
                            accumulated.append(card)
                            continuation.yield(DeckSnapshot(title: title, cards: accumulated, isComplete: false))
                        }
                        continuation.yield(DeckSnapshot(title: title, cards: accumulated, isComplete: true))
                        continuation.finish()
                    }
                } catch is CancellationError {
                    continuation.finish(throwing: GenerationError.cancelled)
                } catch {
                    continuation.finish(throwing: GenerationError.underlying(String(describing: error)))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Sample data

    public static let sampleCards: [Flashcard] = [
        Flashcard(question: "What is photosynthesis?", answer: "The process by which plants convert light energy into chemical energy stored as glucose.", orderIndex: 0),
        Flashcard(question: "Where in the cell does photosynthesis occur?", answer: "In the chloroplasts, primarily within the thylakoid membranes and stroma.", orderIndex: 1),
        Flashcard(question: "What pigment captures light for photosynthesis?", answer: "Chlorophyll, which absorbs red and blue light and reflects green.", orderIndex: 2),
        Flashcard(question: "What are the reactants of photosynthesis?", answer: "Carbon dioxide and water, using light energy.", orderIndex: 3),
        Flashcard(question: "What are the products of photosynthesis?", answer: "Glucose and oxygen.", orderIndex: 4),
        Flashcard(question: "What are the two main stages of photosynthesis?", answer: "The light-dependent reactions and the Calvin cycle.", orderIndex: 5),
        Flashcard(question: "What does the Calvin cycle produce?", answer: "It fixes carbon dioxide into glucose using ATP and NADPH.", orderIndex: 6),
        Flashcard(question: "Why is photosynthesis important to life?", answer: "It produces oxygen and forms the base of most food chains.", orderIndex: 7),
    ]
}
