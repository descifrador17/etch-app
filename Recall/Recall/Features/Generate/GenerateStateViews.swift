import SwiftUI
import RecallKit

/// Terminal explanatory state when on-device generation isn't available (§11).
struct UnavailableStateView: View {
    let reason: GenerationError.UnavailableReason

    var body: some View {
        CalmMessage(glyph: glyph, title: title, message: message)
    }

    private var glyph: String {
        switch reason {
        case .modelNotReady: "[...]"
        default: "[x]"
        }
    }

    private var title: String {
        switch reason {
        case .modelNotReady: "Preparing the model"
        default: "Apple Intelligence needed"
        }
    }

    private var message: String {
        switch reason {
        case .deviceNotEligible:
            "On-device generation needs Apple Intelligence. This device isn't supported, but you can still browse and study your saved decks."
        case .appleIntelligenceNotEnabled:
            "On-device generation needs Apple Intelligence. Enable it in Settings to create new decks."
        case .modelNotReady:
            "The on-device model is getting ready. This happens once — it'll be here in a moment."
        case .unknown:
            "On-device generation isn't available right now. Your saved decks are still here to study."
        }
    }
}

/// Terminal failure state with a single retry affordance (§11).
struct FailedStateView: View {
    let error: GenerationError
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.section) {
            CalmMessage(glyph: "[x]", title: title, message: message)
            CalmButton("try again", action: onRetry)
                .frame(maxWidth: 320)
        }
    }

    private var title: String {
        switch error {
        case .noUsableCards: "No cards this time"
        default: "Couldn't create that deck"
        }
    }

    private var message: String {
        switch error {
        case .guardrailTriggered:
            "Couldn't create cards for that. Try rephrasing the topic."
        case .noUsableCards:
            "Hmm, no cards this time — try a more specific topic."
        case .contextWindowExceeded:
            "That topic was a little too much. Try something more focused."
        case .modelUnavailable:
            "On-device generation isn't available right now. Try again in a moment."
        default:
            "Something interrupted generation. Give it another try."
        }
    }
}

/// Shared terminal empty/error layout — a bracket glyph, a title, one mono line.
struct CalmMessage: View {
    let glyph: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text(glyph)
                .font(Theme.Typo.display)
                .foregroundStyle(Theme.Palette.inkSecondary)
            Text(title)
                .font(Theme.Typo.title)
                .foregroundStyle(Theme.Palette.ink)
            Text(message)
                .font(Theme.Typo.body)
                .foregroundStyle(Theme.Palette.inkSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .padding(Theme.Spacing.section)
    }
}

#Preview("Unavailable") {
    UnavailableStateView(reason: .appleIntelligenceNotEnabled)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Palette.surface)
        .preferredColorScheme(.dark)
}

#Preview("Failed") {
    FailedStateView(error: .noUsableCards, onRetry: {})
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Palette.surface)
        .preferredColorScheme(.dark)
}
