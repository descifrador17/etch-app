import SwiftUI
import RecallKit

struct DeckRow: View {
    let deck: Deck

    private var dueCount: Int { deck.dueCount() }

    var body: some View {
        CardSurface {
            HStack(alignment: .center, spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(deck.title)
                        .font(Theme.Typo.title)
                        .foregroundStyle(Theme.Palette.ink)
                        .lineLimit(2)

                    Text("\(deck.cards.count) card\(deck.cards.count == 1 ? "" : "s")")
                        .font(Theme.Typo.caption)
                        .foregroundStyle(Theme.Palette.inkSecondary)
                }

                Spacer(minLength: Theme.Spacing.sm)

                if dueCount > 0 {
                    DueBadge(count: dueCount)
                }
            }
            .padding(Theme.Spacing.cardInner)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            dueCount > 0
                ? "\(deck.title), \(deck.cards.count) cards, \(dueCount) due"
                : "\(deck.title), \(deck.cards.count) cards"
        )
    }
}

/// Small accent pill: count of cards due now.
private struct DueBadge: View {
    let count: Int

    var body: some View {
        Text("\(count) due")
            .font(Theme.Typo.caption)
            .foregroundStyle(.white)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs / 2)
            .background(
                Capsule().fill(Theme.Palette.accent)
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
}
