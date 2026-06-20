import SwiftUI

/// A full-width calm button. Two variants:
/// - `.filled` — sage accent fill, the primary action.
/// - `.quiet`  — inkSecondary text, no fill, for low-emphasis / disabled-feeling actions.
public struct CalmButton: View {
    public enum Style {
        case filled
        case quiet
    }

    private let title: String
    private let style: Style
    private let isEnabled: Bool
    private let action: () -> Void

    @State private var pressed = false

    public init(
        _ title: String,
        style: Style = .filled,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.isEnabled = isEnabled
        self.action = action
    }

    public var body: some View {
        Button {
            Haptics.softTap()
            action()
        } label: {
            Text(title)
                .font(Theme.Typo.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
                .foregroundStyle(foreground)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .scaleEffect(pressed ? 0.97 : 1)
        .animation(Motion.settle, value: pressed)
        .opacity(isEnabled ? 1 : 0.55)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if isEnabled { pressed = true } }
                .onEnded { _ in pressed = false }
        )
        .accessibilityAddTraits(.isButton)
    }

    private var foreground: Color {
        switch style {
        case .filled: .white
        case .quiet: Theme.Palette.inkSecondary
        }
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .filled: Theme.Palette.accent
        case .quiet: Color.clear
        }
    }
}

#Preview("CalmButton") {
    ZStack {
        Theme.Palette.surface.ignoresSafeArea()
        VStack(spacing: Theme.Spacing.md) {
            CalmButton("Create deck") {}
            CalmButton("Create deck", isEnabled: false) {}
            CalmButton("Stop", style: .quiet) {}
        }
        .padding()
    }
}
