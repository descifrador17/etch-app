import SwiftUI
import RecallKit

struct StudyView: View {
    let deck: Deck

    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: StudyViewModel?

    var body: some View {
        ZStack {
            Theme.Palette.surface.ignoresSafeArea()
            if let viewModel {
                content(viewModel)
            }
        }
        .task {
            if viewModel == nil {
                viewModel = StudyViewModel(deck: deck, repository: container.repository)
            }
        }
    }

    @ViewBuilder
    private func content(_ viewModel: StudyViewModel) -> some View {
        VStack(spacing: Theme.Spacing.section) {
            header(viewModel)

            if viewModel.finished {
                SessionEndView(nextDue: viewModel.nextDue) { dismiss() }
            } else if let card = viewModel.current {
                Spacer()
                StudyCard(card: card, showAnswer: viewModel.showAnswer) {
                    viewModel.reveal()
                }
                Spacer()
                if viewModel.showAnswer {
                    GradeBar { grade in
                        withAnimation(Motion.settle) { viewModel.grade(grade) }
                    }
                    .transition(.opacity)
                } else {
                    Text("tap the card to reveal")
                        .font(Theme.Typo.caption)
                        .foregroundStyle(Theme.Palette.inkSecondary)
                        .frame(height: 56)
                }
            }
        }
        .padding(Theme.Spacing.section)
        .animation(Motion.gentle, value: viewModel.showAnswer)
    }

    private func header(_ viewModel: StudyViewModel) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack {
                Text(deck.title)
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Palette.inkSecondary)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Text("[x]")
                        .font(Theme.Typo.body)
                        .foregroundStyle(Theme.Palette.inkSecondary)
                }
                .accessibilityLabel("Close study session")
            }
            ProgressBar(progress: viewModel.finished ? 1 : viewModel.progress)
                .frame(height: 4)
        }
    }
}

/// The study card — front first, flips to the answer on reveal.
private struct StudyCard: View {
    let card: Flashcard
    let showAnswer: Bool
    let onReveal: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            face(text: card.question, kind: "Question", showing: !showAnswer)
            face(text: card.answer, kind: "Answer", showing: showAnswer)
                .rotation3DEffect(.degrees(180), axis: (0, 1, 0))
        }
        .rotation3DEffect(.degrees(showAnswer ? 180 : 0), axis: (0, 1, 0))
        .animation(reduceMotion ? nil : Motion.flip, value: showAnswer)
        .contentShape(Rectangle())
        .onTapGesture { if !showAnswer { onReveal() } }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(showAnswer ? "Answer. \(card.answer)" : "Question. \(card.question)")
        .accessibilityHint(showAnswer ? "Grade your recall below" : "Double tap to reveal the answer")
    }

    private func face(text: String, kind: String, showing: Bool) -> some View {
        CardSurface {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("// \(kind.uppercased())")
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Palette.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(text)
                    .font(Theme.Typo.cardFace)
                    .foregroundStyle(Theme.Palette.ink)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .minimumScaleFactor(0.6)
                    .lineLimit(8)
            }
            .padding(Theme.Spacing.cardInner)
            .frame(maxWidth: .infinity, minHeight: 260)
        }
        .opacity(showing ? 1 : 0)
    }
}

/// Thin terminal progress bar — hairline track, ink fill, sharp corners.
private struct ProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Theme.Palette.hairline)
                Rectangle()
                    .fill(Theme.Palette.ink)
                    .frame(width: max(0, min(1, progress)) * geo.size.width)
            }
        }
        .animation(Motion.gentle, value: progress)
        .accessibilityHidden(true)
    }
}

/// "Done for now" with the next review time.
private struct SessionEndView: View {
    let nextDue: Date?
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Spacer()
            Text("[x]")
                .font(Theme.Typo.display)
                .foregroundStyle(Theme.Palette.gradeEasy)
            Text("done for now")
                .font(Theme.Typo.title)
                .foregroundStyle(Theme.Palette.ink)
            if let nextDue {
                Text("next review \(Self.relative(to: nextDue))")
                    .font(Theme.Typo.body)
                    .foregroundStyle(Theme.Palette.inkSecondary)
            } else {
                Text("nicely done.")
                    .font(Theme.Typo.body)
                    .foregroundStyle(Theme.Palette.inkSecondary)
            }
            Spacer()
            CalmButton("done", action: onDone)
        }
    }

    private static func relative(to date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

#Preview("Study") {
    StudyView(deck: Deck(topic: "Photosynthesis", title: "Photosynthesis", cards: MockGenerator.sampleCards))
        .environment(AppContainer())
        .preferredColorScheme(.dark)
}
