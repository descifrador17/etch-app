import Testing
import Foundation
@testable import RecallKit

@Suite("SpacedRepetitionScheduler")
struct SchedulerTests {

    /// A fixed reference date so due-date math is deterministic.
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func daysBetween(_ a: Date, _ b: Date) -> Int {
        Calendar.current.dateComponents([.day], from: a, to: b).day ?? -999
    }

    // MARK: - Again

    @Test("Again resets reps and resurfaces within ~1 minute")
    func againResurfacesSoon() {
        let state = ReviewState(easeFactor: 2.5, intervalDays: 10, repetitions: 4, dueDate: now, lastReviewedAt: nil)
        let next = SpacedRepetitionScheduler.next(state, grade: .again, now: now)

        #expect(next.repetitions == 0)
        #expect(next.intervalDays == 0)
        #expect(next.dueDate == now.addingTimeInterval(60))
        #expect(next.lastReviewedAt == now)
    }

    @Test("Again drops ease by 0.20 but never below 1.3")
    func againEaseFloor() {
        let high = SpacedRepetitionScheduler.next(.new, grade: .again, now: now)
        #expect(abs(high.easeFactor - 2.30) < 1e-9)

        let low = ReviewState(easeFactor: 1.35, intervalDays: 0, repetitions: 0, dueDate: now, lastReviewedAt: nil)
        let floored = SpacedRepetitionScheduler.next(low, grade: .again, now: now)
        #expect(floored.easeFactor == 1.3)
    }

    // MARK: - Good progression

    @Test("Good follows 1 → 6 → interval*ease day progression")
    func goodProgression() {
        var s = ReviewState.new

        s = SpacedRepetitionScheduler.next(s, grade: .good, now: now)   // rep 1 → 1 day
        #expect(s.repetitions == 1)
        #expect(s.intervalDays == 1)
        #expect(daysBetween(now, s.dueDate) == 1)

        s = SpacedRepetitionScheduler.next(s, grade: .good, now: now)   // rep 2 → 6 days
        #expect(s.repetitions == 2)
        #expect(s.intervalDays == 6)
        #expect(daysBetween(now, s.dueDate) == 6)

        let easeAtThree = s.easeFactor
        s = SpacedRepetitionScheduler.next(s, grade: .good, now: now)   // rep 3 → 6 * ease
        #expect(s.repetitions == 3)
        #expect(abs(s.intervalDays - 6 * easeAtThree) < 1e-9)
    }

    // MARK: - Hard

    @Test("Hard grows interval gently and lowers ease")
    func hardProgression() {
        let first = SpacedRepetitionScheduler.next(.new, grade: .hard, now: now)
        #expect(first.repetitions == 1)
        #expect(first.intervalDays == 1)                      // first hard pins to 1 day
        #expect(abs(first.easeFactor - 2.35) < 1e-9)

        let second = SpacedRepetitionScheduler.next(first, grade: .hard, now: now)
        #expect(second.repetitions == 2)
        #expect(abs(second.intervalDays - 1.2) < 1e-9)        // interval * 1.2
    }

    @Test("Hard ease never falls below 1.3")
    func hardEaseFloor() {
        let low = ReviewState(easeFactor: 1.4, intervalDays: 5, repetitions: 3, dueDate: now, lastReviewedAt: nil)
        let next = SpacedRepetitionScheduler.next(low, grade: .hard, now: now)
        #expect(next.easeFactor == 1.3)
    }

    // MARK: - Easy

    @Test("Easy applies the 1.3 bonus and raises ease, capped at 3.0")
    func easyProgression() {
        let first = SpacedRepetitionScheduler.next(.new, grade: .easy, now: now)
        #expect(first.repetitions == 1)
        #expect(abs(first.intervalDays - 2 * 1.3) < 1e-9)     // (rep 1 → 2) * 1.3
        #expect(abs(first.easeFactor - 2.65) < 1e-9)

        let capped = ReviewState(easeFactor: 2.95, intervalDays: 20, repetitions: 5, dueDate: now, lastReviewedAt: nil)
        let next = SpacedRepetitionScheduler.next(capped, grade: .easy, now: now)
        #expect(next.easeFactor == 3.0)                        // ceiling holds
    }

    // MARK: - Invariants

    @Test("Every non-again grade stamps lastReviewedAt and a future due date", arguments: [ReviewGrade.hard, .good, .easy])
    func futureDue(grade: ReviewGrade) {
        let next = SpacedRepetitionScheduler.next(.new, grade: grade, now: now)
        #expect(next.lastReviewedAt == now)
        #expect(next.dueDate > now)
    }
}
