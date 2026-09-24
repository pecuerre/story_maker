# Architecture Decision Records

This directory records important decisions about Universe Maker's architecture, domain boundaries,
and long-term development workflow. ADRs preserve the reasoning behind the code, especially when
a future contributor might otherwise be tempted to reverse a deliberate choice.

The current architecture and conventions are documented in:

- [`../architecture.md`](../architecture.md)
- [`../data_model.md`](../data_model.md)
- [`../universe_maker_conventions.md`](../universe_maker_conventions.md)
- [`../known_quirks.md`](../known_quirks.md)

## Current decisions

| ADR | Status | Decision |
|---|---|---|
| [0001](0001-universe-and-story-scope.md) | Accepted | Keep world-building universe-scoped and scripts story-scoped |
| [0002](0002-json-crud-with-stimulus-editors.md) | Accepted | Use JSON CRUD with Stimulus for taxonomy and modal editors |
| [0003](0003-disposable-schema-and-seed-data.md) | Accepted | Keep migrations schema-only and rebuild demo data from `db/data/` |
| [0004](0004-universe-data-and-demo-seeding.md) | Accepted | Organize disposable data by universe and separate it from production seeds |

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
- Update the relevant files in `docs/` when the implementation changes. An ADR explains why;
  the reference documentation explains what the current system does.
- Keep ADRs short and factual. Record uncertainty and follow-up work rather than inventing
  certainty.
