# Events and the Timeline

The Event model is a content model like any other, with three things that make it special, and the
Timeline is the one read that draws it. Schema is in [data_model.md](../data_model.md#content-tables);
the Event list's page shape is in [conventions.md](../conventions.md#views---three-patterns).

## What makes Event special

1. `Event` includes `Hierarchical` (parent/position) **plus** the self-referencing `before_event`,
   `after_event`, and `simultaneous_event` associations. `display_label` walks with a visited list,
   and `cannot_reference_self` checks both object identity and the foreign-key id. Database check
   constraints close the insert-time gap where an id is assigned only during save. Destroying an event
   nullifies every incoming temporal reference; a referrer that existed only to point at that event is
   removed first, so `must_be_identifiable` remains true for retained rows. **The editor never offers
   the event being edited as one of its own three references** — see
   [The editor's own temporal references](#the-editors-own-temporal-references). A label has two forms
   here, and the reason is in
   [i18n.md](i18n.md#a-record-label-that-is-also-a-search-documents-title).
2. Tags are **optional**, as on every content model (`has_many_tags` adds no presence validation).
   Event has a `_tag` taxonomy like the other content models: `EventTag` + `events_event_tags` HABTM +
   `EventTagsController` + labeled Event tags navigation.
3. Identity is title-driven: users enter `title`; `set_name` copies `title` to `name` on create and
   whenever the title changes. It is prepended before `HasSlug`, so the event slug follows the title on
   create and rename.
4. `must_be_identifiable`: an event needs a title, a start/end datetime, **or** a relation to another
   event. Related events must belong to the same universe. There is deliberately **no** name-presence
   rule.
5. `Section` and `Event` both declare `has_many :scenes, dependent: :nullify`, so deleting a Section
   only ungroups and deleting an Event only clears the reference. Neither removes a Scene.

`EventsController` uses the flat list + modal pattern, and includes `MaintainsSiblingPositions` and
`RequiresJsonMutationFormat` like the other positioned, JSON-only controllers.

## The editor's own temporal references

An Event cannot be its own `before_event`, `after_event`, or `simultaneous_event`, and the three
**Happens before / Happens after / Same time as** selects must therefore never offer the record being
edited. `cannot_reference_self` and the three `events_*_event_not_self` check constraints are the
authority and are unchanged; the option list is the browser's half of the same rule, so a reader is
not offered a choice the server will refuse.

**The exclusion is client-side because it cannot be anything else.** One modal form serves every row of
the Events list, so a single server render cannot know which row is about to be edited, and
`@events_for_select` is every universe event. The server sends the whole list; the modal controller
removes exactly the one option that belongs to the row being opened, and puts it back before the next
row opens.

- A select opts in on the control itself with `data-modal-form-exclude-self`, and the row's identity
  travels on its trigger as `data-modal-form-record-id` (added by `shared/_row_actions`).
  `modal_form_controller.js` does the rest — see
  [conventions.md](../conventions.md#views---three-patterns) for the shared mechanism.
- Exactly one `<option>` is detached, and it is re-inserted in the place the server rendered it. **The
  option list is never rebuilt.** Removing and re-appending a `<select>`'s children loses which option
  the select holds, which silently gave the create form a temporal reference it would then have
  submitted; `test/system/modal_json_flow_test.rb` pins the empty selection that prevents it.
- The create trigger carries no record id, so it offers every event: a record with no id cannot be its
  own reference. Row-to-row restoration is pinned by `test/javascript/modal_form_controller_test.js`
  for each option, and end to end by a browser case that dismisses one row's editor and opens the
  next row's: one modal form really does serve every row on the page, and the second editor's
  **Happens before** select has to hold the first row's option back.

## The Timeline algorithm

The Timeline is the **second tab of the Event workspace**, not a page of its own. It renders the same
`shared/_content_tabs` strip as the Events list, built by the same
`content_workspace_tabs(:event)`, so each tab is the active one on its own page and the strip is the
way between them. That is why the left sidebar has one **Events** link rather than two: the Timeline
route is unchanged and remains canonical, it is simply reached through the strip. The Timeline's own
sentence is a `shared/_content_intro` below the strip, like every other workspace's.

`TimelineController` (`get "timeline", to: "timeline#index"`) hands the universe's events to
**`TimelineLayout`** (`app/models/timeline_layout.rb`) with **`UnionFind`**
(`app/models/union_find.rb`):

1. Events marked as simultaneous (`simultaneous_event`) are grouped with union-find.
2. Between groups a directed "happens no later than" DAG is built, trying in order of confidence: full
   non-overlapping start/end ranges → start dates alone → end dates alone → explicit
   `before_event`/`after_event`. Edges that would create a cycle are skipped.
3. Longest-path layering assigns rows: no known predecessor → top row; otherwise at least one row below
   all predecessors.
4. The view renders `@layers`/`@edges`; `timeline_controller.js` redraws the edges between nodes on
   resize, and the node popovers carry content from `TimelineHelper#event_popover_content` (dates,
   tags, relations, description).

**The three date passes are pairwise, and the cycle test is not run per pair.** The reachability walk
that refuses an edge only has anything to refuse when the dates contradict something: on a timeline
whose events each stand alone (no simultaneity grouping) and whose intervals are well-formed, a date
edge can never close a cycle, so `TimelineLayout#dates_speak_first?` establishes that once and the
walks are skipped. A timeline that groups simultaneous events, or that carries an interval ending
before it starts (nothing validates that yet), walks every candidate edge exactly as before. The one
date-pass candidate that can still close a cycle is two zero-length events at the same instant, which
is checked separately rather than by skipping the whole pass.

**`@layers` is the only source of the rendered order, and `@edges` is read back off it** rather than
off the raw associations. That is the whole point: a `before_event`/`after_event` the graph refused —
because it contradicted a stronger signal, or because accepting it would have closed a cycle — is
**not** drawn. It is never drawn reversed "to match" the rows, because an arrow running the wrong way
across rows that say the opposite is worse than no arrow, and reversing would invent a relation the
author never declared. A relation named from both sides yields one arrow, not two. So the drawn edges
can never contradict the rows they span.

A Scene may reference one Event, and several Scenes may reference the same Event; the reference and
the Scene's own in-world `datetime` are independent and neither writes or clears the other.

## Timeline interaction

- A node is a `<button>`, not a focusable `<div>`. It renders the record's id as its text, which a
  screen reader would otherwise announce as a bare number, so it carries an `aria-label` built from the
  same `event_popover_title` the popover header uses. The popover trigger is `hover focus click`,
  because a touch pointer never hovers.
- The view is **static**: there is no pan, zoom, or transform. A Timeline is a layered view, not a map.
- A timeline node keeps the color stored on the record, because that is author data rather than a
  theme token. See [visual_design.md](../visual_design.md).
