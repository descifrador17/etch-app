import SwiftUI

/// The foundational terminal-style container — flat `surfaceRaised` fill, a 1px
/// hairline border, sharp corners, no shadow. Every framed block sits on one.
public struct CardSurface<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.Palette.surfaceRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(Theme.Palette.hairline, lineWidth: 1)
            )
    }
}

#Preview("CardSurface") {
    ZStack {
        Theme.Palette.surface.ignoresSafeArea()
        CardSurface {
            Text("a terminal surface")
                .font(Theme.Typo.cardFace)
                .foregroundStyle(Theme.Palette.ink)
                .padding(Theme.Spacing.cardInner)
        }
        .padding()
    }
}
