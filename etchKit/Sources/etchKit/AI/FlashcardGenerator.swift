import FoundationModels
import Foundation

/// Real on-device generator. `@MainActor` because `LanguageModelSession` drives
/// UI-facing streaming and isn't `Sendable`; the framework runs inference off
/// the main thread internally, so this does not block the UI.
@MainActor
public final class FlashcardGenerator: FlashcardGenerating {

    public init() {}

    public nonisolated var availability: GeneratorAvailability {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:           return .unavailable(.deviceNotEligible)
            case .appleIntelligenceNotEnabled: return .unavailable(.appleIntelligenceNotEnabled)
            case .modelNotReady:               return .unavailable(.modelNotReady)
            @unknown default:                  return .unavailable(.unknown)
            }
        }
    }

    public func prewarm() {
        guard case .available = availability else { return }
        let session = LanguageModelSession(instructions: Self.instructions(for: .medium))
        session.prewarm()
    }

    public func streamDeck(topic: String, difficulty: Difficulty = .medium) -> AsyncThrowingStream<DeckSnapshot, Error> {
        AsyncThrowingStream { continuation in
            let trimmed = topic.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                continuation.finish(throwing: GenerationError.emptyTopic)
                return
            }
            guard case .available = availability else {
                let reason: GenerationError.UnavailableReason =
                    if case .unavailable(let r) = availability { r } else { .unknown }
                continuation.finish(throwing: GenerationError.modelUnavailable(reason))
                return
            }

            let task = Task { @MainActor in
                do {
                    let session = LanguageModelSession(instructions: Self.instructions(for: difficulty))
                    let options = GenerationOptions(temperature: 0.6)
                    let stream = session.streamResponse(
                        to: Self.prompt(for: trimmed, difficulty: difficulty),
                        generating: GeneratedDeck.self,
                        options: options
                    )

                    var last: GeneratedDeck.PartiallyGenerated?
                    for try await snapshot in stream {
                        try Task.checkCancellation()
                        last = snapshot.content
                        continuation.yield(Self.snapshot(from: snapshot.content, complete: false))
                    }

                    // Final snapshot: reuse the last partial, flip isComplete.
                    if let last {
                        continuation.yield(Self.snapshot(from: last, complete: true))
                    } else {
                        continuation.yield(DeckSnapshot(isComplete: true))
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: GenerationError.cancelled)
                } catch {
                    continuation.finish(throwing: Self.map(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Prompt

    private static let baseInstructions = """
    You generate concise study flashcards. Each card tests exactly one idea. \
    Questions are specific and unambiguous. Answers are correct and self-contained, \
    1 to 3 sentences, with no filler. Cover the most important, distinct sub-topics. \
    Avoid duplicate cards. Use clear, plain language.
    """

    private static func instructions(for difficulty: Difficulty) -> String {
        let level: String
        switch difficulty {
        case .easy:
            level = "Target a beginner. Test basic recall: definitions, key terms, and simple facts. Keep questions short and answers to a single sentence."
        case .medium:
            level = "Target a learner with some familiarity. Test solid conceptual understanding and the relationships between ideas."
        case .hard:
            level = "Target an advanced learner. Test applied reasoning, comparisons, cause and effect, and common misconceptions."
        case .ultra:
            level = "Target an expert. Test deep synthesis, edge cases, subtle distinctions, and non-obvious implications."
        }
        return baseInstructions + " " + level
    }

    private static func prompt(for topic: String, difficulty: Difficulty) -> String {
        "Create a \(difficulty.rawValue)-difficulty study flashcard deck for the topic: \"\(topic)\"."
    }

    // MARK: - Mapping

    private static func snapshot(
        from partial: GeneratedDeck.PartiallyGenerated,
        complete: Bool
    ) -> DeckSnapshot {
        let cards: [Flashcard] = (partial.cards ?? []).enumerated().compactMap { index, card in
            guard let question = card.question, let answer = card.answer,
                  !question.isEmpty, !answer.isEmpty else { return nil }
            return Flashcard(question: question, answer: answer, orderIndex: index)
        }
        return DeckSnapshot(title: partial.title, cards: cards, isComplete: complete)
    }

    private static func map(_ error: Error) -> GenerationError {
        if let generationError = error as? LanguageModelSession.GenerationError {
            switch generationError {
            case .guardrailViolation, .refusal:
                return .guardrailTriggered
            case .exceededContextWindowSize:
                return .contextWindowExceeded
            default:
                return .underlying(String(describing: generationError))
            }
        }
        if error is CancellationError { return .cancelled }
        return .underlying(String(describing: error))
    }
}
