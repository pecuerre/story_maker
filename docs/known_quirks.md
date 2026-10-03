# Known Quirks & Tech Debt

Verified **open** oddities in this codebase — things that look like bugs, are bugs, or will
surprise you. This file holds only open findings: when one is fixed, the whole entry moves to
[delivery_history.md](delivery_history.md) with the history of the fix, and no "this used to be broken"
note is left behind here. Index of all docs: [README.md](README.md).

This re-audit was performed on 2026-09-24 against commit `8fcf4d4`. It is an observation record
only: no application, test, configuration, dependency, or generated-asset fixes were made in this
pass. The separate DataFactor follow-up section below was checked against the current tree on
2026-09-25; it is not a full replacement for the original audit. Severity labels distinguish
reachable security/data-loss issues from lower-priority hardening and contract decisions. Entries
numbered **63 and above** were added on 2026-10-03 and **68 and above** on 2026-10-04, while the
collaboration draft system was being
built, verified the same way, and listed here rather than left in [`backlog.md`](backlog.md) because
each one is reachable now rather than only pending.

## Critical security observations

5. **Critical — the exposed Kamal master key still requires owner rotation and history cleanup.**
   The current tree now ignores and untracks `.kamal/secrets`, keeps the local copy mode `0600`,
   and CI rejects a tracked secrets path. Those containment changes do not invalidate prior
   repository/history copies or rotate `RAILS_MASTER_KEY`; the owner must rotate the key, the
   affected `secret_key_base`/signed artifacts, and any credentials it protects before deployment.
   No secret value is reproduced in this document.
   See [`delivery_history.md`](delivery_history.md) for the repository-containment change and
   [`config/deploy.yml`](../config/deploy.yml) for the local secret contract.

6. **Low — a personal access token pasted into a backlog paragraph stays in Git history.** A
   GitHub fine-grained personal access token was pasted into the "Keep the demo reset isolated to
   the development database" paragraph of `docs/backlog.md` by mistake and committed in `af2fcde`.
   The working-tree text was redacted, and that backlog item has since been delivered and deleted.
   The string itself is still in `git log` permanently. The owner reports the token as read-only
   against a **public** repository, which bounds the exposure: those contents were already readable
   by anyone, so this was a hygiene failure rather than a disclosure. Revoking it is still worth
   doing — it costs nothing — but note that a fine-grained token's real grants live on GitHub's
   side and are not recorded in this repository, so "read-only" is the owner's account of it rather
   than something the tree can verify. Only rotation settles it.
   See [`delivery_history.md`](delivery_history.md) for the same incident as it was recorded when
   the backlog item was still open. No secret value is reproduced in this document.

## Mutation, route, and data-contract observations

    **Scenes are covered** (see [ADR 0007](adr/0007-story-owned-scenes-and-elements.md)):
    `Scene` validates `optional_references_exist`,
    `section_belongs_to_story`, and `event_belongs_to_story_universe`, and
    `datetime_is_a_valid_point` rejects an unparseable in-world time that Active Record would
    otherwise cast to `nil` and silently discard, so those values render `422` field errors with the
    submitted input preserved. The `#group` action instead resolves the Section through
    `@story.sections.find`, making a foreign or unknown target a `404`. Scene/Scene Tag
    assignment also has
    collection-id guards, so unknown, duplicate, and cross-story tag
    ids become ordinary validation errors before the constrained join can raise. The Scene-owned
    presence links are covered the same way: an unknown or foreign
    `character_id`, `item_id`, or `location_id` is a `404` because the record is resolved through
    `Current.universe`, and a duplicate pair is a `422` field error before the unique index can raise.
    The hierarchical `parent_id` and the Event temporal references are covered the same way, by
    `Hierarchical#parent_reference_exists` and `Event#temporal_references_exist`; see
    [conventions.md](conventions.md#models).

20. **Medium — generated routes advertise unsupported actions and templates.** `config/routes.rb:2-25`
    uses broad session, password, and content resources even though the documented action surface is
    narrower (`docs/conventions.md:63-66`). Examples include missing
    `sessions#show/edit/update`, `passwords#index/show/destroy`, content `show/edit` actions, and
    `new` routes whose controllers have no templates. The route table contains dozens of entries
    that cannot render a supported page; direct requests can produce 404, unsupported-format, or
    missing-template responses. The existing route test checks positional helper arguments, not
    route/action/template contracts.
    Partly reduced on 2026-09-25: every content model and every tag model now has a real, tested
    `show` action, so the `show` half of the content surface is no longer an empty route. The
    `edit` routes for modal-edited content, the session/password actions, and the `new` routes
    without templates are unchanged and still need either an action or a route restriction.
    The tag-controller half was reduced on 2026-09-28: the eight `*_tags` resources are restricted
    to `index/show/create/update/destroy`, the dead `new` actions are removed, and the taxonomy
    node's vestigial `data-edit-url`/`data-create-url` attributes are gone. The content-controller
    `new`/`edit` routes and the session/password actions remain open.

22. **Medium — raw SQL/import and flat direct-model paths can still bypass ordered-position
    maintenance.** The `PositionedResourceOrder` service now transactionally
    handles create, move, reparent, and destroy for current positioned controllers, and the
    `Hierarchical` callback closes gaps after direct hierarchical destroys. Two flat sequences were
    added with the Scene deliveries — the Story-owned `Scene` order and the Scene-owned
    `SceneElement`
    order — which are normalized only when a mutation goes through `ScenesController` or
    `SceneElementsController`; unlike `Hierarchical`, neither `Scene` nor `SceneElement` has a model
    callback that repairs positions after a direct destroy. Direct SQL, association manipulation,
    and direct-model writes therefore
    still bypass the service for both hierarchies and flat sequences, and SQLite has no
    portable row-lock/unique-position guarantee. Do not treat those paths as normalized without an
    explicit import/console workflow; see ADR 0009 and [`delivery_history.md`](delivery_history.md).
    One caller was added on 2026-10-03 that is not a controller: `DraftApplier` writes a draft's
    remembered changes through the same service, so applying a draft in a draft-based universe does
    normalize. It decides *which* models are ordered by reading their own columns rather than by
    asking a controller, and `test/services/draft_applier_test.rb` holds that derivation against every
    routed controller in both directions — so this finding's list of bypassing paths is unchanged, and
    the applier is a maintained caller rather than a new hole.

23. **Medium — legacy HABTM join tables have no database integrity constraints.** The seven
    pre-Scene join tables contain only two integer columns and no indexes, foreign keys, or
    uniqueness constraints (for example `db/schema.rb:42-45,84-87,117-120,150-153,186-189,224-227`;
    the migrations use bare `create_join_table`, e.g.
    `db/migrate/20260923130012_create_characters.rb:14`). The Scene-owned and Scene-tag tables are
    the exception: `scenes_scene_tags`, `scene_element_speakers`, `scene_characters`, `scene_items`,
    and `scene_locations` all have
    real foreign keys and a unique pair index, and `scene_elements` adds a `check_constraint` on
    `kind`. Direct SQL,
    imports, failed association replacement, or duplicate IDs can still create orphan/duplicate rows
    in the legacy tables. Scoped association reads prevent foreign tags from being disclosed through
    ordinary model/view paths, and controller saves roll back rejected ID replacements. A direct
    HABTM collection writer can still write a join row before a later validation failure in a
    legacy table, however, because the database has no constraints to reject it.

27. **Low — User model validation does not match its NOT NULL schema.** `users.name` and
    `users.email_address` are `NULL: false` (`db/schema.rb:304-312`), but `User` has no presence
    validations (`app/models/user.rb:1-10`). Model callers can see `valid? == true` and then receive
    a database exception on `save!`. There is no public registration controller, which limits the
    current blast radius, but seed/import callers are not protected.

28. **Low, contract-dependent — reversed temporal intervals are accepted.** `Event`, `Relation`,
    and `Ownership` do not validate that an end/to date follows its start/from date
    (`app/models/event.rb:17-19,67-72`, `relation.rb:16-17`, `ownership.rb:16-17`). A range with
    `end < start` saves successfully and can be displayed or interpreted inconsistently. The
    desired treatment of unknown or intentionally open intervals should be made explicit.

29. **Low — composite Relation/Ownership slugs depend on unordered tag input.** Their callbacks use
    `relation_tags.first` or `ownership_tags.first` without an explicit order
    (`app/models/relation.rb:43`, `app/models/ownership.rb:42`). Creating equivalent records
    with tags supplied in a different order can produce different slugs, which matters for
    symbolic development-data references and class-level lookup.

63. **Medium — a remembered change that has moved is reported and then closed with its draft, so the
    author has to redo it by hand.** `DraftsController#apply` writes the changes whose record is still at
    the version they were remembered against, reports the rest in one flash sentence, and moves the
    draft to `applied` regardless (`app/services/draft_applier.rb`,
    `app/controllers/drafts_controller.rb:51-62`). Nothing stores an outcome per change and a remembered
    change is append-only, so the unapplied change's values survive only as a row on the draft's page
    (`draft_changes.payload`), where nothing reads them back into an editor. In practice: an
    administrator sets a universe to `wikipedia`, two contributors edit the same record, and the second
    one's edit is reported once and then has to be retyped. The draft always closing is deliberate and
    load-bearing — a remembered `create` names no record, so an apply left open could write the author a
    second copy of it (ADR 0021) — and the resolution UI that removes this cost is Phase 3, recorded in
    [`backlog.md`](backlog.md) as **Collaboration system — Phase 3: Conflict resolution**. A backlog
    number is not cited here on purpose: it is deleted when the item is done, and this entry outlives it.

64. **Low — the apply's outcome is reported once and then lost.** `DraftApplier::Result` carries what was
    written and why the rest was not, and the controller turns it into one flash message; nothing records
    it on the draft. A draft's page therefore cannot say which of its changes were applied and which were
    not, and deliberately does not try to infer it: an apply moves every version it writes, so comparing
    a record's current version with the remembered one cannot distinguish "written by this draft" from
    "changed by somebody else" (ADR 0021). The consequence is that an applied draft reads as a list of
    remembered intentions rather than as a record of what happened, which is the part of "draft history"
    that Phase 5 will want.

66. **Low — resolving a draft's records costs a lookup per change, and the sidebar panel pays it on every
    page.** `DraftChange#resolved_record` deliberately does not remember its answer (a record deleted after the
    change was written must stop resolving), so each row resolves its own record, and each remembered
    `*_ids` value resolves its tags through `DraftsHelper#association_names` one query at a time. The right
    sidebar's pending panel reads the same draft on **every** page of the universe and resolves each change's
    record, so the cost is no longer one page but all of them; `DraftPreview::PANEL_LIMIT` caps it at five
    rows and counts the remainder, which bounds the exposure without removing it. The panel is one bounded
    read added this way, and a draft assembled from a long editing session is still a query per row. The
    drafts page is the other, and is unbounded per row as before — every other list page in the application
    preloads through a grouped query, so these are the two places that do not. Both would be answered by a
    `DraftChanges::Reader` that resolves a draft's records and tag names in two queries.

68. **Medium — a remembered create is not validated, so a list can show a pending row the universe would
    have refused.** ADR 0020 deliberately does not validate a change when it is remembered: the applier
    re-runs the live path, where the model's own validations are authoritative. That is right for the
    drafts page, which reports what the author *asked for*. It is not right for a **list**, because
    `DraftPreview#creates_for` builds the pending record straight from the payload with no validation at
    all (`app/models/draft_preview.rb`). Verified on 2026-10-04 in a `wikipedia` universe: posting an Event
    with no title and no dates answers **202** and the Events list renders a pending row reading
    **“Event #”** — `Event#display_label`'s last rung, `t("events.display_label.unidentified", id: nil)`
    — where the same submission on the `direct` path answers **422 must have a title, a date, or a
    relation to another event**. A nameless Character create is the same defect with a quieter face: the
    row renders its badge and its description with **no subject at all**, and a nameless taxonomy create
    renders a bare **Draft** badge. The row has no id, so there is nothing to name it by, and no way to
    withdraw it from the list except discarding the whole draft. The deep cause is the one finding 64
    records: nothing stores an outcome per change before an apply, so the list cannot know which
    remembered changes will be refused. Whether a row that will not apply is badged differently, named
    from its type, or withheld is a product decision and belongs with **Collaboration system — Phase 3:
    Conflict resolution** in [`backlog.md`](backlog.md), not here.

69. **Low — a pending row carries no tags and no photo, so a remembered create shows less than the author
    submitted.** `DraftPreview#creates_for` assigns the payload sliced to `model.column_names`
    (`app/models/draft_preview.rb`), which is what keeps the collection writers (`character_tag_ids`) and
    the two virtual photo attributes off a record that will never be saved — and is also why a payload
    naming a renamed column is harmless. The cost is visible: a new Character the author tagged
    *Protagonist* and gave a portrait appears in the Characters list with a **Draft** badge and no tag
    badge and no picture, while the same change on the draft's own page shows both, because that page is
    where the payload's values are read rather than printed. Resolving a tag list per pending row costs a
    query per row, which is the trade finding 66 already describes; deciding whether the row should pay
    it is recorded as **What a pending record shows outside the list workspaces** in
    [`backlog.md`](backlog.md).

## Performance, test, and tooling observations

36. **Medium — CI proves a production image boots, but not a deployment.** The test job runs
    `db:test:prepare test` against the checked-in schema (`.github/workflows/ci.yml:125-131`), so it
    was never a from-zero migration run, a Docker build, a production asset boot, or a Solid
    Cache/Queue/Cable setup; there was no coverage measurement or threshold either. A green test job
    was therefore not evidence that a clean production image or the full runtime could boot.
    Two of those halves are now closed. `migrations-from-zero` runs the migration files from zero
    (below), and `production-boot` builds the production image, inspects it, runs it with throwaway
    environment variables, and requires `GET /up` to answer `200` — which also exercises
    `db:prepare`, the four production SQLite databases, and the precompiled assets.
    That job **was failing on every run**: `assets:precompile` boots the production environment, which
    raises without `APP_HOST`, `MAILER_FROM`, and `SMTP_ADDRESS`, so `docker build` never finished.
    Verified through the GitHub Actions API on 2026-10-02 and reproduced locally; those three names
    are now build arguments in the Dockerfile with `.invalid` defaults. `config/deploy.yml` is
    validated on every test run through Kamal's own loader by
    `test/deployment/kamal_configuration_test.rb`, because `bin/kamal config` cannot be run in CI —
    it prints resolved secrets — but loading a configuration is not the same as deploying it. Neither
    the boot check nor that validation exercises production mailer URL/SMTP behavior, and no deploy
    has ever been performed.
    The `migrations-from-zero` job closes the migration half. It used not to: it ran
    `db:drop`, `db:create`, and `db:migrate` as three processes — which is required, because one
    process migrates the inode `db:drop` unlinked — but on the freshly created database `db:migrate`
    **loaded `db/schema.rb` rather than executing the migration files** (see
    [development.md](development.md#amending-a-shipped-migration-does-not-work-here)), so
    `db:migrate:status` reported every migration `up` and `git diff --exit-code db/schema.rb`
    compared the dump against itself. Verified on 2026-10-01, then fixed the same day: the job
    creates `schema_migrations` before migrating so the migration files execute, and a guard step
    fails the job if a `schema_sha1` was recorded in `ar_internal_metadata` — a row only
    `DatabaseTasks.load_schema` writes. Verified by amending a shipped migration to add a column: the
    old sequence reported all 36 migrations `up` with the column absent from the database, and the
    new one runs the migration and fails on the schema diff. The local reset path is covered
    separately by `test/services/development/database_reset_test.rb`.

37. **Low — development fixtures and documentation overstate baseline coverage.**
    `docs/development.md` says all content and tag fixtures are present, but relation,
    ownership, relation-tag, ownership-tag, and membership fixture files are absent; tests create
    many of those records ad hoc. `docs/README.md` advertises an absent `docs/images-to-ai/`
    directory. The development guide also calls `test/helpers` effectively empty even though
    `test/helpers/application_helper_test.rb`, `record_details_link_test.rb`, and
    `scenes_helper_test.rb` are present. The root README's destructive `db:restart` warning has
    been clarified, and the dead `schema.txt` links this finding used to report were removed on
    2026-09-30; the fixture, `images-to-ai`, and `test/helpers` issues in this finding remain open.

39. **Low — the smoke script is not environment-guarded or concurrency-safe.**
    `docs/smoke_test_stories.sh:22-114` uses fixed `/tmp` filenames, has no cleanup trap, can leave
    a created story behind after an extraction failure, and invokes `bin/rails runner` without
    forcing the development environment. It is not part of GitHub CI and should not be treated as a
    reliable cleanup boundary.

62. **Low — the smoke script's login check cannot tell a success from a rejection.**
    `docs/smoke_test_stories.sh:67` asserts `login succeeds` by comparing the response code to `302`,
    and `SessionsController#create` answers `302` in both branches: a successful sign-in redirects to
    `after_authentication_url`, while a rejected one redirects back to `new_session_path` with the
    `sessions.failed` alert (`app/controllers/sessions_controller.rb:15-21`). The check therefore
    also passes with a wrong password, a rate-limited sign-in, or an expired CSRF token. Observed on
    2026-10-02 by running the script against a live server with a deliberately wrong password: it
    printed `ok - login succeeds` and then failed the following checks, so the script as a whole
    still fails and the run is not silently green — but that one line asserts far less than it
    reads, and it is the only thing between a bad credential and nine pages of meaningless output.
    Asserting the redirect *target*, or the presence of the signed-session cookie, would make it mean
    something. Separate from quirk 39, which concerns the script's filesystem and environment
    handling rather than its assertions.

## Contract-dependent and future-feature footguns

These observations are code-proven but depend on a product/deployment decision or are not reachable
through the current normal UI. They are recorded so they are not mistaken for settled behavior:

- **Ability class checks are unsafe for future generic authorization code.** CanCan rules for
  content classes use instance blocks (`app/models/ability.rb:59-81`); a guest class-level
  `authorize!(:read, Character)` can be allowed even though an instance check is denied. Current
  `UniverseAuthorization` passes concrete universe objects, so no active route bypass was found.
  The content-class registry is still hard-coded (`app/models/ability.rb:11-27`) and is now
  load-bearing twice over, since `RecordTarget` gates polymorphic record references through the same
  list. Two things changed on 2026-10-02: the claim that the new-model workflow does not require
  registration was wrong — `development.md` has required it since the checklist was written — and
  `test/models/ability_test.rb` now requires every persisted model to be content, authorized by
  another rule group, or listed there with a reason, so an unregistered model fails the suite
  instead of silently losing its rules. The footgun itself is unchanged: nothing in the application
  prevents a future caller from authorizing a class, only `RecordTarget` declining to hand one out.
- **Ownership-scope resolution now has one shared adapter.** `UniverseScopeResolver`
  (`app/models/universe_scope_resolver.rb`) answers which universe owns a record, and both
  `Ability#universe_for` and `ApplicationHelper#universe_for_record` delegate to it, so
  record-level authorization and rendered mutation controls cannot drift. It resolves a record
  through its own `#universe` or through a declared owner association (`story`, `scene`,
  `section`). Two limits remain: a model nested deeper than one of those must define its own
  `#universe` (otherwise it resolves to nothing and silently loses controls and checks), and the
  content-class registry in `app/models/ability.rb:11-34` is still hard-coded, so a new model must
  be added to it or CanCan will not match a rule for it at all — that half is now a failing test
  rather than a silent omission, see the entry above.
- **Implicit owner access is missing from association APIs.** `User#universes` and
  `Universe#members` are membership-only associations (`app/models/user.rb:6-8`,
  `app/models/universe.rb:41-43`), while the owner is intentionally not stored as a membership row.
  The policy-aware `User#accessible_universes` and the membership view compensate manually
  (`app/models/user.rb:12-14`, `app/views/memberships/index.html.erb:64-70`); new code using the
  ordinary associations can omit owners and report incomplete access/collaboration data.
- **A remembered create says nothing about which story, scene, or section it would belong to.** The payload's
  scope column (`DraftChange#scope_attribute`) is dropped as plumbing on the drafts page, because the page is
  already inside the universe it would place the record in and a bare `story_id` is a number a reader cannot
  name. The list workspaces now show remembered creates too, and they drop it for the same reason — and
  additionally because a pending row is an unsaved record whose position and parent are the applier's to
  decide, so it is appended after the real rows and placed under no parent. An author reviewing twenty
  remembered scenes therefore sees twenty rows that say what each scene is called and nothing about where
  each one would land, and has to go to the record's own workspace to find out. A resolved name per create
  would cost one lookup per row, which is the same trade as finding 66; the reasoning for reading a create
  as an unsaved model rather than a row is in [ADR
  0023](adr/0023-pending-changes-are-read-from-the-draft-and-drawn-as-badges.md).
- **The applier raises rather than reporting a change it cannot interpret.** An unregistered `record_type`
  on a remembered create, or a payload naming an attribute no column holds, is a corrupt row rather than
  something an author typed, and `DraftApplier` lets it raise (`ActiveRecord::RecordNotFound`,
  `ActiveRecord::UnknownAttributeError`) instead of guessing. The run's transaction makes that safe — the
  draft is left exactly as it was — but through the controller it answers as a bare 404
  (`rescue_from ActiveRecord::RecordNotFound`), which reads as "this draft does not exist" rather than as
  "this draft is damaged", and the author's only way forward is **Discard**. The decision is documented
  (ADR 0021); the shape of the answer is the part a reviewer may want to change.
- **No mutation rate limits exist beyond sign-in/password-reset.** Public universes intentionally
  allow every signed-in contributor to write, so throttling content/story/tag/membership mutations
  is a product decision rather than a confirmed defect.
- **Universe/story authorization objects are looked up more than once.** The current request path is
  internally consistent, but a concurrent slug rename or scope mutation could create a TOCTOU
  mismatch between the object authorized and the object acted on; no deterministic exploit was
  demonstrated.
- **Tag colors are format-validated but not contrast-validated.** `HasColor` accepts any
  `#rrggbb` pair for a taxonomy tag's background and foreground
  (`app/models/concerns/has_color.rb:4-7`), so an author can choose a combination that fails
  WCAG contrast. The badge shape still identifies the tag, and color is never the only signal, so
  this is a legibility review item rather than a security finding.
- **Framework routes are broader than the current domain.** `config/application.rb:3` loads
  `rails/all`, exposing unused Active Storage/Action Mailbox/Action Text routes. Their default
  protections reduce immediate risk, but the application has no route allowlist or production
  route-surface check.

## Additional UI and interaction observations

67. **Low — a draft's page prints English attribute names for the models the Scenes workspace never
    translated.** A remembered value is labelled with `Model.human_attribute_name`, and
    `config/locales/*.yml` names the attributes only for the models whose forms are rendered there, so a
    Spanish reader looking at a remembered **Section** or **Scene Element** create sees "Name" and
    "Description" beside Spanish chrome — the documented humanized-English fallback, not a missing key.
    The six collection names the page prints most often (the eight taxonomies' tag assignments) are named
    in both files now, and the Scene-owned models are the rest. Naming those models is the Scenes
    workspace's translation work; this entry exists so it is a known gap rather than a surprise.

49. **Low/conditional — Turbo page snapshots may retain private views after session invalidation.**
    The layout does not disable Turbo caching and defines no `turbo-cache-control`
    (`app/views/layouts/application.html.erb:1-20`, `app/controllers/application_controller.rb:6-7`).
    A private page could be restored from a browser snapshot after a session is invalidated in
    another tab or by expiry, without a fresh authorization request. This depends on Turbo/runtime
    cache behavior and needs a multi-tab browser test before being treated as a confirmed leak.

50. **Low — dead PWA/UI assets still drift from the conventions.** The dynamic taxonomy modal now uses
    consistent heading/required-field semantics, but `app/views/pwa/manifest.json.erb` and
    `app/views/pwa/service-worker.js` have no route or layout link, and the PWA palette contains a
    `red` value that does not match the documented theme. These are low-priority cleanup/style
    inconsistencies.

58. **Medium — a synthetic click on a control inside the fixed navbar misses it.** The navbar is
    `position: fixed-top` (`app/views/layouts/_navbar.html.erb:1`). Capybara scrolls an element into
    view before clicking it, and a fixed navbar does not move with the document, so the element has
    shifted between the scroll and the click and the click lands somewhere else — silently, because
    the click still hits *something*. `test/system/authentication_test.rb`'s "a user can sign in and
    sign out" fails for this reason and has done so before any recent change: clicking **Log out**,
    which is a `button_to` inside a Bootstrap dropdown in that navbar, leaves the reader still signed
    in and still on the page they were on. This is **not** a defect in sign-out — the form is correct,
    the session is destroyed, and driving the same click from the DOM reaches `/session/new`. It is a
    test-harness limitation, and it is currently worked around rather than fixed:
    `test/system/settings_start_page_test.rb` submits the same form with a scripted click. The fix is
    either to stop the harness scrolling for elements inside the fixed navbar (a Capybara
    configuration or a shared helper) or to move the account menu out of the fixed element. Until
    then, the sign-out path has no browser-level coverage that does not work around it, and the
    request suite is the only place sign-out is actually asserted.

56. **Medium — an index write the engine refuses asynchronously is invisible to the job that queued
    it.** `Search::IndexRecordJob` and `Search::RemoveRecordJob` hand a document to the engine and
    return; the engine accepts the request and applies it later, so a *server-side* rejection — an
    unusable document id, a field it will not index, a batch that broke on one document — surfaces
    only in the engine's own task log. `Search::Reindexer` therefore awaits every task **and** checks
    it, and `test/models/searchable_test.rb` holds every declared model's document id to the engine's
    character rules; a job has neither. In practice this was the difference between a reindex
    reporting "indexed 214 documents" with an empty index and one that fails loudly. If index drift
    is ever suspected, `bin/rails search:status` reports the document count and
    `bin/rails search:reindex` is the repair; there is no per-record verification. See
    [ADR 0014](adr/0014-global-search-with-meilisearch.md).

57. **Low — a rename changes a slug, so a universe rename invalidates every path stored below
    it.** `HasSlug` regenerates a slug when a name changes, and each search document stores its own
    `url`, which embeds its record's slug and its universe's. A universe rename is therefore repaired
    by `Search::ReindexUniverseJob` (queued on `saved_change_to_slug?`), which is bounded but not
    instant: between the rename and the job, results in that universe link to a 404. Records that
    merely *mention* the universe are unaffected, because a document stores ids rather than names
    and the displayed context is resolved per request.

58. **Medium — the browser suite is unreliable when the machine is saturated, and it fails as
    unrelated-looking errors.** `bin/rails test:system` parallelizes over
    `number_of_processors`, and each worker holds its own SQLite test database and its own Chrome. On
    an eight-core machine the box is saturated (load average 20+), SQLite's five-second busy timeout
    (`config/database.yml`) expires inside a request, and the resulting `SQLite3::BusyException`
    surfaces through Capybara as "expected `/session/new` to equal `/`", a modal that never opened, or
    a heading that never appeared — in tests that have nothing to do with the database. Verified on a
    pristine checkout of `aa224a2` (10 failures, 41 errors, unchanged by any later work), so it is not
    caused by the change it was noticed during; `PARALLEL_WORKERS=2 bin/rails test:system` is green.
    CI is less exposed because its runners have fewer cores and therefore fewer workers, which is also
    why this has not been seen there. Do not read a single browser run as a verdict, and do not
    "fix" a test that failed this way — re-run it with fewer workers first.

## DataFactor report follow-up observations (2026-09-25)

The 2026-09-25 DataFactor report identified several maintenance and onboarding gaps. They were
checked against the current tree and are recorded here as open follow-ups, not as requirements to
maximize an automated score. The distilled policy is in
[`data_factor_guidance.md`](data_factor_guidance.md), and the corresponding implementation work is
the run of DataFactor follow-up items in [`backlog.md`](backlog.md) — of which one remains open:
container onboarding (finding 52 below). Coverage measurement, credential literals, supply-chain
checks, structured logging, and shared editor/helper duplication have all been delivered; that
document's §3 through §7 say so and say what replaced them, and finding 51 below is closed; see
[architecture.md](architecture.md#runtime-logging-and-observability) and
[`../CHANGELOG.md`](../CHANGELOG.md). The report's claims that no `/up` route or JavaScript
lockfile exists are already stale: `config/routes.rb` exposes `/up`, and `bun.lock` is committed and
used with a frozen install in CI and Docker.

52. **Medium — clean container onboarding is absent.** The repository has a production-oriented
    `Dockerfile` and a server entrypoint that runs `db:prepare`, but no root `docker-compose.yml`
    or devcontainer. A fresh clone therefore still depends on the documented host toolchain, and
    there is no clean-checkout proof that the image, SQLite paths, CSS assets, and `/up` work
    together. The compose path must not run development data in production; this is the
    "One-command containerized onboarding" item in [`backlog.md`](backlog.md). The value-free
    `.env.example` template this entry used to list as missing now exists; the container onboarding
    it served is still absent.

## Audit baseline and evidence

The following non-destructive checks passed during the 2026-09-24 re-audit. They are the evidence
behind the findings above, not a current capability list; the verification run for each later change
is recorded in [`delivery_history.md`](delivery_history.md).

- `bin/rails test` — 226 tests, 1,495 assertions, 0 failures/errors/skips.
- `bin/rails test:system` — 4 tests, 55 assertions, 0 failures/errors/skips, with the 406 caveat
  recorded in [`delivery_history.md`](delivery_history.md).
- `bin/rubocop` — 158 files, no offenses.
- `bin/brakeman --no-pager` — 0 security warnings; it does not cover the client-side DOM XSS path.
- `bin/bundler-audit` — no known vulnerabilities.
- `bin/importmap audit` — no reported vulnerabilities; at this checkpoint it explicitly ignored
  vendored Tom Select.
- `bun audit` — no current vulnerabilities across 97 packages; not part of CI.
- `bin/rails db:migrate:status` — all application migrations up.
- `git diff --check` and final `git status` — clean before this documentation-only edit.

Not run: destructive development tasks (`db:restart`, `db:reset`, `db:drop`, `db:seed`,
`db:seed:replant`), demo-data loaders, Docker/Kamal deployment, production SMTP delivery, a clean
migration-from-zero job, or a live hostile-browser exploit. No production data or secret value was
modified as part of documenting these findings; disposable test probes were rolled back or cleaned.
