import Foundation

/// Domain error for the generation flow. Deliberately separate from Foundation
/// Models' own error type — the UI maps these to calm, human copy (see §11).
public enum GenerationError: Error, Equatable, Sendable {
    case modelUnavailable(UnavailableReason)
    case emptyTopic
    case guardrailTriggered          // input/output tripped safety
    case contextWindowExceeded       // topic + output too large
    case noUsableCards               // model returned 0 cards
    case cancelled
    case underlying(String)

    public enum UnavailableReason: Equatable, Sendable {
        case deviceNotEligible       // hardware can't run Apple Intelligence
        case appleIntelligenceNotEnabled
        case modelNotReady           // downloading / warming up
        case unknown
    }
}
