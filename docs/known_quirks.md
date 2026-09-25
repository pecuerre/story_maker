# Known Quirks & Tech Debt

Verified **open** oddities in this codebase — things that look like bugs, are bugs, or will
surprise you. Each entry was checked against the code (paths given); when one gets fixed, move
it to [resolved_quirks.md](resolved_quirks.md) instead of deleting it, so the fix history
survives. Index of all docs: [README.md](README.md).

This re-audit was performed on 2026-09-24 against commit `8fcf4d4`. It is an observation record
only: no application, test, configuration, dependency, or generated-asset fixes were made in this
pass. Any later documentation-only commit is not part of the audited code baseline. The separate
DataFactor follow-up section below was checked against the current tree on 2026-09-25; it is not a
full replacement for the original audit. Severity labels distinguish reachable security/data-loss
issues from lower-priority hardening and contract decisions.

## Development workflow observations

The former disposable-data coupling and unguarded reset findings were rechecked and resolved on
2026-09-25. They are preserved in [resolved_quirks.md](resolved_quirks.md); the current loader is
`Development::UniverseDataLoader` with registry-driven, environment-guarded tasks.

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

Former finding **#8** was fixed by constructing taxonomy fields and nodes with DOM APIs, assigning
user-controlled values as text/attributes, and adding hostile-name browser regressions. The
resolution is recorded in [`resolved_quirks.md`](resolved_quirks.md).

Former finding **#9** was fixed for Rails application request logs by
`lib/password_reset_path_filter.rb`; password-reset pages also set `no-store` and `no-referrer`.
The path-token redaction, tests, and residual upstream proxy/browser-history risk are recorded in
[`resolved_quirks.md`](resolved_quirks.md).

Former finding **#10** was fixed by requiring explicit production host, sender, and SMTP settings,
using HTTPS mailer URLs, and testing the rendered multipart message. Live provider delivery remains
an external deployment verification and is documented in [`development.md`](development.md). The
resolution is recorded in [`resolved_quirks.md`](resolved_quirks.md).

Former finding **#11** was fixed in the Rails production boundary by enabling `assume_ssl` and
`force_ssl`, setting the session cookie `Secure`, restricting the host allowlist, and preserving
the `/up` exception. A real TLS-terminating proxy and deployment smoke test remain external
verification requirements. The resolution is recorded in [`resolved_quirks.md`](resolved_quirks.md).

12. **Medium — sessions have no application-enforced expiry or source binding.** Login creates a
    permanent cookie and stores only its session ID (`app/controllers/concerns/authentication.rb:41-50`).
    The `sessions` table has no expiry or last-used field (`db/schema.rb:265-272`,
    `app/models/session.rb:1-3`), and lookup validates neither the recorded IP address nor user
    agent (`authentication.rb:24-30,42`). A stolen cookie remains usable until logout, password
    reset, or user deletion, and old rows have no cleanup path. Basic cookie flags now have a
    request regression, but no idle/absolute expiration policy or source-binding test exists.

## Mutation, route, and data-contract observations

17. **High — flat Character/Item/Event modals submit HTML to JSON-only endpoints.** Their forms are
    ordinary Turbo forms (`app/views/characters/index.html.erb:80-103`,
    `app/views/items/index.html.erb:80-102`, `app/views/events/index.html.erb:78-135`), and
    `modal_form_controller.js:16-61` changes the action/method but does not fetch JSON or set an
    `Accept` header. The controllers define only `format.json` branches
    (`app/controllers/characters_controller.rb:24-34`, `items_controller.rb:24-34`,
    `events_controller.rb:20-47`). A browser create/update is saved and then answered with 406
    `ActionController::UnknownFormat`; retrying can create duplicates, and validation errors do not
    reach the UI. The green system test checks the row after a subsequent GET rather than the
    mutation response (`test/system/workspace_navigation_test.rb:32-43`).

18. **Medium — mutation validation failures are still not rendered in every editor.** The taxonomy
    controller now announces non-OK/network failures and keeps the form open, but it does not yet
    render the server's field-error hash. Relation and ownership failures still re-render their
    indexes without a model error summary or preserved invalid form
    (`app/controllers/relations_controller.rb:13-29`,
    `app/controllers/ownerships_controller.rb:13-29`, and their index views). Request tests do not
    cover the complete error UI.

19. **Medium — nonexistent optional association IDs escape the JSON error contract.** Hierarchical
    parents and event temporal references are optional, but an unknown ID can pass model validation
    and reach a database foreign-key exception (`app/models/concerns/hierarchical.rb:5,54-68`,
    `app/models/event.rb:11-13,55-58`). The shared controller only rescues `RecordNotFound` and
    `CanCan::AccessDenied` (`app/controllers/application_controller.rb:20-25`), so malformed
    `parent_id`, `before_event_id`, `after_event_id`, or `simultaneous_event_id` values can become
    500s instead of documented 422 error hashes. No such request tests exist.
    **Scenes are now covered** (slices 11.2/11.3): `Scene` validates `optional_references_exist`,
    `section_belongs_to_story`, and `event_belongs_to_story_universe`, and
    `datetime_is_a_valid_point` rejects an unparseable in-world time that Active Record would
    otherwise cast to `nil` and silently discard, so those values render `422` field errors with the
    submitted input preserved. The `#group` action instead resolves the Section through
    `@story.sections.find`, making a foreign or unknown target a `404`. Slice 11.4 also adds
    collection-id guards on Scene/Scene Tag assignment, so unknown, duplicate, and cross-story tag
    ids become ordinary validation errors before the constrained join can raise. The remaining
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

21. **Medium — changing an owning scope does not migrate dependent graphs.** The hierarchy validator
    checks the current record's parent but not descendants or relationship endpoints
    (`app/models/concerns/hierarchical.rb:40-69`). A model probe moved a parent location to another
    universe while its child remained in the old universe. The same pattern applies to character
    relations/ownerships, section trees, and story-scoped tags. Web controllers do not currently
    permit scope IDs, so this is primarily a model/import/console/association-API hazard, but it
    violates the graph-wide scope rules in ADR 0001 and the cache tests currently move only
    unassociated records.

22. **Medium — raw SQL/import and flat direct-model paths can still bypass ordered-position
    maintenance.** The controller-facing `PositionedResourceOrder` service now transactionally
    handles create, move, reparent, and destroy for current positioned controllers, and the
    `Hierarchical` callback closes gaps after direct hierarchical destroys. Slice 11.1 added the
    flat Story-owned `Scene` sequence, which is normalized only when a mutation goes through
    `ScenesController`; unlike `Hierarchical`, `Scene` has no model callback that repairs positions
    after a direct destroy. Direct SQL, association manipulation, and direct-model writes therefore
    still bypass the service for both hierarchies and flat sequences, and SQLite has no
    portable row-lock/unique-position guarantee. Do not treat those paths as normalized without an
    explicit import/console workflow; see ADR 0009 and [`resolved_quirks.md`](resolved_quirks.md).

23. **Medium — legacy HABTM join tables have no database integrity constraints.** The seven
    pre-Scene join tables contain only two integer columns and no indexes, foreign keys, or
    uniqueness constraints (for example `db/schema.rb:42-45,84-87,117-120,150-153,186-189,224-227`;
    the migrations use bare `create_join_table`, e.g.
    `db/migrate/20260923130012_create_characters.rb:14`). The new `scenes_scene_tags` table is the
    exception: it has real Scene/SceneTag foreign keys and a unique pair index. Direct SQL,
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

Former finding **#25** was fixed: blank reset submissions now use strong parameter expectations and
return a bad-request response without changing the password digest or destroying sessions. The
resolution and test are recorded in [`resolved_quirks.md`](resolved_quirks.md).

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
    `group(:section_id).count`, and the universe page reuses the navbar's memoized story list
    instead of re-counting. The row-level authorization and recursive-children costs above are
    unchanged.

32. **Medium — the existing flat-list system smoke test still masks a failed mutation response.**
    The Character modal request is processed as `TURBO_STREAM`, commits, and returns 406; the test
    asserts the reloaded DOM and never checks response status or error UI. The taxonomy editor now
    has focused CRUD/XSS/accessibility browser coverage, but there is still no browser coverage for
    Item/Event modals, relations, ownerships, memberships, password reset, or mobile behavior for
    those flat lists.

33. **Medium — JavaScript has no test/lint pipeline and test mode disables CSRF.** `package.json:16-20`
    has only CSS build/watch scripts and there are no JavaScript unit/spec files, despite the
    security-sensitive code living in Stimulus controllers. `config/environments/test.rb:28-29`
    disables forgery protection, so system tests do not verify that fetch requests carry valid CSRF
    tokens. Brakeman's clean result does not inspect client-side DOM behavior; the new taxonomy
    hostile-name browser test covers that specific sink but not the entire JavaScript surface.

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
    `db:test:prepare test` against the checked-in schema (`.github/workflows/ci.yml:97-103`), not a
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
- **Accessibility invariants are not fully represented in the navbar/tree.** Current universe/story
  dropdown items use visual `.active` classes without `aria-current` on the links
  (`app/views/layouts/_navbar.html.erb:23-27,48-51,69-74`), and drag/drop reordering has no keyboard
  equivalent (`app/javascript/controllers/taxonomy_tree_controller.js:367-455`). User-selected tag
  colors are format-validated but not contrast-validated (`app/models/concerns/has_color.rb:4-7`).
  These are review items for new UI work rather than security findings.
- **Framework routes are broader than the current domain.** `config/application.rb:3` loads
  `rails/all`, exposing unused Active Storage/Action Mailbox/Action Text routes. Their default
  protections reduce immediate risk, but the application has no route allowlist or production
  route-surface check.

## Additional UI and interaction observations

40. **Medium — flat-list deletes leave stale rows in the current DOM.** The shared delete control is
    a Turbo `button_to` (`app/views/shared/_row_actions.html.erb:30-35`), while Character/Item/Event
    destroy actions return a bare `204` (`app/controllers/characters_controller.rb:47-50`,
    `items_controller.rb:47-50`, `events_controller.rb:43-46`). Turbo receives no redirect or HTML
    replacement, so the deleted row and sidebar count can remain visible until a manual reload; a
    second click can then target a missing record. There is no browser delete regression test.
    The Scene list added in slice 11.1 is **not** affected: it uses the HTML redirect flow
    (`ScenesController#destroy` redirects with `303`), so its delete regression test is
    `test/system/scene_narrative_order_test.rb`. Findings 17 and 18 still apply to every
    modal/JSON consumer and remain the reason slice 11.5 must land before Scene Elements exist.

Former findings **#41–#44** were fixed in the taxonomy hardening pass. Successful mutations now
refresh server-rendered descriptors/counts, boundary insertion uses the actual list, native rename
buttons support Enter/Space, and Move/Insert controls plus touch-visible separators provide
non-drag paths. The resolutions and browser coverage are recorded in
[`resolved_quirks.md`](resolved_quirks.md).

45. **Medium — read-only empty taxonomy pages still instruct users to add or drag records.** The
    shared partial has a read-only empty-state fallback, but Locations and taxonomy views pass
    explicit copy containing “Add”/“drag” instructions (for example
    `app/views/locations/index.html.erb:15` and `app/views/character_tags/index.html.erb:17`).
    Guests and read-only members see mutation instructions even
    though no mutation controls are rendered. The Sections workspace was fixed in slice 11.3 by
    passing both `empty_description` and the new `read_only_empty_description` local; the remaining
    callers still need it.

46. **Medium — the documented Timeline pan/zoom interaction is not implemented, and nodes lack an
    accessible name.** `docs/architecture.md:177-190` describes pan/zoom, but
    `app/javascript/controllers/timeline_controller.js:12-57` only redraws SVG lines and popovers;
    there are no pan, zoom, pointer, or transform handlers. Timeline nodes render only numeric IDs
    (`app/views/timeline/index.html.erb:31-46`) with no role or explanatory accessible label, and
    rely on hover/focus for popovers. No keyboard, touch, resize, or interaction test covers this.

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

54. **Low — taxonomy field-builder duplication creates maintenance drift risk.** The DataFactor
    report identified repeated per-type descriptor logic in `app/helpers/modal_fields.rb` and
    `app/helpers/tags_helper.rb`. The current small-file profile is otherwise a strength, so this
    is a refactoring opportunity rather than a correctness finding. Characterize the serialized
    field/JSON and form contracts before extracting shared declarative behavior; see backlog item
    19.


The following non-destructive checks passed during this pass:

- `bin/rails test` — 226 tests, 1,495 assertions, 0 failures/errors/skips.
- `bin/rails test:system` — 4 tests, 55 assertions, 0 failures/errors/skips, with the 406 caveat in
  finding 32.
- `bin/rubocop` — 158 files, no offenses.
- `bin/brakeman --no-pager` — 0 security warnings; it does not cover the client-side DOM XSS path.
- `bin/bundler-audit` — no known vulnerabilities.
- `bin/importmap audit` — no reported vulnerabilities; at this checkpoint it explicitly ignored
  vendored Tom Select (fixed in the follow-up below).
- `bun audit` — no current vulnerabilities across 97 packages; not part of CI.
- `bin/rails db:migrate:status` — all application migrations up.
- `git diff --check` and final `git status` — clean before this documentation-only edit.

Not run: destructive development tasks (`db:restart`, `db:reset`, `db:drop`, `db:seed`,
`db:seed:replant`), demo-data loaders, Docker/Kamal deployment, production SMTP delivery, a clean
migration-from-zero job, or a live hostile-browser exploit. No production data or secret value was
modified as part of documenting these findings; disposable test probes were rolled back or cleaned.

## Follow-up verification (2026-09-25)

The explicit development-data loader follow-up was verified after ADR 0008:

- `bin/rails test` — 280 tests, 1,701 assertions, 0 failures/errors/skips.
- `bin/rubocop` — 166 files, no offenses.
- `bin/brakeman --no-pager` — 0 security warnings.
- `bin/bundler-audit` — no known vulnerabilities.
- `bin/importmap audit` — no reported vulnerabilities; at this checkpoint vendored Tom Select
  remained ignored (fixed in the follow-up below).
- `UNIVERSE=dark bin/rails db:demo:check` and `UNIVERSE=lotr bin/rails db:demo:check` passed in
  development and test environments.
- `RAILS_ENV=test bin/rails db:seed` passed without loading development data.

Destructive `db:demo:reset`, `db:restart`, Docker/Kamal deployment, production SMTP delivery, a clean
migration-from-zero job, and a live hostile-browser exploit were not run. The loader's transactional
load and rollback paths were covered in the test environment instead.

## Follow-up verification (2026-09-25, Tom Select audit metadata)

The local Tom Select pin was annotated with its locked version and the importmap regression test
was added:

- `bin/importmap packages` reports `tom-select 2.6.2`.
- `bin/importmap audit` reports no vulnerable packages and no longer prints an
  `Ignoring tom-select` notice.
- `bin/rails test test/importmap_audit_test.rb` — 1 test, 4 assertions, 0 failures/errors/skips.
- `bin/rails test` — 281 tests, 1,707 assertions, 0 failures/errors/skips.
- `bin/rubocop` — 167 files, no offenses.
- `bin/brakeman --no-pager` — 0 security warnings.
- `bin/bundler-audit` — no known vulnerabilities.
- `git diff --check` — clean.

The broader Bun/npm graph audit, vendored-file provenance verification, and Dependabot coverage
remain open under backlog item 18. No destructive database, container, deployment, or browser
operations were run for this tooling-only fix.

## Follow-up verification (2026-09-25, ordering/security/taxonomy hardening)

- `bin/rails test` — 300 tests, 1,781 assertions, 0 failures/errors/skips.
- `bin/rails test:system` — 10 tests, 107 assertions, 0 failures/errors/skips, including the new
  taxonomy hostile-name, stale-state, boundary insertion, keyboard, and narrow/touch coverage.
- `bin/rubocop` — 173 files, no offenses.
- `node --check app/javascript/controllers/taxonomy_tree_controller.js` — passed.
- A production-configuration smoke boot with dummy non-secret settings confirmed HTTPS mailer URL
  options, `force_ssl`, `assume_ssl`, SMTP address, and the production host allowlist. Missing
  `APP_HOST` fails with only the variable name in the error.
- Password-reset path filtering, multipart mail rendering, cookie flags, ordering service, and
  loader tests passed. No destructive database task, Docker/Kamal deployment, real SMTP delivery,
  credential rotation, Git-history rewrite, or proxy/log-retention verification was performed.

## Follow-up verification (2026-09-25, Scene core slice 11.1)

- `bin/rails test` — 341 tests, 2,034 assertions, 0 failures/errors/skips.
- `bin/rails test:system` — 12 tests, 151 assertions, 0 failures/errors/skips, including the new
  Scene narrative-order and read-only browser coverage.
- `bin/rubocop` — 179 files, no offenses.
- `bin/brakeman --no-pager` — 0 security warnings.
- `UNIVERSE=dark bin/rails db:demo:check` and `UNIVERSE=lotr bin/rails db:demo:check` passed in the
  test environment with the new `scenes.yml` manifests.
- `bin/rails db:migrate` applied the schema-only `CreateScenes` migration and regenerated
  `db/schema.rb`; no data operations were added to the migration.

Not run: `bin/bundler-audit`, `bin/importmap audit`, `bun audit` (no dependency or JavaScript pin
changed in this slice), `db:demo:reset`/`db:demo:load` (destructive, needs approval), a browser
manual pass against loaded development data, Docker/Kamal deployment, and any production SMTP or
proxy verification.

## Follow-up verification (2026-09-25, Scene references and grouping slices 11.2/11.3)

- `bin/rails test` — 405 tests, 2,344 assertions, 1 failure. The single failure is pre-existing and
  unrelated: `UniverseDataLoaderTest#test_loads_the_Dark_universe_and_normalizes_sibling_positions`
  still expects the story name `netflix dark` after commit `0a236a9` renamed it to `Netflix Dark`
  in `db/data/dark/stories.yml`. It was already failing on a clean tree before this work.
- `bin/rails test:system` — 16 tests, 202 assertions, 0 failures/errors/skips, including the new
  Scene Section-grouping, in-world-time, narrow-viewport with a long title/description,
  keyboard-only, and read-only coverage.
- `bin/rubocop` — 187 files, no offenses.
- `bin/brakeman --no-pager` — 0 security warnings.
- `node --check app/javascript/controllers/taxonomy_tree_controller.js` — passed.
- `UNIVERSE=dark bin/rails db:demo:check` and `UNIVERSE=lotr bin/rails db:demo:check` passed in
  development with the new `scenes.yml` references.
- `CONFIRM_DB_RESET=1 UNIVERSE=dark bin/rails db:demo:reset` and `UNIVERSE=lotr bin/rails
  db:demo:load` rebuilt the local development database from the amended/added migrations, and the
  loaded Dark and LOTR universes were queried to confirm the section paths, event links, and
  independent in-world times. `bin/rails db:migrate:status` shows both Scene migrations applied.

Not run: `bin/bundler-audit`, `bin/importmap audit`, `bun audit` (no dependency or importmap pin
changed in these slices), Docker/Kamal deployment, production SMTP delivery, proxy/log-retention
verification, and a browser manual pass against the reloaded development data. No destructive task
was run beyond the standing `db:demo:reset` approval.

## Follow-up verification (2026-09-25, Scene Tag slice 11.4)

- `bin/rails test` — 440 tests, 2,544 assertions, 1 failure. The remaining failure is the
  pre-existing Dark story-name expectation documented above; the new Scene Tag model, request,
  assignment, loader, authorization, routing, and helper coverage passed.
- `bin/rails test:system` — 18 tests, 225 assertions, 0 failures/errors/skips on the final
  run with a temporary 10-second Capybara wait; the default two-second wait intermittently timed
  out under local browser load. The focused Scene Tag browser file passed with the default wait.
  Coverage includes the Scene Tag taxonomy create/assign journey and read-only path.
- `bin/rubocop` — 196 files, no offenses.
- `bin/brakeman --no-pager` — 0 security warnings; `bin/bundler-audit`, `bin/importmap audit`, and
  `bun audit` reported no vulnerabilities.
- `UNIVERSE=dark bin/rails db:demo:check` and `UNIVERSE=lotr bin/rails db:demo:check` passed. The
  local development database was rebuilt with the approved Dark reset and LOTR create-only load;
  queries confirmed 8 Dark/5 LOTR Scenes, 4 Scene Tags per Story, nested tags, and tagged/untagged
  Scene assignments. `bin/rails db:migrate:status` shows `CreateSceneTags` applied.
- `git diff --check` — clean.

Not run: Docker/Kamal deployment or boot, production SMTP delivery, proxy/log-retention
verification, and a separate manual browser pass outside the automated system suite. The only
known full-suite failure is the pre-existing `UniverseDataLoaderTest` Dark story-name expectation
recorded in the 11.2/11.3 verification section.

## Follow-up verification (2026-09-25, Dark story-name test fix)

- `bin/rails test` — 440 tests, 2,552 assertions, 0 failures, 0 errors, 0 skips. This clears the
  standing failure recorded in the 11.2/11.3 and 11.4 verification sections above. The assertion
  count rose by 8 because the previously failing test aborted at its first bad expectation and
  never ran its remaining assertions.
- Root cause: commit `0a236a9` renamed the `dark` universe's development story to `Netflix Dark`
  in `db/data/dark/stories.yml` but wrote the loader test expectation as the lowercase
  `netflix dark`. The manifest value was always correct, so only the assertion was changed. No
  application code, schema, or demo data was touched.
- `UNIVERSE=dark bin/rails db:demo:check` passed; no YAML manifest changed, so the local
  development database did not need a rebuild.

Not run: `bin/rails test:system` (no behavior, view, or JavaScript change), `bin/rubocop`,
`bin/brakeman`, the dependency audits, `db:demo:reset`/`db:demo:load` (destructive, needs
approval), and Docker/Kamal deployment. `db:demo:check` was re-run for the test-only change
because the assertion reads the checked-in Dark manifest.

## Follow-up verification (2026-09-25, cssbundling rake constant warnings)

- `bin/rails test` — 440 tests, 2,552 assertions, 0 failures, 0 errors, 0 skips, run three
  consecutive times with no `already initialized constant` output. The count is unchanged from the
  Dark story-name fix above; this change only removes the noise.
- `bin/rubocop` — 196 files, no offenses.
- Root cause was in the test suite, not the gem. `DevelopmentDataTasksTest`'s `setup` block called
  `Rails.application.load_tasks` before each of its three tests. That re-runs the Rakefile and
  re-loads every bundled gem's rake file, and `cssbundling-rails` 1.4.3's
  `lib/tasks/cssbundling/build.rake` assigns `Cssbundling::Tasks::LOCK_FILES` without an
  idempotency guard, so every re-load re-defined the constant and warned. Because the parallel
  test workers are separate processes that start with an empty Rake registry, the
  `unless Rake::Task.task_defined?("db:demo:check")` guard never short-circuited and the number of
  warnings varied run to run.
- Fix: the test now loads only this application's own `lib/tasks/**/*.rake`, memoized once per
  process, which is the only thing it asserts about. Gem rake files are never loaded, so no gem
  constant is redefined. `db:demo:check`, `db:demo:load`, and `db:demo:reset` are still registered
  and asserted exactly as before.
- Not a gem upgrade: `cssbundling-rails` stays pinned at 1.4.3, because the application never
  double-loads rake tasks in normal operation. Fixing the constant redefinition inside the gem was
  judged out of scope.

Not run: `bin/rails test:system`, `bin/brakeman`, `bin/bundler-audit`, `bin/importmap audit`,
`bun audit` (no behavior, view, JavaScript, dependency, or schema change), and Docker/Kamal
deployment.
