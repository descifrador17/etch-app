# Recall — iOS Study App · Engineering Handoff

**Audience:** Claude Code (autonomous implementation) + reviewing iOS engineer
**Target:** iOS 26.0+ · Swift 6.1 · Xcode 26 · SwiftUI lifecycle
**Status:** Greenfield. Build in the phase order in §12.

---

## 1. Product in one paragraph

Recall is a single-purpose study app. The user types any topic ("Krebs cycle", "Swift actors", "French R-conjugation"), and an **on-device** AI model generates a deck of flashcards. Decks persist locally in **Core Data**. The user reviews cards with a physical flip interaction and studies them on a **spaced-repetition** schedule. No account, no network, no telemetry. Everything runs and stays on the device.

The entire product thesis is **calm**: nothing blocks, nothing nags, nothing spins harshly. Generation streams in card-by-card. Motion is soft and spring-driven. The palette is warm paper and muted ink. The app should feel closer to a paper notebook than a SaaS dashboard.

---

## 2. Non-negotiable constraints

| Constraint | Decision | Rationale |
|---|---|---|
| AI model | **Foundation Models framework** (`SystemLanguageModel.default`) | On-device, free, private, no API key, no network. Ships with the OS. |
| Structured output | **Guided generation** via `@Generable` / `@Guide` | Guarantees valid `{question, answer}` structs — no JSON parsing, no prompt-format babysitting. |
| Persistence | **Core Data** (`NSPersistentContainer`) | Per requirement. Repository layer hides it from the rest of the app. |
| Min deployment | **iOS 26.0** | Foundation Models requires it. Capability-gate, don't crash, on unsupported hardware. |
| Concurrency | **Swift 6 strict concurrency**, complete checking on | Production target. No `@unchecked Sendable` shortcuts. |
| Networking | **None** | App has no network entitlement. If a reviewer sees `URLSession`, it's a bug. |
| Architecture | MVVM + Repository, feature-foldered, with a local SPM core package | Scales, testable, keeps Core Data + FoundationModels out of the view layer. |

**Device reality check:** Foundation Models only runs on Apple-Intelligence-capable hardware (A17 Pro / M-series and later) with Apple Intelligence enabled. On anything else `availability` returns `.unavailable`. The app must degrade to a clear, calm empty-state — never a crash, never a dead button. See §8.4.

---

## 3. Architecture

```
┌──────────────────────────────────────────────────────────┐
│  App  (RecallApp)  — composition root, DI container       │
├──────────────────────────────────────────────────────────┤
│  Features (SwiftUI Views + @Observable ViewModels)        │
│    Generate · Decks · Review · Study                      │
├──────────────────────────────────────────────────────────┤
│  RecallKit  (local Swift Package)                         │
│   ├─ AI       FlashcardGenerator (FoundationModels)       │
│   ├─ Domain   Flashcard, Deck, ReviewGrade, Scheduler     │
│   ├─ Data     CoreDataStack, FlashcardRepository (proto)  │
│   └─ Design   Theme, Motion, Haptics, components          │
└──────────────────────────────────────────────────────────┘
```

**Layering rule (enforced in review):**

- Views depend on ViewModels. ViewModels depend on *protocols* (`FlashcardRepository`, `FlashcardGenerating`), never concretions.
- The AI layer emits **domain structs** (`Flashcard`), never Core Data objects.
- The data layer maps `NSManagedObject ⇄ Flashcard` and exposes only `Sendable` value types across actor boundaries. `NSManagedObject` never leaves the repository.
- `FoundationModels` types are imported **only** inside `RecallKit/AI`. `CoreData` is imported **only** inside `RecallKit/Data`. Grep for violations.

---

## 4. Project structure

Create exactly this tree. Paths are referenced elsewhere in the doc.

```
Recall/
├─ Recall.xcodeproj
├─ Recall/                          # app target
│  ├─ RecallApp.swift               # @main, DI container, root scene
│  ├─ AppContainer.swift            # dependency container
│  ├─ RootView.swift                # TabView / NavigationStack host
│  ├─ Features/
│  │  ├─ Generate/
│  │  │  ├─ GenerateView.swift
│  │  │  ├─ GenerateViewModel.swift
│  │  │  └─ TopicField.swift
│  │  ├─ Decks/
│  │  │  ├─ DecksView.swift
│  │  │  ├─ DecksViewModel.swift
│  │  │  └─ DeckRow.swift
│  │  ├─ Review/
│  │  │  ├─ DeckDetailView.swift
│  │  │  ├─ FlashcardView.swift     # the flip card
│  │  │  └─ DeckDetailViewModel.swift
│  │  └─ Study/
│  │     ├─ StudyView.swift
│  │     ├─ StudyViewModel.swift
│  │     └─ GradeBar.swift
│  ├─ Resources/
│  │  ├─ Assets.xcassets            # color sets (see §6)
│  │  └─ Recall.xcdatamodeld        # Core Data model
│  └─ Recall.entitlements
├─ RecallKit/                       # local SPM package
│  ├─ Package.swift
│  └─ Sources/RecallKit/
│     ├─ AI/
│     │  ├─ FlashcardGenerating.swift
│     │  ├─ FlashcardGenerator.swift
│     │  ├─ GeneratedSchema.swift   # @Generable DTOs
│     │  └─ GenerationError.swift
│     ├─ Domain/
│     │  ├─ Flashcard.swift
│     │  ├─ Deck.swift
│     │  ├─ ReviewGrade.swift
│     │  └─ SpacedRepetitionScheduler.swift
│     ├─ Data/
│     │  ├─ CoreDataStack.swift
│     │  ├─ FlashcardRepository.swift      # protocol
│     │  ├─ CoreDataFlashcardRepository.swift
│     │  └─ Mapping.swift
│     └─ Design/
│        ├─ Theme.swift
│        ├─ Motion.swift
│        ├─ Haptics.swift
│        └─ Components/
│           ├─ CalmButton.swift
│           ├─ CardSurface.swift
│           └─ ShimmerPlaceholder.swift
└─ RecallTests/
   ├─ SchedulerTests.swift
   ├─ RepositoryTests.swift
   └─ GenerationMappingTests.swift
```

---

## 5. Data model (Core Data)

`Recall.xcdatamodeld` — two entities, one-to-many, **lightweight migration enabled** (`shouldMigrateStoreAutomatically = true`, `shouldInferMappingModelAutomatically = true`).

### Entity: `CDDeck`
| Attribute | Type | Notes |
|---|---|---|
| `id` | UUID | indexed, non-optional |
| `topic` | String | the user's input |
| `title` | String | model-generated display title |
| `createdAt` | Date | |
| `cards` | To-many → `CDCard` | cascade delete, inverse `deck` |

### Entity: `CDCard`
| Attribute | Type | Notes |
|---|---|---|
| `id` | UUID | indexed, non-optional |
| `question` | String | |
| `answer` | String | |
| `orderIndex` | Integer 32 | preserves generated order |
| `createdAt` | Date | |
| **SR fields** | | spaced repetition state |
| `easeFactor` | Double | default `2.5` |
| `intervalDays` | Double | default `0` |
| `repetitions` | Integer 32 | default `0` |
| `dueDate` | Date | default = now (due immediately) |
| `lastReviewedAt` | Date | optional |
| `deck` | To-one → `CDDeck` | inverse `cards` |

> Set **codegen to "Manual/None"** for both entities and write the `NSManagedObject` subclasses by hand inside `RecallKit/Data`, OR keep "Class Definition" and never reference the classes outside the package. Manual is cleaner for Swift 6 because you control `Sendable` annotations and avoid the generated files leaking. Recommended: **Manual/None**, subclasses live next to the stack.

---

## 6. Design system — "calm"

This section is the soul of the app. Treat it as spec, not suggestion.

### 6.1 Color (Asset Catalog color sets, light + dark)

Define these as **named color sets** in `Assets.xcassets` so dark mode is automatic. Values are starting points; keep contrast ≥ 4.5:1 for text.

| Token | Light | Dark | Use |
|---|---|---|---|
| `surface` | `#FAF8F3` (warm paper) | `#16140F` (near-black, warm) | screen background |
| `surfaceRaised` | `#FFFFFF` | `#1F1C16` | cards, sheets |
| `ink` | `#2B2722` | `#EDE8DF` | primary text |
| `inkSecondary` | `#6F685E` | `#A29A8C` | secondary text |
| `accent` | `#5B7A6E` (muted sage) | `#7FA395` | single accent — buttons, due-badge |
| `hairline` | `#ECE6DB` | `#2B2720` | dividers, card borders |

**Rules:** exactly one accent. No gradients on content surfaces (a single near-invisible vertical gradient on the root background is allowed). No pure black, no pure white in dark mode. Shadows are large, soft, low-opacity (`radius: 24, y: 8, opacity: 0.06`) — never hard.

### 6.2 Typography

`Theme.swift` exposes a font ramp built on **`.rounded`** design for warmth:

```swift
enum Typo {
    static let display = Font.system(.largeTitle, design: .rounded, weight: .semibold)
    static let title   = Font.system(.title2,     design: .rounded, weight: .semibold)
    static let cardFace = Font.system(.title,      design: .rounded, weight: .medium)
    static let body    = Font.system(.body,        design: .rounded)
    static let caption = Font.system(.footnote,    design: .rounded, weight: .medium)
}
```

Always use Dynamic Type text styles (above), never fixed point sizes. The flip card uses `.minimumScaleFactor(0.6)` and `.lineLimit(6)` so long answers stay readable without clipping.

### 6.3 Spacing & shape

8-pt grid, but lean generous: section padding `24`, card inner padding `28`, inter-card spacing `16`. Corner radius: cards `28`, buttons `16`, sheets `system`. Use `.continuous` rounded rectangles everywhere.

### 6.4 Motion (`Motion.swift`)

```swift
enum Motion {
    static let gentle  = Animation.spring(response: 0.5,  dampingFraction: 0.85)
    static let flip    = Animation.spring(response: 0.55, dampingFraction: 0.78)
    static let settle  = Animation.spring(response: 0.4,  dampingFraction: 0.9)
}
```

- Card reveal during streaming: each new card fades + rises 12pt with `Motion.gentle`, staggered ~60ms.
- Flip: 3D `rotation3DEffect` around Y, 0→180°, content swapped at 90°. Honor **Reduce Motion** → crossfade instead of rotation (check `@Environment(\.accessibilityReduceMotion)`).
- No spinners. Loading = `ShimmerPlaceholder` skeleton cards (see §6.6) breathing at ~1.4s period.

### 6.5 Haptics (`Haptics.swift`)

Wrap `UIImpactFeedbackGenerator` / `UINotificationFeedbackGenerator`. Use **sparingly**:
- `.soft` light tap on card flip.
- `.success` notification when a deck finishes generating.
- One subtle `.soft` on each grade tap in study.
- Nothing else. Calm means restraint.

### 6.6 Components

- `CardSurface` — rounded `surfaceRaised` container with the soft shadow + hairline border. Every card/sheet uses it.
- `CalmButton` — full-width, `accent` fill, rounded 16, springs to 0.97 scale on press, soft haptic. A `.quiet` variant = `inkSecondary` text, no fill.
- `ShimmerPlaceholder` — skeleton block with a slow masked gradient sweep; used for in-flight cards.

---

## 7. AI layer — Foundation Models

All code in this section lives in `RecallKit/Sources/RecallKit/AI`. This is the only place `import FoundationModels` appears.

### 7.1 Generation schema (`GeneratedSchema.swift`)

Guided generation gives us typed, valid output with zero parsing. Keep these DTOs separate from the domain `Flashcard` so the AI schema can evolve independently.

```swift
import FoundationModels

@Generable
struct GeneratedDeck {
    @Guide(description: "A short, human-friendly title for this study deck, 2 to 5 words.")
    let title: String

    @Guide(description: "Between 8 and 12 flashcards covering the most important, distinct ideas of the topic.")
    let cards: [GeneratedCard]
}

@Generable
struct GeneratedCard {
    @Guide(description: "A focused question testing ONE concept. No 'and'. Under 140 characters.")
    let question: String

    @Guide(description: "A correct, self-contained answer in 1–3 sentences. No preamble like 'The answer is'.")
    let answer: String
}
```

> `@Guide` constraints are enforced by the framework's constrained decoding. You can also use count constraints on arrays where supported by the SDK (e.g. `@Guide(.count(10))`); verify against the installed SDK and prefer descriptive guidance if a constraint API is unavailable. Do **not** rely on the model to "remember" to produce valid shapes — the macro guarantees the shape.

### 7.2 Errors (`GenerationError.swift`)

```swift
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
```

### 7.3 Protocol (`FlashcardGenerating.swift`)

```swift
import Foundation

public protocol FlashcardGenerating: Sendable {
    /// Synchronous capability check for gating UI.
    var availability: GeneratorAvailability { get }

    /// Warm the model so first token latency is low. Best-effort, non-throwing.
    func prewarm()

    /// Streams partial decks as they generate. Each yielded value is a more
    /// complete snapshot. The final value is the complete deck.
    func streamDeck(topic: String) -> AsyncThrowingStream<DeckSnapshot, Error>
}

public enum GeneratorAvailability: Equatable, Sendable {
    case available
    case unavailable(GenerationError.UnavailableReason)
}

/// A progressively-filled view of the deck for streaming UI.
public struct DeckSnapshot: Sendable, Equatable {
    public var title: String?
    public var cards: [Flashcard]   // grows as generation proceeds
    public var isComplete: Bool
}
```

### 7.4 Implementation (`FlashcardGenerator.swift`)

Key behaviors: availability mapping, prewarm, **streaming** so the UI fills in card-by-card, mapping partial → domain, and exhaustive error mapping. Make it a `@MainActor` final class — `LanguageModelSession` drives UI-facing streaming and isn't `Sendable`; keeping it main-actor-isolated is the supported, race-free choice. The framework runs inference off the main thread internally, so this does not block the UI.

```swift
import FoundationModels
import Foundation

@MainActor
public final class FlashcardGenerator: FlashcardGenerating {

    private let model = SystemLanguageModel.default

    public init() {}

    public nonisolated var availability: GeneratorAvailability {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:          return .unavailable(.deviceNotEligible)
            case .appleIntelligenceNotEnabled: return .unavailable(.appleIntelligenceNotEnabled)
            case .modelNotReady:              return .unavailable(.modelNotReady)
            @unknown default:                 return .unavailable(.unknown)
            }
        }
    }

    public func prewarm() {
        guard case .available = availability else { return }
        // A fresh session warmed once; first real request reuses warmth.
        let session = LanguageModelSession(instructions: Self.instructions)
        session.prewarm()
    }

    public func streamDeck(topic: String) -> AsyncThrowingStream<DeckSnapshot, Error> {
        AsyncThrowingStream { continuation in
            let trimmed = topic.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                continuation.finish(throwing: GenerationError.emptyTopic); return
            }
            guard case .available = availability else {
                let reason: GenerationError.UnavailableReason =
                    if case .unavailable(let r) = availability { r } else { .unknown }
                continuation.finish(throwing: GenerationError.modelUnavailable(reason)); return
            }

            let task = Task { @MainActor in
                do {
                    let session = LanguageModelSession(instructions: Self.instructions)
                    let prompt = Self.prompt(for: trimmed)
                    let options = GenerationOptions(temperature: 0.6)

                    let stream = session.streamResponse(
                        to: prompt,
                        generating: GeneratedDeck.self,
                        options: options
                    )

                    for try await partial in stream {
                        try Task.checkCancellation()
                        continuation.yield(Self.snapshot(from: partial, complete: false))
                    }

                    // Re-collect final value for the completed snapshot.
                    // (The last partial already carries full content; mark complete.)
                    continuation.yield(DeckSnapshot(title: nil, cards: [], isComplete: true)
                                        .merging(lastFrom: stream))
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: GenerationError.cancelled)
                } catch let error {
                    continuation.finish(throwing: Self.map(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Prompt

    private static let instructions = """
    You generate concise study flashcards. Each card tests exactly one idea. \
    Questions are specific and unambiguous. Answers are correct and self-contained, \
    1 to 3 sentences, with no filler. Cover the most important, distinct sub-topics. \
    Avoid duplicate cards. Use clear, plain language.
    """

    private static func prompt(for topic: String) -> String {
        "Create a study flashcard deck for the topic: \"\(topic)\"."
    }

    // MARK: - Mapping

    private static func snapshot(
        from partial: GeneratedDeck.PartiallyGenerated,
        complete: Bool
    ) -> DeckSnapshot {
        let cards: [Flashcard] = (partial.cards ?? []).enumerated().compactMap { idx, c in
            guard let q = c.question, let a = c.answer,
                  !q.isEmpty, !a.isEmpty else { return nil }
            return Flashcard(question: q, answer: a, orderIndex: idx)
        }
        return DeckSnapshot(title: partial.title, cards: cards, isComplete: complete)
    }

    private static func map(_ error: Error) -> GenerationError {
        // Map known Foundation Models error cases. Names per installed SDK —
        // adjust the case labels to match. The intent is exhaustive coverage.
        let text = String(describing: error).lowercased()
        if text.contains("guardrail") || text.contains("safety") { return .guardrailTriggered }
        if text.contains("context")  || text.contains("window")  { return .contextWindowExceeded }
        return .underlying(String(describing: error))
    }
}
```

> **Implementation note for Claude Code:** the exact spelling of `SystemLanguageModel.availability`'s reasons, the `streamResponse(...)` signature, `PartiallyGenerated`, and the concrete error enum (`LanguageModelSession.GenerationError` / `.exceededContextWindowSize` / `.guardrailViolation`) must be confirmed against the **Foundation Models SDK in the installed Xcode 26**. Use Xcode Quick Help / module interface to pin the real symbols, then replace the string-matching in `map(_:)` with proper `catch let error as <ConcreteError>` pattern matches. The architecture above is correct; only the leaf symbol names may need tightening. The `.merging(lastFrom:)` helper is pseudocode — implement final-snapshot capture by retaining the last successfully yielded snapshot and flipping `isComplete = true`. Don't ship the placeholder.

### 7.5 Generation tuning

- `temperature: 0.6` — varied but grounded. Expose nothing to the user; calm = no knobs.
- Topic length guard: clamp UI input to ~80 chars; refuse empty/whitespace before hitting the model.
- One in-flight generation at a time. New request cancels the previous `Task`.

---

## 8. Feature behavior

### 8.1 Generate (`Features/Generate`)

- A single centered `TopicField` over a calm background. Placeholder rotates gentle examples ("photosynthesis", "Combine operators", "WWII treaties").
- `CalmButton` "Create deck" — disabled (quiet) until non-empty.
- On submit: VM calls `streamDeck`. UI immediately shows **8 shimmer skeleton cards**. As real cards stream in, each skeleton is replaced by a real card with the staggered rise animation. The deck title fades in at the top when it arrives.
- On completion: success haptic, brief settle, auto-navigate (or offer a calm "Review now" button) into `DeckDetailView`, and the deck is already persisted (persist as the final snapshot lands; see §9).
- Cancel: a quiet "Stop" appears during generation; tapping cancels cleanly and discards the partial.

**`GenerateViewModel` skeleton:**

```swift
@MainActor
@Observable
final class GenerateViewModel {
    enum Phase: Equatable { case idle, generating, done(Deck), failed(GenerationError) }

    private(set) var phase: Phase = .idle
    private(set) var streamingCards: [Flashcard] = []
    private(set) var streamingTitle: String?

    private let generator: FlashcardGenerating
    private let repository: FlashcardRepository
    private var task: Task<Void, Never>?

    init(generator: FlashcardGenerating, repository: FlashcardRepository) {
        self.generator = generator
        self.repository = repository
    }

    func onAppear() { generator.prewarm() }

    func generate(topic: String) {
        task?.cancel()
        streamingCards = []; streamingTitle = nil; phase = .generating
        task = Task {
            do {
                var last = DeckSnapshot(title: nil, cards: [], isComplete: false)
                for try await snap in generator.streamDeck(topic: topic) {
                    streamingTitle = snap.title ?? streamingTitle
                    streamingCards = snap.cards
                    last = snap
                }
                guard !last.cards.isEmpty else { phase = .failed(.noUsableCards); return }
                let deck = try await repository.createDeck(
                    topic: topic,
                    title: last.title ?? topic,
                    cards: last.cards
                )
                Haptics.success()
                phase = .done(deck)
            } catch let e as GenerationError {
                phase = .failed(e)
            } catch {
                phase = .failed(.underlying(String(describing: error)))
            }
        }
    }

    func cancel() { task?.cancel(); phase = .idle; streamingCards = [] }
}
```

### 8.2 Decks (`Features/Decks`)

- The home tab. List of saved decks via `@FetchRequest` (or an `@Observable` VM backed by `NSFetchedResultsController` — prefer the VM for testability and to keep the view Core-Data-free).
- Each `DeckRow` (in a `CardSurface`): title, topic, card count, a small **due badge** (count of cards with `dueDate <= now`) in `accent`.
- Swipe to delete with a soft confirmation. Empty state: a calm illustration + one line "Create your first deck."
- Tap → `DeckDetailView`.

### 8.3 Review & Study (`Features/Review`, `Features/Study`)

**DeckDetailView** — browse all cards, each a `FlashcardView` you can tap to flip. A prominent quiet **"Study"** entry when cards are due.

**FlashcardView (the flip):**

```swift
struct FlashcardView: View {
    let card: Flashcard
    @State private var flipped = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            face(text: card.question, showing: !flipped)
            face(text: card.answer,   showing: flipped)
                .rotation3DEffect(.degrees(180), axis: (0,1,0))
        }
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (0,1,0))
        .animation(reduceMotion ? .none : Motion.flip, value: flipped)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.softTap()
            if reduceMotion { withAnimation(.easeInOut) { flipped.toggle() } }
            else { flipped.toggle() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(flipped ? "Answer. \(card.answer)" : "Question. \(card.question)")
        .accessibilityHint("Double tap to flip")
    }

    private func face(text: String, showing: Bool) -> some View {
        CardSurface {
            Text(text)
                .font(Typo.cardFace)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .lineLimit(6)
                .padding(28)
        }
        .opacity(showing ? 1 : 0)   // hide the mirror-image back-face
    }
}
```

> For Reduce Motion, swap the 3D rotation for an opacity crossfade (the `.easeInOut` branch above) and skip `rotation3DEffect`'s motion. Keep the same flip semantics.

**StudyView + spaced repetition:**

- Presents only **due** cards (`dueDate <= now`), one at a time, front first.
- Tap reveals the answer. Then a `GradeBar` shows four quiet buttons: **Again · Hard · Good · Easy**.
- Grading updates the card's SR state via `SpacedRepetitionScheduler` (§10), persists it, and advances. Progress is shown as a thin, calm bar — no numbers shouting.
- Session end: a soft "Done for now" with the next due time ("Next review in 2 days"). Success haptic once.

---

## 9. Data flow & persistence

**Generation → persistence:** persist **once**, when the final snapshot arrives (not per-streamed-card — avoids churn and partial decks on cancel). `repository.createDeck(topic:title:cards:)` writes on a **background context** and returns a `Sendable` `Deck` domain struct (mapped from the saved objects' IDs/values).

**Reads:** repository exposes async methods returning domain structs and an `AsyncStream`/`NSFetchedResultsController`-backed observation for the decks list. Views never see `NSManagedObject`.

**Writes (grading):** `repository.updateReviewState(cardID:state:)` performs on the background context, saves, and the decks/detail observation reflects the change.

**Concurrency contract:** all Core Data mutation goes through `perform`/`performAndWait` on the appropriate context. `NSManagedObjectID` is the only Core Data type allowed to cross a `Task` boundary, and even then it stays inside the repository. Cross-actor surface is 100% value types.

---

## 10. Spaced repetition (`SpacedRepetitionScheduler.swift`)

Pure, deterministic, **no I/O** — trivially unit-testable. SM-2-derived with a 4-grade UI.

```swift
public enum ReviewGrade: Int, Sendable, CaseIterable {
    case again = 0, hard = 1, good = 2, easy = 3
}

public struct ReviewState: Equatable, Sendable {
    public var easeFactor: Double
    public var intervalDays: Double
    public var repetitions: Int
    public var dueDate: Date
    public var lastReviewedAt: Date?

    public static let new = ReviewState(
        easeFactor: 2.5, intervalDays: 0, repetitions: 0,
        dueDate: .now, lastReviewedAt: nil
    )
}

public enum SpacedRepetitionScheduler {
    /// Returns the next review state. `now` is injected for testability.
    public static func next(_ s: ReviewState, grade: ReviewGrade, now: Date = .now) -> ReviewState {
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
            interval = (switch reps { case 1: 2; case 2: 6; default: interval * ease }) * 1.3
            ease = min(3.0, ease + 0.15)
        }

        let due = grade == .again
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
```

---

## 11. Error handling & edge cases — required behaviors

| Case | Behavior |
|---|---|
| Device not eligible / AI off | Generate screen shows a calm explanatory state: "On-device generation needs Apple Intelligence. Enable it in Settings, or use a supported device." Button is disabled, not dead. **No crash.** |
| Model not ready (downloading) | Show "Preparing the on-device model…" with a breathing shimmer; retry affordance. Re-check `availability` on foreground. |
| Empty / whitespace topic | Button stays quiet/disabled; no request fired. |
| Guardrail triggered | Soft message: "Couldn't create cards for that. Try rephrasing the topic." Never expose raw error. |
| Context window exceeded | Same calm retry copy; internally we already keep prompts tiny so this is rare. |
| Model returns 0 usable cards | "Hmm, no cards this time — try a more specific topic." Offer retry. |
| User cancels mid-stream | Discard partial, return to idle instantly, no persisted deck. |
| Long answer text | `minimumScaleFactor` + line limit; never clip mid-word. |
| Reduce Motion ON | Crossfades instead of 3D flips and staggered rises. |
| VoiceOver | Flip card is one element reading "Question/Answer …" with a flip hint; grade buttons are clearly labeled. |
| Dynamic Type XXL | Layouts use scroll + flexible frames; cards grow, never truncate the question. |
| Backgrounding during generation | Task continues if possible; on cancel/expiry, fail gracefully to idle. |

---

## 12. Implementation plan (build in this order)

Each phase is independently buildable and reviewable. Don't start a phase before the previous compiles and its tests pass.

- [ ] **Phase 0 — Scaffold.** Create Xcode project (iOS 26 target, Swift 6 strict concurrency), the `RecallKit` local package, the folder tree from §4, and wire the package into the app. App launches to an empty `RootView`. Add the (empty-network) entitlements file.
- [ ] **Phase 1 — Design system.** `Theme`, `Motion`, `Haptics`, color sets in the asset catalog (light+dark), and the three components (`CardSurface`, `CalmButton`, `ShimmerPlaceholder`). Build a `#Preview` gallery screen to eyeball calm. Verify dark mode + Dynamic Type + Reduce Motion in previews.
- [ ] **Phase 2 — Domain + Scheduler.** `Flashcard`, `Deck`, `ReviewGrade`, `ReviewState`, `SpacedRepetitionScheduler`. **Write `SchedulerTests` first** and make them pass. Pure code, no UI.
- [ ] **Phase 3 — Core Data.** `Recall.xcdatamodeld` (§5), `NSManagedObject` subclasses (Manual/None codegen), `CoreDataStack` (with in-memory variant for tests), `FlashcardRepository` protocol, `CoreDataFlashcardRepository`, `Mapping`. `RepositoryTests` against an in-memory store: create deck, fetch, update review state, delete (cascade). Background-context writes verified.
- [ ] **Phase 4 — AI layer.** `GeneratedSchema` (`@Generable`), `GenerationError`, `FlashcardGenerating`, `FlashcardGenerator`. **Confirm every Foundation Models symbol against the installed SDK** (see §7.4 note) and replace placeholder error-mapping/final-snapshot code with real implementations. Add a `MockGenerator` (scripted `AsyncThrowingStream`) for previews/tests so the rest of the app builds without a capable device. `GenerationMappingTests` verify partial→domain mapping with the mock.
- [ ] **Phase 5 — Generate feature.** `GenerateViewModel` (inject `MockGenerator` in previews, real one in app), `GenerateView`, `TopicField`. Streaming UI with skeletons → staggered real cards → persist on completion. Handle all §11 states. Verify on a real Apple-Intelligence device.
- [ ] **Phase 6 — Decks feature.** `DecksViewModel`, `DecksView`, `DeckRow`, due badges, swipe-delete, empty state. Backed by repository observation.
- [ ] **Phase 7 — Review.** `DeckDetailView`, `FlashcardView` flip (with Reduce Motion + VoiceOver), `DeckDetailViewModel`.
- [ ] **Phase 8 — Study.** `StudyViewModel` (due-card queue), `StudyView`, `GradeBar`. Grading persists SR state and advances; session-end summary with next-due time.
- [ ] **Phase 9 — Polish pass.** Haptics audit (restraint!), motion timing, dark mode, Dynamic Type XXL, Reduce Motion, VoiceOver sweep. Run on device; confirm first-token latency is acceptable with prewarm.

---

## 13. Testing strategy

- **Unit (must pass in CI):** `SchedulerTests` (every grade path, ease floors/ceilings, interval growth, due-date math with injected `now`), `RepositoryTests` (in-memory store: CRUD, cascade delete, review-state update, ordering by `orderIndex`), `GenerationMappingTests` (partial snapshots → domain cards, drops incomplete cards, marks completion).
- **Generator:** test against `MockGenerator` only (the real on-device model is non-deterministic and device-gated — never assert on its content). Assert streaming order, cancellation, and error propagation.
- **Previews as a test surface:** every view has previews for light/dark, Dynamic Type XL, Reduce Motion, and (where relevant) the unavailable-model state, all driven by `MockGenerator` + in-memory Core Data.
- **Manual device pass:** required on a real A17 Pro/M-series device for the actual model — latency, guardrail behavior, real card quality.

---

## 14. Definition of done

- App builds clean under **Swift 6 strict concurrency** with zero warnings; no `@unchecked Sendable`.
- On a capable device: typing a topic streams a deck card-by-card, persists it, and it survives relaunch.
- On a non-capable device/simulator: calm unavailable state, **no crash**, rest of the app (browsing existing decks) works.
- Spaced repetition advances correctly; due badges and "next review" times are accurate.
- Reduce Motion, Dynamic Type (to XXL), dark mode, and VoiceOver all pass the sweep in §12 Phase 9.
- No network code anywhere. No `print`-style telemetry. `CoreData` imported only in `Data/`, `FoundationModels` only in `AI/`.
- All unit tests green.

---

## 15. Explicitly out of scope (v1)

iCloud/CloudKit sync · sharing/export · images or audio on cards · multiple-choice or cloze types · editing generated cards · widgets · cross-device handoff · any analytics. Keep the surface small and the app calm. Revisit after v1 ships.

---

## Appendix A — Domain types (`Domain/`)

```swift
public struct Flashcard: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var question: String
    public var answer: String
    public var orderIndex: Int
    public var review: ReviewState

    public init(id: UUID = UUID(), question: String, answer: String,
                orderIndex: Int, review: ReviewState = .new) {
        self.id = id; self.question = question; self.answer = answer
        self.orderIndex = orderIndex; self.review = review
    }
}

public struct Deck: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var topic: String
    public var title: String
    public var createdAt: Date
    public var cards: [Flashcard]

    public var dueCount: Int { cards.filter { $0.review.dueDate <= .now }.count }
}
```

## Appendix B — Repository protocol (`Data/FlashcardRepository.swift`)

```swift
public protocol FlashcardRepository: Sendable {
    func createDeck(topic: String, title: String, cards: [Flashcard]) async throws -> Deck
    func allDecks() async throws -> [Deck]
    func deck(id: UUID) async throws -> Deck?
    func deleteDeck(id: UUID) async throws
    func updateReviewState(cardID: UUID, state: ReviewState) async throws
    /// Observation for the decks list (wrap NSFetchedResultsController).
    func decksStream() -> AsyncStream<[Deck]>
}
```

> `createDeck` maps the incoming `[Flashcard]` to `CDCard` rows on a background context, sets `orderIndex`, saves, and returns the persisted `Deck`. All Core Data work stays behind this protocol.

---

**End of handoff.** Build phase-by-phase (§12); the one place to slow down and verify real SDK symbols is the Foundation Models layer (§7.4).
