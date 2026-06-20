import SwiftUI

/// An in-flight placeholder block — a dim `surfaceRaised` rectangle with a
/// hairline border and a slow opacity pulse (no gradient sweep, no spinner).
/// Honors Reduce Motion (the pulse simply stops).
public struct ShimmerPlaceholder: View {
    private let cornerRadius: CGFloat

    @State private var dim = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(cornerRadius: CGFloat = Theme.Radius.card) {
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Theme.Palette.surfaceRaised)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.Palette.hairline, lineWidth: 1)
            )
            .opacity(dim ? 0.45 : 0.85)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    dim = true
                }
            }
            .accessibilityHidden(true)
    }
}

#Preview("ShimmerPlaceholder") {
    ZStack {
        Theme.Palette.surface.ignoresSafeArea()
        VStack(spacing: Theme.Spacing.interCard) {
            ForEach(0..<3, id: \.self) { _ in
                ShimmerPlaceholder()
                    .frame(height: 72)
            }
        }
        .padding()
    }
}
