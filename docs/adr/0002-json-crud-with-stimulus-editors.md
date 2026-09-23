# ADR 0002: Use JSON CRUD with Stimulus for taxonomy and modal editors

- **Status:** Accepted
- **Date:** 2026-09-24
- **Related:** [`../architecture.md`](../architecture.md), [`../universe_maker_conventions.md`](../universe_maker_conventions.md)

## Context

Universe Maker has interactive editors for hierarchical taxonomies and flat lists. These editors
need to update small pieces of a page without a full navigation cycle, while the application
still needs explicit validation errors and predictable controller behavior.

Using full-page HTML forms for every mutation would make tree editing, drag-and-drop reordering,
and modal-based CRUD unnecessarily complex. Introducing a separate front-end framework or API
layer would also be disproportionate for the current Rails and Hotwire application.

## Decision

Use the existing Stimulus controllers and JSON endpoints for the interactive CRUD flows:

- taxonomy tree editors use `taxonomy_tree_controller.js`;
- flat list editors use `modal_form_controller.js` and `format.json` responses;
- tag selectors use the existing Tom Select integration;
- sibling-position updates use the existing positioned-controller conventions.

Tag controllers and the character, location, item, event, and section mutation controllers remain
JSON-only. Universes, stories, relations, and ownerships retain the HTML redirect/re-render flow
where that is the established interaction.

New features should reuse one of the three existing view patterns rather than creating a fourth
parallel CRUD architecture.

## Consequences

### Benefits

- Small mutations do not require a full page reload.
- Tree and modal interactions share one predictable JSON contract.
- The application remains aligned with Rails, Turbo, and Stimulus instead of adding another UI
  framework.
- Validation and error responses can be handled consistently by the existing controllers.

### Costs and constraints

- Controllers and views must agree on JSON status codes, response shapes, and error handling.
- HTML form submissions are intentionally not supported by JSON-only mutation endpoints.
- Client-side behavior requires targeted JavaScript and, where appropriate, browser-level tests.

## Alternatives considered

### Use full-page HTML CRUD everywhere

Rejected because it would complicate drag-and-drop tree editing and modal interactions and would
discard the established Stimulus patterns.

### Introduce a separate SPA/API architecture

Rejected because it would add significant complexity without a demonstrated need. The current
application is already well served by Rails and Hotwire.

## Related documentation

- [`../architecture.md`](../architecture.md)
- [`../universe_maker_conventions.md`](../universe_maker_conventions.md)
- [`../development.md`](../development.md)
