import SwiftUI
import etchKit

struct DeckRow: View {
    let deck: Deck

    private var dueCount: Int { deck.dueCount() }

    var body: some View {
        CardSurface {
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                Text("[#]")
                    .font(Theme.Typo.body)
                    .foregroundStyle(Theme.Palette.inkSecondary)

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(deck.title)
                        .font(Theme.Typo.body.weight(.semibold))
                        .foregroundStyle(Theme.Palette.ink)
                        .lineLimit(2)

                    HStack(spacing: Theme.Spacing.xs) {
                        Text("\(deck.cards.count) card\(deck.cards.count == 1 ? "" : "s")")
                            .font(Theme.Typo.caption)
                            .foregroundStyle(Theme.Palette.inkSecondary)
                        Text("[\(deck.difficulty.label)]")
                            .font(Theme.Typo.caption)
                            .foregroundStyle(deck.difficulty.tint)
                    }
                }

                Spacer(minLength: Theme.Spacing.sm)

                if dueCount > 0 {
                    Text("[\(dueCount) due]")
                        .font(Theme.Typo.caption)
                        .foregroundStyle(Theme.Palette.accent)
                }
            }
            .padding(Theme.Spacing.cardInner)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            dueCount > 0
                ? "\(deck.title), \(deck.cards.count) cards, \(deck.difficulty.label), \(dueCount) due"
                : "\(deck.title), \(deck.cards.count) cards, \(deck.difficulty.label)"
        )
    }
}

#Preview("DeckRow") {
    VStack(spacing: Theme.Spacing.interCard) {
        DeckRow(deck: Deck(topic: "Photosynthesis", title: "Photosynthesis", cards: MockGenerator.sampleCards))
        DeckRow(deck: Deck(topic: "Swift", title: "Swift Actors", cards: Array(MockGenerator.sampleCards.prefix(3)).map {
            var c = $0; c.review.dueDate = .distantFuture; return c
        }))
    }
    .padding()
    .background(Theme.Palette.surface)
    .preferredColorScheme(.dark)
}
