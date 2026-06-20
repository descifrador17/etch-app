import Foundation

/// The four-grade review outcome surfaced in the Study UI.
/// Backed by `Int` so it maps cleanly to/from Core Data without extra glue.
public enum ReviewGrade: Int, Sendable, CaseIterable {
    case again = 0
    case hard = 1
    case good = 2
    case easy = 3
}
