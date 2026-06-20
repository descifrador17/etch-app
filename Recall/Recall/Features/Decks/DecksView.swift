import SwiftUI
import RecallKit

struct DecksView: View {
    @Environment(AppContainer.self) private var container
    @State private var viewModel: DecksViewModel?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Palette.surface.ignoresSafeArea()
                if let viewModel {
                    content(viewModel)
                }
            }
            .navigationTitle("Decks")
            .navigationDestination(for: Deck.self) { deck in
                DeckDetailView(deck: deck)
            }
        }
        .task {
            if viewModel == nil {
                viewModel = DecksViewModel(repository: container.repository)
            }
            viewModel?.start()
        }
    }

    @ViewBuilder
    private func content(_ viewModel: DecksViewModel) -> some View {
        if viewModel.decks.isEmpty {
            if viewModel.hasLoaded {
                EmptyDecksView()
            } else {
                Color.clear   // brief, silent first load
            }
        } else {
            List {
                ForEach(viewModel.decks) { deck in
                    ZStack {
                        NavigationLink(value: deck) { EmptyView() }.opacity(0)
                        DeckRow(deck: deck)
                    }
                    .listRowInsets(EdgeInsets(top: Theme.Spacing.xs, leading: Theme.Spacing.md,
                                              bottom: Theme.Spacing.xs, trailing: Theme.Spacing.md))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            withAnimation(Motion.settle) { viewModel.delete(deck) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
        }
    }
}

/// Calm empty state — one line, one gentle illustration.
struct EmptyDecksView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Theme.Palette.accent)
            Text("No decks yet")
                .font(Theme.Typo.title)
                .foregroundStyle(Theme.Palette.ink)
            Text("Create your first deck from the Create tab.")
                .font(Theme.Typo.body)
                .foregroundStyle(Theme.Palette.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Spacing.section)
    }
}

#Preview("Decks") {
    DecksView()
        .environment(AppContainer())
}
