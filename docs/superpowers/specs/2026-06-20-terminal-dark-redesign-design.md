# Terminal-Dark Redesign — Design Spec

**Date:** 2026-06-20
**Scope:** Whole-app visual redesign of the etch (etch-app) iOS flash-cards app.
**Source design language:** `docs/DESIGN.md` (OpenCode terminal-native system), inverted to dark mode only.

---

## 1. Goal

Replace the current warm "calm" design system (rounded fonts, sage accent, soft
shadows, large 28px radii, paper-cream surfaces) with the terminal-native system
described in `docs/DESIGN.md`: 100% monospace type, ASCII bracket markers as the
only iconography, hairline-bordered flat surfaces, 4px radius on interactive
elements / 0px everywhere else, and no shadows or gradients.

`docs/DESIGN.md` is authored as a *light* marketing site. This app is the
*in-product* surface and must be **dark mode only**. The core transformation is
therefore: invert the palette, force the dark color scheme app-wide, and apply
the terminal vocabulary to the four feature screens.

## 2. Decisions (locked)

| Decision | Choice | Rationale |
|---|---|---|
| Typeface | **System monospace** (`Font.system(_, design: .monospaced)`, i.e. SF Mono) | Zero bundling, preserves Dynamic Type, ships instantly. Berkeley Mono is paid; SF Mono is the closest free system option. |
| Reach | **Whole app, all screens** | Tokens + shared components + every feature view. |
| Color | **Mono + semantic accents** | White-on-black brand chrome; sanctioned Apple semantic ramp where it carries meaning (Apple Blue primary action, grade ramp). |
| Color wiring | **Code-defined palette** in `Theme.swift` + `.preferredColorScheme(.dark)` at root | Single source of truth matching DESIGN.md tokens; avoids editing ~12 asset-catalog JSON files. |
| Primary button | **Apple-Blue fill, white mono label** | Per the "Apple Blue for primary action" color decision; the doc sanctions the accent ramp for the in-product TUI. |
| Root navigation | **Custom top `primary-nav` strip** replacing the system bottom `TabView` chrome | Faithful to the doc's nav spec (wordmark left, text tabs right). |

## 3. Tokens — the inverted dark palette

`Theme.Palette` is redefined as code-defined `Color(hex:)` values (a small
`Color(hex:)` initializer is added to `Theme.swift`). The light marketing ladder
is inverted:

| Token | Value | Role |
|---|---|---|
| `canvas` | `#000000` | every screen background (pure black) |
| `surfaceCard` | `#1A1A1A` | cards, card-face, inputs, elevated rows |
| `ink` | `#FFFFFF` | headlines, card text, primary labels |
| `body` | `#CCCCCC` | paragraph / body copy |
| `mute` | `#999999` | metadata, captions, resting tab labels |
| `ash` | `#666666` | disabled text, skeleton blocks |
| `hairline` | `rgba(255,255,255,0.12)` | section dividers, borders |
| `hairlineStrong` | `#666666` | tab underline, emphasized rule |
| `accent` | `#0A84FF` | primary action, selection (Apple Blue, dark variant) |
| `gradeAgain` | `#FF453A` | grade: Again (red) |
| `gradeHard` | `#FF9F0A` | grade: Hard (orange) |
| `gradeGood` | `#FFD60A` | grade: Good (yellow) |
| `gradeEasy` | `#30D158` | grade: Easy (green) |

**Backwards-compat aliases:** existing call sites reference `surface`,
`surfaceRaised`, and `inkSecondary`. Keep these as aliases to avoid a churn of
renames: `surface → canvas`, `surfaceRaised → surfaceCard`,
`inkSecondary → mute`. New code may use the new names; old names resolve to the
new palette.

### Typography

All roles use `design: .monospaced`, keeping Dynamic Type text styles (no fixed
point sizes):

| `Theme.Typo` | Style | Weight |
|---|---|---|
| `display` | `.largeTitle` | bold |
| `title` | `.title2` | semibold |
| `cardFace` | `.title` | medium |
| `body` | `.body` | regular |
| `caption` | `.footnote` | regular |

(A monospaced `button`/`mono-strong` weight is `.body`/`.medium` where needed.)

### Shape & elevation

- `Radius.card = 0` (sharp containers), `Radius.button = 4` (the only rounded thing).
- **`Theme.Shadow` is deleted.** Nothing casts a shadow. Depth = the `#1A1A1A`
  elevated surface + hairline borders only.
- `Theme.Spacing` keeps its 8px base ladder; `section` ≈ 32.

### Motion

`Motion` is retained. The flip animation stays (it is a core product
interaction). Spring softness may be tightened slightly toward a snappier
terminal feel, but this is non-essential and motion tokens are not a focus.

## 4. Shared components

- **`CardSurface`** → flat `surfaceCard` (`#1A1A1A`) fill, **1px hairline border,
  0px corners, no shadow**. A terminal-style framed block.
- **`CalmButton`** (same public API) → `.filled` = Apple-Blue fill / white mono
  label, 4px radius; `.quiet` = transparent fill, `mute` text, hairline border.
  Press feedback = subtle opacity change rather than the scale bounce.
- **`GradeBar`** → four bracketed mono buttons `[ again ] [ hard ] [ good ]
  [ easy ]`, each rendered in its grade color (colored text + hairline/colored
  border, transparent fill).
- **`ShimmerPlaceholder`** → terminal placeholder: dim `#1A1A1A` block, hairline
  border, sharp corners, slow opacity pulse (no gradient sweep). Reduce-Motion
  path unchanged in spirit.
- **Iconography** → SF Symbols replaced by ASCII markers ("the brackets are the
  icons"): due badge → `[N due]`; empty/error/done states use `[+]` / `[x]` /
  `[...]` glyphs + mono text instead of `rectangle.stack` / `sparkles` / `leaf` /
  `checkmark.seal` / `hourglass`.

## 5. Screens

- **Root nav (`RootView`)** → replace the system bottom `TabView` with a top
  `primary-nav` strip: `etch` wordmark at left; `decks` / `create` text tabs at
  right (active = `ink` with 2px `hairlineStrong` underline + `aria`/accessibility
  current; resting = `mute`). Each tab hosts its own `NavigationStack` below the
  strip. Selection state held in `RootView`.
- **Decks (`DecksView` / `DeckRow`)** → flat hairline-separated mono rows:
  `[#] Photosynthesis · 12 cards   [3 due]`. No floating cards, no shadow. Empty
  state: mono text + bracket glyph, no SF Symbol. Swipe-to-delete retained.
- **Generate (`GenerateView` / `TopicField` / `GenerateStateViews` /
  `GeneratingView`)** → idle reads like a prompt: a `> what do you want to learn?`
  line, a terminal-framed input (`TopicField`), a blue `[ create deck ]` button.
  Generating = streaming mono rows with terminal placeholders + `[ stop ]`.
  Unavailable/failed states use mono copy + bracket glyphs.
- **Study (`StudyView`) / Review (`DeckDetailView` / `FlashcardView`)** → flip
  card becomes a terminal frame (`surfaceCard`, hairline, sharp corners) with a
  `// QUESTION` / `// ANSWER` mono label header; flip interaction kept. Progress
  bar = thin hairline track with `ink` fill, sharp corners. Grade bar as in §4.
  Session-end uses mono text, no seal icon.

## 6. App wiring

- `etchApp` pins `.preferredColorScheme(.dark)` and keeps `.tint(accent)`.
- Palette is code-defined in `Theme.swift`; existing `Palette.xcassets` colorsets
  become unused (left in place, not deleted, to avoid project-file churn — they
  no longer feed the UI).

## 7. Out of scope (YAGNI)

- Bundling a custom font (Berkeley Mono / JetBrains Mono).
- Light mode or any color-scheme toggle.
- New product features or data/model changes.
- Animations beyond what already exists.
- Marketing-only pieces from `docs/DESIGN.md` (testimonials, charts, footer, FAQ,
  install snippet, hero TUI mockup) — none map to this app.

## 8. Acceptance

- App launches in dark mode only; no light-mode rendering anywhere.
- Every text role renders in a monospaced face.
- No drop shadows, gradients, or non-zero container radii (interactive elements =
  4px only).
- All four screens (Decks, Generate, Study, Review) and shared components reflect
  the terminal vocabulary.
- Existing behavior (generation streaming, flip, spaced-repetition grading,
  swipe-delete, accessibility labels/Reduce-Motion paths) is preserved.
- `etchKit` tests still pass; the app builds clean under Swift 6 strict
  concurrency.
