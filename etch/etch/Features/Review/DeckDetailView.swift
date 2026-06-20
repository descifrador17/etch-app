import SwiftUI
import etchKit

struct DeckDetailView: View {
    let deck: Deck

    @Environment(AppContainer.self) private var container
    @State private var viewModel: DeckDetailViewModel?
    @State private var studying = false

    var body: some View {
        ZStack {
            Theme.Palette.surface.ignoresSafeArea()
            if let viewModel {
                content(viewModel)
            }
        }
        .navigationTitle(deck.title)
        .navigationBarTitleDisplayMode(.large)
        .task {
            if viewModel == nil {
                viewModel = DeckDetailViewModel(deck: deck, repository: container.repository)
            }
            await viewModel?.refresh()
        }
        .sheet(isPresented: $studying, onDismiss: {
            Task { await viewModel?.refresh() }
        }) {
            StudyView(deck: viewModel?.deck ?? deck)
        }
    }

    private func content(_ viewModel: DeckDetailViewModel) -> some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.interCard) {
                HStack {
                    Text("[\(viewModel.deck.difficulty.label)]")
                        .font(Theme.Typo.caption)
                        .foregroundStyle(viewModel.deck.difficulty.tint)
                    Spacer()
                }

                if viewModel.hasDue {
                    CalmButton("study \(viewModel.dueCount) due") {
                        studying = true
                    }
                    .padding(.bottom, Theme.Spacing.xs)
                }

                ForEach(viewModel.deck.cards) { card in
                    FlashcardView(card: card)
                }
            }
            .padding(Theme.Spacing.section)
        }
        .scrollIndicators(.hidden)
    }
}

#Preview("DeckDetail") {
    NavigationStack {
        DeckDetailView(deck: Deck(topic: "Photosynthesis", title: "Photosynthesis", cards: MockGenerator.sampleCards))
    }
    .environment(AppContainer())
    .preferredColorScheme(.dark)
}
