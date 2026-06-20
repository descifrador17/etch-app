import SwiftUI
import etchKit

struct GenerateView: View {
    @Environment(AppContainer.self) private var container
    @State private var viewModel: GenerateViewModel?
    @State private var topic = ""
    @State private var difficulty: Difficulty = .medium
    @State private var presentedDeck: Deck?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Palette.surface.ignoresSafeArea()
                content
                    .padding(Theme.Spacing.section)
            }
            .toolbar(.hidden, for: .navigationBar)
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
                viewModel.generate(topic: topic, difficulty: difficulty)
            }

            DifficultyPicker(selection: $difficulty)

            CalmButton(
                "create deck",
                style: topic.trimmingCharacters(in: .whitespaces).isEmpty ? .quiet : .filled,
                isEnabled: !topic.trimmingCharacters(in: .whitespaces).isEmpty
            ) {
                viewModel.generate(topic: topic, difficulty: difficulty)
            }
            .accessibilityIdentifier("createDeckButton")
            Spacer()
            Spacer()
        }
    }
}

/// Bracketed difficulty selector `[easy] [medium] [hard] [ultra]`. The active
/// level shows its tint; the rest stay muted. Matches the terminal tab style.
private struct DifficultyPicker: View {
    @Binding var selection: Difficulty

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("> difficulty")
                .font(Theme.Typo.body)
                .foregroundStyle(Theme.Palette.ink)
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(Difficulty.allCases, id: \.self) { level in
                    let active = level == selection
                    Button {
                        Haptics.softTap()
                        selection = level
                    } label: {
                        Text("[\(level.label)]")
                            .font(Theme.Typo.buttonLabel)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.sm)
                            .foregroundStyle(active ? level.tint : Theme.Palette.inkSecondary)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                                    .strokeBorder(active ? level.tint.opacity(0.7) : Theme.Palette.hairline, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("difficulty-\(level.rawValue)")
                    .accessibilityLabel(level.label)
                    .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
    }
}

#Preview("Generate — available") {
    GenerateView()
        .environment(AppContainer())
        .preferredColorScheme(.dark)
}
