import SwiftUI
import RecallKit

@MainActor
@Observable
final class GenerateViewModel {
    enum Phase: Equatable {
        case idle
        case generating
        case done(Deck)
        case failed(GenerationError)
    }

    private(set) var phase: Phase = .idle
    private(set) var streamingCards: [Flashcard] = []
    private(set) var streamingTitle: String?

    /// Number of skeleton placeholders shown before/while cards stream in.
    let skeletonCount = 8

    private let generator: FlashcardGenerating
    private let repository: FlashcardRepository
    private var task: Task<Void, Never>?

    init(generator: FlashcardGenerating, repository: FlashcardRepository) {
        self.generator = generator
        self.repository = repository
    }

    var isGenerating: Bool { phase == .generating }

    var availability: GeneratorAvailability { generator.availability }

    func onAppear() {
        generator.prewarm()
    }

    func generate(topic: String) {
        let trimmed = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        task?.cancel()
        streamingCards = []
        streamingTitle = nil
        phase = .generating

        task = Task {
            do {
                var last = DeckSnapshot()
                for try await snapshot in generator.streamDeck(topic: trimmed) {
                    streamingTitle = snapshot.title ?? streamingTitle
                    streamingCards = snapshot.cards
                    last = snapshot
                }
                guard !Task.isCancelled else { return }
                guard !last.cards.isEmpty else {
                    phase = .failed(.noUsableCards)
                    return
                }
                let deck = try await repository.createDeck(
                    topic: trimmed,
                    title: last.title ?? trimmed,
                    cards: last.cards
                )
                Haptics.success()
                phase = .done(deck)
            } catch let error as GenerationError {
                if error == .cancelled { return }
                phase = .failed(error)
            } catch {
                phase = .failed(.underlying(String(describing: error)))
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        streamingCards = []
        streamingTitle = nil
        phase = .idle
    }

    func reset() {
        cancel()
    }
}
