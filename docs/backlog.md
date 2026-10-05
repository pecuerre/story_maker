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
analytics, and AI tools. Replace the remaining temporary `aria-disabled` links with a real contextual
inspector as the underlying product areas become concrete. The inspector should show information
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

Add client- or server-backed search/filter/sort controls to Characters, Locations, Events, Items,
Relations, Ownerships, and taxonomy trees. Preserve universe/story scope, make filters removable
and visible in the URL where practical, and define behavior for empty results separately from an
empty database. Start with the fields already exposed by each model. The story-owned Scenes list
already has this shape (text, Section group, Scene Tag, inclusive in-world date range, canonical
query in the URL); reuse its `SceneFilter` conventions here instead of inventing a second filter
pattern, and reuse `Search::Scope` for the boundary rather than re-deciding what "this universe"
means.

**A filter also has to say what happens to a pending row.** In a universe that remembers changes, a
list appends the records the reader's own draft would create and badges the ones it would edit or
delete ([ADR 0023](adr/0023-pending-changes-are-read-from-the-draft-and-drawn-as-badges.md)). A pending
row has no id, so it cannot satisfy a filter on any column the author did not submit, and the Scenes
list already answers this by staying filtered. Decide deliberately per workspace: hide pending rows
when a filter is active (what Scenes does), keep them and show a count, or match them on the values
the payload carries. The third is the only one that can ever put a pending row in a result set, and it
is the one that needs the filter to read a payload rather than a record.

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
memberships are available from the universe workspace. The right sidebar still reserves temporary
links for Collaborators, Conflicts, Branches, Forks, Analytics, and AI tools, and it now leads its
Collaboration group with the reader's own **pending-changes panel** and the **Pending changes** entry
beneath it, which is what a draft-based universe needs. Those
remaining placeholders stay future product areas. Before replacing them with navigation, specify the
underlying records and permissions: inconsistency detection, incomplete/undefined records, submissions,
changes/forks, graphs, analytics, and drafts. A feature should appear as a live navigation item when
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

24. **Collaboration system — Phase 5: GitHub mode (review workflow)**

    In `github` mode, drafts are submitted for review. Owner+admins review and apply or reject.

    - **Slice 5.4:** A "Review requests" link in the right sidebar (owner+admin only). The queue and
      the submission's page, its approve button (with conflict resolution) and its reject button with
      a notes field were delivered in 5.2; what is left is the sidebar entry, so the queue has a way in
      from the workspace. Tests: request tests, system test.
    - **Slice 5.5:** Full flow: start editing → make changes → submit for review → owner reviews →
      approve/reject. In-app notifications: when a review request is submitted, when it's
      approved/rejected. Update docs. Update changelog.

25. **Collaboration system — Phase 6: Polish + notifications**

    The collaboration system feels complete and polished.

    - **Slice 6.1:** In-app notifications. Create `notifications` table (`user_id`, `type`, `read`,
      `payload` JSON, `created_at`). Notify when: your draft is approved, your draft is rejected,
      someone submits a review request, someone replies to your discussion. Notification bell in the
      navbar. Tests: model tests, request tests.
    - **Slice 6.2:** Real-time updates via Solid Cable. Broadcast when a draft is applied (so other
      users see the changes), when a discussion message is posted, when a review request is
      submitted/approved/rejected. Tests: system tests.
    - **Slice 6.3:** Write an ADR for the collaboration system architecture. Update all relevant docs.
      Update changelog.

    **Deliberately deferred:** per-field conflict detection (per-record only for now); real-time
    collaborative editing (async with explicit apply, not Google Docs style); markdown in discussions
    (plain text first); email notifications (in-app first, email later); draft branching/forking (a
    draft is a linear set of changes); draft merging (one draft at a time per user per universe).

26. **What a pending badge has to say beyond its state**

    A list row carrying a remembered edit says **Pending edit** and nothing else. That is accurate — the
    row is the stored record, and the change is not in it — and thin: a record with three remembered edits
    on three different fields carries one badge, and a reader cannot tell which fields their draft would
    write, in what order, or whether two of the three changes touch the same attribute. The values are
    available (each change's `payload`), and finding 68 shows what is missing is not the data but a rule
    for how much of it a row may read. Decide what the badge carries: the fields a remembered edit touched,
    a count of the changes on that record, or the draft's own page as the only place any of it is said. The
    last is the status quo and costs nothing; the first costs a per-row payload read, which is the trade in
    finding 66, and the second is a number without a subject. This is the fifth question the conflict
    phase raised; its resolution page asks per record and never reaches a list row, so the phase
    delivered without settling it and the decision stands here: it should be made once, not once per
    surface.

27. **What a pending record shows outside the list workspaces**

    The pending badges live in the nine list workspaces and nowhere else. Three places a reader would
    reasonably look carry no sign of pending work: a **record's own details page** (read-only by design, so
    the question is whether a badge belongs there at all or whether "Details" is deliberately a clean
    record of what is stored), the **global search dropdown** (which indexes stored documents, so a
    remembered create cannot appear in it), and a **tag's list of the records carrying it**
    (`shared/_tagged_record_list`, which renders stored rows only). Separately, a pending row itself shows
    **no tags and no photo** even though the payload carries both, because resolving them costs a query per
    row — finding 69 has the verified behaviour. Decide, per surface: badge it, leave it clean, or resolve
    the values. Start from the details page: it is the one a reader reaches from a pending row's name, and
    today that link is absent for a create because there is nothing yet to link to.

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
