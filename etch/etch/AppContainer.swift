import SwiftUI
import etchKit

/// Composition root. Owns the singletons the feature layer depends on, expressed
/// only as protocols so views never see concretions.
@MainActor
@Observable
final class AppContainer {
    let repository: FlashcardRepository
    let generator: FlashcardGenerating

    init() {
        self.repository = CoreDataFlashcardRepository()
        self.generator = Self.makeGenerator()
    }

    private static func makeGenerator() -> FlashcardGenerating {
        // Deterministic generator for UI tests (the real model is non-deterministic).
        if ProcessInfo.processInfo.arguments.contains("-useMockGenerator") {
            return MockGenerator()
        }

        // Real on-device generator everywhere. On a simulator that lacks Apple
        // Intelligence we fall back to a scripted generator so the app stays
        // fully demoable; real devices always use the on-device model and show
        // the calm unavailable state when ineligible.
        let real = FlashcardGenerator()
        #if targetEnvironment(simulator)
        if case .unavailable = real.availability {
            return MockGenerator()
        }
        return real
        #else
        return real
        #endif
    }
}
