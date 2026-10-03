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

The right utility sidebar now reserves a stable home for future collaboration, analytics, and AI
tools. Replace its temporary `aria-disabled` links with a real contextual inspector as the
underlying product areas become concrete. The inspector should show information relevant to the
current page: selected entity details, related records, taxonomy usage, filters, or quick actions.
It remains a Bootstrap `offcanvas-end` below `xl` and can be hidden when there is nothing useful
to show. Candidate data includes selected-character relations/ownerships, relation-tag usage
counts, and story outline progress.

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
Collaboration group with the live **Pending changes** entry a draft-based universe needs. Those
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

21. **Collaboration system — Phase 2: Draft system (core data model + interception)**

    In `wikipedia` or `github` mode, mutations are stored as draft changes instead of written directly.
    Users can see their pending changes and apply them. Conflict resolution comes in Phase 3.

    - **Slice 2.1 (delivered 2026-10-03):** `drafts` (`user_id`, `universe_id`, `status` string
      default `"draft"` not null: `draft`/`applied`/`discarded`/`submitted`, timestamps) and
      `draft_changes` (`draft_id`, `record_type`, `record_id` nullable, `action` string:
      `create`/`update`/`delete`, `base_version` string nullable, `created_at`) exist, with `Draft`
      and `DraftChange` and their model tests. Three deviations from the text above, all settled and
      recorded in [ADR 0019](adr/0019-collaboration-foundations.md): the remembered attributes are
      `payload`, because Rails refuses an attribute named `changes` (or `attributes`);
      `base_version` may only be filled through `DraftChange.capture_base_version`, so it is always
      a comparable string; and a change is append-only — `created_at`, no `updated_at`, updates
      raise.
    - **Slice 2.2 (delivered 2026-10-03):** `app/controllers/concerns/draft_mutation.rb` intercepts
      every mutation controller, and in a `wikipedia` or `github` universe the mutation is remembered in
      the request author's open draft instead of written. `remember_draft_create`/`_update`/`_delete` are
      called inside each action and return `false` in a `direct` universe, so the live write below them is
      untouched; all twenty mutation controllers call them, and the twenty also answer a remembered change
      in their own response flow (JSON `202`, or the HTML redirect with `drafts.flash.remembered`). A
      remembered `create` stores the submitted attributes plus the column that places the record in its
      scope. Four decisions the slice text did not settle, all in
      [ADR 0020](adr/0020-remembering-mutations-instead-of-writing-them.md): the interception is a call
      inside the action rather than a callback, because only there does the controller hold both the record
      it would have written and the attributes it was going to write with it; a remembered change is not
      validated when it is remembered, because the applier re-runs the live path where the validations are
      authoritative; each controller keeps its own response flow rather than answering JSON everywhere; and
      a Scene's `move`, its `group`, and a Scene Element's `move` are intercepted too, so no write path is
      left open in a draft-based universe. `Draft.open_for!` is the one place a draft is opened outside a
      test, and `test/controllers/draft_mutation_test.rb` walks all twenty controllers in both modes.
      This slice left draft mode with no page; slice 2.3 below delivered it.
    - **Slice 2.3 (delivered 2026-10-03):** `DraftsController#index` (lists current user's drafts for the
      universe), `#show` (shows one draft with all its changes), `#apply` (applies all non-conflicting
      changes; conflict resolution comes in Phase 3), and `#discard` (discards a draft), with a draft list
      page and a draft detail page, `resources :drafts, only: %i[index show]` plus two member POSTs, and
      request, service, and system tests. Three decisions the slice text did not settle, all in
      [ADR 0021](adr/0021-applying-a-draft-through-the-live-mutation-path.md): an applier must write through
      the live mutation path, so it derives a model's ordering from its own columns rather than keeping a
      second list of the fifteen controllers that declare theirs — `test/services/draft_applier_test.rb`
      holds that derivation against every routed controller in both directions; a change whose record has
      moved, whose record is gone, or that the live path refuses is **reported** rather than asked about,
      because refusing the whole apply would strand a draft that can neither be applied nor closed; and the
      draft becomes `applied` either way, because a remembered create names no record and applying a
      partly-written draft twice would write a second copy of it. The whole run is one transaction with the
      status change inside it, so an unexpected failure leaves the draft exactly as it was. A conflict is
      therefore reported rather than resolved until Phase 3: the author sees how many changes were written
      and how many were not, and the rest stay readable on the draft's page. A draft is read as its own
      author's inside the authorized universe — no guest can reach the page at all — and the right sidebar
      carries a **Pending changes** entry wherever a draft can exist, because a page nothing links to
      leaves the trap slice 2.2 closed only in the code.
    - **Slice 2.4 (delivered 2026-10-03):** `DraftEditingController` is a `POST`/`DELETE` singleton
      `/u/:universe_slug/editing` behind a **Start editing** / **Stop editing** control on the universe
      page, rendered only where it is enforced — a draft-based universe, a signed-in reader, `write`
      access — and the page states the pending count as a link into the drafts list. Four decisions the
      slice text did not settle, all in
      [ADR 0022](adr/0022-an-editing-session-claims-the-browser-and-one-draft-stays-open.md): the control
      **claims the session rather than gating remembering**, because a reader who forgot to press it must
      not write straight through a universe whose mode exists to stop exactly that, and the interception
      from 2.2 stays unconditional — entering a session opens the draft *before* the first change instead;
      the flag is a session value keyed by universe (`DraftEditingSession`), dropped by
      `clear_session_context` at every session boundary, so a sign-out releases the claim but keeps the
      draft; **stopping is not discarding**, and the flash says how much is still waiting; and the two
      review questions the slice raised are both answered against the count — the sidebar's **Pending
      changes** entry stays rendered wherever a draft can exist, because it is also how the history is
      reached, while "create a draft if one doesn't exist" is now enforced by a **partial unique index**
      over the open statuses (closing finding 65 in [`known_quirks.md`](known_quirks.md)) with
      `Draft.open_for!` re-reading the winner's row on a lost race. Tests: request, model, CSRF, and
      system coverage of the control, the flag's boundaries, and the "remembered without the toggle" case.
    - **Slice 2.5:** When in draft mode, show pending changes as a panel/sidebar. For draft-created
      records: show them in the list with a "draft" badge. For draft-edited records: show current
      values with a "pending edit" badge. For draft-deleted records: show the record with a "pending
      deletion" badge. Modify list queries to include draft changes for the current user. Tests:
      request tests, system test.

22. **Collaboration system — Phase 3: Conflict resolution**

    When applying a draft, detect conflicts and let the user choose "theirs" or "mine" per conflicting
    record. Conflict detection is per-record (not per-field). Uses `updated_at` as a version stamp:
    when a draft change is created, store the record's `updated_at`; at apply time, a mismatch means
    someone else modified the record.

    Three questions this phase has to settle before the slices below, all recorded while slice 2.3 was
    delivered and all consequences of what it had to choose (ADR 0021): whether a change's **outcome** is
    stored on the row or only returned by the applier — nothing records it today, so a draft's page
    cannot say which of its changes were written (finding 64 in
    [`known_quirks.md`](known_quirks.md)); where an author's **unapplied** values live, because today they
    are a `payload` on a closed draft that nothing reads back into an editor, so a reported conflict has
    to be retyped (finding 63); and whether a **delete answered "mine"** is a restore-then-edit or an
    update-in-place, since the record is soft-deleted and `PositionedResourceOrder` normalized its
    siblings when it went.

    - **Slice 3.1:** Create `app/services/draft_conflict_detector.rb`. The rule itself already
       exists as `DraftApplier`'s skip decision; this slice promotes it to a detector that reports each
       conflict with its change and the record's current state, which is what the resolution page shows.
       For each draft change:
      **Create** → no conflict possible. **Update** → if record's `updated_at` != `base_version` →
      CONFLICT; if record is soft-deleted → CONFLICT. **Delete** → if record's `updated_at` !=
      `base_version` → CONFLICT; if record is already soft-deleted → no conflict (already gone).
      Tests: unit tests for all conflict scenarios.
    - **Slice 3.2:** Conflict resolution UI. When applying a draft with conflicts, show a conflict
      resolution page. For each conflict: show the record name and type, what the current user wants
      to do, what "theirs" means, two buttons: "Apply theirs" (discard my change for this record) and
      "Apply mine" (overwrite with my change). For "apply mine" on a delete conflict: restore the
      record and apply the edit. For "apply mine" on an edit conflict: overwrite the current values
      with the draft values. Tests: request tests, system test.
    - **Slice 3.3:** Extend `app/services/draft_applier.rb`, which slice 2.3 delivered with the
      non-conflicting half already done — it writes a draft's changes through the live mutation path,
      reports what it could not write, and closes the draft inside one transaction. This slice adds the
      user's choice for a conflicting change: "theirs" discards it, "mine" applies it over the current
      values, and a delete conflict answered "mine" restores the record first. The returned summary
      includes which changes were answered and how. Tests: unit tests, integration tests.

23. **Collaboration system — Phase 4: Wikipedia mode (end-to-end)**

    The full wikipedia flow works: start editing → make changes → apply → changes are live.

    - **Slice 4.1:** Ensure all mutation controllers properly intercept in `wikipedia` mode. Ensure
      the apply flow works end-to-end. Ensure conflict resolution works in `wikipedia` mode. Update
      the UI to guide the user through the flow. Tests: full request + system test coverage.
    - **Slice 4.2:** Flash messages for successful apply. Empty state for no pending changes. Draft
      history (list of applied drafts). Update docs. Update changelog.

24. **Collaboration system — Phase 5: GitHub mode (review workflow)**

    In `github` mode, drafts are submitted for review. Owner+admins review and apply or reject.

    - **Slice 5.1:** Create `review_requests` table (`draft_id`, `universe_id`, `submitted_by_id`,
      `status` string: `pending`/`approved`/`rejected`, `reviewed_by_id`, `review_notes` text,
      timestamps). `ReviewRequest` model (belongs_to :draft, :universe, :submitted_by, :reviewed_by).
      When a draft is submitted, create a review request and change the draft status to `submitted`.
      Tests: model tests.
    - **Slice 5.2:** `ReviewRequestsController#index` (lists pending review requests, owner+admin
      only), `#show` (shows a review request with the draft's changes), `#approve` (applies the
      draft's changes with conflict resolution if needed), `#reject` (rejects with notes, changes
      draft status back to `draft`). Routes: `resources :review_requests, only: [:index, :show,
      approve, reject]`. Tests: request tests, system test.
    - **Slice 5.3:** In `github` mode, the "Apply changes" button becomes "Submit for review". The
      user can add a submission message. The draft status changes to `submitted`. The draft owner can
      see the status of their submission. Tests: request tests, system test.
    - **Slice 5.4:** A "Review requests" link in the right sidebar (owner+admin only). The review
      page shows the draft's changes, the submitter's message. Approve button (with conflict
      resolution if needed). Reject button with a notes field. Tests: request tests, system test.
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

These items are deliberately **LATER** by default. Use the owner's **NOW / LATER / NEVER** decision
before expanding a feature task; the DataFactor report is directional evidence, not an automatic
work order.

## FUTURE WORK
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
