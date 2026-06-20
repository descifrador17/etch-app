import SwiftUI
import etchKit

/// The flip card. 3D rotation around Y, content swapped at 90°. Honors Reduce
/// Motion (crossfade) and reads as one VoiceOver element with a flip hint.
struct FlashcardView: View {
    let card: Flashcard
    var minHeight: CGFloat = 220

    @State private var flipped = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            face(text: card.question, kind: "Question", showing: !flipped)
            face(text: card.answer, kind: "Answer", showing: flipped)
                .rotation3DEffect(.degrees(180), axis: (0, 1, 0))
        }
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (0, 1, 0))
        .animation(reduceMotion ? nil : Motion.flip, value: flipped)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.softTap()
            if reduceMotion {
                withAnimation(.easeInOut(duration: 0.25)) { flipped.toggle() }
            } else {
                flipped.toggle()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(flipped ? "Answer. \(card.answer)" : "Question. \(card.question)")
        .accessibilityHint("Double tap to flip")
        .accessibilityAddTraits(.isButton)
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
                    .lineLimit(6)
            }
            .padding(Theme.Spacing.cardInner)
            .frame(maxWidth: .infinity, minHeight: minHeight)
        }
        .opacity(showing ? 1 : 0)   // hide the mirror-image back-face
    }
}

#Preview("Flashcard") {
    FlashcardView(card: MockGenerator.sampleCards[0])
        .padding()
        .background(Theme.Palette.surface)
        .preferredColorScheme(.dark)
}
