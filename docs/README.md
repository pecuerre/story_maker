# Universe Maker — Documentation

Everything learned about this project lives in this directory. The root `README.md` is a short
quick start; this directory is the source of truth for project knowledge. Facts were verified
against the code — last full pass: September 2026, after the Bootstrap visual-shell refresh, the
*stories / story-scoped sections* rework, the *tags are optional everywhere* change, the
per-universe development-data convention, and the public/private universe access policy.

| File | Contents |
|---|---|
| [vision.md](vision.md) | The idea in plain words: what the tool is for, continuity as the core promise, collaboration & analyzers (the "does this fit the goal?" reference) |
| [../CHANGELOG.md](../CHANGELOG.md) | Date-based history of application, site, data, security, documentation, and tooling changes |
| [visual_design.md](visual_design.md) | Bootstrap theme tokens, light/dark, typography, spacing, application shell, responsive behavior, accessibility, and the painted treatment of the shared view patterns |
| [conventions.md](conventions.md) | The cross-cutting code conventions: models, controllers, routes, the three page patterns, list rows, record details pages, helpers, Stimulus controllers |
| [data_model.md](data_model.md) | Database schema: ownership graph, every table, tag taxonomy matrix, hierarchies & positions, soft delete, per-model validations, the slug system |
| [architecture.md](architecture.md) | Stack, request lifecycle (`Current`, before_action chain), authentication & sessions, routing/URL-generation rules, response-format matrix, production boundary, caching |
| [features/](features/) | One document per feature, each the single home of that feature's rules: [scenes](features/scenes.md), [plots](features/plots.md), [story structures](features/story_structures.md), [story interchange](features/story_interchange.md), [universe backup](features/universe_backup.md), [tropes](features/tropes.md), [routes](features/routes.md), [canon](features/canon.md), [map](features/map.md), [tags](features/tags.md), [search](features/search.md), [navigation](features/navigation.md), [photos](features/photos.md), [events](features/events.md), [characters](features/characters.md), [factions](features/factions.md), [locations](features/locations.md), [items](features/items.md), [export](features/exports.md), [mentions](features/mentions.md), [appearances](features/appearances.md), [i18n](features/i18n.md), [settings](features/settings.md), [list filters](features/list_filters.md) |
| [development.md](development.md) | Clarifying a request before coding, running the app, Minitest and client-side test suites, lint/security scans, per-universe development data (`db/data/<universe_slug>/`), CI, Kamal deployment, smoke test, and the full "adding a new model" workflow |
| [data_factor_guidance.md](data_factor_guidance.md) | DataFactor report snapshot, verified/current status, sustainable maintenance guidance, and acceptance criteria for quality, security, CI, onboarding, and observability work |
| [known_quirks.md](known_quirks.md) | Verified **open** oddities, dead code and tech debt — read before changing shared code |
| [delivery_history.md](delivery_history.md) | **Historical record**: the dated project history and the quirks/tech debt that **used to exist and is fixed now** — what each change was, why it was made that way, and how a resolved problem was solved |
| [backlog.md](backlog.md) | Shared pending-work list for the owner and AI assistants, including ideas for the future |
| [adr/](adr/) | Architecture Decision Records: the reasoning behind foundational domain and workflow decisions |
| [smoke_test_stories.sh](smoke_test_stories.sh) | Curl-based end-to-end smoke test (login → stories → sections); moved here from `/tmp/opencode/` so it is tracked |

How to use these docs:

- This directory is a **lookup index, not a book**. It is far too long to read end to end, and
  nobody does. Find the document that owns your subject and read that one:

  | Subject | Owner |
  |---|---|
  | Request lifecycle, auth/sessions, access policy, test-env behavior | [architecture.md](architecture.md) |
  | Schema, columns, constraints, validations, slugs, positions, soft delete | [data_model.md](data_model.md) |
  | Code patterns, page patterns, list rows, details pages, helpers | [conventions.md](conventions.md) |
  | Colors, tokens, theme, shell, responsive behavior, accessibility | [visual_design.md](visual_design.md) |
   | Scenes, Elements, participation, the Scene filter | [features/scenes.md](features/scenes.md) |
    | Story-owned Plot arcs and Scene assignments | [features/plots.md](features/plots.md) |
    | Starting a Story from a code-owned Section/Scene shape | [features/story_structures.md](features/story_structures.md) |
    | The interchange layout, canon ledger, references, and validator | [features/story_interchange.md](features/story_interchange.md) |
    | The admin-only Universe backup archive and its deferred data | [features/universe_backup.md](features/universe_backup.md) |
     | Global trope references and contextual assignments | [features/tropes.md](features/tropes.md) |
    | Universe-scoped Routes between Locations | [features/routes.md](features/routes.md) |
     | Universe canon rules with an optional Story owner | [features/canon.md](features/canon.md) |
   | Map view of Locations and Routes | [features/map.md](features/map.md) |
  | The tag DSL, taxonomies, the tree and its editor | [features/tags.md](features/tags.md) |
  | Global search and its dropdown | [features/search.md](features/search.md) |
  | The navbar and both workspace sidebars | [features/navigation.md](features/navigation.md) |
  | Record photos and the cropper | [features/photos.md](features/photos.md) |
   | Events and the Timeline algorithm | [features/events.md](features/events.md) |
   | Universe-scoped Faction profiles and tags | [features/factions.md](features/factions.md) |
   | Character profiles, Faction membership, and knowledge changes | [features/characters.md](features/characters.md) |
   | Prose mentions, suggestions, and in-place name highlighting | [features/mentions.md](features/mentions.md) |
   | The Story-wide appearance grid and its two layers | [features/appearances.md](features/appearances.md) |
   | Location profile answers, presence, search, and the Locations workspace | [features/locations.md](features/locations.md) |
   | Item profiles, ownership, search, and the Items workspace | [features/items.md](features/items.md) |
   | Reading a Story as a printable book, and the export scopes | [features/exports.md](features/exports.md) |
   | Translations and writing a translatable string | [features/i18n.md](features/i18n.md) |
  | The platform Settings page and its two preferences | [features/settings.md](features/settings.md) |
  | The contract every in-list filter shares | [features/list_filters.md](features/list_filters.md) |
  | Setup, commands, tests, CI, demo data, deployment | [development.md](development.md) |
  | Verified open oddities and tech debt | [known_quirks.md](known_quirks.md) |
  | Foundational decisions and their reasoning | [adr/](adr/) |
  | Quality/operations work derived from the DataFactor report | [data_factor_guidance.md](data_factor_guidance.md) |

  The same mapping is in the root [`AGENTS.md`](../AGENTS.md), which is the version an assistant
  reads first.
- **One fact, one home.** A fact is stated once, in the document that owns its subject; every other
  document links to it rather than restating it. This is enforced: `test/docs_test.rb` fails the
  suite when a section heading is owned by two documents, when a relative link is dead, or when a
  cross-document anchor no longer exists.
- **A wrong duplicate is worse than a missing fact.** A confident, well-written, wrong paragraph
  gets acted on, whereas an absent fact sends the reader to the code. When a document and the code
  disagree, the code wins and the document is fixed in the same change.
- Historical records are deliberately exempt and never rewritten: an ADR states what was decided
  at the time, and [delivery_history.md](delivery_history.md) states what was delivered and what used
  to be broken. Both may disagree with the code now, because their value is the reasoning.
- Changing behavior? Update the document that owns the subject, in the same change.
- After every code, site, data, test, documentation, configuration, security, or tooling change,
  add or update a dated entry in [`../CHANGELOG.md`](../CHANGELOG.md) using the actual work date.
  That entry is the short form — one or two sentences naming the subject, never a paragraph, and
  over 60 words fails `test/docs_test.rb`. When a change has
  reasoning worth keeping that no live document owns, the long form goes to
  [delivery_history.md](delivery_history.md) in the same change.

## Shared backlog

[backlog.md](backlog.md) is the owner's and AI assistants' shared list for pending work and future
ideas. The owner can write rough notes without worrying about formatting. If an AI notices another
worthwhile improvement while working, it should ask whether to do it **now**, **later**, or
**never**. A **later** item is added under `FUTURE WORK`; a **never** item is not added, and extra
work is never silently added to the current task.

The backlog is a pending-work list only. When an item is finished, add its dated
[`../CHANGELOG.md`](../CHANGELOG.md) entry and then delete the item — the same discipline
[known_quirks.md](known_quirks.md) uses when a finding is fixed. Finished items are not kept here as
"completed" prose, and the remaining numbers are never renumbered or reused.
