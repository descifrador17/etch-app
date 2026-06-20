import SwiftUI

/// A breathing skeleton block used for in-flight cards. No spinner — a slow
/// masked gradient sweep at ~1.4s, honoring Reduce Motion (falls back to a
/// gentle opacity pulse).
public struct ShimmerPlaceholder: View {
    private let cornerRadius: CGFloat

    @State private var phase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(cornerRadius: CGFloat = Theme.Radius.card) {
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Theme.Palette.hairline.opacity(0.7))
            .overlay {
                if !reduceMotion {
                    sweep
                }
            }
            .opacity(reduceMotion ? pulseOpacity : 1)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onAppear { startAnimating() }
            .accessibilityHidden(true)
    }

    private var sweep: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [.clear, Theme.Palette.surfaceRaised.opacity(0.55), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geo.size.width * 0.6)
            .offset(x: phase * geo.size.width * 1.6)
        }
    }

    @State private var pulse = false
    private var pulseOpacity: Double { pulse ? 0.9 : 0.5 }

    private func startAnimating() {
        if reduceMotion {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        } else {
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}

#Preview("ShimmerPlaceholder") {
    ZStack {
        Theme.Palette.surface.ignoresSafeArea()
        VStack(spacing: Theme.Spacing.interCard) {
            ForEach(0..<3, id: \.self) { _ in
                ShimmerPlaceholder()
                    .frame(height: 120)
            }
        }
        .padding()
    }
}
