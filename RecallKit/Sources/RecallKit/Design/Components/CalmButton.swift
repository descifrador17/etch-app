import SwiftUI

/// A full-width terminal button. Two variants:
/// - `.filled` — Apple-Blue fill, white mono label, the primary action.
/// - `.quiet`  — transparent fill, mute label, hairline border, low-emphasis.
/// Labels render bracketed, e.g. `[ create deck ]`.
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
            Text("[ \(title) ]")
                .font(Theme.Typo.buttonLabel)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
                .foregroundStyle(foreground)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                        .fill(background)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                        .strokeBorder(border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(pressed ? 0.7 : (isEnabled ? 1 : 0.4))
        .animation(Motion.settle, value: pressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if isEnabled { pressed = true } }
                .onEnded { _ in pressed = false }
        )
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }

    private var foreground: Color {
        switch style {
        case .filled: .white
        case .quiet:  Theme.Palette.inkSecondary
        }
    }

    private var background: Color {
        switch style {
        case .filled: Theme.Palette.accent
        case .quiet:  .clear
        }
    }

    private var border: Color {
        switch style {
        case .filled: .clear
        case .quiet:  Theme.Palette.hairlineStrong
        }
    }
}

#Preview("CalmButton") {
    ZStack {
        Theme.Palette.surface.ignoresSafeArea()
        VStack(spacing: Theme.Spacing.md) {
            CalmButton("create deck") {}
            CalmButton("create deck", isEnabled: false) {}
            CalmButton("stop", style: .quiet) {}
        }
        .padding()
    }
}
