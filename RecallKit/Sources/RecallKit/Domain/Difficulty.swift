import Foundation

/// How challenging a generated deck should be. The raw `String` is the
/// persistence form; read it back with `Difficulty(rawValue:)` and fall back to
/// `.medium` for anything unknown (e.g. legacy decks).
public enum Difficulty: String, CaseIterable, Sendable {
    case easy
    case medium
    case hard
    case ultra
}
