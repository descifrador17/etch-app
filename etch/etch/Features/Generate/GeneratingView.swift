import SwiftUI
import etchKit

/// Streaming UI: terminal placeholder rows replaced, one at a time, by real
/// cards rising into place. The deck title fades in once it arrives.
struct GeneratingView: View {
    let title: String?
    let cards: [Flashcard]
    let skeletonCount: Int
    let onStop: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var slotCount: Int { max(skeletonCount, cards.count) }

    var body: some View {
        VStack(spacing: Theme.Spacing.section) {
            titleHeader

            ScrollView {
                LazyVStack(spacing: Theme.Spacing.interCard) {
                    ForEach(0..<slotCount, id: \.self) { index in
                        slot(at: index)
                    }
                }
                .padding(.bottom, Theme.Spacing.section)
                .animation(reduceMotion ? nil : Motion.gentle, value: cards.count)
            }
            .scrollIndicators(.hidden)

            CalmButton("stop", style: .quiet, action: onStop)
        }
    }

    @ViewBuilder
    private var titleHeader: some View {
        if let title {
            Text("> \(title)")
                .font(Theme.Typo.title)
                .foregroundStyle(Theme.Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity)
                .id(title)
        } else {
            Text("> writing your deck…")
                .font(Theme.Typo.title)
                .foregroundStyle(Theme.Palette.inkSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func slot(at index: Int) -> some View {
        if index < cards.count {
            StreamingCard(card: cards[index])
                .transition(
                    reduceMotion
                        ? .opacity
                        : .move(edge: .bottom).combined(with: .opacity)
                )
        } else {
            ShimmerPlaceholder()
                .frame(height: 72)
        }
    }
}

/// A freshly streamed card — shows the question in a terminal frame.
private struct StreamingCard: View {
    let card: Flashcard

    var body: some View {
        CardSurface {
            Text(card.question)
                .font(Theme.Typo.body.weight(.medium))
                .foregroundStyle(Theme.Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .padding(Theme.Spacing.cardInner)
        }
    }
}

#Preview("Generating") {
    GeneratingView(
        title: "Photosynthesis",
        cards: Array(MockGenerator.sampleCards.prefix(3)),
        skeletonCount: 8,
        onStop: {}
    )
    .padding()
    .background(Theme.Palette.surface)
    .preferredColorScheme(.dark)
}
