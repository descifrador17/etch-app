import Foundation

/// Per-card spaced-repetition state. Pure value type, safe to cross actor
/// boundaries. Persisted field-by-field on `CDCard`.
public struct ReviewState: Hashable, Sendable {
    public var easeFactor: Double
    public var intervalDays: Double
    public var repetitions: Int
    public var dueDate: Date
    public var lastReviewedAt: Date?

    public init(
        easeFactor: Double,
        intervalDays: Double,
        repetitions: Int,
        dueDate: Date,
        lastReviewedAt: Date?
    ) {
        self.easeFactor = easeFactor
        self.intervalDays = intervalDays
        self.repetitions = repetitions
        self.dueDate = dueDate
        self.lastReviewedAt = lastReviewedAt
    }

    /// A freshly generated card: due immediately, default ease.
    public static let new = ReviewState(
        easeFactor: 2.5,
        intervalDays: 0,
        repetitions: 0,
        dueDate: .now,
        lastReviewedAt: nil
    )
}

/// SM-2-derived scheduler with a four-grade UI. Pure, deterministic, no I/O —
/// `now` is injected so the math is trivially unit-testable.
public enum SpacedRepetitionScheduler {

    public static func next(
        _ s: ReviewState,
        grade: ReviewGrade,
        now: Date = .now
    ) -> ReviewState {
        var ease = s.easeFactor
        var reps = s.repetitions
        var interval = s.intervalDays

        switch grade {
        case .again:
            reps = 0
            interval = 0                        // resurface in the same session / very soon
            ease = max(1.3, ease - 0.20)
        case .hard:
            reps += 1
            interval = reps == 1 ? 1 : interval * 1.2
            ease = max(1.3, ease - 0.15)
        case .good:
            reps += 1
            interval = switch reps {
            case 1: 1
            case 2: 6
            default: interval * ease
            }
        case .easy:
            reps += 1
            let base: Double = switch reps {
            case 1: 2
            case 2: 6
            default: interval * ease
            }
            interval = base * 1.3
            ease = min(3.0, ease + 0.15)
        }

        let due: Date = grade == .again
            ? now.addingTimeInterval(60)        // ~1 min; effectively "again this session"
            : Calendar.current.date(byAdding: .day, value: Int(interval.rounded()), to: now) ?? now

        return ReviewState(
            easeFactor: ease,
            intervalDays: interval,
            repetitions: reps,
            dueDate: due,
            lastReviewedAt: now
        )
    }
}
