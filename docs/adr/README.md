# Architecture Decision Records

This directory records important decisions about Universe Maker's architecture, domain boundaries,
and long-term development workflow. ADRs preserve the reasoning behind the code, especially when
a future contributor might otherwise be tempted to reverse a deliberate choice.

The current architecture and conventions are documented in:

- [`../architecture.md`](../architecture.md) — request lifecycle, auth, access policy
- [`../data_model.md`](../data_model.md) — schema, constraints, validations, slugs, positions
- [`../conventions.md`](../conventions.md) — cross-cutting code patterns and page shapes
- [`../features/`](../features/) — one document per feature, each the single home of that
  feature's rules: [scenes](../features/scenes.md), [tags](../features/tags.md),
  [search](../features/search.md), [navigation](../features/navigation.md),
  [photos](../features/photos.md), [events](../features/events.md), [i18n](../features/i18n.md),
  [settings](../features/settings.md)
- [`../known_quirks.md`](../known_quirks.md) — verified open findings
- [`../visual_design.md`](../visual_design.md) — the visual system and painted treatment

An ADR explains **why** a decision was made; the document that owns the subject explains **what the
current system does**. When the two disagree, the living document is right and the ADR records the
reasoning as of its date.

## Current decisions

| ADR | Status | Decision |
|---|---|---|
| [0001](0001-universe-and-story-scope.md) | Accepted | Keep world-building universe-scoped and scripts story-scoped |
| [0002](0002-json-crud-with-stimulus-editors.md) | Accepted | Use JSON CRUD with Stimulus for taxonomy and modal editors |
| [0003](0003-disposable-schema-and-seed-data.md) | Accepted | Keep migrations schema-only and rebuild demo data from `db/data/` |
| [0004](0004-universe-data-and-demo-seeding.md) | Accepted | Organize disposable data by universe and separate it from production seeds |
| [0005](0005-universe-access-levels.md) | Accepted | Use universe-level public/private access with three membership levels |
| [0006](0006-data-factor-quality-guidance.md) | Accepted | Treat external repository scores as directional signals and prioritize verified quality work |
| [0007](0007-story-owned-scenes-and-elements.md) | Accepted | Add story-owned ordered Scenes, optional Elements, links, and grouping without duplicating universe records |
| [0008](0008-explicit-development-universe-loader.md) | Accepted | Use a registry-driven, environment-guarded loader for disposable development universes |
| [0009](0009-transactional-position-maintenance.md) | Accepted | Maintain hierarchical and flat ordered collections through one transactional service |
| [0010](0010-safe-taxonomy-editing-and-state-refresh.md) | Accepted | Build taxonomy UI safely and refresh server state after mutations |
| [0011](0011-modal-json-mutation-contract.md) | Accepted | Submit the shared modal as JSON, explain rejections in the modal, and refresh from the server |
| [0012](0012-client-side-verification-and-csrf.md) | Accepted | Verify client-side code with Bun tests, Biome, and a real browser CSRF check |
| [0013](0013-platform-settings-and-browser-theme.md) | Accepted | Keep platform settings browser-owned, server-rendered, and out of the universe workspace |
| [0014](0014-global-search-with-meilisearch.md) | Accepted | Answer the top-bar search with Meilisearch, filtered by what the reader may read, and state it when there is no engine |
| [0015](0015-record-photos.md) | Accepted | Give every main record one optional `Photo`, cropped to a square and stored as a 300×300 re-encode |
| [0016](0016-internationalization-and-browser-locale.md) | Accepted | Translate application chrome through I18n keys, and keep the language a browser-owned preference |
| [0017](0017-browser-owned-start-page-and-remembered-destination.md) | Accepted | Remember where the reader was headed across sign-in in the browser rather than the session |
| [0018](0018-session-lifetime-and-user-agent-binding.md) | Accepted | End sessions on a lifetime, and bind them to the user agent rather than the IP |
| [0019](0019-collaboration-foundations.md) | Accepted | Settle the collaboration system's authorization, version-stamp, and page-shape foundations before building it |
| [0020](0020-remembering-mutations-instead-of-writing-them.md) | Accepted | Remember a mutation inside the action that would have written it, and keep each controller's own response flow |
| [0021](0021-applying-a-draft-through-the-live-mutation-path.md) | Accepted | Apply a draft through the live mutation path, and report a change that has moved rather than ask about it |
| [0022](0022-an-editing-session-claims-the-browser-and-one-draft-stays-open.md) | Accepted | Let an editing session claim the browser without gating remembering, and make one open draft a database rule |
| [0023](0023-pending-changes-are-read-from-the-draft-and-drawn-as-badges.md) | Accepted | Read pending changes from the draft and draw them as badges, and never rewrite a list row to match one |
| [0024](0024-an-applies-outcome-is-stored-and-a-closed-draft-stays-inspectable.md) | Accepted | Store an apply's outcome per change and on the draft, and keep a closed draft inspectable |

## Format

Use a numbered Markdown file named `NNNN-short-title.md`, for example:

```text
0004-example-decision.md
```

Each ADR should contain:

1. **Status** — `Proposed`, `Accepted`, or `Superseded by ADR NNNN`
2. **Date** — when the decision was recorded
3. **Context** — the forces or problem that made a decision necessary
4. **Decision** — what was chosen, stated positively and concretely
5. **Consequences** — benefits, costs, and new constraints
6. **Alternatives considered** — meaningful options that were rejected
7. **Related documentation** — links to the relevant project docs

A copyable starting point is in [`0000-template.md`](0000-template.md).

## Workflow

- Create a new ADR for decisions that affect domain ownership, public interfaces, persistence,
  security boundaries, or a workflow that future contributors must preserve.
- Do not edit an accepted ADR merely to make it describe today's implementation. Add a new ADR
  and mark the old one `Superseded` when a decision changes.
- **Never cite a backlog item number.** A number is deleted from [`../backlog.md`](../backlog.md)
  when its item is completed, so a citation to one eventually points at nothing. Cite the reference
  documentation or ADR that holds the delivered behavior, the dated `CHANGELOG.md` entry for the
  delivery (or its long form in [`../delivery_history.md`](../delivery_history.md)), or an open entry
  in [`../known_quirks.md`](../known_quirks.md) — all of which are kept
  after the work is finished. The same applies to a delivery "slice" number: name the stage by what
  it added, not by the number it was called while it was pending.
- Update the relevant files in `docs/` when the implementation changes. An ADR explains why;
  the reference documentation explains what the current system does.
- Keep ADRs short and factual. Record uncertainty and follow-up work rather than inventing
  certainty.
