# ADR 0023: Pending changes are read from the draft and drawn as badges; a list is never rewritten to match one

- **Status:** Accepted
- **Date:** 2026-10-04
- **Related:** [`../conventions.md`](../conventions.md),
  [`../architecture.md`](../architecture.md),
  [`../features/navigation.md`](../features/navigation.md),
  [`../known_quirks.md`](../known_quirks.md),
  [0019](0019-collaboration-foundations.md),
  [0020](0020-remembering-mutations-instead-of-writing-them.md),
  [0021](0021-applying-a-draft-through-the-live-mutation-path.md),
  [0022](0022-an-editing-session-claims-the-browser-and-one-draft-stays-open.md)

## Context

A draft-based universe remembers a mutation instead of writing it. Slices 2.1 through 2.4 built
that half end to end: the schema, the interception in all twenty mutation controllers, the applier,
the drafts pages, and the editing-session control. What they left is the other half of the promise.

An author who adds a character in a `wikipedia` universe is told their change was remembered, goes
to the draft, applies it, and the character exists. That is a coherent workflow. But between those
two points the universe looks exactly as it did before they started, so the author has **no way to
tell a remembered change from a lost one**. They add a character and look at the Characters list:
it is not there. They rename one and look at the list: the old name is there, with no indication that
something else is pending. The only evidence is a flash that scrolled past and a draft page they have
to go and find. Slice 2.5 is what closes that gap, and it raises four questions the slice text did not
settle.

**1. What is "modify list queries to include draft changes"?** The slice asks for it, and the phrase
reads as a join. There is nothing to join. A remembered **create** names no record at all — ADR 0019
settled that, because the id is the database's to assign when the change is applied — so there is no
row any content query could return. A remembered **delete** has not deleted anything, so its record is
in the list already. A remembered **edit** also names a record that is still there. One of the three
states is about a row that does not exist, and no amount of query work changes that.

**2. What is a pending create, as a thing a view can render?** The obvious answer is a view object
with three fields. But then every list row in the application grows a second rendering path for it,
and a Relation is not three fields — it is two characters with an arrow between them, and an Ownership
is a localized sentence. Re-deriving each model's label outside the model is how the two paths drift.

**3. Does a "pending edit" badge mean the row shows the remembered values?** It is the obvious thing
for the feature to do, and it is the one thing it must not do. The badge says *pending*. If the row
showed the author's unapplied values, the page would be claiming the record holds values it does not
hold, and the claim would be true only until the draft was discarded — at which point the same row
would silently change back with no request from the reader.

**4. What does the sidebar panel cost?** The panel is rendered in the layout, so it is rendered on
every page of the universe. Each row names the record its change is about, and resolving that is a
query — the unbounded-per-row read already recorded as finding 66, widened from one page to all of
them.

## Decision

### The draft is the query; the content query is untouched

`DraftPreview` reads the reader's own open draft and answers three questions: what is waiting, what is
waiting *on this record*, and what new records the draft would have created. Every list calls it
beside the relation its controller already built.

That is the whole of "include draft changes in the list": a second, parallel source for the same page,
not a modified source. A list's own query keeps its own ordering, its own `includes`, and its own soft-
delete scope, because none of those has anything to say about a record that does not exist. In
particular, **a pending row is never sorted into the list**: it is appended after the real rows, in
the order it was remembered. Re-sorting would mean re-deriving each controller's ordering in Ruby,
which is the second list ADR 0021 refused to keep for the applier.

**The state of a stored record is keyed by identity and nothing else.** A `:edit` and a `:deletion` are
read by `[record_type, record_id]`, so a change cannot attach itself to a different record of the same
type, and a change whose record has been soft-deleted is simply never asked about — it is not in any
list. **A deletion wins an edit on the same record**: a row badged "pending edit" above a row badged
"pending deletion" gives one record two answers on one page, and the deletion decides whether the edit
matters.

### A pending record is an unsaved instance of the model

`DraftPreview#creates_for` builds `model.new` and assigns the payload's columns, sliced to
`model.column_names`. That is what makes a pending row render with `record_label` and a live row's
own partial: a Relation is still two characters with an arrow between them, an Event is still its
display label, an Ownership is still its sentence. One rendering path per model, and the pending row
inherits it.

The slice of columns is load-bearing, not defensive. Everything else in a payload is a collection
writer (`character_tag_ids`) or a virtual attribute (`photo_data`, `remove_photo`) — the values the
payload exists for, because they are the ones `record.changes` would have dropped. Assigning them to a
record that will never be saved would build an association the object then throws away; **not**
assigning them is why the same slice makes a payload naming a column that has since been renamed
harmless rather than an exception on every page of the universe.

What a pending row therefore cannot have is a **Details link, an editor, a delete menu, or a
position**: all four need an id. They are not switched off — there is nothing to switch off, because
`shared/_row_actions` fetches `record.id` and `dom_id(record)` and a tree node's `update_url` is built
from the record. The way into a pending change is the drafts page, which is what the sidebar panel and
the **Pending changes** entry both lead to.

In a taxonomy tree the row is **deliberately not `.taxonomy-node`**. `taxonomy_tree_controller` counts
`.taxonomy-node` children to place insert separators and to compute a new sibling's position, so a row
in that list would be draggable, movable past, and renameable by a reader who cannot see it yet. It
renders as `.taxonomy-pending` after the real roots, because a remembered create has no parent to hang
it under — the same accepted limit the drafts page already had for a create's story or scene.
`restoreEmptyState` learned about the new class for the same reason the server suppresses the empty
state when one is present: showing a reader both would be two answers to "is this taxonomy empty?".

### A row is never rewritten to match its badge

A pending **edit** shows the values that are stored today. A pending **deletion** shows the record, its
links, and its menu, because none of that has stopped being true. The badge is the only new thing on
the row.

Two places refuse a pending row outright, for the same reason: it is a record that does not exist and
cannot be the answer to a question about one that does. A **filtered** Scenes list stays filtered —
`SceneFilter` narrows the story's real scenes by section, tag, and date range, and a record with no id
cannot match any of them, so offering a pending row beside "nothing matched these filters" would answer
a question nobody asked. And a remembered **Scene** that names a section is not listed as ungrouped: it
belongs on that section's page once it exists, and listing it in both places would put one future record
in two. It is filtered by its own `section_id`, which the payload carries because it is a column.

An empty list whose only content is a pending create says so by showing the row: a writer who is told
they have no characters while a row with a name sits under the message is reading two answers to one
question.

### The panel is a bounded glance, and it renders at zero

The right sidebar's **Collaboration** group led with a **Pending changes** link (ADR 0021); the panel
now sits above it and says what is waiting. It is a glance rather than a second drafts page: each row
resolves the record its change names, so `DraftPreview::PANEL_LIMIT` caps the list and the remainder is
**counted** rather than dropped. It renders at zero as well as at any count, because the entry beside
it is also how a reader with nothing pending reaches the history — the same argument ADR 0021 made for
the link.

Two HTML facts shaped the markup and are worth recording because they are silent when wrong. The
panel is a sibling `<li>`, not a parent of the shared link partial, because that partial is itself a
list item and **a `<li>` inside a `<li>` is hoisted back out by the HTML parser** — which would quietly
move the entry outside the panel that belongs to it, with no error anywhere. And the pending-change
count sentence moved from `drafts.editing.pending_changes` to `drafts.pending.count`, because the
universe page's button and the sidebar's panel now say the same thing and two keys for one fact is how
a fact goes stale in one place.

## Consequences

### Benefits

- An author can tell a remembered change from a lost one without leaving the page they were working
  on, in every list workspace, and can see the same fact in the sidebar from anywhere in the universe.
- A pending row cannot be acted on, because there is nothing to act on: no id, no URL, no position. The
  affordances that would fail are absent rather than hidden.
- One rendering path per model. Adding a workspace is two lines — a badge beside the tags, a rendered
  partial after the rows — and no model gains a second way of naming itself.
- A `direct` universe and a guest pay nothing and are shown nothing: `DraftPreview#available?` is
  false, and every caller returns empty.

### Costs and constraints

- **Pending rows are appended, not placed.** A remembered create appears after the rows its siblings
  sort before it, which is honest — it is not in that order yet, and the applier decides — but it does
  mean the list is not alphabetical while a draft is open.
- **A pending row carries no tags and no photo.** Those are the values the payload exists for, and they
  are read on the drafts page; a row that tried to render them would be resolving a collection per row
  for a record with no identity.
- **A pending create says nothing about where it would go.** No parent, no story, no scene. This is the
  limit finding 63 and the "contract-dependent footguns" list already recorded for the drafts page,
  widened from one page to the lists; it is unchanged, not new.
- **The panel costs a query per row on every page of the universe.** Bounded at five, but bounded is
  not free: a universe whose pages were previously draft-free now carries one draft lookup per page.
  A shared reader that resolves a draft's records in two queries would remove it, which is the same fix
  finding 66 names for the drafts page.
- **A pending row is in every list it belongs to.** A Scene create shows on the Scenes list and, when
  it names no section, on the Sections page's ungrouped list. Two lists showing one future record is
  correct — they are two views of the same story — but it is two places to look for it.
- **A badge is a claim the reader has to trust**, because the row underneath it is unchanged. That is
  the deliberate trade for "a pending edit shows stored values", and it is why every badge carries a
  `title` saying which state it is.

### Rejected: joining the draft into the list's own query

The literal reading of "modify list queries to include draft changes". It cannot work: a remembered
create has no id, so there is no `LEFT JOIN` that produces it, and a union of stored rows and unsaved
ones is not a relation. Worse, it would put the draft's rows through each controller's ordering,
`includes`, and count — so a pending Character would drag `character_tags` eager loads and a pending
Scene would take a position in a sequence whose boundaries the list computed from real rows.

### Rejected: a view object for a pending create

`PendingCharacter.new(name, description)` rendered by a second row partial. Cheap, and it drifts: a
Relation is two endpoints and an arrow, an Event has a display-label ladder, an Ownership has a
localized sentence. Each of those would be re-derived outside the model, and the list row and the
pending row would disagree about what a Relation is called — which is a visible bug, on a page whose
whole job is to be trustworthy.

### Rejected: showing the remembered values on a pending edit

The feature's obvious reading, and the one that makes the badge a lie. The row would hold values the
record does not hold, and would give them back — silently, on the next request — when the draft was
discarded. A page that says "this is what your universe says, and here is what is pending on top" has
to draw the line somewhere, and the line is between the record's own values and everything else.

### Rejected: an unbounded panel

It would be the drafts page again, and finding 66 says what that costs. The panel is on the layout, so
its cost is every page rather than one.

## Related documentation

- [`../conventions.md`](../conventions.md)
- [`../architecture.md`](../architecture.md)
- [`../features/navigation.md`](../features/navigation.md)
- [`../known_quirks.md`](../known_quirks.md)
- [0019](0019-collaboration-foundations.md)
- [0020](0020-remembering-mutations-instead-of-writing-them.md)
- [0021](0021-applying-a-draft-through-the-live-mutation-path.md)
- [0022](0022-an-editing-session-claims-the-browser-and-one-draft-stays-open.md)