import SwiftUI

/// View-layer presentation for `Difficulty`: a lowercase label and a tint drawn
/// from the existing grade ramp (green → yellow → orange → red).
public extension Difficulty {
    var label: String {
        switch self {
        case .easy:   "easy"
        case .medium: "medium"
        case .hard:   "hard"
        case .ultra:  "ultra"
        }
    }

    var tint: Color {
        switch self {
        case .easy:   Theme.Palette.gradeEasy
        case .medium: Theme.Palette.gradeGood
        case .hard:   Theme.Palette.gradeHard
        case .ultra:  Theme.Palette.gradeAgain
        }
    }
}
