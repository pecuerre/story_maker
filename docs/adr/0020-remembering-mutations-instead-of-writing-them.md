# ADR 0020: Remember a mutation inside the action that would have written it

- **Status:** Accepted
- **Date:** 2026-10-03
- **Related:** [`../conventions.md`](../conventions.md),
  [`../architecture.md`](../architecture.md),
  [`../data_model.md`](../data_model.md),
  [`../features/scenes.md`](../features/scenes.md),
  [0019](0019-collaboration-foundations.md),
  [0011](0011-modal-json-mutation-contract.md),
  [0009](0009-transactional-position-maintenance.md)

The ADR 0019 rule this one implements: **`DraftMutation` is the only code that decides whether a
mutation is written or remembered**, and no controller compares the collaboration mode itself.

## Context

The draft system stores a change for its author to apply instead of writing it. [ADR
0019](0019-collaboration-foundations.md) settled the data model, the version stamp, and the rule that an
applier must re-run the live mutation path rather than write records directly. What it left open is the
other end: the request path has to decide, twenty times over, whether a mutation is written or remembered.

Twenty controllers already existed, and they are not uniform. Fifteen answer JSON from a modal;
Relations, Ownerships, and Scenes answer an HTML redirect. Some build the record through an association
(`@story.sections.new`), some through a scope (`Current.universe.characters.new`), and three Scene
presence links resolve a Character, Item, or Location through the universe before saving — so what they
write is not what was submitted. Some are ordered by `PositionedResourceOrder`, which computes a position
at save time. Three of them have a second and third write path beyond `create`/`update`/`destroy`: a
Scene's narrative `move`, its Section `group`, and a Scene Element's `move`.

Three questions had to be answered before any of this could be written, and each of them has a way of
going wrong that does not raise.

**1. Where does the request path find out what a mutation would write?** A `before_action` is the obvious
place — one filter, twenty controllers, nothing to forget. But a filter runs before the action builds its
record, so it would have to rebuild the record from the request to describe the change. That means
answering "what would this action write?" twice, once for real and once for the draft, and the two answers
drift apart the first time a controller assigns something the filter cannot see — which is exactly what
the three presence links do.

**2. What goes in the payload?** The obvious source is the record's own state: for a `create`, the unsaved
record the controller just built. That is complete for columns and useless for everything else.
`record.attributes` does not carry a tag id list (a HABTM association is not a column), and it cannot carry
the photo at all: `HasPhoto` keeps `photo_data` and `remove_photo` in instance variables and never marks
them dirty, so `record.changes` is empty for a photo-only edit. Using either would silently drop the
author's change. And copying *all* of the record's attributes is worse than dropping: a `position` that has
not been assigned and a `slug` that has not been generated would be remembered as values to write, and the
live path would then be told to save `nil` into a `NOT NULL` column.

**3. What does the caller get back?** The collaboration plan said "return JSON". Fifteen controllers would
have been right. Three — Relations, Ownerships, Scenes — render HTML forms through Turbo, and a JSON body
in a browser is a page of raw text.

## Decision

### The interception is a call inside the action, not a callback

`DraftMutation` exposes `remember_draft_create`, `remember_draft_update`, and `remember_draft_delete`. Each
returns `false` and does nothing in a `direct` universe, and `true` once it has remembered a change and
rendered the response, so every action is written as a guard:

```ruby
def create
  attributes = character_params
  @character = Current.universe.characters.new(attributes)
  return if remember_draft_create(@character, attributes)

  respond_to do |format|
    # ... the existing direct write, untouched ...
  end
end
```

This is the cost of the decision stated plainly: **a controller can forget the call, and a controller that
forgets it writes straight through in a draft-based universe.** Nothing about the framework prevents it,
and no callback can be reached from inside an action after the write has been composed.

That is accepted, and paid for with a test rather than a mechanism.
`test/controllers/draft_mutation_test.rb` walks all twenty mutation controllers in both modes and asserts
the one thing that differs — in `direct` a mutation writes, in a draft-based universe it does not — so a
forgotten call fails the suite naming the controller. A filter that could not be skipped would be a better
guarantee only if it could be written at all, and it cannot: describing a `create` needs the record the
action builds.

### The payload is the submitted attributes, plus the one column that places the record

A `create` remembers the permitted attributes exactly as submitted, merged with the single scope column the
controller answered through the association it built the record with (`universe_id`, `story_id`, or
`scene_id`, chosen the way `UniverseScopeResolver` walks). An `update` remembers the submitted attributes;
a `delete` remembers nothing.

The presence links pass the record instead: they have already assigned the resolved foreign key, and their
editors use a blank counterpart to mean "keep what is stored", which is not a value that can be remembered
as submitted. `record.changes` after the assignment is exactly what the live path would have written.

Nothing else is copied out of the record. A column the author never submitted is the live path's to decide,
and remembering it would be remembering a decision.

### Each controller answers in its own flow

`202 Accepted` with `{ draft: true, draft_id:, change: { … } }` for the JSON workspaces, and the
documented HTML redirect with `drafts.flash.remembered` for the redirect ones. The HTML flow cannot name a
record that was never written, so it uses `redirect_back_or_to`: the author's own last page, falling back
to the universe, with the verb's status preserved.

### Every write path is intercepted, including the ones beyond create/update/destroy

A Scene's `move`, its Section `group`, and a Scene Element's `move` are updates like any other, and a
draft-based universe with one write-through hole in it is not a draft-based universe. They remember the
`position` or the `section_id` they asked for. `group` resolves its Section *before* remembering, so a
grouping into another story's Section is still a 404.

### The change is not validated when it is remembered

A remembered change is the author's statement of intent. [ADR 0019](0019-collaboration-foundations.md)
settled that applying it re-runs the live mutation path, where the model's own validations are
authoritative; validating here as well would produce two answers to one question about one record, and the
author would be shown whichever ran first. A create the live path would refuse is therefore remembered and
reported as remembered, and the refusal arrives when it is applied.

`DraftChange`'s own validations are the exception, and they raise: a change the application cannot
describe is a defect in the controller, not something the author typed.

## Consequences

### Benefits

- The payload is complete. A tag assignment, a photo crop, and the story a section belongs to are all in
  it, because all three come from the one place that knows all three.
- A controller's write path is unchanged, line for line, below the guard. There is no second code path to
  keep in step with the first, and no service extraction yet — the intended cost of an applier that re-runs
  the live path has not been paid, which is right while there is no applier.
- Every write path in a draft-based universe is remembered, so switching a universe's mode has one meaning.
- The response a caller receives is the response its editor already handles. The modal treats any `2xx` as
  "saved, refresh", so nothing in the browser changes shape mid-phase.

### Costs and constraints

- **The interception can be forgotten.** This is the load-bearing cost of the whole design, and the test
  table is the only guard. A new mutation controller must be added to that table, and the table is a
  literal list of twenty controllers for exactly this reason.
- **A remembered position is a position, not a move.** "Move up" is remembered as the position one step
  above where the scene was when the author pressed the button. Applied later, against a sequence that has
  moved on, `PositionedResourceOrder` clamps it — which is the honest answer (the sequence is contiguous
  and someone else's change is in it), but it is not the same outcome the live move would have had.
- **A remembered create's scope is trusted from the payload at apply time.** `DraftChange` validates the
  universe of a record it *names*, and a create names none, so the `story_id`/`scene_id` in a create
  payload is checked when the change is applied rather than when it is remembered. It is written by a
  controller that already resolved the scope through the authorized universe, so it is not a request value;
  the applier still has to resolve it rather than trust it.
- **Draft mode currently has no interface.** Remembering works end to end and a draft's changes are stored,
  but nothing lists them, applies them, or shows an author that a change is pending. Switching a universe to
  `wikipedia` or `github` today therefore collects changes that cannot be seen. That is the next slices'
  work, and it is why an admin changing the mode is a decision with a visible cost.
- **Two concurrent requests can open two drafts** for one author, because there is no unique index on
  `[user_id, universe_id]` (ADR 0019). The consequence is two drafts rather than a refused write.

### Rejected: a `before_action` that intercepts every mutation

It cannot describe a `create`. The filter would run before the action builds the record, so it would either
duplicate each controller's attribute extraction — twenty copies of the answer that must agree with the
twenty originals — or be handed the record through a new callback each controller has to implement
anyway, which is the same explicit cooperation wearing a callback's clothes.

### Rejected: remembering the record's own attributes

Complete for columns, silent about everything else. A tag assignment and a photo crop would both vanish,
neither would raise, and the author would find out at apply time that their change had been forgotten. It is
the failure mode this project's docs are most careful about: a wrong duplicate is worse than a missing
fact, and a silently truncated payload is worse than a rejected one.

### Rejected: copying every column the request did not submit

It would make a remembered `create` self-contained at the cost of remembering values nobody chose: a nil
`position` where the ordering service would have computed one, a nil `slug` where `HasSlug` would have
generated one, and a `deleted_at` of nil that says nothing. The applier would then have to know which of
those it may believe.

### Rejected: one JSON response for every intercepted mutation

Fifteen controllers would have been right and three would have been broken in the browser. Relations,
Ownerships, and Scenes are submitted by plain HTML forms through Turbo, and the documented response table
is a deliberate boundary rather than an accident to work around. The cost of keeping each flow is that a
draft response has two shapes, and the tests say so explicitly.

### Rejected: intercepting only `create`, `update`, and `destroy`

That was the plan's list, and it left three write paths — a Scene's narrative `move`, its Section `group`,
and a Scene Element's `move` — writing straight through in a mode whose whole promise is that nothing is
written until the author applies it. A universe that remembers a rename and quietly reorders a scene is
worse than one that does neither, because the author is told their changes are pending.

## Related documentation

- [`../conventions.md`](../conventions.md)
- [`../architecture.md`](../architecture.md)
- [`../data_model.md`](../data_model.md)
- [0019](0019-collaboration-foundations.md)
- [0011](0011-modal-json-mutation-contract.md)
