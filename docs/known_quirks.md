# Known Quirks & Tech Debt

Verified **open** oddities in this codebase — things that look like bugs, are bugs, or will
surprise you. This file holds only open findings: when one is fixed, the whole entry moves to
[resolved_quirks.md](resolved_quirks.md) with the history of the fix, and no "this used to be broken"
note is left behind here. Index of all docs: [README.md](README.md).

This re-audit was performed on 2026-09-24 against commit `8fcf4d4`. It is an observation record
only: no application, test, configuration, dependency, or generated-asset fixes were made in this
pass. The separate DataFactor follow-up section below was checked against the current tree on
2026-09-25; it is not a full replacement for the original audit. Severity labels distinguish
reachable security/data-loss issues from lower-priority hardening and contract decisions.

## Development workflow observations

55. **Medium — editing an applied migration silently does nothing on a fresh database.**
    `ActiveRecord::Tasks::DatabaseTasks.initialize_database` in Rails 8.1
    (`activerecord-8.1.3.1/lib/active_record/tasks/database_tasks.rb:651-669`) loads
    `db/schema.rb` when the target database has no `schema_migrations` table and a schema dump
    exists. `db:migrate`, the guarded `db:restart`, and `db:demo:reset` therefore **load the
    checked-in schema instead of executing the migration files** on a database they just created.
    An amended create migration is never run, the regenerated `db/schema.rb` keeps the old shape,
    and the only symptom is a later "unknown column"/"unknown attribute" failure in a form,
    manifest, or test. This was hit while adding the Scene Section/Event/datetime references, which
    is why they arrived in a separate `AddSceneReferencesToScenes` migration. Add a new migration
    for any change to a table whose create migration has already shipped, and verify the column is
    present before trusting a manifest or a form that uses it.

## Critical security observations

5. **Critical — the exposed Kamal master key still requires owner rotation and history cleanup.**
   The current tree now ignores and untracks `.kamal/secrets`, keeps the local copy mode `0600`,
   and CI rejects a tracked secrets path. Those containment changes do not invalidate prior
   repository/history copies or rotate `RAILS_MASTER_KEY`; the owner must rotate the key, the
   affected `secret_key_base`/signed artifacts, and any credentials it protects before deployment.
   No secret value is reproduced in this document.
   See [`resolved_quirks.md`](resolved_quirks.md) for the repository-containment change and
   [`config/deploy.yml`](../config/deploy.yml) for the local secret contract.

12. **Medium — sessions have no application-enforced expiry or source binding.** Login creates a
    permanent cookie and stores only its session ID (`app/controllers/concerns/authentication.rb:41-50`).
    The `sessions` table has no expiry or last-used field (`db/schema.rb:265-272`,
    `app/models/session.rb:1-3`), and lookup validates neither the recorded IP address nor user
    agent (`authentication.rb:24-30,42`). A stolen cookie remains usable until logout, password
    reset, or user deletion, and old rows have no cleanup path. Basic cookie flags now have a
    request regression, but no idle/absolute expiration policy or source-binding test exists.

## Mutation, route, and data-contract observations

19. **Medium — nonexistent optional association IDs escape the JSON error contract.** Hierarchical
    parents and event temporal references are optional, but an unknown ID can pass model validation
    and reach a database foreign-key exception (`app/models/concerns/hierarchical.rb:5,54-68`,
    `app/models/event.rb:11-13,55-58`). The shared controller rescues `CanCan::AccessDenied`,
    `RecordNotFound`, and a JSON request whose CSRF token was rejected
    (`app/controllers/application_controller.rb:20-37`), so malformed
    `parent_id`, `before_event_id`, `after_event_id`, or `simultaneous_event_id` values can become
    500s instead of documented 422 error hashes. No such request tests exist.
    **Scenes are now covered** (slices 11.2/11.3): `Scene` validates `optional_references_exist`,
    `section_belongs_to_story`, and `event_belongs_to_story_universe`, and
    `datetime_is_a_valid_point` rejects an unparseable in-world time that Active Record would
    otherwise cast to `nil` and silently discard, so those values render `422` field errors with the
    submitted input preserved. The `#group` action instead resolves the Section through
    `@story.sections.find`, making a foreign or unknown target a `404`. Slice 11.4 also adds
    collection-id guards on Scene/Scene Tag assignment, so unknown, duplicate, and cross-story tag
    ids become ordinary validation errors before the constrained join can raise. The Scene-owned
    presence links are covered the same way from slices 11.7–11.9: an unknown or foreign
    `character_id`, `item_id`, or `location_id` is a `404` because the record is resolved through
    `Current.universe`, and a duplicate pair is a `422` field error before the unique index can raise.
    The remaining
    unprotected paths are the hierarchical `parent_id` and the Event temporal references above.

20. **Medium — generated routes advertise unsupported actions and templates.** `config/routes.rb:2-25`
    uses broad session, password, and content resources even though the documented action surface is
    narrower (`docs/universe_maker_conventions.md:63-66`). Examples include missing
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
    maintenance.** The controller-facing `PositionedResourceOrder` service now transactionally
    handles create, move, reparent, and destroy for current positioned controllers, and the
    `Hierarchical` callback closes gaps after direct hierarchical destroys. Slices 11.1 and 11.6
    added two flat sequences — the Story-owned `Scene` order and the Scene-owned `SceneElement`
    order — which are normalized only when a mutation goes through `ScenesController` or
    `SceneElementsController`; unlike `Hierarchical`, neither `Scene` nor `SceneElement` has a model
    callback that repairs positions after a direct destroy. Direct SQL, association manipulation,
    and direct-model writes therefore
    still bypass the service for both hierarchies and flat sequences, and SQLite has no
    portable row-lock/unique-position guarantee. Do not treat those paths as normalized without an
    explicit import/console workflow; see ADR 0009 and [`resolved_quirks.md`](resolved_quirks.md).

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

24. **Medium — Timeline output can contradict its layer ordering.** `TimelineLayout` rejects an
    edge that would create a cycle (`app/models/timeline_layout.rb:33-40`), but later rebuilds
    `@edges` directly from raw event associations (`:103-115`). A valid model state with dates
    ordering A before B and `B.before_event = A` produces layers with A above B while the view
    receives a B-to-A sequence edge. The view renders those edges directly
    (`app/views/timeline/index.html.erb:3,31-45`). The model has no temporal-consistency validation
    for this contradiction, and timeline tests do not cover conflicting dates/relations.

26. **Low — duplicate universe names become uncaught uniqueness exceptions.** `HasSlug` derives a
    global universe slug from the name, but `Universe` has no slug-uniqueness validation
    (`app/models/concerns/has_slug.rb:26-38`, `app/models/universe.rb:4-8`). The database unique
    index then raises `ActiveRecord::RecordNotUnique` during an ordinary create/update
    (`app/controllers/universes_controller.rb:31-50`) instead of rendering a field error. The form
    does not accept a slug to disambiguate the collision.

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
    (`app/models/relation.rb:21-31`, `app/models/ownership.rb:21-31`). Creating equivalent records
    with tags supplied in a different order can produce different slugs, which matters for
    symbolic development-data references and class-level lookup.

30. **Low — JSON/field contracts have several silent omissions.** Relation/Ownership parameter
    lists omit their optional `name` fields (`app/controllers/relations_controller.rb:43-45`,
    `app/controllers/ownerships_controller.rb:43-45`), and modal datetime helpers format only to
    minutes (`app/helpers/modal_fields.rb:16-26,230-292`), silently discarding stored seconds.
    Relation/ownership HTML redirects also use 302 where the response matrix documents a 303-style
    redirect. These are contract drifts rather than authorization failures.

## Performance, test, and tooling observations

31. **Medium — several ordinary list/tree paths have avoidable N+1 or superlinear work.** Row-level
    authorization checks call `Universe#access_level_for` for each record (`app/views/shared/_row_actions.html.erb:1-3`,
    `app/models/universe.rb:62-71`); membership pages use `joins(:user)` and then dereference each
    user (`app/controllers/memberships_controller.rb:62-64`); hierarchy controllers preload only
    immediate children while the recursive partial descends further
    (`app/controllers/locations_controller.rb:8-15`, `app/views/shared/_taxonomy_node.html.erb:86-105`);
    relation-only event display strings can query temporal associations
    (`app/controllers/events_controller.rb:8-11`, `app/models/event.rb:21-42`); and TimelineLayout
    performs three pairwise event passes with reachability checks
    (`app/models/timeline_layout.rb:46-81,126-153`). These costs are separate from the explicitly
    backlogged search/filter work.
    The new record details pages deliberately added none of this: tag usage counts come from
    `TaggedRecordCounts` (one grouped query) and the Section tree's scene counts from one
    `group(:section_id).count`, and the universe page reuses its memoized story list
    instead of re-counting. The row-level authorization and recursive-children costs above are
    unchanged.

34. **Medium — dependency auditing does not cover the complete JavaScript dependency graph.**
    The local Tom Select pin now carries `# @2.6.2` version metadata in `config/importmap.rb:9`,
    so `bin/importmap audit` includes that direct package/version in its advisory request. The
    audit still does not verify that the vendored file's bytes came from that npm release, and it
    does not replace an audit of the complete Bun/npm graph. That graph is not audited in CI, and
    `.github/dependabot.yml:1-12` has no JavaScript/Bun or Docker ecosystem entry. A local
    `bun audit` currently reports no vulnerabilities, but that check is absent from the workflow.
    The DataFactor report's observation that no JavaScript lockfile exists is stale: `bun.lock` is
    committed and CI/Docker use `bun install --frozen-lockfile`. The remaining audit/Dependabot
    coverage is still a backlog item (see `docs/backlog.md`, item 18).

35. **Medium — the production image retains test and build artifacts.** `Dockerfile:24-28` excludes
    only the `development` bundle group, not `development:test`, so Capybara/Selenium and shared
    development/test gems remain installed. The build stage runs `bun install`
    (`Dockerfile:51-54`) and the final image copies the entire build-stage `/rails` tree
    (`Dockerfile:74-76`), including `node_modules` and build tooling. CI does not build/inspect the
    production image to catch this.

36. **Medium — CI does not prove clean migrations or production boot.** The test job runs
    `db:test:prepare test` against the checked-in schema (`.github/workflows/ci.yml:124-131`), not a
    from-zero migration run, Docker build, production asset boot, Solid Cache/Queue/Cable setup,
    Kamal validation, or production mailer URL/SMTP behavior. There is no coverage measurement or
    threshold. The local migration status is currently clean, but those deployment paths remain
    untested. The DataFactor coverage recommendation is tracked as backlog item 14; the container
    and supply-chain follow-ups are items 15 and 18. A green test job is not evidence that a clean
    production image or the full runtime can boot.

37. **Low — development fixtures and documentation overstate baseline coverage.**
    `docs/development.md:42-44` says all content and tag fixtures are present, but relation,
    ownership, relation-tag, ownership-tag, and membership fixture files are absent; tests create
    many of those records ad hoc. `docs/README.md:19` and `docs/data_model.md:207` link to missing
    `docs/schema.txt`, and `docs/README.md:23` advertises an absent `docs/images-to-ai/` directory.
    The development guide also calls `test/helpers` and mailer previews effectively empty even though
    `test/helpers/application_helper_test.rb` and a mailer preview are present. The root README's
    destructive `db:restart` warning has been clarified; the fixture and missing-link issues in
    this finding remain open.

38. **Low — setup and supply-chain reproducibility has gaps.** `bin/dev:3-5` installs an unpinned
    `foreman` gem at runtime; the Dockerfile comment refers to a nonexistent `.ruby-version` while
    the actual pin is `mise.toml`; and CI/Docker install `libvips` although the local prerequisites
    do not list it. GitHub Actions use mutable major tags, the Docker base image is not digest-pinned,
    and Bun is installed through a remote script. These are hardening/reproducibility concerns,
    not current application failures.

39. **Low — the smoke script is not environment-guarded or concurrency-safe.**
    `docs/smoke_test_stories.sh:22-114` uses fixed `/tmp` filenames, has no cleanup trap, can leave
    a created story behind after an extraction failure, and invokes `bin/rails runner` without
    forcing the development environment. It is not part of GitHub CI and should not be treated as a
    reliable cleanup boundary.

## Contract-dependent and future-feature footguns

These observations are code-proven but depend on a product/deployment decision or are not reachable
through the current normal UI. They are recorded so they are not mistaken for settled behavior:

- **Ability class checks are unsafe for future generic authorization code.** CanCan rules for
  content classes use instance blocks (`app/models/ability.rb:59-81`); a guest class-level
  `authorize!(:read, Character)` can be allowed even though an instance check is denied. Current
  `UniverseAuthorization` passes concrete universe objects, so no active route bypass was found.
  The content-class registry is also hard-coded (`app/models/ability.rb:11-27`), while the documented
  new-model workflow does not explicitly require updating it.
- **Ownership-scope resolution now has one shared adapter.** `UniverseScopeResolver`
  (`app/models/universe_scope_resolver.rb`) answers which universe owns a record, and both
  `Ability#universe_for` and `ApplicationHelper#universe_for_record` delegate to it, so
  record-level authorization and rendered mutation controls cannot drift. It resolves a record
  through its own `#universe` or through a declared owner association (`story`, `scene`,
  `section`). Two limits remain: a model nested deeper than one of those must define its own
  `#universe` (otherwise it resolves to nothing and silently loses controls and checks), and the
  content-class registry in `app/models/ability.rb:11-28` is still hard-coded, so a new model must
  be added to it or CanCan will not match a rule for it at all.
- **Implicit owner access is missing from association APIs.** `User#universes` and
  `Universe#members` are membership-only associations (`app/models/user.rb:6-8`,
  `app/models/universe.rb:41-43`), while the owner is intentionally not stored as a membership row.
  The policy-aware `User#accessible_universes` and the membership view compensate manually
  (`app/models/user.rb:12-14`, `app/views/memberships/index.html.erb:64-70`); new code using the
  ordinary associations can omit owners and report incomplete access/collaboration data.
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

46. **Medium — the documented Timeline pan/zoom interaction is not implemented, and nodes lack an
    accessible name.** `docs/architecture.md:177-190` describes pan/zoom, but
    `app/javascript/controllers/timeline_controller.js:12-91` only redraws SVG lines and popovers;
    there are no pan, zoom, pointer, or transform handlers. Timeline nodes render only numeric IDs
    (`app/views/timeline/index.html.erb:31-46`) with no role or explanatory accessible label, and
    rely on hover/focus for popovers. Its unit test covers the drawn geometry; no keyboard, touch,
    resize, or interaction test covers this.

47. **Medium — the Event edit selector offers the event itself as a temporal reference.**
    `EventsController#index` puts all universe events in `@events_for_select`
    (`app/controllers/events_controller.rb:8-12`), and the modal renders all three reference selects
    without excluding the record being edited (`app/views/events/index.html.erb:112-127`). Selecting
    the current event is allowed by the browser but rejected by the model, producing a validation
    path that is not explained by the current Turbo/JSON UI.

48. **Medium — delegated admins can demote or remove themselves into a blank 403.** The membership
    UI permits changing/removing the current membership (`app/views/memberships/index.html.erb:73-96`).
    After the mutation redirects to the admin-only Members page, the same user no longer passes the
    admin authorization callback and receives a bodyless 403
    (`app/controllers/memberships_controller.rb:37-53`,
    `app/controllers/concerns/universe_authorization.rb:35-40`). There is no self-demotion browser
    or request test.

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
in [`backlog.md`](backlog.md), items 14–19. The report's claims that no `/up` route or JavaScript
lockfile exists are already stale: `config/routes.rb` exposes `/up`, and `bun.lock` is committed and
used with a frozen install in CI and Docker.

51. **Medium — production observability is minimal.** Production logs to tagged `STDOUT`, and the
    application now redacts password-reset path segments before request logging, but there is no
    structured request formatter, error-tracking integration, or metrics contract. The existing
    `/up` route and health-log silencing are useful foundations; they need a regression test and a
    deliberate privacy/redaction policy before external tracking or metrics are added. See backlog
    item 16.

52. **Medium — clean container onboarding is absent.** The repository has a production-oriented
    `Dockerfile` and a server entrypoint that runs `db:prepare`, but no root `docker-compose.yml`,
    devcontainer, or value-free `.env.example`. A fresh clone therefore still depends on the
    documented host toolchain, and there is no clean-checkout proof that the image, SQLite paths,
    CSS assets, and `/up` work together. The compose path must not run development data in
    production; see backlog item 15.

53. **Low/conditional — local demo and smoke-test credentials are literal values.** The LOTR
    development users contain literal passwords (`db/data/lotr/users.yml:1-6`), the Dark fixture
    users contain literal passwords (`db/data/dark/users.yml:1-10`), and
    `docs/smoke_test_stories.sh:17,28-29` documents/defaults a real-looking password. These are
    disposable fixtures rather than production credentials, but literals are easy to reuse and
    trigger security hygiene checks. Require an explicit environment value or generate a local
    value instead, while preserving the documented synthetic development login and load commands
    for manual verification. A value-free template is not a secret. The separate critical master-key
    rotation/history task remains open. See backlog item 17.

## Audit baseline and evidence

The following non-destructive checks passed during the 2026-09-24 re-audit. They are the evidence
behind the findings above, not a current capability list; the verification run for each later change
is recorded in [`resolved_quirks.md`](resolved_quirks.md).

- `bin/rails test` — 226 tests, 1,495 assertions, 0 failures/errors/skips.
- `bin/rails test:system` — 4 tests, 55 assertions, 0 failures/errors/skips, with the 406 caveat
  recorded in [`resolved_quirks.md`](resolved_quirks.md).
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
