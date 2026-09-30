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
links for Tracking, Analyzer, richer Collaboration, Graphs, Analytics, and AI tools. Those remain
future product areas. Before replacing the placeholders with navigation, specify the underlying
records and permissions: inconsistency detection, incomplete/undefined records, submissions,
changes/forks, graphs, analytics, and drafts. A feature should appear as a live navigation item when
it has a useful destination and clear empty/loading/error states.

14. **Coverage measurement and CI gate (DataFactor follow-up)**

   Measure the current Minitest baseline with a real coverage tool (SimpleCov is a reasonable
   starting point), start collection before Rails loads, and decide whether the report's suggested
   80% threshold is appropriate for this codebase. Add the threshold only after measuring, upload
   the HTML report from CI, and add tests for meaningful uncovered behavior rather than padding
   assertions. Keep generated coverage out of Git and document the local command, exclusions, and
   the limits of the smoke system suite.

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

16. **Structured logging and runtime observability (DataFactor follow-up)**

   Preserve the existing `/up` health route and add a regression test. Evaluate structured request
   logging, request IDs, and optional error tracking with explicit redaction for password-reset
   tokens, cookies, credentials, DSNs, and personal data. Initialize an external tracker only when
   an environment variable is supplied. Define authentication, cardinality, retention, and privacy
   rules before adding metrics; do not add a public endpoint or dependency merely because a report
   names one. This work must coordinate with the logging, transport, and mailer findings in
   `known_quirks.md`.

17. **Development credential and environment hygiene (DataFactor follow-up)**

   Replace hardcoded local/demo passwords in the LOTR development users, Dark user data, and smoke script
   with an explicit environment variable or a generated local-only value. Make missing values fail
   clearly. Preserve or update the documented synthetic development login and exact load/verification
   instructions in the same change. Add a value-free `.env.example` only with an intentional
   `.gitignore` exception and document variable names/purposes without values. Never commit real
   `.env` files. This item is separate from the critical tracked `.kamal/secrets` rotation/removal
   work already recorded in `known_quirks.md`.

18. **Complete dependency, JavaScript, and container supply-chain checks (DataFactor follow-up)**

   Preserve the committed `bun.lock` and frozen installs. Add a supported Bun/npm audit path,
   verify the provenance and version consistency of locally vendored JavaScript, and add appropriate
   npm/Bun and Docker Dependabot ecosystems. Consider a clean production-image build/boot smoke
   check and Kamal configuration validation. Do not add a deploy job or typecheck job without an
   approved deployment contract or a real static-type toolchain; avoid unpinned or ceremonial CI
   steps. Coordinate with the existing known findings about vendored assets, image size, and
   reproducibility.

19. **Reduce shared editor/helper duplication (DataFactor follow-up)**

   Characterize the serialized field and JSON contracts used by `modal_fields.rb` and
   `tags_helper.rb` before changing them. Then extract declarative/shared helpers only where they
   remove real drift risk, with focused model/request/browser regressions. Preserve the existing
   three UI patterns, JSON-only mutation contracts, optional tags, authorization, and accessible
   error states. Do not refactor solely to improve a line-count metric.

20. **Collaboration system — Phase 1: Foundation (collaboration mode + discussions)**

    Universes gain a collaboration mode setting, and every record gains a discussion page. No draft
    functionality yet. Decisions: discussions are configurable per model via a `HasDiscussion` concern
    (initially all content models + tags); SceneElement/SceneCharacter etc. have discussions inside
    their Scene page, not as a separate user concern for now.

    - **Slice 1.1:** Add `collaboration_mode` column to `universes` (string, default `"direct"`, not
      null; values: `direct`, `wikipedia`, `github`). Add `Universe#direct?`, `#wikipedia?`,
      `#github?`, `#draft_based?` helpers. Add a setting on the universe settings page (owner/admin
      only) to change the mode. Update docs + changelog. Tests: model validation, request test.
    - **Slice 1.2:** Create `discussions` table (`record_type`, `record_id`, `universe_id`, `title`,
      timestamps) and `discussion_messages` table (`discussion_id`, `user_id`, `body`, timestamps).
      `Discussion` model (polymorphic belongs_to :record, belongs_to :universe, has_many :messages),
      `DiscussionMessage` model (belongs_to :discussion, belongs_to :user). Create `HasDiscussion`
      concern (`has_one :discussion, as: :record, dependent: :destroy` + `find_or_create_discussion`
      helper). Include in all content models and tag models. Tests: model tests, polymorphic
      association tests.
    - **Slice 1.3:** Routes: `resources :discussions, only: [:show, :create]` nested under universe,
      with `resources :messages, only: [:create]` nested under discussions. `DiscussionsController#show`
      (loads record through authorized scope, renders record details + discussion thread),
      `DiscussionsController#create` (find or create discussion for a record),
      `MessagesController#create` (add message). Views: discussion page uses `shared/_record_details`
      for the record header, then message thread + reply form. Add "Discuss" link on every record's
      details page. Tests: request tests, system test.
    - **Slice 1.4:** Message timestamps, author names, empty state copy. Update
      `docs/conventions.md` with the discussion page pattern. Update changelog.

21. **Collaboration system — Phase 2: Draft system (core data model + interception)**

    In `wikipedia` or `github` mode, mutations are stored as draft changes instead of written directly.
    Users can see their pending changes and apply them. Conflict resolution comes in Phase 3.

    - **Slice 2.1:** Create `drafts` table (`user_id`, `universe_id`, `status` string default `"draft"`
      not null: `draft`/`applied`/`discarded`/`submitted`, timestamps) and `draft_changes` table
      (`draft_id`, `record_type`, `record_id` nullable, `action` string: `create`/`update`/`delete`,
      `changes` JSON/text, `base_version` string nullable, `created_at`). `Draft` model (belongs_to
      :user, belongs_to :universe, has_many :draft_changes), `DraftChange` model (belongs_to :draft).
      Validations: action inclusion, record_type presence. Tests: model tests, association tests.
    - **Slice 2.2:** Create `app/controllers/concerns/draft_mutation.rb`. The concern intercepts
      `create`, `update`, `destroy` actions. When the universe is in a draft mode: for `create` store
      `action=create`, `record_id=null`, `changes`=new attributes; for `update` store `action=update`,
      `record_id=id`, `changes`=changed attributes, `base_version`=record's `updated_at`; for
      `destroy` store `action=delete`, `record_id=id`, `base_version`=record's `updated_at`. Return
      JSON response indicating the change was stored as a draft. In `direct` mode: proceed with
      current behavior. Include the concern in all mutation controllers (characters, locations, items,
      events, relations, ownerships, sections, scenes, all tags, scene_elements, scene_characters,
      scene_items, scene_locations). Tests: request tests for each controller in both direct and draft
      mode.
    - **Slice 2.3:** `DraftsController#index` (lists current user's drafts for the universe),
      `#show` (shows one draft with all its changes), `#apply` (applies all non-conflicting changes;
      conflict resolution comes in Phase 3), `#discard` (discards a draft). Views: draft list page,
      draft detail page. Routes: `resources :drafts, only: [:index, :show, :apply, :discard]`.
      Tests: request tests, system test.
    - **Slice 2.4:** Add "Start editing" / "Stop editing" toggle button in the universe view (visible
      to users with write access in draft-based modes). When in draft mode, show "N pending changes"
      indicator. Toggle stored in session. When entering draft mode, create a draft for the user if one
      doesn't exist. Tests: request tests, system test.
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

    - **Slice 3.1:** Create `app/services/draft_conflict_detector.rb`. For each draft change:
      **Create** → no conflict possible. **Update** → if record's `updated_at` != `base_version` →
      CONFLICT; if record is soft-deleted → CONFLICT. **Delete** → if record's `updated_at` !=
      `base_version` → CONFLICT; if record is already soft-deleted → no conflict (already gone).
      Returns a list of conflicts with the draft change and the current record state. Tests: unit
      tests for all conflict scenarios.
    - **Slice 3.2:** Conflict resolution UI. When applying a draft with conflicts, show a conflict
      resolution page. For each conflict: show the record name and type, what the current user wants
      to do, what "theirs" means, two buttons: "Apply theirs" (discard my change for this record) and
      "Apply mine" (overwrite with my change). For "apply mine" on a delete conflict: restore the
      record and apply the edit. For "apply mine" on an edit conflict: overwrite the current values
      with the draft values. Tests: request tests, system test.
    - **Slice 3.3:** Create `app/services/draft_applier.rb`. Applies non-conflicting changes directly.
      For conflicting changes, applies the user's choice. Runs in a transaction. Returns a summary of
      what was applied. Tests: unit tests, integration tests.

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

26. **Keep the demo reset isolated to the development database**

    On 2026-09-29, `CONFIRM_DB_RESET=1 UNIVERSE=dark bin/rails db:demo:reset` invoked Rails
    `db:drop`, which dropped both `storage/development.sqlite3` and `storage/test.sqlite3` before
    recreating them. The owner's approval for this task covers only the disposable development
    database, never test or production. Replace the broad task dependency with a development-only
    database reset path, and add task-level coverage proving test/production database files or data
    are untouched. Preserve the explicit confirmation guard, validate the named universe, and verify
    the rebuilt development records before reporting success.

28. review comments. add comments when needed, remove comments when not needed

29. is is has_many_tagd or has_many_tagged?

30. define a code_style.md?

31. consider moving all scene_* supporting classes to a namespace?

32. adding several stories to one universe. for instance. in dark add 2 more stories called:
    a) Netflix Darker, b) Bethesda Dark. add some info to the demo data .yml files. the idea of this
    is testing hwo it looks when you have several stories. and also to test the login -> universe ->
    story flow

33. the `has_many_tags` raw-SQL warning, and the audit baseline that claims Brakeman is clean

    `bin/brakeman --no-pager` reports one **Weak**-confidence SQL-injection warning at
    `app/models/concerns/has_many_tags.rb:109`, where a `joins("INNER JOIN …")` string is built by
    interpolating `reflect_on_association(...)` results. Nothing interpolated there comes from a
    request — the table and column names come from the model's own associations — so it reads as a
    false positive, but it is still a string-built join rather than a symbol or a hash, and it is the
    kind of construct a future edit could make reachable. Confirm that reading, then either rewrite
    the join without string interpolation or record why the warning is safe to accept.
    The reason this is listed rather than fixed silently: the audit baseline in
    [`known_quirks.md`](known_quirks.md) records `bin/brakeman --no-pager` as **0 security
    warnings**, which is now wrong and will mislead the next person who trusts it. Update that
    baseline in the same change, whether the warning is fixed or accepted.

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
