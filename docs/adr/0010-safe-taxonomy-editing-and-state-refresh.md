# ADR 0010: Build taxonomy UI by DOM APIs and refresh server state after mutations

- **Status:** Accepted
- **Date:** 2026-09-25
- **Related:** [`0002`](0002-json-crud-with-stimulus-editors.md), [`../architecture.md`](../architecture.md), [`../universe_maker_conventions.md`](../universe_maker_conventions.md), [`../backlog.md`](../backlog.md)

## Context

The taxonomy editor serialized parent and tag labels into an HTML string and interpolated those
strings into `innerHTML`. Stored names could therefore become DOM elements or event-handler
attributes when another user opened an editor. The same one-time serialized state became stale
after create, rename, delete, and move operations. The tree also depended on hover-only insertion
controls and HTML5 drag/drop, with newly created nodes losing native rename semantics.

## Decision

Keep taxonomy mutations JSON-only, but construct all dynamic fields, options, nodes, labels, and
ARIA values with DOM APIs and text/attribute assignment. User-controlled values are never passed
through `innerHTML`.

After every successful taxonomy mutation, perform a same-URL Turbo visit. The fresh HTML response
is the authority for serialized parent/tag descriptors, hierarchy state, page counts, and cached
sidebar counts. This intentionally trades a small navigation refresh for eliminating a class of
stale-state and XSS bugs; the editor remains within the existing Stimulus/JSON architecture.

Provide pointer-neutral controls in addition to drag/drop:

- native rename buttons that support Enter and Space;
- visible Move up/Move down controls;
- Insert before/Insert after actions and first/last insertion boundaries;
- touch-visible insertion targets and focus restoration.

Readers continue to see the same hierarchy without mutation controls. Section and Location editors
also expose scoped parent selectors so reparenting does not require drag/drop.

## Consequences

### Benefits

- Stored names and descriptions are treated as text throughout the editor.
- Parent/tag options and counts cannot silently remain stale after a successful mutation.
- Keyboard and touch users have an ordering and insertion path independent of drag/drop.
- Browser regressions can assert hostile-name safety, refreshed options/counts, boundary insertion,
  and keyboard/touch controls.

### Costs and constraints

- A successful mutation briefly refreshes the page rather than applying a complex local state
  synchronizer.
- Turbo availability and focus restoration must be tested; fallback navigation remains required.
- Drag/drop and explicit controls must share the same JSON position contract.
- Error responses need a visible status path; this ADR does not turn taxonomy editors into a
  general client-side validation framework.

## Alternatives considered

### Continue sanitizing HTML strings

Rejected because escaping strings is fragile and the project requires user-controlled values to be
constructed as text, not repaired as markup.

### Update every dependent descriptor and count locally

Rejected for the first hardened version because the state graph includes serialized options,
hierarchy nodes, page counts, and cached sidebar counts. A server render is less error-prone and
is the authoritative recovery path.

### Remove drag/drop entirely

Rejected because drag/drop remains useful for pointer users; explicit controls are the accessible
alternative, not a replacement for the existing visual interaction.

## Related documentation

- [`../architecture.md`](../architecture.md)
- [`../universe_maker_conventions.md`](../universe_maker_conventions.md)
- [`../visual_design.md`](../visual_design.md)
- [`../known_quirks.md`](../known_quirks.md)
