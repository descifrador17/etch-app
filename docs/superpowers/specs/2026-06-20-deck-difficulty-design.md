# Deck Difficulty Selection — Design Spec

**Date:** 2026-06-20
**Scope:** Let the user pick a difficulty (easy / medium / hard / ultra) when creating a deck; that difficulty shapes generation and is persisted and displayed.
**Branch:** Built on `redesign/terminal-dark` (extends the redesigned Generate screen).

---

## 1. Goal

On the Create screen, the user chooses one of four difficulty levels before
generating. The level changes the *depth and style* of the generated flashcards
(not their count), is saved with the deck, and is shown as a colored tag on the
deck row and the deck detail header.

## 2. Decisions (locked)

| Decision | Choice |
|---|---|
| Effect of difficulty | Depth & style only — card count stays ~8–12 |
| Persistence | Persist the chosen difficulty with the deck and display it |
| Default level | `medium` |
| Levels | `easy`, `medium`, `hard`, `ultra` |
| Branch | Continue on `redesign/terminal-dark` |

## 3. Domain — `Difficulty`

New file `etchKit/Sources/etchKit/Domain/Difficulty.swift`:

```swift
public enum Difficulty: String, CaseIterable, Sendable {
    case easy, medium, hard, ultra
}
```

- Raw `String` value is the persistence form.
- `Difficulty(rawValue:)` is used when reading from storage; callers fall back to
  `.medium` for any unknown/missing value.
- `Deck` (in `Domain/Deck.swift`) gains `public var difficulty: Difficulty`, with
  the initializer defaulting it to `.medium` so existing construction sites and
  previews keep compiling.
- Color mapping is **not** in the domain type. The view layer maps
  difficulty → color (easy→green, medium→yellow, hard→orange, ultra→red), reusing
  the existing `Theme.Palette.grade*` tokens, mirroring how `GradeBar` maps grades
  to colors today.

## 4. Generation

`FlashcardGenerating.streamDeck(topic:)` becomes
`streamDeck(topic:difficulty:)`.

- **`FlashcardGenerator` (real):** add a per-level instruction block that sets the
  cognitive target:
  - `easy` — beginner; basic recall: definitions, key terms, simple facts; short answers.
  - `medium` — student with some familiarity; solid conceptual understanding and relationships between ideas.
  - `hard` — advanced learner; applied reasoning, comparisons, why/how, common misconceptions.
  - `ultra` — expert; deep synthesis, edge cases, subtle distinctions, non-obvious implications.

  The shared base instruction (concise, one-idea-per-card, no duplicates) is kept.
  The `GeneratedDeck` `@Generable` schema is unchanged — still 8–12 cards (depth
  lever only, per §2). The level is folded into both the instructions and the
  per-topic prompt.
- **`MockGenerator`:** `streamDeck(topic:difficulty:)` accepts the parameter and
  ignores it for content (still streams the sample deck), keeping previews and
  tests deterministic.

## 5. Persistence

Additive, lightweight-migration-safe (the stack already enables
`shouldMigrateStoreAutomatically` + `shouldInferMappingModelAutomatically`):

- `CoreDataStack.makeModel()`: add to `CDDeck`
  `attribute("difficulty", .stringAttributeType, defaultValue: "medium")`.
- `CDDeck`: `@NSManaged var difficulty: String`.
- `Mapping.swift` `CDDeck.toDomain()`: map
  `difficulty: Difficulty(rawValue: difficulty) ?? .medium`.
- `FlashcardRepository.createDeck(topic:title:cards:)` →
  `createDeck(topic:title:difficulty:cards:)`. The Core Data implementation sets
  `cdDeck.difficulty = difficulty.rawValue` on insert.

## 6. View + ViewModel

- `GenerateViewModel.generate(topic:)` → `generate(topic:difficulty:)`; the level
  is passed straight through to `streamDeck(topic:difficulty:)` and then to
  `repository.createDeck(topic:title:difficulty:cards:)`.
- `GenerateView` idle screen: below `TopicField`, add a `> difficulty` label and a
  bracketed selector row `[easy] [medium] [hard] [ultra]`. Active item = its
  difficulty color + ink weight (or underline), inactive = `mute`, matching the
  terminal tab style. Selection is `@State private var difficulty: Difficulty = .medium`
  in `GenerateView`, passed into `generate`.
- **Display:**
  - `DeckRow`: a colored difficulty tag (e.g. `[hard]`) rendered near the card
    count, using the difficulty→color mapping.
  - `DeckDetailView`: the same tag shown in the detail header (above or beside the
    study CTA).

## 7. Testing

- New `etchKit` tests:
  - Repository: `createDeck(..., difficulty: .hard, ...)` round-trips — the
    fetched/returned deck has `.hard`.
  - Mapping: a `CDDeck` with an unknown/garbage `difficulty` string maps to
    `.medium`; default-on-insert yields `.medium` when unspecified.
  - Mock generator: `streamDeck(topic:difficulty:)` accepts the param and still
    streams the sample deck.
- Update existing call sites to the new signatures: `RepositoryTests`,
  generation/mapping tests, and `GenerateViewModel`.
- Re-run app build, `etchKit` unit tests, and the `GenerateFlowUITests` E2E. The
  UI test uses the default (`medium`) selection, so the flow stays green; if the
  difficulty selector intercepts a tap, give the selector items accessibility
  identifiers and/or leave the default untouched so the test path is unaffected.

## 8. Acceptance

- Create screen shows a four-way difficulty selector defaulting to `medium`.
- Choosing a level changes the generation prompt (verifiable: real generator
  builds different instructions per level; covered structurally, not by asserting
  model output).
- The chosen difficulty persists and appears as a colored tag on the deck row and
  the deck detail header.
- Existing decks (no stored difficulty) load as `medium` with no crash/migration
  error.
- Build is clean under Swift 6 strict concurrency; all unit tests and the UI E2E
  pass.

## 9. Out of scope (YAGNI)

- Per-card difficulty.
- Editing a deck's difficulty after creation.
- Scaling card count or answer length by difficulty.
- Filtering/sorting decks by difficulty.
