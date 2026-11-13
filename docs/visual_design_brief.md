# Visual Design Brief

This is the agreed starting point for the visual design initiative recorded in
[backlog.md](backlog.md). It states who the workspace is for, the character to aim for, what
"modern" means here, the reference products worth borrowing from, the constraints any direction
must respect, and the screens a direction is judged on. It is not a design system, not approval of
specific changes, and not a competitor audit.

The brief exists so the rendered-interface audit, the directions exploration, and the prototype all
start from the same target instead of re-litigating it. The conventions the application follows
today stay in [visual_design.md](visual_design.md); this document owns the aim those conventions are
measured against until a direction is chosen.

## Who the workspace is for

The **solo writer** keeping one universe consistent is the primary user, and density is tuned for
that person at a desktop width. Collaboration and public reading are real and must keep working — a
universe can be public or private, and members read, write, or administer it — but they do not set
the density target.

Three consequences follow:

- **One memory is the bottleneck.** The same person records facts and writes prose, so moving
  between a record's facts and the prose that uses them has to be cheap. A screen that makes one
  fact easy to read but pushes its neighbours off-screen costs the writer a navigation.
- **The workspace is read before it is written.** The design assumption is that most visits are
  looking something up — where a character has been, who owns an item, which scenes a location
  appears in — rather than creating a record. The rendered-interface audit and the later participant
  work are what can confirm it. The reference layer is the default surface, with the editing controls
  close behind.
- **Access state is part of the reference.** A guest, a read-only member, and an admin see the same
  facts with different controls. Compact layouts must keep it obvious what is being shown and
  whether it can be changed; density must never hide permissions.

## The character to aim for

The target is a **reference atlas**: a workspace that reads like a well-made reference work about
the universe, with a writing surface inside it.

- **Facts and their links lead.** A record page answers "what is recorded about this?" before
  "what can I do with it?". Related records are an index, not a gallery.
- **Density is a feature.** More records, facts, and relations per screen; whitespace groups
  content instead of surrounding every element.
- **Type, alignment, and rules carry hierarchy.** A container earns its border. Headings are not
  boxes, and a section is not a card merely because it is a section.
- **Chrome stays quiet and scoped.** The universe/story context is always explicit, navigation
  recedes, and the sidebar keeps its scope hues.
- **One primary action per page still holds.** Secondary actions compress into row and toolbar
  controls rather than expanding into equal-weight buttons.
- **Prose remains first-class.** Element editing must stay comfortable: density is not a wall of
  small text, and a Scene's prose keeps a readable measure.

The character is dense but still calm. What it is not: a dashboard of metric tiles, a card gallery,
a marketing page, or a minimal writing app that hides the world-building behind menus.

## What modern means here

Modern means **density and restraint**, not surface effects:

- more information per screen at desktop widths, with compact but consistent row and metadata
  shapes;
- fewer nested borders, reduced shadow, and flatter surfaces;
- hierarchy from type weight, size, and alignment rather than from boxes;
- immediate feedback instead of decorative motion, and any motion respects `prefers-reduced-motion`;
- keyboard and touch parity as a built-in property, not a later addition;
- light and dark designed together, with tokens for both.

Deliberately excluded: glass or blur effects, gradient decoration, oversized page headers, animated
page transitions, a second component framework, and a web-font dependency.

## Reference products and what to borrow

The owner named these products; the qualities below are what is worth borrowing from each, checked
against the competitor survey recorded in [backlog.md](backlog.md) where it covers them.

- **Novelcrafter** — the codex is the workspace rather than a settings area: an entity has its own
  reference page, and the prose links back into it. Borrow the sense that world-building is where
  the app lives, not something reached through an admin menu.
- **Wikipedia** — every entity has a stable page that opens with a compact summary of its key
  facts, then prose, then dense tables and cross-links. Borrow the summary-first record page and the
  discipline of consistent entity names and links.
- **Wikidata** — a statement is a row, and the same rows can be read as a list or compared in a
  table. Borrow one fact shape rendered as both detail rows and comparison tables, instead of a
  different component per view.
- **PlotLens and Novilot** — the survey records evidence-cited findings and timeline or tension
  views. Borrow the rule that a chart or report keeps a table equivalent and cites the passage or
  record it refers to, rather than presenting a verdict.

Borrowing means taking a quality, not a shell. None of these products' navigation, palette, or
component library is imported wholesale.

## Constraints

Any direction must respect all of these:

- **Stack.** Bootstrap 5.3, Bootstrap Icons, Sass, PostCSS, Hotwire/Turbo, and Stimulus with import
  maps. No second component framework or utility-only CSS system
  ([visual_design.md](visual_design.md#design-decision)).
- **Tokens.** Palette, typography, radii, and component defaults live in `_theme.scss`; shell and
  layout values use `--um-*` custom properties. A light-only literal colour is a bug, and every
  component is checked in both themes ([visual_design.md](visual_design.md#theme-tokens)).
- **Colour is meaning.** Danger red is not a category colour, scope hues belong to their sidebar
  blocks, and author-chosen tag colours are data ([visual_design.md](visual_design.md#theme-tokens)).
- **Accessibility.** 4.5:1 text and 3:1 boundary contrast, visible focus, keyboard and touch paths,
  reduced-motion handling, table equivalents for diagrams, and never colour alone for status
  ([visual_design.md](visual_design.md#accessibility-and-interaction)).
- **Widths.** Desktop is the primary reference at 1440 CSS pixels, with tablet and phone retained.
  The right tools panel becomes an offcanvas drawer below `xl`
  ([visual_design.md](visual_design.md#responsive-behavior)).
- **Touch targets.** The current row floor is about 40 CSS pixels, and taxonomy insertion targets
  are at least 44×44. A denser desktop row must not shrink the phone's touch targets; if row height
  is reduced, it is reduced at wide breakpoints only.
- **Translations.** Every string is translatable, and Spanish copy is often longer than English, so
  a compact label or header must survive both languages ([features/i18n.md](features/i18n.md)).
- **Page patterns.** The taxonomy tree, the flat list with a modal, and the plain full-page form
  stay the three patterns, with their shared header, row, empty-state, and details treatments
  ([visual_design.md](visual_design.md#shared-view-patterns)).
- **Loading and fonts.** No web-font dependency today; the system sans stack is intentional. A font
  candidate must justify its loading and fallback before it is adopted.
- **Authorization.** Controls are gated by `ability.rb` and `UniverseAuthorization`; a visual change
  never becomes the place access is decided.

## Representative screens

Every proposed direction is shown on this set, so the comparison is like-for-like. The
rendered-interface audit captures these first; the directions exploration and the prototype reuse
them.

1. The application shell at 1440 CSS pixels: navbar, left sidebar, right tools sidebar, with a
   populated Story selected.
2. The Story overview, empty and populated.
3. A flat list with its filter — Characters — including rows, counts, and the row menu.
4. A taxonomy tree with its inline editor — Tags.
5. A record details page — a Character with a Markdown profile, related content, and the
   universe/story scope visible.
6. Scene details and the Scene editor, including prose and the read-only state.

Each is reviewed at 1440 desktop with tablet (768) and phone (390) spot checks, in light and dark,
in English and Spanish. The 2026-11-12 baseline already captured part of this set once; its
observations and the state of the walkthrough are recorded in
[delivery_history.md](delivery_history.md#2026-11-12), and a direction is compared against the
screens as they render, not against a description of them.

## What this brief does not decide

- Palette values, type scale, spacing scale, radii, and component treatments — the directions
  exploration proposes these and the owner chooses.
- Whether the current two-sidebar shell survives, and how navigation is restructured.
- Any implementation detail, ticket, or rollout order.
- Whether density improves real writing; only the participant and accessibility work can say that.

The open work that follows this brief is listed in [backlog.md](backlog.md) under the visual design
initiative: the rendered-interface audit, the directions exploration, and the prototype.
