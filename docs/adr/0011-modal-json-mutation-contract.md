# ADR 0011: Submit the shared modal as JSON, explain rejections in the modal, and refresh from the server

- **Status:** Accepted
- **Date:** 2026-09-26
- **Related:** [`0002`](0002-json-crud-with-stimulus-editors.md), [`0007`](0007-story-owned-scenes-and-elements.md), [`0010`](0010-safe-taxonomy-editing-and-state-refresh.md), [`../architecture.md`](../architecture.md), [`../universe_maker_conventions.md`](../universe_maker_conventions.md), [`../known_quirks.md`](../known_quirks.md), [`../backlog.md`](../backlog.md)

## Context

The flat-list modal (Characters, Items, Events) rendered an ordinary Turbo form and let
`modal_form_controller.js` only rewrite the action and method. Nothing submitted JSON, so every
browser create or update reached a JSON-only controller as HTML. `respond_to` raised
`ActionController::UnknownFormat` **after** the record had already been saved: the write committed,
the caller received `406 Not Acceptable`, validation errors never reached the form, and a retry
created a duplicate. Deleting a row used a Turbo `button_to` against a `204 No Content` destroy, so
Turbo had no replacement to apply and the row plus its count stayed in the DOM. The browser suite
passed anyway because it asserted the row after a later navigation.

Backlog item 11.5 makes this shared path reliable before slice 11.6 builds Scene Elements and
speakers on it, and slices 11.7–11.9 add three more role-bearing modal workspaces to the same
controller. The response matrix itself does not change: JSON-only endpoints stay JSON-only and the
HTML flow stays the HTML flow.

## Decision

### The modal submits JSON itself

A modal page declares its own mutation contract with
`data-modal-form-response-value="json"|"html"`. In `json` mode the controller intercepts the form's
`submit`, forwards the form's own field names as `application/x-www-form-urlencoded` with
`Accept: application/json` and the CSRF token, and reads the result. The controller method comes
from the form's `_method` field, so create and update share one code path. In `html` mode
(relations, ownerships) nothing is intercepted and the browser's own submission stands. The mode is
declared in every modal view and asserted per page in `test/controllers/modal_json_contract_test.rb`,
so a new page cannot silently drift back to HTML.

Two payload corrections are made on the way: Rails' own hidden plumbing is dropped, and an empty
multi-select sends one explicit blank value so removing the last tag clears the assignment instead
of leaving the stored ids untouched.

### A rejection is explained where the author is looking

A `422` error hash is rendered twice: once in a summary at the top of the modal that takes focus,
and once next to the control that caused it (`aria-invalid` plus `aria-describedby`). An error keyed
on `:base`, and an association-scoped error with no matching field, are summarized only. Because a
model reports an association rejection on the association (`before_event`) while the form field is
the foreign key (`before_event_id`), field lookup accepts both spellings. The modal stays open with
the entered values intact, the submit button is never left disabled, and a request that never
reached the server, a `4xx`/`5xx` that is not a validation failure, and an unreadable response body
are each reported with their own message. Errors are built with DOM APIs and text assignment, like
every other editor here.

### A successful mutation refreshes the page; a delete is a first-class mutation

After any successful create, update, or delete the controller performs a same-URL Turbo visit, so
rows, page counts, and cached sidebar counts come from one fresh server render. Delete is issued by
the same controller (the row menu's `modal-form#destroy` button) because a JSON-only destroy has no
Turbo form to follow; it asks for the mandatory confirmation copy, and a `404` means the record is
already gone, so the list is refreshed rather than the failure being reported. A delete that fails
keeps the row and reports why in the page-level live region. This is the same trade ADR 0010 made for
the taxonomy tree: a small navigation refresh instead of a local state synchronizer.

### A JSON-only endpoint refuses a non-JSON mutation before it writes

`RequiresJsonMutationFormat` gives JSON-only mutation controllers one guard that answers
`406 Not Acceptable` before any write, so a rejected request can never commit behind an error. The
guard is an explicit `before_action` in each controller so the documented callback order is visible
and testable.

## Consequences

### Benefits

- A browser mutation is answered with the response the server actually intended.
- A failed save is visible, explained, and recoverable without retyping the form.
- Removed rows and stale counts cannot survive a mutation.
- The reliability contract lives in one controller, so Elements and presence links inherit it.

### Costs and constraints

- Every successful mutation costs one navigation round trip, accepted deliberately.
- A new JSON-only modal page must declare the mode, render the error region, and mark its submit
  button; the request test fails if it does not.
- The controller owns the delete request for JSON-only rows, so `_row_actions` takes an explicit
  `delete_via:` and the confirmation copy travels in `data-modal-form-confirm` instead of
  `data-turbo-confirm`.
- Client-side behavior still needs browser regressions; a request test cannot see the error UI, the
  pending state, or the refresh.

## Alternatives considered

### Keep the HTML form and accept 406

Rejected because it committed the write and hid the error, which is a data-integrity problem
(deduplicating on retry) as much as a usability one.

### Render rows and update counts locally after the fetch

Rejected for the same reason as ADR 0010: page counts, cached sidebar counts, tag badges, and
selector options all have to agree, and one server render is the authoritative way to get that.

### Move relations and ownerships to JSON as well

Rejected because that would change the documented response matrix for no user-visible gain in this
slice. Declaring the mode per page keeps the choice explicit and reversible.

### Validate everything in the browser

Rejected because the same-Universe, same-Story, and record-level rules are server rules; the browser
reports what the server decided instead of predicting it.

## Related documentation

- [`../architecture.md`](../architecture.md)
- [`../universe_maker_conventions.md`](../universe_maker_conventions.md)
- [`../visual_design.md`](../visual_design.md)
- [`../resolved_quirks.md`](../resolved_quirks.md)
- [`0002-json-crud-with-stimulus-editors.md`](0002-json-crud-with-stimulus-editors.md)
- [`0010-safe-taxonomy-editing-and-state-refresh.md`](0010-safe-taxonomy-editing-and-state-refresh.md)
