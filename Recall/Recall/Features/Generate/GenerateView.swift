import SwiftUI
import RecallKit

struct GenerateView: View {
    @Environment(AppContainer.self) private var container
    @State private var viewModel: GenerateViewModel?
    @State private var topic = ""
    @State private var presentedDeck: Deck?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Palette.surface.ignoresSafeArea()
                content
                    .padding(Theme.Spacing.section)
            }
            .navigationTitle("Create")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $presentedDeck) { deck in
                DeckDetailView(deck: deck)
            }
        }
        .task {
            if viewModel == nil {
                viewModel = GenerateViewModel(
                    generator: container.generator,
                    repository: container.repository
                )
            }
            viewModel?.onAppear()
        }
        .onChange(of: presentedDeck) { _, newValue in
            // Returned from the pushed deck — reset to a fresh idle screen.
            if newValue == nil {
                topic = ""
                viewModel?.reset()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let viewModel {
            switch viewModel.availability {
            case .unavailable(let reason):
                UnavailableStateView(reason: reason)
            case .available:
                available(viewModel)
            }
        }
    }

    @ViewBuilder
    private func available(_ viewModel: GenerateViewModel) -> some View {
        switch viewModel.phase {
        case .idle:
            idle(viewModel)
        case .generating:
            GeneratingView(
                title: viewModel.streamingTitle,
                cards: viewModel.streamingCards,
                skeletonCount: viewModel.skeletonCount,
                onStop: { viewModel.cancel() }
            )
        case .failed(let error):
            FailedStateView(error: error) {
                viewModel.reset()
            }
        case .done(let deck):
            // Stream finished — fall through to the deck on the next runloop tick.
            Color.clear
                .onAppear { presentedDeck = deck }
        }
    }

    private func idle(_ viewModel: GenerateViewModel) -> some View {
        VStack(spacing: Theme.Spacing.section) {
            Spacer()
            Text("> what do you want to learn?")
                .font(Theme.Typo.title)
                .foregroundStyle(Theme.Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

            TopicField(topic: $topic, isEnabled: true) {
                viewModel.generate(topic: topic)
            }

            CalmButton(
                "create deck",
                style: topic.trimmingCharacters(in: .whitespaces).isEmpty ? .quiet : .filled,
                isEnabled: !topic.trimmingCharacters(in: .whitespaces).isEmpty
            ) {
                viewModel.generate(topic: topic)
            }
            .accessibilityIdentifier("createDeckButton")
            Spacer()
            Spacer()
        }
    }
}

#Preview("Generate — available") {
    GenerateView()
        .environment(AppContainer())
        .preferredColorScheme(.dark)
}
