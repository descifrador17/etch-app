import SwiftUI

/// The foundational rounded container — `surfaceRaised` fill, soft low-opacity
/// shadow, hairline border. Every card and sheet sits on one of these.
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
            .shadow(
                color: .black.opacity(Theme.Shadow.opacity),
                radius: Theme.Shadow.radius,
                x: 0,
                y: Theme.Shadow.y
            )
    }
}

#Preview("CardSurface") {
    ZStack {
        Theme.Palette.surface.ignoresSafeArea()
        CardSurface {
            Text("A calm surface")
                .font(Theme.Typo.cardFace)
                .foregroundStyle(Theme.Palette.ink)
                .padding(Theme.Spacing.cardInner)
        }
        .padding()
    }
}
