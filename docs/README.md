# Universe Maker — Documentation

Everything learned about this project lives in this directory. The root `README.md` is a short
quick start; this directory is the source of truth for project knowledge. Facts were verified
against the code — last full pass: September 2026, after the Bootstrap visual-shell refresh, the
*stories / story-scoped sections* rework, and the *tags are optional everywhere* change.

| File | Contents |
|---|---|
| [vision.md](vision.md) | The idea in plain words: what the tool is for, continuity as the core promise, collaboration & analyzers (the "does this fit the goal?" reference) |
| [visual_design.md](visual_design.md) | Bootstrap theme tokens, application shell, responsive navigation, shared page/list/taxonomy patterns, accessibility and UI decisions |
| [universe_maker_conventions.md](universe_maker_conventions.md) | Code conventions & patterns: models, controllers, routes, views (3 page patterns), helpers, Stimulus controllers, top bar & sidebar navigation, Event/Timeline feature notes |
| [data_model.md](data_model.md) | Database schema: ownership graph, every table, tag taxonomy matrix, hierarchies & positions, per-model validations, the slug system |
| [architecture.md](architecture.md) | Stack, request lifecycle (`Current`, before_action chain), authentication & sessions, routing/URL-generation rules, response-format matrix, Timeline algorithm |
| [development.md](development.md) | Running the app, test suite, lint/security scans, seeding (dark YAML loader + lotr), CI, Kamal deployment, smoke test, "adding a new model" checklist |
| [known_quirks.md](known_quirks.md) | Verified **open** oddities, dead code and tech debt — read before changing shared code |
| [resolved_quirks.md](resolved_quirks.md) | Quirks/tech debt that **used to exist and is fixed now** — what the problem was and how it was solved |
| [schema.txt](schema.txt) | Hand-maintained sketch of the core entities (owner-maintained, not generated) |
| [backlog.md](backlog.md) | Shared pending-work list for the owner and AI assistants, including ideas for the future |
| [adr/](adr/) | Architecture Decision Records: the reasoning behind foundational domain and workflow decisions |
| [smoke_test_stories.sh](smoke_test_stories.sh) | Curl-based end-to-end smoke test (login → stories → sections); moved here from `/tmp/opencode/` so it is tracked |
| `images-to-ai/` | Screenshots/images used when prompting AI assistants |

How to use these docs:

- Changing behavior? Update the matching doc in the same commit — this directory is meant to be
  the single, trackable source of knowledge about the app.
- Meeting the codebase for the first time? Read order:
  [architecture.md](architecture.md) → [data_model.md](data_model.md) →
  [universe_maker_conventions.md](universe_maker_conventions.md) →
  [visual_design.md](visual_design.md) → [known_quirks.md](known_quirks.md).

## Shared backlog

[backlog.md](backlog.md) is the owner's and AI assistants' shared list for pending work and future
ideas. The owner can write rough notes without worrying about formatting. If an AI notices another
worthwhile improvement while working, it should ask whether to do it **now**, **later**, or
**never**. A **later** item is added under `FUTURE WORK`; a **never** item is not added, and extra
work is never silently added to the current task.
