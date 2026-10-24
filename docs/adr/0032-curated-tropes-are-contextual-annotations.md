# ADR 0032: Curate shared trope references and annotate their context

- **Status:** Accepted
- **Date:** 2026-10-24
- **Related:** [Universe and Story scope](0001-universe-and-story-scope.md), [Tropes](../features/tropes.md), [Data model](../data_model.md)

## Context

Scene Tags are owned by a Story. They cannot express a reference library shared across all Stories
and Universes, and reusing them would make a trope definition Story-local. A trope's effect also
depends on its use: a global good/bad value would erase the context writers need to evaluate it.
Descriptions from an external trope site additionally require careful attribution and license
handling.

## Decision

- Keep a small, curated, app-wide reference list in `TropeCatalog`, maintained in code. The initial
  list is a ten-entry proof of concept, not a complete trope database.
- Store original short descriptions and craft notes, plus a link and attribution to each source page.
  Do not scrape or copy source prose without confirming the applicable license requirements.
- Allow authors to annotate a reference independently on a Story and on individual Scenes. Each
  assignment may carry a free-text context note; neither level implies the other.
- Leave automated detection to a future decision. Saved assignments are manual, author-reviewed
  annotations.

## Consequences

- The stable catalogue slug is stored by the two assignment tables; there is no editable global
  `Trope` content model or external-import workflow.
- The same trope can be described as effective in one context and problematic in another without
  changing its shared entry.
- Story CRUD uses the existing draft-aware HTML mutation flow, so Story-level annotations are not
  written directly in a draft-based Universe.
- New entries require code and translations, but the initial sample stays small and can be revised
  before a larger catalogue is considered.
- Story and Scene soft deletion retain their annotations for restoration; hard deletion removes them.

## Alternatives considered

- Reuse `SceneTag`: rejected because Scene Tags belong to one Story and already express author-defined
  local labels.
- Give each trope a universal good/bad classification: rejected because use is context-dependent.
- Import or scrape full source descriptions: deferred until license and attribution requirements are
  explicitly confirmed.
- Add AI trope detection: deferred; this delivery proves the manually reviewed annotation workflow.
