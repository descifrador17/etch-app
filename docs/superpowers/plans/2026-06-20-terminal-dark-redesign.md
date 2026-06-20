# Terminal-Dark Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Recall's warm "calm" design system with the dark-only, terminal-native (monospace / ASCII-bracket / hairline-flat) language from `docs/DESIGN.md`, across every screen.

**Architecture:** Redefine the design tokens in `Theme.swift` (code-defined inverted-dark palette + monospaced type + sharp shape, no shadows), restyle the four shared components, force dark color scheme at the app root, then restyle each of the four feature screens. All changes are in-place edits to existing files — no new source files, so the Xcode project does **not** need regenerating.

**Tech Stack:** SwiftUI (iOS 26), Swift 6 strict concurrency, local `RecallKit` SPM package (Design layer), Xcode 26.

## Global Constraints

- Dark mode only — `.preferredColorScheme(.dark)` at the root; no light-mode rendering, no scheme toggle.
- Every text role uses `Font.system(..., design: .monospaced)`; keep Dynamic Type text styles, no fixed point sizes.
- No drop shadows, no gradients. Container radius = `0`; interactive-element radius = `4` only.
- Iconography is ASCII bracket markers (`[+]` `[x]` `[...]` `[#]`), not SF Symbols.
- Preserve all existing behavior: generation streaming, card flip, spaced-repetition grading, swipe-to-delete, accessibility labels, and Reduce-Motion paths.
- Swift 6 strict concurrency; `@MainActor` protocols unchanged. No networking.
- Verification command (the build gate), run from repo root:
  `xcodebuild -project Recall/Recall.xcodeproj -scheme Recall -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
- Unit tests (run at the end), from `RecallKit/`:
  `xcodebuild test -scheme RecallKit -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`

---

### Task 1: Redefine design tokens in Theme.swift

**Files:**
- Modify: `RecallKit/Sources/RecallKit/Design/Theme.swift`

**Interfaces:**
- Produces:
  - `Color(hex: UInt32)` initializer (sRGB, opaque).
  - `Theme.Palette`: keeps existing names `surface`, `surfaceRaised`, `ink`, `inkSecondary`, `accent`, `hairline` (repointed to the dark palette); adds `body`, `ash`, `hairlineStrong`, `gradeAgain`, `gradeHard`, `gradeGood`, `gradeEasy` — all `Color`.
  - `Theme.Typo`: keeps `display`, `title`, `cardFace`, `body`, `caption`; adds `buttonLabel` — all monospaced `Font`.
  - `Theme.Radius`: `card = 0`, `button = 4`.
  - `Theme.Spacing`: unchanged names; `section = 32`.
  - `Theme.Shadow` is **left intact in this task** (its only consumer, `CardSurface`, is changed in Task 2; deleting it here would break the build).

- [ ] **Step 1: Replace the file contents**

```swift
import SwiftUI

/// The terminal-native dark design system. Pure-black canvas, monospaced ink,
/// hairline borders, no shadows. Colors are code-defined so the (dark-only)
/// palette lives in one legible place. See docs/DESIGN.md.
public enum Theme {}

// MARK: - Color hex helper

public extension Color {
    /// Opaque sRGB color from a 0xRRGGBB literal.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue:  Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

// MARK: - Palette (inverted dark ladder)

public extension Theme {
    enum Palette {
        // Surfaces
        public static let surface        = Color(hex: 0x000000) // canvas — every screen bg
        public static let surfaceRaised  = Color(hex: 0x1A1A1A) // cards, inputs, elevated rows
        // Ink ladder
        public static let ink            = Color(hex: 0xFFFFFF) // headlines, card text
        public static let body           = Color(hex: 0xCCCCCC) // paragraph copy
        public static let inkSecondary   = Color(hex: 0x999999) // mute — metadata, captions
        public static let ash            = Color(hex: 0x666666) // disabled, skeleton
        // Lines
        public static let hairline       = Color.white.opacity(0.12)
        public static let hairlineStrong = Color(hex: 0x666666)
        // Accent + semantic grade ramp
        public static let accent         = Color(hex: 0x0A84FF) // Apple Blue (dark variant)
        public static let gradeAgain     = Color(hex: 0xFF453A) // red
        public static let gradeHard      = Color(hex: 0xFF9F0A) // orange
        public static let gradeGood      = Color(hex: 0xFFD60A) // yellow
        public static let gradeEasy      = Color(hex: 0x30D158) // green
    }
}

// MARK: - Typography (100% monospaced, Dynamic-Type driven)

public extension Theme {
    enum Typo {
        public static let display     = Font.system(.largeTitle, design: .monospaced, weight: .bold)
        public static let title       = Font.system(.title2,     design: .monospaced, weight: .semibold)
        public static let cardFace    = Font.system(.title,      design: .monospaced, weight: .medium)
        public static let body        = Font.system(.body,       design: .monospaced)
        public static let buttonLabel = Font.system(.body,       design: .monospaced, weight: .medium)
        public static let caption     = Font.system(.footnote,   design: .monospaced)
    }
}

// MARK: - Spacing & Shape

public extension Theme {
    enum Spacing {
        public static let section: CGFloat = 32
        public static let cardInner: CGFloat = 20
        public static let interCard: CGFloat = 12
        public static let xs: CGFloat = 8
        public static let sm: CGFloat = 12
        public static let md: CGFloat = 16
    }

    enum Radius {
        public static let card: CGFloat = 0    // sharp containers
        public static let button: CGFloat = 4  // the only rounded thing
    }

    /// Retained only until CardSurface stops consuming it (Task 2). No element
    /// in the terminal system casts a shadow.
    enum Shadow {
        public static let radius: CGFloat = 24
        public static let y: CGFloat = 8
        public static let opacity: Double = 0.06
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild -project Recall/Recall.xcodeproj -scheme Recall -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **` (existing call sites still resolve via retained names).

- [ ] **Step 3: Commit**

```bash
git add RecallKit/Sources/RecallKit/Design/Theme.swift
git commit -m "design: invert tokens to terminal-dark palette and monospaced type"
```

---

### Task 2: Restyle CardSurface as a flat terminal frame

**Files:**
- Modify: `RecallKit/Sources/RecallKit/Design/Components/CardSurface.swift`
- Modify: `RecallKit/Sources/RecallKit/Design/Theme.swift` (delete `Theme.Shadow`)

**Interfaces:**
- Consumes: `Theme.Palette.surfaceRaised`, `Theme.Palette.hairline`, `Theme.Radius.card`.
- Produces: `CardSurface` — same public API (`init(@ViewBuilder content:)`), now a flat `#1A1A1A` block with a 1px hairline border, 0px corners, no shadow.

- [ ] **Step 1: Replace CardSurface body**

```swift
import SwiftUI

/// The foundational terminal-style container — flat `surfaceRaised` fill, a 1px
/// hairline border, sharp corners, no shadow. Every framed block sits on one.
public struct CardSurface<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.Palette.surfaceRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(Theme.Palette.hairline, lineWidth: 1)
            )
    }
}

#Preview("CardSurface") {
    ZStack {
        Theme.Palette.surface.ignoresSafeArea()
        CardSurface {
            Text("a terminal surface")
                .font(Theme.Typo.cardFace)
                .foregroundStyle(Theme.Palette.ink)
                .padding(Theme.Spacing.cardInner)
        }
        .padding()
    }
}
```

- [ ] **Step 2: Delete the now-orphaned `Theme.Shadow` enum**

In `RecallKit/Sources/RecallKit/Design/Theme.swift`, remove the entire `enum Shadow { ... }` block added/retained in Task 1 (and its doc comment).

- [ ] **Step 3: Build to verify**

Run: `xcodebuild -project Recall/Recall.xcodeproj -scheme Recall -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **` (no remaining references to `Theme.Shadow`).

- [ ] **Step 4: Commit**

```bash
git add RecallKit/Sources/RecallKit/Design/Components/CardSurface.swift RecallKit/Sources/RecallKit/Design/Theme.swift
git commit -m "design: flatten CardSurface to a hairline terminal frame; drop shadow token"
```

---

### Task 3: Restyle CalmButton (blue primary / quiet outline)

**Files:**
- Modify: `RecallKit/Sources/RecallKit/Design/Components/CalmButton.swift`

**Interfaces:**
- Consumes: `Theme.Palette.accent`, `.ink`, `.inkSecondary`, `.hairlineStrong`, `Theme.Typo.buttonLabel`, `Theme.Radius.button`.
- Produces: `CalmButton(_:style:isEnabled:action:)` — unchanged API. `.filled` = Apple-Blue fill / white mono label; `.quiet` = transparent fill, mute label, hairline border. Labels render bracketed (`[ title ]`). 4px radius.

- [ ] **Step 1: Replace the body and helpers**

```swift
import SwiftUI

/// A full-width terminal button. Two variants:
/// - `.filled` — Apple-Blue fill, white mono label, the primary action.
/// - `.quiet`  — transparent fill, mute label, hairline border, low-emphasis.
/// Labels render bracketed, e.g. `[ create deck ]`.
public struct CalmButton: View {
    public enum Style {
        case filled
        case quiet
    }

    private let title: String
    private let style: Style
    private let isEnabled: Bool
    private let action: () -> Void

    @State private var pressed = false

    public init(
        _ title: String,
        style: Style = .filled,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.isEnabled = isEnabled
        self.action = action
    }

    public var body: some View {
        Button {
            Haptics.softTap()
            action()
        } label: {
            Text("[ \(title) ]")
                .font(Theme.Typo.buttonLabel)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
                .foregroundStyle(foreground)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                        .fill(background)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                        .strokeBorder(border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(pressed ? 0.7 : (isEnabled ? 1 : 0.4))
        .animation(Motion.settle, value: pressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if isEnabled { pressed = true } }
                .onEnded { _ in pressed = false }
        )
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }

    private var foreground: Color {
        switch style {
        case .filled: .white
        case .quiet:  Theme.Palette.inkSecondary
        }
    }

    private var background: Color {
        switch style {
        case .filled: Theme.Palette.accent
        case .quiet:  .clear
        }
    }

    private var border: Color {
        switch style {
        case .filled: .clear
        case .quiet:  Theme.Palette.hairlineStrong
        }
    }
}

#Preview("CalmButton") {
    ZStack {
        Theme.Palette.surface.ignoresSafeArea()
        VStack(spacing: Theme.Spacing.md) {
            CalmButton("create deck") {}
            CalmButton("create deck", isEnabled: false) {}
            CalmButton("stop", style: .quiet) {}
        }
        .padding()
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -project Recall/Recall.xcodeproj -scheme Recall -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add RecallKit/Sources/RecallKit/Design/Components/CalmButton.swift
git commit -m "design: terminal CalmButton — blue primary, bracketed quiet outline"
```

---

### Task 4: Restyle ShimmerPlaceholder as a terminal block

**Files:**
- Modify: `RecallKit/Sources/RecallKit/Design/Components/ShimmerPlaceholder.swift`

**Interfaces:**
- Consumes: `Theme.Palette.surfaceRaised`, `.hairline`, `Theme.Radius.card`.
- Produces: `ShimmerPlaceholder(cornerRadius:)` — unchanged API; default `cornerRadius` now `Theme.Radius.card` (0). Renders a dim hairline-bordered block with a slow opacity pulse, no gradient sweep. Honors Reduce Motion.

- [ ] **Step 1: Replace the file contents**

```swift
import SwiftUI

/// An in-flight placeholder block — a dim `surfaceRaised` rectangle with a
/// hairline border and a slow opacity pulse (no gradient sweep, no spinner).
/// Honors Reduce Motion (the pulse simply stops).
public struct ShimmerPlaceholder: View {
    private let cornerRadius: CGFloat

    @State private var dim = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(cornerRadius: CGFloat = Theme.Radius.card) {
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Theme.Palette.surfaceRaised)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.Palette.hairline, lineWidth: 1)
            )
            .opacity(dim ? 0.45 : 0.85)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    dim = true
                }
            }
            .accessibilityHidden(true)
    }
}

#Preview("ShimmerPlaceholder") {
    ZStack {
        Theme.Palette.surface.ignoresSafeArea()
        VStack(spacing: Theme.Spacing.interCard) {
            ForEach(0..<3, id: \.self) { _ in
                ShimmerPlaceholder()
                    .frame(height: 72)
            }
        }
        .padding()
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -project Recall/Recall.xcodeproj -scheme Recall -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add RecallKit/Sources/RecallKit/Design/Components/ShimmerPlaceholder.swift
git commit -m "design: terminal placeholder block, no gradient sweep"
```

---

### Task 5: Restyle GradeBar as bracketed colored grades

**Files:**
- Modify: `Recall/Recall/Features/Study/GradeBar.swift`

**Interfaces:**
- Consumes: `ReviewGrade` (`.again/.hard/.good/.easy`, `allCases`), `Theme.Palette.grade*`, `Theme.Typo.buttonLabel`, `Theme.Radius.button`.
- Produces: `GradeBar(onGrade:)` — unchanged API. Four bracketed buttons `[ again ] [ hard ] [ good ] [ easy ]`, each colored by its grade (colored label + matching border, transparent fill).

- [ ] **Step 1: Replace the file contents**

```swift
import SwiftUI
import RecallKit

/// Four bracketed grade buttons, each in its semantic color:
/// again=red, hard=orange, good=yellow, easy=green.
struct GradeBar: View {
    var onGrade: (ReviewGrade) -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(ReviewGrade.allCases, id: \.self) { grade in
                Button {
                    onGrade(grade)
                } label: {
                    Text("[ \(label(for: grade)) ]")
                        .font(Theme.Typo.buttonLabel)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.md)
                        .foregroundStyle(color(for: grade))
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                                .fill(Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                                .strokeBorder(color(for: grade).opacity(0.6), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(label(for: grade))
            }
        }
    }

    private func label(for grade: ReviewGrade) -> String {
        switch grade {
        case .again: "again"
        case .hard:  "hard"
        case .good:  "good"
        case .easy:  "easy"
        }
    }

    private func color(for grade: ReviewGrade) -> Color {
        switch grade {
        case .again: Theme.Palette.gradeAgain
        case .hard:  Theme.Palette.gradeHard
        case .good:  Theme.Palette.gradeGood
        case .easy:  Theme.Palette.gradeEasy
        }
    }
}

#Preview("GradeBar") {
    GradeBar(onGrade: { _ in })
        .padding()
        .background(Theme.Palette.surface)
}
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -project Recall/Recall.xcodeproj -scheme Recall -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Recall/Recall/Features/Study/GradeBar.swift
git commit -m "design: bracketed colored GradeBar (red/orange/yellow/green ramp)"
```

---

### Task 6: Force dark color scheme at the app root

**Files:**
- Modify: `Recall/Recall/RecallApp.swift`

**Interfaces:**
- Consumes: `Theme.Palette.accent`.
- Produces: app always renders in dark mode.

- [ ] **Step 1: Add `.preferredColorScheme(.dark)`**

```swift
import SwiftUI
import RecallKit

@main
struct RecallApp: App {
    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(container)
                .tint(Theme.Palette.accent)
                .preferredColorScheme(.dark)
        }
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -project Recall/Recall.xcodeproj -scheme Recall -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Recall/Recall/RecallApp.swift
git commit -m "design: pin app to dark mode only"
```

---

### Task 7: Custom terminal top-nav in RootView

**Files:**
- Modify: `Recall/Recall/RootView.swift`

**Interfaces:**
- Consumes: `DecksView()`, `GenerateView()`, `Theme.Palette.*`, `Theme.Typo.*`, `Theme.Spacing.*`, `Haptics.softTap()`.
- Produces: `RootView` — a `recall` wordmark (left) + `decks` / `create` text tabs (right, active = ink + 2px underline, resting = mute), with the selected screen below. Replaces the system `TabView` chrome.

- [ ] **Step 1: Replace the file contents**

```swift
import SwiftUI
import RecallKit

/// Top "primary-nav" strip: `recall` wordmark at left, `decks` / `create` text
/// tabs at right. The selected screen (each its own NavigationStack) renders below.
struct RootView: View {
    private enum Section: String, CaseIterable {
        case decks, create
    }

    @State private var selection: Section = .decks

    var body: some View {
        VStack(spacing: 0) {
            nav
            Divider().overlay(Theme.Palette.hairline)
            Group {
                switch selection {
                case .decks:  DecksView()
                case .create: GenerateView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.Palette.surface.ignoresSafeArea())
    }

    private var nav: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("recall")
                .font(Theme.Typo.title)
                .foregroundStyle(Theme.Palette.ink)
            Spacer()
            HStack(spacing: Theme.Spacing.md) {
                ForEach(Section.allCases, id: \.self) { section in
                    tab(section)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }

    private func tab(_ section: Section) -> some View {
        let active = selection == section
        return Button {
            Haptics.softTap()
            selection = section
        } label: {
            Text(section.rawValue)
                .font(Theme.Typo.buttonLabel)
                .foregroundStyle(active ? Theme.Palette.ink : Theme.Palette.inkSecondary)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(active ? Theme.Palette.hairlineStrong : .clear)
                        .frame(height: 2)
                        .offset(y: 6)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    RootView()
        .environment(AppContainer())
        .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -project Recall/Recall.xcodeproj -scheme Recall -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Recall/Recall/RootView.swift
git commit -m "design: terminal top-nav strip replacing system tab bar"
```

---

### Task 8: Restyle Decks list, rows, and empty state

**Files:**
- Modify: `Recall/Recall/Features/Decks/DecksView.swift`
- Modify: `Recall/Recall/Features/Decks/DeckRow.swift`

**Interfaces:**
- Consumes: `Deck` (`.title`, `.cards`, `.dueCount()`), `Theme.*`, `CardSurface`, `Motion.settle`.
- Produces: flat hairline mono deck rows with a `[#]` marker and a `[N due]` text badge; mono empty state with no SF Symbol. Existing `NavigationStack`, navigation, and swipe-to-delete preserved.

- [ ] **Step 1: Replace `DeckRow.swift`**

```swift
import SwiftUI
import RecallKit

struct DeckRow: View {
    let deck: Deck

    private var dueCount: Int { deck.dueCount() }

    var body: some View {
        CardSurface {
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                Text("[#]")
                    .font(Theme.Typo.body)
                    .foregroundStyle(Theme.Palette.inkSecondary)

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(deck.title)
                        .font(Theme.Typo.body.weight(.semibold))
                        .foregroundStyle(Theme.Palette.ink)
                        .lineLimit(2)

                    Text("\(deck.cards.count) card\(deck.cards.count == 1 ? "" : "s")")
                        .font(Theme.Typo.caption)
                        .foregroundStyle(Theme.Palette.inkSecondary)
                }

                Spacer(minLength: Theme.Spacing.sm)

                if dueCount > 0 {
                    Text("[\(dueCount) due]")
                        .font(Theme.Typo.caption)
                        .foregroundStyle(Theme.Palette.accent)
                }
            }
            .padding(Theme.Spacing.cardInner)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            dueCount > 0
                ? "\(deck.title), \(deck.cards.count) cards, \(dueCount) due"
                : "\(deck.title), \(deck.cards.count) cards"
        )
    }
}

#Preview("DeckRow") {
    VStack(spacing: Theme.Spacing.interCard) {
        DeckRow(deck: Deck(topic: "Photosynthesis", title: "Photosynthesis", cards: MockGenerator.sampleCards))
        DeckRow(deck: Deck(topic: "Swift", title: "Swift Actors", cards: Array(MockGenerator.sampleCards.prefix(3)).map {
            var c = $0; c.review.dueDate = .distantFuture; return c
        }))
    }
    .padding()
    .background(Theme.Palette.surface)
    .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Replace the `EmptyDecksView` in `DecksView.swift`**

Replace the `EmptyDecksView` struct (only that struct) with:

```swift
/// Terminal empty state — a bracket glyph and two mono lines.
struct EmptyDecksView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text("[ ]")
                .font(Theme.Typo.display)
                .foregroundStyle(Theme.Palette.inkSecondary)
            Text("no decks yet")
                .font(Theme.Typo.title)
                .foregroundStyle(Theme.Palette.ink)
            Text("create your first deck from the create tab.")
                .font(Theme.Typo.body)
                .foregroundStyle(Theme.Palette.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Spacing.section)
    }
}
```

- [ ] **Step 3: Update the `DecksView` preview to pin dark mode**

At the bottom of `DecksView.swift`, change the `#Preview("Decks")` block to append `.preferredColorScheme(.dark)`:

```swift
#Preview("Decks") {
    DecksView()
        .environment(AppContainer())
        .preferredColorScheme(.dark)
}
```

(Leave the `DecksView` body, `List`, navigation, and swipe-actions logic unchanged — only the empty state and preview change here.)

- [ ] **Step 4: Build to verify**

Run: `xcodebuild -project Recall/Recall.xcodeproj -scheme Recall -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Recall/Recall/Features/Decks/DecksView.swift Recall/Recall/Features/Decks/DeckRow.swift
git commit -m "design: terminal deck rows and empty state"
```

---

### Task 9: Restyle Generate idle + TopicField as a prompt

**Files:**
- Modify: `Recall/Recall/Features/Generate/GenerateView.swift`
- Modify: `Recall/Recall/Features/Generate/TopicField.swift`

**Interfaces:**
- Consumes: `GenerateViewModel`, `CardSurface`, `CalmButton`, `Theme.*`, `Motion.gentle`.
- Produces: idle screen with a `> what do you want to learn?` prompt line, a terminal-framed `TopicField`, and a `[ create deck ]` button. `TopicField` placeholders rendered lowercase with a leading `> `.

- [ ] **Step 1: Replace the `idle(_:)` function in `GenerateView.swift`**

Replace only the `idle(_ viewModel:)` method with:

```swift
    private func idle(_ viewModel: GenerateViewModel) -> some View {
        VStack(spacing: Theme.Spacing.section) {
            Spacer()
            Text("> what do you want to learn?")
                .font(Theme.Typo.title)
                .foregroundStyle(Theme.Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

            TopicField(topic: $topic, isEnabled: true) {
                viewModel.generate(topic: topic)
            }

            CalmButton(
                "create deck",
                style: topic.trimmingCharacters(in: .whitespaces).isEmpty ? .quiet : .filled,
                isEnabled: !topic.trimmingCharacters(in: .whitespaces).isEmpty
            ) {
                viewModel.generate(topic: topic)
            }
            .accessibilityIdentifier("createDeckButton")
            Spacer()
            Spacer()
        }
    }
```

(Leave the rest of `GenerateView` — `body`, `content`, `available`, navigation — unchanged.)

- [ ] **Step 2: Update the `GenerateView` preview to pin dark mode**

```swift
#Preview("Generate — available") {
    GenerateView()
        .environment(AppContainer())
        .preferredColorScheme(.dark)
}
```

- [ ] **Step 3: Replace `TopicField.swift`**

```swift
import SwiftUI
import RecallKit

/// The single prompt-style input. Placeholder rotates gentle lowercase examples
/// behind a leading `> ` caret.
struct TopicField: View {
    @Binding var topic: String
    var isEnabled: Bool
    var onSubmit: () -> Void

    @FocusState private var focused: Bool
    @State private var placeholderIndex = 0

    private let placeholders = ["photosynthesis", "combine operators", "wwii treaties", "swift actors", "the krebs cycle"]
    private let rotation = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    /// Topic length is clamped to ~80 chars per the generation tuning guard.
    private let maxLength = 80

    var body: some View {
        CardSurface {
            HStack(spacing: Theme.Spacing.xs) {
                Text(">")
                    .font(Theme.Typo.body)
                    .foregroundStyle(Theme.Palette.accent)
                TextField(
                    "",
                    text: $topic,
                    prompt: Text(placeholders[placeholderIndex])
                        .foregroundColor(Theme.Palette.inkSecondary)
                )
                .focused($focused)
                .font(Theme.Typo.body)
                .foregroundStyle(Theme.Palette.ink)
                .textInputAutocapitalization(.never)
                .submitLabel(.go)
                .accessibilityIdentifier("topicField")
                .disabled(!isEnabled)
                .onSubmit(onSubmit)
                .onChange(of: topic) { _, newValue in
                    if newValue.count > maxLength {
                        topic = String(newValue.prefix(maxLength))
                    }
                }
            }
            .padding(Theme.Spacing.cardInner)
        }
        .onReceive(rotation) { _ in
            guard topic.isEmpty else { return }
            withAnimation(Motion.gentle) {
                placeholderIndex = (placeholderIndex + 1) % placeholders.count
            }
        }
        .onAppear { focused = true }
    }
}
```

- [ ] **Step 4: Build to verify**

Run: `xcodebuild -project Recall/Recall.xcodeproj -scheme Recall -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Recall/Recall/Features/Generate/GenerateView.swift Recall/Recall/Features/Generate/TopicField.swift
git commit -m "design: prompt-style Generate idle and TopicField"
```

---

### Task 10: Restyle Generate state views + streaming view

**Files:**
- Modify: `Recall/Recall/Features/Generate/GenerateStateViews.swift`
- Modify: `Recall/Recall/Features/Generate/GeneratingView.swift`

**Interfaces:**
- Consumes: `GenerationError`, `CalmButton`, `CardSurface`, `ShimmerPlaceholder`, `Flashcard`, `Theme.*`, `Motion.gentle`.
- Produces: mono unavailable/failed/done states using bracket glyphs (no SF Symbols); streaming view with a `> writing your deck…` header, terminal placeholder rows, and a `[ stop ]` button.

- [ ] **Step 1: Replace `CalmMessage` in `GenerateStateViews.swift`**

Replace the `CalmMessage` struct (and its previews at the file end) so it takes a bracket `glyph` string instead of an SF Symbol, and drop the shimmer branch:

```swift
/// Shared terminal empty/error layout — a bracket glyph, a title, one mono line.
struct CalmMessage: View {
    let glyph: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text(glyph)
                .font(Theme.Typo.display)
                .foregroundStyle(Theme.Palette.inkSecondary)
            Text(title)
                .font(Theme.Typo.title)
                .foregroundStyle(Theme.Palette.ink)
            Text(message)
                .font(Theme.Typo.body)
                .foregroundStyle(Theme.Palette.inkSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .padding(Theme.Spacing.section)
    }
}

#Preview("Unavailable") {
    UnavailableStateView(reason: .appleIntelligenceNotEnabled)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Palette.surface)
        .preferredColorScheme(.dark)
}

#Preview("Failed") {
    FailedStateView(error: .noUsableCards, onRetry: {})
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Palette.surface)
        .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Update `UnavailableStateView` to pass a glyph**

Replace the `UnavailableStateView` body and its `symbol` computed property so it calls `CalmMessage(glyph:title:message:)` (drop `showsShimmer` and `symbol`):

```swift
struct UnavailableStateView: View {
    let reason: GenerationError.UnavailableReason

    var body: some View {
        CalmMessage(glyph: glyph, title: title, message: message)
    }

    private var glyph: String {
        switch reason {
        case .modelNotReady: "[...]"
        default: "[x]"
        }
    }

    // `title` and `message` computed properties are unchanged.
```

(Keep the existing `title` and `message` switches verbatim. You may lowercase the copy if desired, but it is not required.)

- [ ] **Step 3: Update `FailedStateView` to pass a glyph**

In `FailedStateView.body`, change the `CalmMessage(...)` call to:

```swift
            CalmMessage(glyph: "[x]", title: title, message: message)
```

(`CalmButton("Try again", ...)` and the `title`/`message` switches stay as-is.)

- [ ] **Step 4: Replace `GeneratingView.swift`**

```swift
import SwiftUI
import RecallKit

/// Streaming UI: terminal placeholder rows replaced, one at a time, by real
/// cards rising into place. The deck title fades in once it arrives.
struct GeneratingView: View {
    let title: String?
    let cards: [Flashcard]
    let skeletonCount: Int
    let onStop: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var slotCount: Int { max(skeletonCount, cards.count) }

    var body: some View {
        VStack(spacing: Theme.Spacing.section) {
            titleHeader

            ScrollView {
                LazyVStack(spacing: Theme.Spacing.interCard) {
                    ForEach(0..<slotCount, id: \.self) { index in
                        slot(at: index)
                    }
                }
                .padding(.bottom, Theme.Spacing.section)
                .animation(reduceMotion ? nil : Motion.gentle, value: cards.count)
            }
            .scrollIndicators(.hidden)

            CalmButton("stop", style: .quiet, action: onStop)
        }
    }

    @ViewBuilder
    private var titleHeader: some View {
        if let title {
            Text("> \(title)")
                .font(Theme.Typo.title)
                .foregroundStyle(Theme.Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity)
                .id(title)
        } else {
            Text("> writing your deck…")
                .font(Theme.Typo.title)
                .foregroundStyle(Theme.Palette.inkSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func slot(at index: Int) -> some View {
        if index < cards.count {
            StreamingCard(card: cards[index])
                .transition(
                    reduceMotion
                        ? .opacity
                        : .move(edge: .bottom).combined(with: .opacity)
                )
        } else {
            ShimmerPlaceholder()
                .frame(height: 72)
        }
    }
}

/// A freshly streamed card — shows the question in a terminal frame.
private struct StreamingCard: View {
    let card: Flashcard

    var body: some View {
        CardSurface {
            Text(card.question)
                .font(Theme.Typo.body.weight(.medium))
                .foregroundStyle(Theme.Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .padding(Theme.Spacing.cardInner)
        }
    }
}

#Preview("Generating") {
    GeneratingView(
        title: "Photosynthesis",
        cards: Array(MockGenerator.sampleCards.prefix(3)),
        skeletonCount: 8,
        onStop: {}
    )
    .padding()
    .background(Theme.Palette.surface)
    .preferredColorScheme(.dark)
}
```

- [ ] **Step 5: Build to verify**

Run: `xcodebuild -project Recall/Recall.xcodeproj -scheme Recall -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add Recall/Recall/Features/Generate/GenerateStateViews.swift Recall/Recall/Features/Generate/GeneratingView.swift
git commit -m "design: terminal generate-state + streaming views"
```

---

### Task 11: Restyle Study, Flashcard, and DeckDetail

**Files:**
- Modify: `Recall/Recall/Features/Study/StudyView.swift`
- Modify: `Recall/Recall/Features/Review/FlashcardView.swift`
- Modify: `Recall/Recall/Features/Review/DeckDetailView.swift`

**Interfaces:**
- Consumes: `StudyViewModel`, `DeckDetailViewModel`, `Flashcard`, `GradeBar`, `CalmButton`, `CardSurface`, `Theme.*`, `Motion.*`.
- Produces: terminal flip card with a `// QUESTION` / `// ANSWER` mono label header; sharp hairline progress bar with `ink` fill; mono session-end (no seal icon). DeckDetail study button label lowercased.

- [ ] **Step 1: In `StudyView.swift`, update the card-face label and progress bar**

In the private `StudyCard.face(text:kind:showing:)` method, replace the label `Text` so it reads as a mono comment and is left-aligned:

```swift
    private func face(text: String, kind: String, showing: Bool) -> some View {
        CardSurface {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("// \(kind.uppercased())")
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Palette.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(text)
                    .font(Theme.Typo.cardFace)
                    .foregroundStyle(Theme.Palette.ink)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .minimumScaleFactor(0.6)
                    .lineLimit(8)
            }
            .padding(Theme.Spacing.cardInner)
            .frame(maxWidth: .infinity, minHeight: 260)
        }
        .opacity(showing ? 1 : 0)
    }
```

In the private `ProgressBar`, change the fill colors and use sharp rectangles:

```swift
private struct ProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Theme.Palette.hairline)
                Rectangle()
                    .fill(Theme.Palette.ink)
                    .frame(width: max(0, min(1, progress)) * geo.size.width)
            }
        }
        .animation(Motion.gentle, value: progress)
        .accessibilityHidden(true)
    }
}
```

In the `header(_:)` close button, swap the SF Symbol for a mono `[x]`:

```swift
                Button {
                    dismiss()
                } label: {
                    Text("[x]")
                        .font(Theme.Typo.body)
                        .foregroundStyle(Theme.Palette.inkSecondary)
                }
                .accessibilityLabel("Close study session")
```

In the "tap to reveal" hint, lowercase the copy: `Text("tap the card to reveal")`.

- [ ] **Step 2: In `StudyView.swift`, replace `SessionEndView`**

```swift
private struct SessionEndView: View {
    let nextDue: Date?
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Spacer()
            Text("[x]")
                .font(Theme.Typo.display)
                .foregroundStyle(Theme.Palette.gradeEasy)
            Text("done for now")
                .font(Theme.Typo.title)
                .foregroundStyle(Theme.Palette.ink)
            if let nextDue {
                Text("next review \(Self.relative(to: nextDue))")
                    .font(Theme.Typo.body)
                    .foregroundStyle(Theme.Palette.inkSecondary)
            } else {
                Text("nicely done.")
                    .font(Theme.Typo.body)
                    .foregroundStyle(Theme.Palette.inkSecondary)
            }
            Spacer()
            CalmButton("done", action: onDone)
        }
    }

    private static func relative(to date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}
```

- [ ] **Step 3: Pin the `StudyView` preview to dark mode**

```swift
#Preview("Study") {
    StudyView(deck: Deck(topic: "Photosynthesis", title: "Photosynthesis", cards: MockGenerator.sampleCards))
        .environment(AppContainer())
        .preferredColorScheme(.dark)
}
```

- [ ] **Step 4: In `FlashcardView.swift`, update `face(text:kind:showing:)` to the mono comment label**

```swift
    private func face(text: String, kind: String, showing: Bool) -> some View {
        CardSurface {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("// \(kind.uppercased())")
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Palette.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(text)
                    .font(Theme.Typo.cardFace)
                    .foregroundStyle(Theme.Palette.ink)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .minimumScaleFactor(0.6)
                    .lineLimit(6)
            }
            .padding(Theme.Spacing.cardInner)
            .frame(maxWidth: .infinity, minHeight: minHeight)
        }
        .opacity(showing ? 1 : 0)
    }
```

Pin its preview to dark mode:

```swift
#Preview("Flashcard") {
    FlashcardView(card: MockGenerator.sampleCards[0])
        .padding()
        .background(Theme.Palette.surface)
        .preferredColorScheme(.dark)
}
```

- [ ] **Step 5: In `DeckDetailView.swift`, lowercase the study-button label and pin the preview**

Change the study button to:

```swift
                    CalmButton("study \(viewModel.dueCount) due") {
                        studying = true
                    }
                    .padding(.bottom, Theme.Spacing.xs)
```

And the preview:

```swift
#Preview("DeckDetail") {
    NavigationStack {
        DeckDetailView(deck: Deck(topic: "Photosynthesis", title: "Photosynthesis", cards: MockGenerator.sampleCards))
    }
    .environment(AppContainer())
    .preferredColorScheme(.dark)
}
```

- [ ] **Step 6: Build to verify**

Run: `xcodebuild -project Recall/Recall.xcodeproj -scheme Recall -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: Commit**

```bash
git add Recall/Recall/Features/Study/StudyView.swift Recall/Recall/Features/Review/FlashcardView.swift Recall/Recall/Features/Review/DeckDetailView.swift
git commit -m "design: terminal flip card, progress bar, and session-end"
```

---

### Task 12: Full verification pass

**Files:** none (verification only).

- [ ] **Step 1: Clean build of the app**

Run: `xcodebuild -project Recall/Recall.xcodeproj -scheme Recall -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 2: Run RecallKit unit tests**

Run: `cd RecallKit && xcodebuild test -scheme RecallKit -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: `** TEST SUCCEEDED **` (scheduler, repository, generation-mapping unaffected by visual changes).

- [ ] **Step 3: Run the UI happy-path test**

Run: `xcodebuild test -project Recall/Recall.xcodeproj -scheme Recall -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:RecallUITests/GenerateFlowUITests`
Expected: `** TEST SUCCEEDED **`. If a selector regressed because button titles were lowercased, update the test's expected strings (e.g. `createDeckButton` is matched by accessibility identifier, which is unchanged — no edit expected).

- [ ] **Step 4: Visual smoke check (manual / via run skill)**

Launch the app in the iPhone 17 Pro simulator and confirm: dark canvas everywhere, monospaced type on every screen, bracketed buttons, hairline deck rows, terminal flip card, colored grade bar. Capture a screenshot of each of the four screens.

- [ ] **Step 5: Commit any test-string fixes (if needed)**

```bash
git add -A
git commit -m "test: align UI assertions with redesigned labels"
```

---

## Self-Review

**Spec coverage:**
- §3 tokens → Task 1. ✓
- §3 shape/shadow removal → Tasks 1–2. ✓
- §4 CardSurface/CalmButton/GradeBar/ShimmerPlaceholder/iconography → Tasks 2,3,5,4 + bracket glyphs throughout 8–11. ✓
- §5 Root nav → Task 7; Decks → Task 8; Generate → Tasks 9–10; Study/Review → Task 11. ✓
- §6 app wiring (dark scheme, tint) → Task 6. ✓
- §8 acceptance (build clean, tests pass, behavior preserved) → Task 12. ✓

**Placeholder scan:** No TBD/TODO; every code step shows full code. ✓

**Type consistency:** `CalmButton`, `GradeBar`, `CardSurface`, `ShimmerPlaceholder`, `CalmMessage(glyph:title:message:)` signatures are consistent across tasks; `Theme.Palette` token names introduced in Task 1 are the exact names referenced in Tasks 2–11 (`surface`, `surfaceRaised`, `ink`, `body`, `inkSecondary`, `ash`, `hairline`, `hairlineStrong`, `accent`, `gradeAgain/Hard/Good/Easy`); `Theme.Typo.buttonLabel` introduced in Task 1 and used in Tasks 3,5,7. ✓

**Note:** `CalmMessage` API changed from `(symbol:title:message:showsShimmer:)` to `(glyph:title:message:)` in Task 10 — both its call sites (`UnavailableStateView`, `FailedStateView`) are updated in the same task. ✓
