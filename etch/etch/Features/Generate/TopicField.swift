import SwiftUI
import etchKit

/// The single prompt-style input. Placeholder rotates gentle lowercase examples
/// behind a leading `> ` caret.
struct TopicField: View {
    @Binding var topic: String
    var isEnabled: Bool
    var onSubmit: () -> Void

    @FocusState private var focused: Bool
    @State private var placeholderIndex = 0

    private let placeholders = ["photosynthesis", "combine operators", "wwii treaties", "swift actors", "the krebs cycle"]
    private let rotation = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    /// Topic length is clamped to ~80 chars per the generation tuning guard.
    private let maxLength = 80

    var body: some View {
        CardSurface {
            HStack(spacing: Theme.Spacing.xs) {
                Text(">")
                    .font(Theme.Typo.body)
                    .foregroundStyle(Theme.Palette.accent)
                TextField(
                    "",
                    text: $topic,
                    prompt: Text(placeholders[placeholderIndex])
                        .foregroundColor(Theme.Palette.inkSecondary)
                )
                .focused($focused)
                .font(Theme.Typo.body)
                .foregroundStyle(Theme.Palette.ink)
                .textInputAutocapitalization(.never)
                .submitLabel(.go)
                .accessibilityIdentifier("topicField")
                .disabled(!isEnabled)
                .onSubmit(onSubmit)
                .onChange(of: topic) { _, newValue in
                    if newValue.count > maxLength {
                        topic = String(newValue.prefix(maxLength))
                    }
                }
            }
            .padding(Theme.Spacing.cardInner)
        }
        .onReceive(rotation) { _ in
            guard topic.isEmpty else { return }
            withAnimation(Motion.gentle) {
                placeholderIndex = (placeholderIndex + 1) % placeholders.count
            }
        }
        .onAppear { focused = true }
    }
}
