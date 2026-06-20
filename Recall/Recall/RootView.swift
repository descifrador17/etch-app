import SwiftUI
import RecallKit

/// Top "primary-nav" strip: `recall` wordmark at left, `decks` / `create` text
/// tabs at right. The selected screen (each its own NavigationStack) renders below.
struct RootView: View {
    private enum Section: String, CaseIterable {
        case decks, create
    }

    @State private var selection: Section = .decks

    var body: some View {
        VStack(spacing: 0) {
            nav
            Divider().overlay(Theme.Palette.hairline)
            Group {
                switch selection {
                case .decks:  DecksView()
                case .create: GenerateView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.Palette.surface.ignoresSafeArea())
    }

    private var nav: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("recall")
                .font(Theme.Typo.title)
                .foregroundStyle(Theme.Palette.ink)
            Spacer()
            HStack(spacing: Theme.Spacing.md) {
                ForEach(Section.allCases, id: \.self) { section in
                    tab(section)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }

    private func tab(_ section: Section) -> some View {
        let active = selection == section
        return Button {
            Haptics.softTap()
            selection = section
        } label: {
            Text(section.rawValue)
                .font(Theme.Typo.buttonLabel)
                .foregroundStyle(active ? Theme.Palette.ink : Theme.Palette.inkSecondary)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(active ? Theme.Palette.hairlineStrong : .clear)
                        .frame(height: 2)
                        .offset(y: 6)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    RootView()
        .environment(AppContainer())
        .preferredColorScheme(.dark)
}
