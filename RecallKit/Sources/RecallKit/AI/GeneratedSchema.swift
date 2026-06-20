import FoundationModels

/// Guided-generation DTOs. The `@Generable` macro guarantees the model returns
/// these exact shapes — no JSON parsing, no prompt-format babysitting. Kept
/// separate from the domain `Flashcard` so the AI schema can evolve independently.

@Generable
struct GeneratedDeck {
    @Guide(description: "A short, human-friendly title for this study deck, 2 to 5 words.")
    let title: String

    @Guide(description: "Between 8 and 12 flashcards covering the most important, distinct ideas of the topic.")
    let cards: [GeneratedCard]
}

@Generable
struct GeneratedCard {
    @Guide(description: "A focused question testing ONE concept. No 'and'. Under 140 characters.")
    let question: String

    @Guide(description: "A correct, self-contained answer in 1–3 sentences. No preamble like 'The answer is'.")
    let answer: String
}
