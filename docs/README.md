# Universe Maker — Documentation

Everything learned about this project lives in this directory (the root `README.md` is still the
Rails scaffold boilerplate). Facts were verified against the code — last full pass: September
2026, after the *stories / story-scoped sections* rework.

| File | Contents |
|---|---|
| [vision.md](vision.md) | The idea in plain words: what the tool is for, continuity as the core promise, collaboration & analyzers (the "does this fit the goal?" reference) |
| [universe_maker_conventions.md](universe_maker_conventions.md) | Code conventions & patterns: models, controllers, routes, views (3 page patterns), helpers, Stimulus controllers, top bar & sidebar navigation, Event/Timeline feature notes |
| [data_model.md](data_model.md) | Database schema: ownership graph, every table, tag taxonomy matrix, hierarchies & positions, per-model validations, the slug system |
| [architecture.md](architecture.md) | Stack, request lifecycle (`Current`, before_action chain), authentication & sessions, routing/URL-generation rules, response-format matrix, Timeline algorithm |
| [development.md](development.md) | Running the app, test suite, lint/security scans, seeding (dark YAML loader + lotr), CI, Kamal deployment, smoke test, "adding a new model" checklist |
| [known_quirks.md](known_quirks.md) | Verified oddities, dead code and tech debt — read before changing shared code |
| [schema.txt](schema.txt) | Hand-maintained sketch of the core entities (owner-maintained, not generated) |
| [todo.txt](todo.txt) | Owner's backlog/idea notes ("(A)" markers) |
| [smoke_test_stories.sh](smoke_test_stories.sh) | Curl-based end-to-end smoke test (login → stories → sections); moved here from `/tmp/opencode/` so it is tracked |
| `images-to-ai/` | Screenshots/images used when prompting AI assistants |

How to use these docs:

- Changing behavior? Update the matching doc in the same commit — this directory is meant to be
  the single, trackable source of knowledge about the app.
- Meeting the codebase for the first time? Read order:
  [architecture.md](architecture.md) → [data_model.md](data_model.md) →
  [universe_maker_conventions.md](universe_maker_conventions.md) →
  [known_quirks.md](known_quirks.md).
