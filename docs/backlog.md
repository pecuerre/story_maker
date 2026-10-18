# SHARED BACKLOG

This is the one place for **pending** work, rough ideas, and things we may want
to do in the future. The owner can append ideas without worrying about format.

## How finished work leaves this file

This file follows the same discipline as [known_quirks.md](known_quirks.md), where a fixed
finding is no longer an open item. When work is finished it does not stay here as a
"completed" paragraph. In the same change that delivers it:

1. add or update the dated entry in [`../CHANGELOG.md`](../CHANGELOG.md), then
2. delete the item from this file.

The changelog is the durable record of delivered work, so nothing else has to track it
here. Do not archive finished items under a separate heading, and do not leave a
completion summary behind.

## How AI assistants should use this file

When you notice another worthwhile improvement while working on a task, ask
the owner whether to do it NOW, LATER, or NEVER.

- NOW: do the extra work as part of the current task, then update the changelog and
  remove the item.
- LATER: add it under FUTURE WORK below.
- NEVER: do not implement it and do not add it to this file.

Do not silently expand the current task. Keep this file focused on work that is
still pending.

## PENDING WORK

Items are numbered and the numbers are stable: a finished item is deleted without
renumbering, so the remaining numbers are left as they are and a number is never reused or
made to mean a different idea.

Because a number disappears from this file when its item is completed, **do not cite a backlog
number from another document**. Reference a pending idea by its heading text, and cite delivered
work through the matching document in `docs/` or its dated `CHANGELOG.md` entry.

3. **Contextual inspector / right-side utility panel**

The right utility sidebar now holds one live block — the reader's pending-changes panel and the
**Pending changes** entry above it — and reserves the rest of its space for future collaboration,
analytics, and AI tools. The Collaboration group's temporary `aria-disabled` links were removed on
2026-10-05 rather than replaced, and the remaining placeholders are in the Analytics and AI groups.
Replace those with a real contextual inspector as the underlying product areas become concrete. The inspector should show information
relevant to the current page: selected entity details, related records, taxonomy usage, filters, or
quick actions. It remains a Bootstrap `offcanvas-end` below `xl` and can be hidden when there is
nothing useful to show. Two constraints the panel sets: it is the first thing in the Collaboration
group rather than a bare link, so a second live block has to earn its place the same way, and it is
bounded at five rows because it is rendered on every page of the universe. Candidate data includes
selected-character relations/ownerships, relation-tag usage counts, and story outline progress.

4. **Search, filtering, and sorting for large lists**

The top-bar search is now implemented and answers across every model; see
[ADR 0014](adr/0014-global-search-with-meilisearch.md) and the delivered work in
[`../CHANGELOG.md`](../CHANGELOG.md). What is still missing is the *in-list* half: a list a reader
has already landed on should be able to narrow, sort, and show its filters in the URL.

**This ships as five ordered slices**, each finished by adding its dated
[`../CHANGELOG.md`](../CHANGELOG.md) entry and deleting its own paragraph below; the number stays on
the whole deliverable rather than moving to whichever slice is next. Slices 2 to 5 are blocked on the
one before them.

**What already exists, so no slice rebuilds it.** The story-owned Scenes list is the one working
in-list filter, and its rules are owned by [`features/scenes.md`](features/scenes.md) — read that
rather than restating them here. Reuse its shape instead of inventing a second filter pattern, and
reuse `Search::Scope` for the boundary rather than re-deciding what "this universe" means. Start with
the fields already exposed by each model, preserve universe/story scope, make filters removable and
visible in the URL where practical, and define behavior for empty results separately from an empty
database, as Scenes does.

**Decided 2026-10-15: a filtered list stays filtered and shows no pending rows.** A remembered create
has no id, so it cannot satisfy a filter on any column the author did not submit, and offering one
beside a "nothing matched" message answers a question the reader did not ask. This is what Scenes
already does ([ADR 0023](adr/0023-pending-changes-are-read-from-the-draft-and-drawn-as-badges.md)),
and it is settled once for every workspace rather than re-decided seven times. The other two answers
stay rejected: keeping pending rows with a count puts a row outside the filter the reader just applied,
and matching them on payload values is the only one that can put a pending row in a result set, which
needs the filter to read a draft payload rather than a record.

**Slice 1 is delivered.** The shared contract is `ListFilter` (`app/models/list_filter.rb`) and
`FilteredListQuery` (`app/controllers/concerns/filtered_list_query.rb`), with its rules in
[`features/list_filters.md`](features/list_filters.md) and a worked filter over a second model in
`test/models/list_filter_test.rb`. The remaining four slices build on it.

**Slice 2 is delivered.** The Characters list narrows by text and character tag and takes a reader's
order through `CharacterFilter`, which is the first use of `SORTS` and the first list with three
empty states to tell apart. `docs/features/list_filters.md` now owns the sort rules the later slices
reuse. The grouping-tag case came out of it and is the rule to carry forward: the filter validates
against **every** tag of the universe while the editor still offers only the assignable ones, so a
record carrying a grouping tag is still filterable.

**Slice 3 is delivered.** The Items list narrows by text, item tag, and the reader's order, and the
Events list adds an inclusive day range over its start datetime plus the same sort control. Both
lists say what each active filter does, and the Events edit form's temporal-reference pickers are
narrowed by the filter like the rest of the list.

**Slice 4 — Relations and Ownerships.** The hard text filter: both labels fall back to something
composed rather than stored — `Relation` to `"A → B"`, `Ownership` to a *translated* sentence — so the
query has to reach the two endpoint names rather than run a `LIKE` on the record's own `name`, and the
Ownership fallback cannot be matched in SQL in any language at all, which is worth saying out loud
rather than faking. Both controllers also re-render `index` from a rejected create or update, so an
active filter has to survive the re-render along with the error summary beside it.

**Slice 5 — Locations and the taxonomy trees.** Locations and all eight tag taxonomies are the tree
pattern rather than the flat list, so the filter area goes into `shared/_taxonomy_tree` and the pending
rows are `.taxonomy-pending` nodes, not rows. **Sorting is a product decision here, not a query:** the
trees are drag-sortable on `position` and `HierarchyIndex` hard-codes `[position, id]`, so a
reader-chosen sort would show an order the drag control contradicts. Settle whether a tree sorts at all
before writing the query, and settle which count the header badge reads — the eight per-taxonomy views
issue a fresh `.count` while `TagsController` uses `hierarchy.records.length`.

5. **Richer relationship and entity rows**

Make list rows more useful for scanning large universes. Relations should render as a readable
sentence such as `Ariadne — is friend to → Lysander`, with direction and dates as metadata.
Characters could show relation/ownership counts, locations could show parent/child context, events
could show date range and related events, and items could show current/historical owners. Add
these as derived presentation data where possible; avoid duplicating source fields in the UI.

6. **Story overview dashboard**

Turn the current Story overview into a compact working dashboard: story description, section
count, section-tree preview, recently edited sections, quick “Add section” action, and links into
the relevant Universe Bible records. This should remain lightweight until the underlying section
and appearance/usage data are available.

7. **Universe summary cards**

Make the Universes index useful for choosing a workspace. Add story and entity counts, visibility,
recent activity, and a clear “Open universe” action. Consider eager-loading/caching the summary
counts so the index does not issue one count query per universe. Keep the existing authorization
and visibility rules in mind before exposing any summary data.

9. **Story-planning and world-building tools**

Story-owned scene planning is now implemented; see
[ADR 0007](adr/0007-story-owned-scenes-and-elements.md) and the dated entries in
[`../CHANGELOG.md`](../CHANGELOG.md). Revisit the adjacent ideas that decision did not settle — Plot,
Tropes, Routes, Map, Distances, Meetings, POV structure, and turn-level dialogue — only with a
concrete domain decision: define what each record means, which scope owns it, how it appears in the
current page patterns, and whether it is worth adding to the data model. Replace a reserved link
only when the feature has a real destination and useful empty, loading, and error states. The MVP's
own limits stay visible rather than implied away: a Scene's `datetime` and its Event reference are
independent and may contradict each other, free-text roles are annotations the application does not
interpret, and one Dialogue block cannot say which line a speaker said. Continuity *checking* is
still the analyzer's job, and nothing here performs it.

10. **Collaboration and universe analysis**

Universe-level access management is implemented: public/private visibility and read/write/admin
memberships are available from the universe workspace. The right sidebar leads its Collaboration group
with the reader's own **pending-changes panel** and the **Pending changes** entry beneath it, which is
what a draft-based universe needs, and follows them with the admin-only **Review requests** queue. Its
**Collaborators**, **Conflicts**, **Branches**, and **Forks** placeholders were removed on 2026-10-05
rather than replaced; **Collaborators** and the History page beside it are specified in the separate
item **Collaborators and universe change history in the Collaboration sidebar group**. What remains a
future product area is Analytics and AI. Before replacing those with navigation, specify the underlying
records and permissions: analytics and AI tools. A feature should appear as a live navigation item when
it has a useful destination and clear empty/loading/error states.

15. **One-command containerized onboarding (DataFactor follow-up)**

   Add and verify a development-safe `docker compose up` path using a development-specific service
   or command. It must prepare an isolated SQLite database, persist the correct local
   database/storage paths, expose the app, pass `/up`, build CSS assets, and work from a clean
   checkout. The existing Dockerfile is production-oriented and its server entrypoint calls
   `db:prepare`, which now loads production-safe seeds only; do not present that production
   entrypoint as a development data workflow. Document the verified development-specific command
   as an alternative to the `mise`/`bundle`/`bun` setup. Do not run development data in a
   production container, mount real data, or duplicate the existing entrypoint blindly. A
   devcontainer is optional and should follow the same boundary.

28. **A draft-based development universe**

    Every `db/data/<universe_slug>/universes.yml` sets no `collaboration_mode`, so both registered demo
    universes are `direct` and **none of the collaboration workflow is reachable by hand**. The remembering
    path, the drafts pages, the editing-session control, and the pending badges in the lists all have to be
    exercised by switching a universe to Wikipedia in its settings, which is also the only way to see what
    the direct path feels like without. Add a third `db/data/` universe in a draft-based mode, or set one
    of the existing two, with enough records to show a pending create, a pending edit, and a pending delete
    at once, and record the known development login, the scoped URL, and the exact load command. Two
    things to weigh first: a draft-based demo universe makes **every** mutation in it remembered, so the
    ordinary manual verification of the direct path disappears for that universe; and drafts are
    per-author, so the demo only shows pending work for the login that made it — a second author sees
    nothing at all, which is correct and is not what a demo is for. Neither is a reason to skip it, but
    both change what the demo is.

29. **Dropping one change a draft cannot describe**

   A draft holding a remembered change the applier cannot read is refused in words rather than applied,
   and the author's only way out is **Discard**, which throws away the other changes in the draft with it.
   The refusal names the change and leaves it listed, so nothing is hidden — but a draft with one corrupt
   change among nineteen cannot be applied at all, and a draft-based universe is a place where an editor can
   reach that state by accident (a hand-edited `draft_changes` row, a model renamed under the demo data, a
   loader from an older version). The general answer is the per-change control ADR 0021 deferred for
   conflicts: a way to drop one remembered change and apply the rest. Decided on 2026-10-05: not now. It
   belongs with a later collaboration phase rather than as a fix to the refusal, and the refusal itself is
   settled — see the resolved finding in [`delivery_history.md`](delivery_history.md).

30. **An API for external tools, apps, and agents to read and write universes and stories**

   Deliver this as four ordered slices. Each ships on its own, and each is finished by adding its
   dated [`../CHANGELOG.md`](../CHANGELOG.md) entry and deleting its own paragraph here; the number
   stays on the whole deliverable rather than moving to whichever slice is next. Slices 2 to 4 are
   blocked on the one before them.

   **What already exists, so no slice rebuilds it.** The write half is largely delivered:
   characters, locations, items, events, sections, every `*_tags` controller, `scene_elements` —
   which is what a dialogue is — and the four scene-presence links all answer `format.json` for
   create, update, and destroy, refusing a non-JSON mutation with `406` before anything is written
   ([ADR 0011](adr/0011-modal-json-mutation-contract.md)). Authorization is already the right model:
   universe read/write/admin in `Ability` and `UniverseAuthorization`
   ([ADR 0005](adr/0005-universe-access-levels.md)). Limits are already per account, per universe,
   and set by that universe's admins ([ADR 0028](adr/0028-per-universe-mutation-budget.md),
   [ADR 0029](adr/0029-per-endpoint-throttle-groups.md)), so a credential bound to a person inherits
   the intended boundaries rather than needing new machinery.

   **Slice 1 — the credential.** `api_tokens` (`user_id`, `name`, `token_digest`, `last_used_at`,
   `revoked_at`) and `api_token_universes` (`api_token_id`, `universe_id`); the token is shown once
   and only its digest is stored, the same discipline as `password_digest`. A `TokenAuthentication`
   concern beside `Authentication` resolves `Authorization: Bearer …` into `Current.user` and
   `Current.api_token` and narrows the reachable universes to the join table. `Api::BaseController`
   drops `allow_browser versions: :modern` and forgery protection for that surface only, and keeps
   `Ability` and `MutationThrottle` untouched. Prove it with one vertical slice — characters index,
   show, and the three mutations — plus the case where a token issued for one universe is refused on
   another. This slice needs its own ADR: a new credential type and a new request surface are both
   foundational rather than extensions of an existing decision.

   **Slice 2 — the read surface.** Stories, sections, scenes, locations, items, events, relations,
   ownerships, and tags answer `index` and `show` as JSON. Each already answers those two actions as
   HTML against a tested and authorized query, so this is a projection of existing scoping rather
   than new policy. One read is genuinely new: `SceneElementsController` has no read action at all
   today — Elements are read on Scene Details
   ([features/scenes.md](features/scenes.md)) — so the API needs a `scene_id`-scoped index for them.

   **Slice 3 — the write surface for the HTML-only records.** Scenes (create, update, destroy, move,
   group), plus stories, relations, and ownerships. These are the controllers with no `format.json`
   branch, which is the actual reason an agent cannot create a Scene today. Reusing
   `MaintainsSiblingPositions` keeps [ADR 0009](adr/0009-transactional-position-maintenance.md)'s
   transactional positioning and its clamp-past-the-end no-op.

   **Slice 4 — limits and boundaries.** A per-token budget layered inside the universe budget, so
   one agent cannot spend its owner's, reusing `MutationThrottle`'s cache-counter contract with the
   token in the key. A read-side throttle, which does not exist because
   `MutationThrottle::MUTATING_METHODS` deliberately excludes `GET`. And token management — listing
   and revoking — because a credential an operator cannot see or kill is not shippable.

   **Decided 2026-10-14: the credential is bound to a User and an explicit set of universes**, not
   to universes with no user behind them, so notifications, drafts, and the collaborators history all
   keep an author.

   **To settle when slice 1 starts: whether the surface is `namespace :api` with parallel `Api::*`
   controllers or token auth allowed through to the existing ones.** The recommendation is `Api::*`.
   The existing controllers carry HTML-only setup an API has no use for — `set_section_paths`,
   `set_event_options`, `remember_start_page`, the remembered-story session state — so sharing them
   means either running that setup on every call or branching the callback chain, with the
   `allow_browser` and CSRF bypass living inside the browser controllers. The cost is similar
   controller code; policy, validation, and the position services stay single-sourced either way.

   **Decided with slice 1's contract: a mutation in a draft-based universe answers `202` with the
   remembered change instead of writing.** That is correct for an agent but is not a failure, and
   must not be treated as one. Both registered demo universes are `direct`, so it is invisible
   locally and only appears in production.

   An OpenAPI document and an MCP server are **out of scope** unless the owner asks for them: both
   are clients of this API rather than part of it.

These items are deliberately **LATER** by default. Use the owner's **NOW / LATER / NEVER** decision
before expanding a feature task; the DataFactor report is directional evidence, not an automatic
work order.

## FUTURE WORK
- **One accepted ADR still points at something this change moved.** [ADR
  0023](adr/0023-pending-changes-are-read-from-the-draft-and-drawn-as-badges.md) cites finding
  63, which left [`known_quirks.md`](known_quirks.md) when the conflict page removed the cost of
  retyping an unapplied change. The decision stands and only the pointer is stale, so the fix is one
  clause on its "pending create says nothing about where it would go" bullet — not a rewrite of the
  body. ADR 0021's half of the same note was done on 2026-10-04 when the stored outcomes landed: its
  Status line now says which costs
  [ADR 0024](adr/0024-an-applies-outcome-is-stored-and-a-closed-draft-stays-inspectable.md)
  superseded and which of its reasoning still holds. Deferred by owner decision on 2026-10-04.
- **change universes to subdomains**. replace the /u/universe_slug for universe_slug.<website>.com
- **Structured dialogue turns.** Replace or augment free-text Dialogue elements with ordered lines,
  speaker changes, parentheticals, and optional character attribution once the MVP reveals real usage.
- **Scene point-of-view/focus Character.** Record whose perspective presents a Scene separately from
  all Characters present, supporting same-Event/different-POV analysis without duplicating Event data.
- **Composite Scene-to-Event links.** If a Scene often contains several Events, introduce a scoped
  join model with roles/order rather than overloading the first version's optional single Event.
- **Narrative-order versus chronology comparison.** Visualize a Story's Scene sequence beside the
  Universe Timeline to expose flashbacks, parallel scenes, and unexplained order changes.
- **Structured Scene roles.** Analyze recurring free-text Character/Item/Location annotations before
  promoting useful values to controlled, analyzer-friendly role types.
- **Scene character-presence analyzer.** Use explicit participants and derived speakers to answer
  where a Character appears, with Story context and confidence/inference labels kept separate from
  author-entered facts.
- **Scene character-knowledge analyzer.** Track what a Character witnesses or is told in a Scene;
  this needs explicit attribution rules and should not be inferred from mere presence.
- **Scene causality and temporal analyzer.** Compare Scene order, linked Events, independent
  Scene datetimes, and Element chronology to explain likely contradictions rather than silently
  rewriting author data.
- **Scene prose-contradiction analyzer.** Analyze Element text for claims that conflict with Universe
  facts; this is a separate product from structured temporal/causal checks and should explain its
  evidence and uncertainty.
- **Timeline pan/zoom.** `architecture.md` and the conventions described a pan/zoom interaction for
  `timeline_controller.js` from the feature's first commit, but it was never implemented — the
  controller only draws edges between nodes. The docs were corrected on 2026-09-29 to describe the
  Timeline as the static layered view it is; this item is the actual feature, deferred by decision.
  Building it is a UI design question, not a defect fix: a draggable/zoomable viewport changes how
  the layer markers and node circles read, needs a keyboard and touch path to be usable at all, and
  the SVG edges must stay aligned under the transform. Worth doing only if a universe's event count
  makes the current wrapped layout genuinely hard to read.

## other ideas
- export in book format
- export in script format
