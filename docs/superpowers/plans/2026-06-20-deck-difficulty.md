# Deck Difficulty Selection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user pick a difficulty (easy/medium/hard/ultra) when creating a deck; the level shapes the generation prompt and is persisted and shown as a colored tag.

**Architecture:** Add a `Difficulty` domain enum + a `Deck.difficulty` field, thread it through generation (`streamDeck`) and persistence (`createDeck`, a new additive Core Data attribute), surface a bracketed selector on the Create screen, and display a colored tag on the deck row and detail. Generation difference is prompt-only (card count unchanged).

**Tech Stack:** SwiftUI (iOS 26), Swift 6 strict concurrency, etchKit SPM package, FoundationModels, Core Data (programmatic model, lightweight migration), Swift Testing.

## Global Constraints

- Difficulty is a **depth/style** lever only — card count stays ~8–12 (the `GeneratedDeck` `@Generable` schema is unchanged).
- Difficulty is **persisted and displayed**; default is **`medium`**.
- Levels: `easy`, `medium`, `hard`, `ultra` (a `String`-raw enum; raw value is the persistence form).
- Existing decks with no stored difficulty must load as `medium` (no crash, no manual migration model).
- Concrete `createDeck` / `streamDeck` get a `difficulty: Difficulty = .medium` default so existing call sites/tests compile unchanged; ViewModels call through the protocol existential and pass difficulty explicitly.
- New files are etchKit sources/tests (SPM auto-included) or private views inside existing app files — **no `ruby scripts/generate_project.rb` needed**.
- Swift 6 strict concurrency; `@MainActor` protocols unchanged. No networking.
- Color mapping reuses existing `Theme.Palette.grade*` tokens: easy→`gradeEasy` (green), medium→`gradeGood` (yellow), hard→`gradeHard` (orange), ultra→`gradeAgain` (red).
- Build gate (repo root):
  `xcodebuild -project etch/etch.xcodeproj -scheme etch -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
- Unit tests (from `etchKit/`):
  `xcodebuild test -scheme etchKit -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`

---

### Task 1: `Difficulty` domain type, `Deck` field, and style mapping

**Files:**
- Create: `etchKit/Sources/etchKit/Domain/Difficulty.swift`
- Create: `etchKit/Sources/etchKit/Design/DifficultyStyle.swift`
- Modify: `etchKit/Sources/etchKit/Domain/Deck.swift`
- Test: `etchKit/Tests/etchKitTests/DifficultyTests.swift`

**Interfaces:**
- Produces:
  - `enum Difficulty: String, CaseIterable, Sendable { case easy, medium, hard, ultra }`
  - `Deck.difficulty: Difficulty` (initializer param `difficulty: Difficulty = .medium`, inserted before `cards`).
  - `extension Difficulty { var label: String; var tint: Color }` (Design layer).

- [ ] **Step 1: Write the failing test**

Create `etchKit/Tests/etchKitTests/DifficultyTests.swift`:

```swift
import Testing
@testable import etchKit

@Suite("Difficulty")
struct DifficultyTests {
    @Test("Cases and raw values are stable")
    func rawValues() {
        #expect(Difficulty.allCases == [.easy, .medium, .hard, .ultra])
        #expect(Difficulty(rawValue: "ultra") == .ultra)
        #expect(Difficulty(rawValue: "nope") == nil)
    }

    @Test("Deck defaults to medium difficulty")
    func deckDefault() {
        let deck = Deck(topic: "t", title: "t", cards: [])
        #expect(deck.difficulty == .medium)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd etchKit && xcodebuild test -scheme etchKit -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:etchKitTests/DifficultyTests`
Expected: FAIL to compile — `Difficulty` not found / `Deck` has no `difficulty`.

- [ ] **Step 3: Create the `Difficulty` enum**

Create `etchKit/Sources/etchKit/Domain/Difficulty.swift`:

```swift
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
```

- [ ] **Step 4: Add the `difficulty` field to `Deck`**

In `etchKit/Sources/etchKit/Domain/Deck.swift`, add the stored property and initializer parameter (default `.medium`, placed before `cards`):

```swift
public struct Deck: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var topic: String
    public var title: String
    public var createdAt: Date
    public var difficulty: Difficulty
    public var cards: [Flashcard]

    public init(
        id: UUID = UUID(),
        topic: String,
        title: String,
        createdAt: Date = .now,
        difficulty: Difficulty = .medium,
        cards: [Flashcard]
    ) {
        self.id = id
        self.topic = topic
        self.title = title
        self.createdAt = createdAt
        self.difficulty = difficulty
        self.cards = cards
    }

    /// Count of cards due for review as of `now`. Drives the due badge.
    public func dueCount(asOf now: Date = .now) -> Int {
        cards.filter { $0.review.dueDate <= now }.count
    }
}
```

- [ ] **Step 5: Create the style mapping**

Create `etchKit/Sources/etchKit/Design/DifficultyStyle.swift`:

```swift
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
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `cd etchKit && xcodebuild test -scheme etchKit -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:etchKitTests/DifficultyTests`
Expected: PASS (2 tests).

- [ ] **Step 7: Commit**

```bash
git add etchKit/Sources/etchKit/Domain/Difficulty.swift etchKit/Sources/etchKit/Design/DifficultyStyle.swift etchKit/Sources/etchKit/Domain/Deck.swift etchKit/Tests/etchKitTests/DifficultyTests.swift
git commit -m "feat: Difficulty domain type, Deck field, and style mapping"
```

---

### Task 2: Persist difficulty + wire the Create-screen selector

**Files:**
- Modify: `etchKit/Sources/etchKit/Data/CoreDataStack.swift` (add attribute)
- Modify: `etchKit/Sources/etchKit/Data/CDDeck.swift` (add `@NSManaged`)
- Modify: `etchKit/Sources/etchKit/Data/Mapping.swift` (map difficulty)
- Modify: `etchKit/Sources/etchKit/Data/FlashcardRepository.swift` (protocol signature)
- Modify: `etchKit/Sources/etchKit/Data/CoreDataFlashcardRepository.swift` (impl)
- Modify: `etch/etch/Features/Generate/GenerateViewModel.swift`
- Modify: `etch/etch/Features/Generate/GenerateView.swift`
- Test: `etchKit/Tests/etchKitTests/RepositoryTests.swift`

**Interfaces:**
- Consumes: `Difficulty`, `Deck.difficulty` (Task 1).
- Produces:
  - `FlashcardRepository.createDeck(topic:title:difficulty:cards:)` (protocol); concrete impl signature `createDeck(topic: String, title: String, difficulty: Difficulty = .medium, cards: [Flashcard]) async throws -> Deck`.
  - `GenerateViewModel.generate(topic: String, difficulty: Difficulty)`.
  - `DifficultyPicker` (private view in `GenerateView.swift`) bound to a `Difficulty`.

- [ ] **Step 1: Write the failing tests**

Append to `etchKit/Tests/etchKitTests/RepositoryTests.swift` (inside the struct), and add `import CoreData` at the top of the file (after `import Foundation`):

```swift
    @Test("Create persists the chosen difficulty")
    func persistsDifficulty() async throws {
        let repo = makeRepo()
        let deck = try await repo.createDeck(topic: "t", title: "t", difficulty: .hard, cards: sampleCards())
        #expect(deck.difficulty == .hard)
        let fetched = try await repo.deck(id: deck.id)
        #expect(fetched?.difficulty == .hard)
    }

    @Test("Difficulty defaults to medium when unspecified")
    func defaultsDifficulty() async throws {
        let repo = makeRepo()
        let deck = try await repo.createDeck(topic: "t", title: "t", cards: sampleCards())
        #expect(deck.difficulty == .medium)
    }

    @Test("Unknown stored difficulty maps to medium")
    func unknownDifficultyMapsToMedium() async throws {
        let stack = CoreDataStack(inMemory: true)
        let repo = CoreDataFlashcardRepository(stack: stack)
        let ctx = stack.newBackgroundContext()
        let id = UUID()
        try await ctx.perform {
            let d = NSEntityDescription.insertNewObject(forEntityName: "CDDeck", into: ctx) as! CDDeck
            d.id = id
            d.topic = "t"
            d.title = "t"
            d.createdAt = .now
            d.difficulty = "legacy-value"
            try ctx.save()
        }
        let fetched = try await repo.deck(id: id)
        #expect(fetched?.difficulty == .medium)
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd etchKit && xcodebuild test -scheme etchKit -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:etchKitTests/CoreDataFlashcardRepository`
Expected: FAIL to compile — `createDeck` has no `difficulty:` label; `CDDeck` has no `difficulty`.

- [ ] **Step 3: Add the Core Data attribute**

In `etchKit/Sources/etchKit/Data/CoreDataStack.swift`, add a `difficulty` attribute to the deck properties array:

```swift
        // Deck attributes
        deck.properties = [
            attribute("id", .UUIDAttributeType, indexed: true),
            attribute("topic", .stringAttributeType),
            attribute("title", .stringAttributeType),
            attribute("createdAt", .dateAttributeType),
            attribute("difficulty", .stringAttributeType, defaultValue: "medium"),
        ]
```

- [ ] **Step 4: Add the managed property**

In `etchKit/Sources/etchKit/Data/CDDeck.swift`, add inside the class:

```swift
    @NSManaged var difficulty: String
```

- [ ] **Step 5: Map the attribute to the domain**

In `etchKit/Sources/etchKit/Data/Mapping.swift`, update `CDDeck.toDomain()`:

```swift
extension CDDeck {
    func toDomain() -> Deck {
        let mapped = cards
            .map { $0.toDomain() }
            .sorted { $0.orderIndex < $1.orderIndex }
        return Deck(
            id: id,
            topic: topic,
            title: title,
            createdAt: createdAt,
            difficulty: Difficulty(rawValue: difficulty) ?? .medium,
            cards: mapped
        )
    }
}
```

- [ ] **Step 6: Update the repository protocol and implementation**

In `etchKit/Sources/etchKit/Data/FlashcardRepository.swift`, change the requirement:

```swift
    func createDeck(topic: String, title: String, difficulty: Difficulty, cards: [Flashcard]) async throws -> Deck
```

In `etchKit/Sources/etchKit/Data/CoreDataFlashcardRepository.swift`, update the method (note the `= .medium` default and setting the attribute on insert):

```swift
    public func createDeck(topic: String, title: String, difficulty: Difficulty = .medium, cards: [Flashcard]) async throws -> Deck {
        let context = stack.newBackgroundContext()
        let deck = try await context.perform {
            let cdDeck = NSEntityDescription.insertNewObject(forEntityName: "CDDeck", into: context) as! CDDeck
            cdDeck.id = UUID()
            cdDeck.topic = topic
            cdDeck.title = title
            cdDeck.createdAt = .now
            cdDeck.difficulty = difficulty.rawValue

            for (index, card) in cards.enumerated() {
                let cdCard = NSEntityDescription.insertNewObject(forEntityName: "CDCard", into: context) as! CDCard
                cdCard.apply(card)
                cdCard.orderIndex = Int32(index)
                cdCard.createdAt = .now
                cdCard.deck = cdDeck
            }

            try context.save()
            return cdDeck.toDomain()
        }
        await broadcast()
        return deck
    }
```

- [ ] **Step 7: Thread difficulty through the ViewModel**

In `etch/etch/Features/Generate/GenerateViewModel.swift`, change `generate(topic:)` to accept difficulty and pass it to `createDeck` (the `streamDeck` call stays topic-only until Task 3):

```swift
    func generate(topic: String, difficulty: Difficulty) {
        let trimmed = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        task?.cancel()
        streamingCards = []
        streamingTitle = nil
        phase = .generating

        task = Task {
            do {
                var last = DeckSnapshot()
                for try await snapshot in generator.streamDeck(topic: trimmed) {
                    streamingTitle = snapshot.title ?? streamingTitle
                    streamingCards = snapshot.cards
                    last = snapshot
                }
                guard !Task.isCancelled else { return }
                guard !last.cards.isEmpty else {
                    phase = .failed(.noUsableCards)
                    return
                }
                let deck = try await repository.createDeck(
                    topic: trimmed,
                    title: last.title ?? trimmed,
                    difficulty: difficulty,
                    cards: last.cards
                )
                Haptics.success()
                phase = .done(deck)
            } catch let error as GenerationError {
                if error == .cancelled { return }
                phase = .failed(error)
            } catch {
                phase = .failed(.underlying(String(describing: error)))
            }
        }
    }
```

- [ ] **Step 8: Add the selector to the Create screen**

In `etch/etch/Features/Generate/GenerateView.swift`:

(a) Add state next to `@State private var topic = ""`:

```swift
    @State private var difficulty: Difficulty = .medium
```

(b) Replace the `idle(_:)` method body so it includes the picker and passes `difficulty` to both generate calls:

```swift
    private func idle(_ viewModel: GenerateViewModel) -> some View {
        VStack(spacing: Theme.Spacing.section) {
            Spacer()
            Text("> what do you want to learn?")
                .font(Theme.Typo.title)
                .foregroundStyle(Theme.Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

            TopicField(topic: $topic, isEnabled: true) {
                viewModel.generate(topic: topic, difficulty: difficulty)
            }

            DifficultyPicker(selection: $difficulty)

            CalmButton(
                "create deck",
                style: topic.trimmingCharacters(in: .whitespaces).isEmpty ? .quiet : .filled,
                isEnabled: !topic.trimmingCharacters(in: .whitespaces).isEmpty
            ) {
                viewModel.generate(topic: topic, difficulty: difficulty)
            }
            .accessibilityIdentifier("createDeckButton")
            Spacer()
            Spacer()
        }
    }
```

(c) Add the private picker view at the end of the file (before the `#Preview`):

```swift
/// Bracketed difficulty selector `[easy] [medium] [hard] [ultra]`. The active
/// level shows its tint; the rest stay muted. Matches the terminal tab style.
private struct DifficultyPicker: View {
    @Binding var selection: Difficulty

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("> difficulty")
                .font(Theme.Typo.body)
                .foregroundStyle(Theme.Palette.ink)
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(Difficulty.allCases, id: \.self) { level in
                    let active = level == selection
                    Button {
                        Haptics.softTap()
                        selection = level
                    } label: {
                        Text("[\(level.label)]")
                            .font(Theme.Typo.buttonLabel)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.sm)
                            .foregroundStyle(active ? level.tint : Theme.Palette.inkSecondary)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                                    .strokeBorder(active ? level.tint.opacity(0.7) : Theme.Palette.hairline, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("difficulty-\(level.rawValue)")
                    .accessibilityLabel(level.label)
                    .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
    }
}
```

- [ ] **Step 9: Run the unit tests + build**

Run: `cd etchKit && xcodebuild test -scheme etchKit -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:etchKitTests/CoreDataFlashcardRepository`
Expected: PASS (existing + 3 new tests).

Run (repo root): `xcodebuild -project etch/etch.xcodeproj -scheme etch -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 10: Commit**

```bash
git add etchKit/Sources/etchKit/Data etch/etch/Features/Generate/GenerateViewModel.swift etch/etch/Features/Generate/GenerateView.swift etchKit/Tests/etchKitTests/RepositoryTests.swift
git commit -m "feat: persist deck difficulty and add Create-screen selector"
```

---

### Task 3: Vary the generation prompt by difficulty

**Files:**
- Modify: `etchKit/Sources/etchKit/AI/FlashcardGenerating.swift` (protocol signature)
- Modify: `etchKit/Sources/etchKit/AI/FlashcardGenerator.swift` (per-level prompt)
- Modify: `etchKit/Sources/etchKit/AI/MockGenerator.swift` (accept param)
- Modify: `etch/etch/Features/Generate/GenerateViewModel.swift` (pass to streamDeck)
- Test: `etchKit/Tests/etchKitTests/GenerationMappingTests.swift`

**Interfaces:**
- Consumes: `Difficulty` (Task 1).
- Produces:
  - `FlashcardGenerating.streamDeck(topic:difficulty:)` (protocol); concrete impls add `difficulty: Difficulty = .medium` default.

- [ ] **Step 1: Write the failing test**

Append to `etchKit/Tests/etchKitTests/GenerationMappingTests.swift` (inside the struct):

```swift
    @Test("Mock accepts a difficulty and still streams the sample deck")
    func mockAcceptsDifficulty() async throws {
        let generator = MockGenerator(
            behavior: .stream(cards: MockGenerator.sampleCards, title: "T"),
            stepDelay: .milliseconds(1)
        )
        var final: DeckSnapshot?
        for try await snapshot in generator.streamDeck(topic: "x", difficulty: .ultra) {
            final = snapshot
        }
        #expect(final?.isComplete == true)
        #expect(final?.cards.count == MockGenerator.sampleCards.count)
    }
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd etchKit && xcodebuild test -scheme etchKit -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:etchKitTests/GenerationMappingTests`
Expected: FAIL to compile — `streamDeck` has no `difficulty:` label.

- [ ] **Step 3: Update the protocol**

In `etchKit/Sources/etchKit/AI/FlashcardGenerating.swift`, change the requirement:

```swift
    /// Streams progressively-more-complete deck snapshots. The final value is
    /// the complete deck, marked `isComplete`.
    func streamDeck(topic: String, difficulty: Difficulty) -> AsyncThrowingStream<DeckSnapshot, Error>
```

- [ ] **Step 4: Update the real generator with per-level prompts**

In `etchKit/Sources/etchKit/AI/FlashcardGenerator.swift`:

(a) Change the signature and the two internal references (`Self.instructions` → `Self.instructions(for: difficulty)`, `Self.prompt(for: trimmed)` → `Self.prompt(for: trimmed, difficulty: difficulty)`):

```swift
    public func streamDeck(topic: String, difficulty: Difficulty = .medium) -> AsyncThrowingStream<DeckSnapshot, Error> {
        AsyncThrowingStream { continuation in
            let trimmed = topic.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                continuation.finish(throwing: GenerationError.emptyTopic)
                return
            }
            guard case .available = availability else {
                let reason: GenerationError.UnavailableReason =
                    if case .unavailable(let r) = availability { r } else { .unknown }
                continuation.finish(throwing: GenerationError.modelUnavailable(reason))
                return
            }

            let task = Task { @MainActor in
                do {
                    let session = LanguageModelSession(instructions: Self.instructions(for: difficulty))
                    let options = GenerationOptions(temperature: 0.6)
                    let stream = session.streamResponse(
                        to: Self.prompt(for: trimmed, difficulty: difficulty),
                        generating: GeneratedDeck.self,
                        options: options
                    )

                    var last: GeneratedDeck.PartiallyGenerated?
                    for try await snapshot in stream {
                        try Task.checkCancellation()
                        last = snapshot.content
                        continuation.yield(Self.snapshot(from: snapshot.content, complete: false))
                    }

                    if let last {
                        continuation.yield(Self.snapshot(from: last, complete: true))
                    } else {
                        continuation.yield(DeckSnapshot(isComplete: true))
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: GenerationError.cancelled)
                } catch {
                    continuation.finish(throwing: Self.map(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
```

(b) Replace the `instructions` static constant and `prompt` helper with difficulty-aware versions, and update `prewarm()` to use `instructions(for: .medium)`:

```swift
    public func prewarm() {
        guard case .available = availability else { return }
        let session = LanguageModelSession(instructions: Self.instructions(for: .medium))
        session.prewarm()
    }
```

```swift
    // MARK: - Prompt

    private static let baseInstructions = """
    You generate concise study flashcards. Each card tests exactly one idea. \
    Questions are specific and unambiguous. Answers are correct and self-contained, \
    1 to 3 sentences, with no filler. Cover the most important, distinct sub-topics. \
    Avoid duplicate cards. Use clear, plain language.
    """

    private static func instructions(for difficulty: Difficulty) -> String {
        let level: String
        switch difficulty {
        case .easy:
            level = "Target a beginner. Test basic recall: definitions, key terms, and simple facts. Keep questions short and answers to a single sentence."
        case .medium:
            level = "Target a learner with some familiarity. Test solid conceptual understanding and the relationships between ideas."
        case .hard:
            level = "Target an advanced learner. Test applied reasoning, comparisons, cause and effect, and common misconceptions."
        case .ultra:
            level = "Target an expert. Test deep synthesis, edge cases, subtle distinctions, and non-obvious implications."
        }
        return baseInstructions + " " + level
    }

    private static func prompt(for topic: String, difficulty: Difficulty) -> String {
        "Create a \(difficulty.rawValue)-difficulty study flashcard deck for the topic: \"\(topic)\"."
    }
```

- [ ] **Step 5: Update the mock generator**

In `etchKit/Sources/etchKit/AI/MockGenerator.swift`, change the signature only (body unchanged — difficulty is ignored for deterministic content):

```swift
    public func streamDeck(topic: String, difficulty: Difficulty = .medium) -> AsyncThrowingStream<DeckSnapshot, Error> {
```

- [ ] **Step 6: Pass difficulty into streamDeck from the ViewModel**

In `etch/etch/Features/Generate/GenerateViewModel.swift`, update the stream call inside `generate(topic:difficulty:)`:

```swift
                for try await snapshot in generator.streamDeck(topic: trimmed, difficulty: difficulty) {
```

- [ ] **Step 7: Run the unit tests + build**

Run: `cd etchKit && xcodebuild test -scheme etchKit -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:etchKitTests/GenerationMappingTests`
Expected: PASS (existing + 1 new test).

Run (repo root): `xcodebuild -project etch/etch.xcodeproj -scheme etch -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 8: Commit**

```bash
git add etchKit/Sources/etchKit/AI etch/etch/Features/Generate/GenerateViewModel.swift etchKit/Tests/etchKitTests/GenerationMappingTests.swift
git commit -m "feat: vary generation prompt by difficulty level"
```

---

### Task 4: Display the difficulty tag on row + detail

**Files:**
- Modify: `etch/etch/Features/Decks/DeckRow.swift`
- Modify: `etch/etch/Features/Review/DeckDetailView.swift`

**Interfaces:**
- Consumes: `Deck.difficulty`, `Difficulty.label`, `Difficulty.tint` (Tasks 1–2).

- [ ] **Step 1: Add the tag to `DeckRow`**

In `etch/etch/Features/Decks/DeckRow.swift`, update the inner `VStack` to add a difficulty tag beneath the card count, and extend the accessibility label:

```swift
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(deck.title)
                        .font(Theme.Typo.body.weight(.semibold))
                        .foregroundStyle(Theme.Palette.ink)
                        .lineLimit(2)

                    HStack(spacing: Theme.Spacing.xs) {
                        Text("\(deck.cards.count) card\(deck.cards.count == 1 ? "" : "s")")
                            .font(Theme.Typo.caption)
                            .foregroundStyle(Theme.Palette.inkSecondary)
                        Text("[\(deck.difficulty.label)]")
                            .font(Theme.Typo.caption)
                            .foregroundStyle(deck.difficulty.tint)
                    }
                }
```

And update the `accessibilityLabel` modifier to include difficulty:

```swift
        .accessibilityLabel(
            dueCount > 0
                ? "\(deck.title), \(deck.cards.count) cards, \(deck.difficulty.label), \(dueCount) due"
                : "\(deck.title), \(deck.cards.count) cards, \(deck.difficulty.label)"
        )
```

- [ ] **Step 2: Add the tag to `DeckDetailView`**

In `etch/etch/Features/Review/DeckDetailView.swift`, in the `content(_:)` `VStack`, add a difficulty tag row above the study button (as the first child of the `VStack`):

```swift
            VStack(spacing: Theme.Spacing.interCard) {
                HStack {
                    Text("[\(viewModel.deck.difficulty.label)]")
                        .font(Theme.Typo.caption)
                        .foregroundStyle(viewModel.deck.difficulty.tint)
                    Spacer()
                }

                if viewModel.hasDue {
                    CalmButton("study \(viewModel.dueCount) due") {
                        studying = true
                    }
                    .padding(.bottom, Theme.Spacing.xs)
                }

                ForEach(viewModel.deck.cards) { card in
                    FlashcardView(card: card)
                }
            }
```

- [ ] **Step 3: Build to verify**

Run: `xcodebuild -project etch/etch.xcodeproj -scheme etch -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add etch/etch/Features/Decks/DeckRow.swift etch/etch/Features/Review/DeckDetailView.swift
git commit -m "feat: show difficulty tag on deck row and detail"
```

---

### Task 5: Full verification pass

**Files:** none (verification only).

- [ ] **Step 1: Clean build**

Run: `xcodebuild -project etch/etch.xcodeproj -scheme etch -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 2: Full etchKit test suite**

Run: `cd etchKit && xcodebuild test -scheme etchKit -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: `** TEST SUCCEEDED **` (all suites, including the new Difficulty/repository/generation tests).

- [ ] **Step 3: UI happy-path E2E**

Run: `xcodebuild test -project etch/etch.xcodeproj -scheme etch -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:etchUITests/GenerateFlowUITests`
Expected: `** TEST SUCCEEDED **`. The flow leaves the selector at the default (`medium`), so the create path is unaffected; the new `difficulty-*` buttons carry accessibility identifiers and do not collide with `topicField` / `createDeckButton`.

- [ ] **Step 4: Visual smoke check**

Install + launch in the iPhone 17 Pro simulator, screenshot the Create screen (selector visible, `medium` active) and a deck row/detail (colored difficulty tag). Confirm dark/monospace styling holds.

```bash
APP="$(xcodebuild -project etch/etch.xcodeproj -scheme etch -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -showBuildSettings 2>/dev/null | awk -F' = ' '/ BUILT_PRODUCTS_DIR /{d=$2} / FULL_PRODUCT_NAME /{n=$2} END{print d"/"n}')"
xcrun simctl install "iPhone 17 Pro" "$APP"
xcrun simctl launch "iPhone 17 Pro" com.descifrador.etch
```

---

## Self-Review

**Spec coverage:**
- §3 Difficulty enum + Deck field + style mapping → Task 1. ✓
- §4 generation per-level prompt (real) + mock param → Task 3. ✓
- §5 Core Data attribute + CDDeck + mapping + repository signature → Task 2. ✓
- §6 ViewModel `generate(topic:difficulty:)` + selector + display tags → Tasks 2 (VM/selector) & 4 (tags). ✓
- §7 tests (round-trip, default/unknown→medium, mock param) + call-site updates → Tasks 1–3; call sites preserved via concrete `= .medium` defaults, VM updated explicitly. ✓
- §8 acceptance (build clean, tests pass, UI E2E, legacy→medium) → Tasks 2 & 5. ✓

**Placeholder scan:** No TBD/TODO; every code step shows full code. ✓

**Type consistency:** `Difficulty` (Task 1) is referenced with identical case names and `.label`/`.tint`/`.rawValue` across Tasks 2–4. `createDeck(topic:title:difficulty:cards:)` and `streamDeck(topic:difficulty:)` signatures are consistent between protocol (no default), concrete impls (`= .medium`), and call sites. `generate(topic:difficulty:)` defined in Task 2, its `streamDeck` argument added in Task 3, both consistent. `DifficultyPicker(selection:)` binding type is `Difficulty`. ✓

**Note:** Tasks 2 and 3 each change a protocol signature; existing tests compile unchanged because the concrete implementations carry `= .medium` defaults (Swift permits omitting a defaulted middle parameter). The ViewModel calls through protocol existentials and therefore passes `difficulty` explicitly — wired in Task 2 (createDeck) and Task 3 (streamDeck). ✓
