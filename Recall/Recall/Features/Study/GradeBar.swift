import SwiftUI
import RecallKit

/// Four quiet grade buttons. No numbers shouting — just the four choices.
struct GradeBar: View {
    var onGrade: (ReviewGrade) -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(ReviewGrade.allCases, id: \.self) { grade in
                Button {
                    onGrade(grade)
                } label: {
                    Text(label(for: grade))
                        .font(Theme.Typo.body.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.md)
                        .foregroundStyle(Theme.Palette.ink)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                                .fill(Theme.Palette.surfaceRaised)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                                .strokeBorder(Theme.Palette.hairline, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(label(for: grade))
            }
        }
    }

    private func label(for grade: ReviewGrade) -> String {
        switch grade {
        case .again: "Again"
        case .hard: "Hard"
        case .good: "Good"
        case .easy: "Easy"
        }
    }
}

#Preview("GradeBar") {
    GradeBar(onGrade: { _ in })
        .padding()
        .background(Theme.Palette.surface)
}
