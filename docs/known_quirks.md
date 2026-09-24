# Known Quirks & Tech Debt

Verified **open** oddities in this codebase — things that look like bugs, are bugs, or will
surprise you. Each entry was checked against the code (paths given); when one gets fixed, move
it to [resolved_quirks.md](resolved_quirks.md) instead of deleting it, so the fix history
survives. Index of all docs: [README.md](README.md).

This re-audit was performed on 2026-09-24 against commit `8fcf4d4`. It is an observation record
only: no application, test, configuration, dependency, or generated-asset fixes were made in this
pass. Any later documentation-only commit is not part of the audited code baseline. Severity labels
distinguish reachable security/data-loss issues from lower-priority hardening and contract decisions.

## Development workflow observations

4. **Disposable universe data is still coupled to `db:seed`.** `db/data/` is intentionally
   development-only: one subdirectory per universe (`dark/`, `lotr/`, and future universe slugs)
   contains the records used to exercise that universe. The current `dark` and `lotr` loaders use
   `create`/`create!`, and `db/seeds.rb` still loads a hardcoded `["dark", "lotr"]` list, so the
   loaders are not safe to rerun. The container entrypoint also runs `db:prepare` at server start,
   so a fresh production database can receive development users and data. The checked-in loader
   bypasses `MaintainsSiblingPositions`; the Dark YAML omits `position`, so sibling groups are
   seeded with the database default `0` rather than the documented contiguous positions. This is
   not a request to make temporary feature data production-idempotent; the intended fix is an
   explicit, environment-guarded development load/reset task that keeps `db/seeds.rb` production-safe.
   There is also no shared model/universe registry yet: the Dark order is local to
   `db/data/dark/dark.rb:3-22`, LOTR has a separate hand-written loader, and a new universe must be
   added to the hard-coded seed list. A new YAML file in an otherwise supported universe directory
   is not automatically loaded, and a missing file aborts the Dark loader at `YAML.load_file`.
   The current coupling is tracked as a transitional implementation gap in [ADR 0004](adr/0004-universe-data-and-demo-seeding.md).

## Critical security observations

5. **Critical — the Kamal master-key file is version-controlled.** `git ls-files` reports
   `.kamal/secrets`, and the file is not covered by `.gitignore`; `config/deploy.yml:39-42` uses
   that file to inject `RAILS_MASTER_KEY`. The audit confirmed a non-empty master-key assignment
   without reproducing its value. The file is mode `0644`, so anyone with repository or Git-history
   access may be able to decrypt `config/credentials.yml.enc` and forge Rails signed cookies,
   reset tokens, or other signed messages. Treat the value as exposed until the owner verifies and
   rotates it. No secret value is reproduced in this document.

8. **High — taxonomy edit modals have a stored DOM XSS path.** User-controlled taxonomy names are
   returned as option labels (`app/helpers/modal_fields.rb:3-13,173-195,327-349`). The Stimulus
   controller interpolates those labels into an HTML string and assigns it through `innerHTML`
   (`app/javascript/controllers/taxonomy_tree_controller.js:106-116,147-166`, especially line 157).
   Names are only presence-validated, and the application CSP is commented out
   (`config/initializers/content_security_policy.rb:7-29`). A name containing markup can create
   elements/event handlers when another writer or administrator opens a taxonomy edit modal. The
   page exposes a CSRF token (`app/views/layouts/application.html.erb:9`), so script execution can
   use the victim's authenticated browser for same-origin mutations. There is no hostile-name
   browser regression test.

9. **High — password-reset bearer tokens are written to request logs.** Reset tokens are URL path
   segments (`config/routes.rb:3`, `app/controllers/passwords_controller.rb:32-35`,
   `app/views/passwords_mailer/reset.html.erb:3`). `filter_parameter_logging` filters request
   parameters, not path segments, while production logs requests at info level
   (`config/initializers/filter_parameter_logging.rb:6-8`,
   `config/environments/production.rb:36-41`). A logged `GET` or failed `PUT` can therefore expose a
   still-valid reset token to anyone with log access. The audit did not reproduce any token value
   in this document.

10. **High when deployed — password-reset mail and URLs are placeholder configuration.**
    `PasswordsController#create` queues mail (`app/controllers/passwords_controller.rb:11-16`),
    but production uses the default SMTP target `localhost:25` and hardcodes
    `default_url_options = { host: "example.com" }` (`config/environments/production.rb:56-70`).
    `ApplicationMailer` also uses `from@example.com` (`app/mailers/application_mailer.rb:1-4`),
    and `config/deploy.yml` supplies no SMTP or application-host setting. On the committed
    production configuration, delivery is likely to fail and any externally delivered link points
    at the wrong host. The existing controller test only checks that a message was enqueued.

11. **High if no external TLS terminator is assumed — production transport is not enforced.**
    The Kamal proxy/SSL block is commented out (`config/deploy.yml:16-25`), as are
    `config.assume_ssl` and `config.force_ssl` (`config/environments/production.rb:27-34`); the
    runtime host allowlist is empty (`production.rb:82-89`), and the container exposes port 80
    (`Dockerfile:77-83`). The signed authentication cookie is written without `secure: true`
    (`app/controllers/concerns/authentication.rb:41-45`). Unless an external proxy supplies strict
    HTTPS, sessions and password-reset tokens can travel over cleartext HTTP and the application
    does not redirect to HTTPS or set HSTS.

12. **Medium — sessions have no application-enforced expiry or source binding.** Login creates a
    permanent cookie and stores only its session ID (`app/controllers/concerns/authentication.rb:41-45`).
    The `sessions` table has no expiry or last-used field (`db/schema.rb:262-269`,
    `app/models/session.rb:1-3`), and lookup validates neither the recorded IP address nor user
    agent (`authentication.rb:24-30,42`). A stolen cookie remains usable until logout, password
    reset, or user deletion, and old rows have no cleanup path. No session-expiration or
    cookie-attribute tests exist.

16. **High safety issue — `db:restart` has no environment guard.** `lib/tasks/db.rake:1-9` invokes
    `db:drop`, `db:create`, `db:migrate`, and `db:seed` without checking `Rails.env` or requiring an
    explicit destructive-operation acknowledgement. The task description says “development DB,” but
    `RAILS_ENV=production bin/rails db:restart` is not prevented by the task itself. This is separate
    from the known seed coupling above and is especially important before adding features.

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

18. **Medium — mutation validation failures are silent.** The taxonomy Stimulus controller returns
    immediately for every non-OK response and has no network-error handling
    (`app/javascript/controllers/taxonomy_tree_controller.js:129-145,205-265`). Relation and
    ownership failures re-render their indexes, but neither view renders the model's errors or
    preserves the invalid form (`app/controllers/relations_controller.rb:13-29`,
    `app/controllers/ownerships_controller.rb:13-29`, and their index views). Users receive a 422 or
    stale page with no explanation. Request tests do not cover the error UI.

19. **Medium — nonexistent optional association IDs escape the JSON error contract.** Hierarchical
    parents and event temporal references are optional, but an unknown ID can pass model validation
    and reach a database foreign-key exception (`app/models/concerns/hierarchical.rb:5,54-68`,
    `app/models/event.rb:11-13,55-58`). The shared controller only rescues `RecordNotFound` and
    `CanCan::AccessDenied` (`app/controllers/application_controller.rb:20-25`), so malformed
    `parent_id`, `before_event_id`, `after_event_id`, or `simultaneous_event_id` values can become
    500s instead of documented 422 error hashes. No such request tests exist.

20. **Medium — generated routes advertise unsupported actions and templates.** `config/routes.rb:2-25`
    uses broad session, password, and content resources even though the documented action surface is
    narrower (`docs/universe_maker_conventions.md:63-66`). Examples include missing
    `sessions#show/edit/update`, `passwords#index/show/destroy`, content `show/edit` actions, and
    `new` routes whose controllers have no templates. The route table contains dozens of entries
    that cannot render a supported page; direct requests can produce 404, unsupported-format, or
    missing-template responses. The existing route test checks positional helper arguments, not
    route/action/template contracts.

21. **Medium — changing an owning scope does not migrate dependent graphs.** The hierarchy validator
    checks the current record's parent but not descendants or relationship endpoints
    (`app/models/concerns/hierarchical.rb:40-69`). A model probe moved a parent location to another
    universe while its child remained in the old universe. The same pattern applies to character
    relations/ownerships, section trees, and story-scoped tags. Web controllers do not currently
    permit scope IDs, so this is primarily a model/import/console/association-API hazard, but it
    violates the graph-wide scope rules in ADR 0001 and the cache tests currently move only
    unassociated records.

22. **Medium — sibling positions are not a maintained invariant.** `MaintainsSiblingPositions`
    normalizes during controller updates but destroy actions call `destroy!` directly, leaving gaps
    (`app/controllers/concerns/maintains_sibling_positions.rb:12-35`). There is no transaction,
    lock, unique position index, or database constraint for concurrent creates/moves; partial
    `update_columns` normalization can also leave inconsistent positions. The current development
    data loader bypasses the concern and seeds sibling groups with duplicate default positions.
    Existing tests cover a move and cache invalidation, not destruction, concurrency, or seeded
    positions.

23. **Medium — HABTM join tables have no database integrity constraints.** All seven join tables
    contain only two integer columns and no indexes, foreign keys, or uniqueness constraints (for
    example `db/schema.rb:42-45,84-87,117-120,150-153,186-189,224-227,257-260`; the migrations use
    bare `create_join_table`, e.g. `db/migrate/20260923130012_create_characters.rb:14`). Direct SQL,
    imports, failed association replacement, or duplicate IDs can create orphan/duplicate join rows.
    Scoped association reads prevent foreign tags from being disclosed through ordinary model/view
    paths, and controller saves roll back rejected ID replacements. A direct HABTM collection
    writer can still write a join row before a later validation failure, however, because the
    database has no constraints to reject it.

24. **Medium — Timeline output can contradict its layer ordering.** `TimelineLayout` rejects an
    edge that would create a cycle (`app/models/timeline_layout.rb:33-40`), but later rebuilds
    `@edges` directly from raw event associations (`:103-115`). A valid model state with dates
    ordering A before B and `B.before_event = A` produces layers with A above B while the view
    receives a B-to-A sequence edge. The view renders those edges directly
    (`app/views/timeline/index.html.erb:3,31-45`). The model has no temporal-consistency validation
    for this contradiction, and timeline tests do not cover conflicting dates/relations.

25. **Low — blank password-reset submissions are reported as successful.** `has_secure_password`
    ignores an empty string, so `@user.update` can return true while retaining the old digest;
    `PasswordsController#update` then destroys all sessions and reports success
    (`app/controllers/passwords_controller.rb:22-28`). The HTML form marks the fields required, but
    an API/malformed request can still trigger the false-success path. No blank-reset test exists.

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

30. **Low — JSON/field contracts have several silent omissions.** `SectionsController#section_json`
    omits `position` (`app/controllers/sections_controller.rb:80-88`), Relation/Ownership parameter
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

32. **Medium — the green system suite masks a failed mutation response.** The four system tests
    (55 assertions) pass, but the Character modal request is processed as `TURBO_STREAM`, commits,
    and returns 406. The test asserts the reloaded DOM and never checks response status or error UI.
    There is no browser coverage for Item/Event modals, taxonomy CRUD/drag/drop, relations,
    ownerships, memberships, password reset, mobile breakpoints, or keyboard behavior.

33. **Medium — JavaScript has no test/lint pipeline and test mode disables CSRF.** `package.json:16-20`
    has only CSS build/watch scripts and there are no JavaScript test/spec files, despite the
    security-sensitive code living in Stimulus controllers. `config/environments/test.rb:28-29`
    disables forgery protection, so system tests do not verify that fetch requests carry valid CSRF
    tokens. Brakeman's clean result does not inspect the client-side `innerHTML` path.

34. **Medium — dependency auditing does not cover the vendored/runtime JavaScript asset.**
    `config/importmap.rb:9` pins `vendor/javascript/tom-select.js` without version metadata, and
    `bin/importmap audit` explicitly reports that it ignores the vendored package. The Bun/npm
    dependency graph is not audited in CI, and `.github/dependabot.yml:1-12` has no JavaScript/Bun
    or Docker ecosystem entry. A local `bun audit` currently reports no vulnerabilities, but that
    check is absent from the workflow.

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
    untested.

37. **Low — development fixtures and documentation overstate baseline coverage.**
    `docs/development.md:42-44` says all content and tag fixtures are present, but relation,
    ownership, relation-tag, ownership-tag, and membership fixture files are absent; tests create
    many of those records ad hoc. `docs/README.md:19` and `docs/data_model.md:207` link to missing
    `docs/schema.txt`, and `docs/README.md:23` advertises an absent `docs/images-to-ai/` directory.
    The development guide also calls `test/helpers` and mailer previews effectively empty even though
    `test/helpers/application_helper_test.rb` and a mailer preview are present. The root README presents
    `db:restart` without the explicit approval warning present in `AGENTS.md` and
    `docs/development.md`.

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
- **Section-owned models need an undocumented authorization/helper adapter.** The new-model contract
  permits a section ownership scope (`docs/development.md:227-228`), but `Ability#universe_for` and
  `ApplicationHelper#universe_for_record` only understand direct `universe` or `story` ownership
  (`app/models/ability.rb:96-101`, `app/helpers/application_helper.rb:72-77`). A section-owned model
  can therefore resolve to no universe and lose read/write UI and authorization unless it supplies
  custom delegation/handling.
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
- **Development symbolic references are globally resolved.** `db/data/dark/dark.rb:24-37` and
  `HasSlug.method_missing` look up slugs without a universe/story qualifier. The checked-in data
  currently avoids collisions, but duplicate slugs across universe directories could resolve to
  the wrong record; loader scope validation is still missing.
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

41. **Medium — taxonomy tree updates do not refresh all dependent UI state.** Inline create/delete
    operations update the tree DOM but not the page-header count, sidebar count, or serialized
    parent/tag option descriptors (`app/javascript/controllers/taxonomy_tree_controller.js:205-222,256-265`,
    `app/views/shared/_taxonomy_tree.html.erb:22-37`, `app/views/layouts/_left_sidebar.html.erb:1-2`).
    Counts can remain stale until navigation, and a later edit modal can show deleted or outdated
    options. No browser test performs tree CRUD and then reopens an editor or checks counts.

42. **Medium — insertion between a subtree and the next root can choose the wrong parent.**
    `insertAt` uses the previous node in the flattened preorder list as its anchor
    (`app/javascript/controllers/taxonomy_tree_controller.js:34-60`). After a root with children,
    the previous node is the last descendant, so the visual root-level insertion can create a child
    under that descendant instead of a root sibling. No boundary-case browser test exists.

43. **Medium — newly created taxonomy nodes lose inline rename and keyboard semantics.** The
    server-rendered name span has `role="button"`, `tabindex="0"`, and click/Enter actions
    (`app/views/shared/_taxonomy_node.html.erb:27-34`), but `buildNode()` omits all three
    (`app/javascript/controllers/taxonomy_tree_controller.js:294-312`). A node created through the
    inline form is not immediately renameable by clicking or keyboard; the overflow Edit action
    still works. The server-rendered control also responds to Enter but not Space.

44. **Medium — touch users cannot use the taxonomy insertion separators or reorder the tree.** The
    separator buttons are hidden with `opacity: 0` and `pointer-events: none` until hover/focus, and
    the touch media query exposes `.taxonomy-actions` but not `.taxonomy-separator-add`
    (`app/assets/stylesheets/_taxonomy_tree.scss:41-77,104-109`). Reordering is HTML5-drag based with
    no touch or keyboard alternative. System tests use a desktop viewport only.

45. **Medium — read-only empty taxonomy pages still instruct users to add or drag records.** The
    shared partial has a read-only empty-state fallback, but Locations, Sections, and taxonomy views
    pass explicit copy containing “Add”/“drag” instructions (for example
    `app/views/locations/index.html.erb:15`, `sections/index.html.erb:15`, and
    `character_tags/index.html.erb:17`). Guests and read-only members see mutation instructions even
    though no mutation controls are rendered.

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

50. **Low — dynamic taxonomy modal semantics and dead PWA/UI assets drift from the conventions.**
    The dynamic modal uses an `<h1>` while static modals use `<h2>`, and `required_unless` is treated
    as a visible required label even when the symmetric checkbox makes the field optional
    (`app/javascript/controllers/taxonomy_tree_controller.js:106-113,147-165`,
    `app/helpers/modal_fields.rb:241-281`). `app/views/pwa/manifest.json.erb` and
    `app/views/pwa/service-worker.js` have no route or layout link, and the PWA palette contains a
    `red` value that does not match the documented theme. These are low-priority cleanup/style
    inconsistencies.

## Audit evidence and clean checks

The following non-destructive checks passed during this pass:

- `bin/rails test` — 226 tests, 1,495 assertions, 0 failures/errors/skips.
- `bin/rails test:system` — 4 tests, 55 assertions, 0 failures/errors/skips, with the 406 caveat in
  finding 32.
- `bin/rubocop` — 158 files, no offenses.
- `bin/brakeman --no-pager` — 0 security warnings; it does not cover the client-side DOM XSS path.
- `bin/bundler-audit` — no known vulnerabilities.
- `bin/importmap audit` — no reported vulnerabilities, but it explicitly ignored vendored Tom Select
  as described above.
- `bun audit` — no current vulnerabilities across 97 packages; not part of CI.
- `bin/rails db:migrate:status` — all application migrations up.
- `git diff --check` and final `git status` — clean before this documentation-only edit.

Not run: destructive development tasks (`db:restart`, `db:reset`, `db:drop`, `db:seed`,
`db:seed:replant`), demo-data loaders, Docker/Kamal deployment, production SMTP delivery, a clean
migration-from-zero job, or a live hostile-browser exploit. No production data or secret value was
modified as part of documenting these findings; disposable test probes were rolled back or cleaned.
