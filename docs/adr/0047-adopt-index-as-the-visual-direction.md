# ADR 0047: Adopt Index as the reference-atlas visual direction

- **Status:** Accepted
- **Date:** 2026-11-14
- **Related:** [`../visual_directions.md`](../visual_directions.md),
  [`../visual_design_brief.md`](../visual_design_brief.md),
  [`../visual_design.md`](../visual_design.md)

## Context

The visual design brief fixed the aim — a dense reference atlas for a solo writer — and the
constraints any direction had to respect, but deliberately chose no palette, type scale, spacing
scale, or shell. The rendered-interface audit then measured the problems a direction had to improve:
peer list rows at 98px and 65px, two solid primary buttons on filtered lists, hierarchy carried by
nested cards and equal-weight outline buttons, and a file input that kept light browser chrome in
the dark theme.

Three directions were developed and compared on the same representative screens with the same
content: Index, Ledger, and Folio. Their palettes, typography, density, component treatments,
contrast checks, font licensing and fallback analysis, screenshots, and tradeoffs are in
[`../visual_directions.md`](../visual_directions.md).

## Decision

- **Adopt Index** as the visual direction for the next prototype and rollout. It is the reference
  atlas taken literally: a warm paper canvas and ink text, system serif titles and prose, the system
  sans stack for UI, an ink-blue primary, flat surfaces with 3–4px corners, and hierarchy from type
  and hairline rules rather than nested boxes.
- **Keep the information architecture.** Index keeps the two workspace rails, the three page
  patterns, the existing routes, authorization, and every workflow. It narrows the rails to 232 and
  204 pixels, raises the content cap to 1,040 pixels, settles list rows at 46 pixels, and keeps one
  solid primary action per page.
- **Use operating-system fonts only.** Display and prose use the Iowan Old Style → Palatino →
  Book Antiqua → Georgia → Times New Roman → generic serif stack; UI uses the system sans stack.
  There is no web-font dependency, `@font-face`, or network request.
- **Prototype before a site-wide rollout.** Apply Index to the representative screens, review real
  screenshots at 1440, 768, and 390 CSS pixels in Light and Dark and in English and Spanish, and
  refine the direction with the owner before translating it into the shared Bootstrap and token
  system in slices.
- **Keep the choice reversible in slices.** The palette, type, density, and component treatments
  are the decision. The acceptance of Index does not approve a new shell, a second component
  framework, decorative motion, or a change to `ability.rb` and `UniverseAuthorization`.

The specific token values are not repeated here; [`../visual_directions.md`](../visual_directions.md)
owns the proposal and its measured contrast. Once the prototype is approved, the values that survive
belong in [`../visual_design.md`](../visual_design.md) and the theme files.

## Consequences

### Benefits

- The workspace gains a denser, type-led hierarchy that matches the brief and directly addresses the
  audit's row heights, competing primaries, and box-heavy sections without a new page pattern.
- The rollout is mostly palette, type, spacing, and component tokens, so it is the least risky of the
  three directions and can be sliced without a navigation rewrite.
- The direction introduces no font, framework, service, or build dependency.
- Ledger's tabular treatment for analytics and Folio's prose measure remain available as later
  borrowings once Index's own components exist.

### Costs and constraints

- The serif stack varies by operating system. Iowan Old Style is Apple-only; Palatino, Book Antiqua,
  Georgia, and Times New Roman substitute elsewhere, changing the apparent size and width. The
  prototype and rollout must check the fallback on the machines the owner actually uses.
- The warm neutral palette must be re-checked against author-chosen tag colours, particularly pale
  tags chosen against the old cool white.
- A 46px row is denser than the old Scene row at 65px, so the phone touch target must be verified and
  the row must not shrink below 40px at narrow widths.
- The narrowed tools rail has to survive Spanish labels such as **Solicitudes de revisión**; wrapping
  is acceptable, truncation is not.
- Index keeps both sidebars, so it does not materially widen the content column at 1440. That width
  gain belongs to Folio's one-rail shell and is not part of this choice.

## Alternatives considered

### Ledger

Rejected as the direction, not as a source of patterns. Its 40px rows and 13.5px base give the most
records per screen, but the monochrome, square, uppercase treatment reads as an administration
console and makes prose editing feel like a form. Its tabular numerals and compact comparison tables
remain the right borrowing for analytics.

### Folio

Rejected because its 54px rows and 30px section gaps are the lowest lookup density, and its one-rail
shell with a tools drawer is the largest structural change. It gives prose the best home, so its
64-character measure and generous Element editing surface remain available as a later borrowing.

### A hybrid of all three now

Rejected. Mixing the directions at the token level would reproduce the current system's competing
blues, shadows, and equal-weight controls and would make the decision impossible to read. Index is
chosen first; a specific pattern from another direction can be adopted later when it has a job to do.

## Related documentation

- [`../visual_directions.md`](../visual_directions.md) — the three proposals, contrast checks, font
  analysis, screenshots, and recommendation.
- [`../visual_design_brief.md`](../visual_design_brief.md) — the aim, users, references, constraints,
  and representative screens.
- [`../visual_design.md`](../visual_design.md) — the current visual system and the conventions the
  prototype translates into.
