import SwiftUI
import RecallKit

/// Four bracketed grade buttons, each in its semantic color:
/// again=red, hard=orange, good=yellow, easy=green.
struct GradeBar: View {
    var onGrade: (ReviewGrade) -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(ReviewGrade.allCases, id: \.self) { grade in
                Button {
                    onGrade(grade)
                } label: {
                    Text("[ \(label(for: grade)) ]")
                        .font(Theme.Typo.buttonLabel)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.md)
                        .foregroundStyle(color(for: grade))
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                                .fill(Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                                .strokeBorder(color(for: grade).opacity(0.6), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(label(for: grade))
            }
        }
    }

    private func label(for grade: ReviewGrade) -> String {
        switch grade {
        case .again: "again"
        case .hard:  "hard"
        case .good:  "good"
        case .easy:  "easy"
        }
    }

    private func color(for grade: ReviewGrade) -> Color {
        switch grade {
        case .again: Theme.Palette.gradeAgain
        case .hard:  Theme.Palette.gradeHard
        case .good:  Theme.Palette.gradeGood
        case .easy:  Theme.Palette.gradeEasy
        }
    }
}

#Preview("GradeBar") {
    GradeBar(onGrade: { _ in })
        .padding()
        .background(Theme.Palette.surface)
}
