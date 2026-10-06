# Known Quirks & Tech Debt

Verified **open** oddities in this codebase — things that look like bugs, are bugs, or will
surprise you. This file holds only open findings: when one is fixed, the whole entry moves to
[delivery_history.md](delivery_history.md) with the history of the fix, and no "this used to be broken"
note is left behind here. Index of all docs: [README.md](README.md).

This re-audit was performed on 2026-09-24 against commit `8fcf4d4`. It is an observation record
only: no application, test, configuration, dependency, or generated-asset fixes were made in this
pass. The separate DataFactor follow-up section below was checked against the current tree on
2026-09-25; it is not a full replacement for the original audit. Severity labels distinguish
reachable security/data-loss issues from lower-priority hardening and contract decisions.

Entries numbered **63 and above** were added on 2026-10-03, **68 and above** on 2026-10-04,
and **70** on 2026-10-05, while the collaboration draft system was being built, verified the same way,
and listed here rather than left in [`backlog.md`](backlog.md) because each one is reachable now rather
than only pending.

Entries **71 and above** were added on 2026-10-05 when the collaboration backlog item's
*deliberately deferred* paragraph was converted: each is a behaviour a reader can reach today and be
surprised by, where the backlog item had recorded a decision nobody had made yet, so the two files
were answering different questions and the item could be deleted.

Finding 64 left this file on 2026-10-04, when the apply's outcome became stored rather than reported once,
and the unnumbered finding that read "the applier raises rather than reporting a change it cannot
interpret" left it the same day, when the apply and a reviewer's approval started refusing such a draft
in words. Finding 68 left this file on 2026-10-05, when a pending row the apply may refuse was settled
as badged exactly as it is and never withheld, which is a decision rather than a change and left no code
behind it, and finding 66 left it the same day, when `DraftChanges::Reader` read a draft's records and
tag names once per class instead of once per row; the right sidebar's **Review requests** figure it
also described stays, and is a deliberate uncached `COUNT` rather than an oversight. The unnumbered
finding "implicit owner access is missing from association APIs" left it on 2026-10-05 as well,
when `User#universes` and `Universe#members` became owner-aware readers instead of membership-only
associations. The unnumbered "Scenes are covered" finding left it on 2026-10-06, when the entry was
confirmed to describe no open defect and to restate what `scenes.md` and `conventions.md` already own,
so the resolved status note went instead of a numbered entry.

Findings **20, 27, 28, 29, and 58** left this file on 2026-10-06, when the session and password
resources were restricted to the actions their flows have, the four modal-edited content models lost
their template-less `new` actions, `User` gained the presence validations its `NOT NULL` columns
imply, a reversed interval became a validation error on all three models that record one, a composite
slug began reading its tag segment in a defined order, and the fixed-navbar click finding turned out to
describe a test that does not fail — see `delivery_history.md` for the verification each one went through.

The **framework-routes** bullet in "Contract-dependent and future-feature footguns" was rewritten the
same day after being probed rather than re-read. It had described Active Storage, Action Mailbox, and
Action Text as one undifferentiated set of "unused" routes, which is the framing that leads a reader to
delete something load-bearing: Active Storage serves every record photo, while the two families that
genuinely are unused are inert — the Action Mailbox ingress endpoints 404 because
`ActionMailbox.ingress` is `nil`, and the `rails/conductor` endpoints 403 outside development.

Finding **23** left this file on 2026-10-06 without any code changing. It was written on 2026-09-25,
`db/migrate/20260928120000_add_integrity_constraints_to_legacy_join_tables.rb` landed three days later
and gave all seven legacy tag join tables the foreign keys and unique-pair index the finding said they
lacked, and the 2026-09-28 changelog entry recorded it — but the finding was never closed, so this file
went on asserting a defect the database had been rejecting for eight days. Verified against the running
test database rather than the migration: every legacy table has both foreign keys and its unique index,
an orphan insert raises `ActiveRecord::InvalidForeignKey`, and a duplicate raises
`ActiveRecord::RecordNotUnique`.

See [`delivery_history.md`](delivery_history.md).

## Mutation, route, and data-contract observations



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





69. **Low — a pending row carries no tags and no photo, so a remembered create shows less than the author
    submitted.** `DraftPreview#creates_for` assigns the payload sliced to `model.column_names`
    (`app/models/draft_preview.rb`), which is what keeps the collection writers (`character_tag_ids`) and
    the two virtual photo attributes off a record that will never be saved — and is also why a payload
    naming a renamed column is harmless. The cost is visible: a new Character the author tagged
    *Protagonist* and gave a portrait appears in the Characters list with a **Draft** badge and no tag
    badge and no picture, while the same change on the draft's own page shows both, because that page is
    where the payload's values are read rather than printed. Resolving a tag list per pending row is now a
    scan rather than a query, because `DraftChanges::Reader` resolves a collection of changes in one
    query per class — but a pending row is on the **list's** side, not the draft's page's, and a list
    resolves no payload at all; deciding whether the row should pay that read is recorded as **What a
    pending record shows outside the list workspaces** in [`backlog.md`](backlog.md).

71. **Low — conflict detection is per-record, so two people editing different fields of one record still
    collide.** `DraftConflictDetector` compares one stored `base_version` against the record's current
    version, which is a whole-record fact: any save between remembering and applying makes every change
    to that record conflict, whatever field it touched. The cost is a common path rather than an edge
    case — ADR 0019 states that two people editing one record collide by design — and it lands as a
    resolution page asking the author to choose between values on a field the other person never
    touched. Nothing is lost: **Apply theirs** keeps the other edit and reports the author's change in
    `Result#answered`, so it is redoable by hand from the draft's own page. The alternative is a
    field-level diff and a merge policy per model, which is why the decision is
    [ADR 0019](adr/0019-collaboration-foundations.md)'s and not a defect; revisit it only with real usage
    showing authors routinely losing unrelated edits to it.

72. **Low — a draft is a linear set of changes, so branching, forking, and merging are refused rather
    than absent.** One open draft per author per universe is a partial unique index
    ([ADR 0022](adr/0022-an-editing-session-claims-the-browser-and-one-draft-stays-open.md)), so an
    author who wants to pursue two directions for one record cannot, and the second attempt is a
    refused write rather than a second line of work. Merging two drafts has no path at all: `apply`
    closes its draft on the first run, and `DraftApplier` takes one draft's changes. This is
    consistent with the rest of the workflow rather than a gap in it — a change is append-only
    ([ADR 0019](adr/0019-collaboration-foundations.md)) and an apply is one transaction — and the
    product decision of what a branch *is* has not been made. Nothing in the navigation offers a
    destination for it: the right sidebar's **Branches** and **Forks** placeholders were removed on
    2026-10-05 as entries with no model and no decision behind them, which is
    [features/navigation.md](features/navigation.md)'s rule against a link to a route that does not
    exist rather than a claim that the workflow supports it.

73. **Low — a notification reaches the bell only; nothing is delivered outside the application.**
    There is no email, no push, and no digest: a submission, a decision, or a reply is written as a
    row, counted uncached, and announced to the reader's own websocket stream. A reader who is not
    looking at the page when a draft is decided learns about it by returning, and a reader who never
    returns does not learn it at all — there is no row anyone else can see, because a notification has
    exactly one reader. In-app first was a deliberate choice ([ADR
    0025](adr/0025-a-notification-is-a-stored-sentence.md)) and email is its own decision rather than a
    delivery detail: it needs an address the reader can unsubscribe, a retention answer the in-app row
    does not have, and a locale the request no longer supplies. `PasswordsMailer` is the only mailer in
    the application, and `config/environments/production.rb` already configures SMTP — so the transport
    exists and the question is entirely what a notice may promise.

74. **Low — a discussion message is plain text, so a reader who types markdown gets their own
    punctuation.** `discussion_messages.body` is plain text and the thread renders it as such, with no
    sanitizing step because there is no formatting step to sanitize: `**bold**`, `# heading`, and
    `- item` all appear verbatim in the message. This is reachable now and visible to any writer
    accustomed to a markdown editor elsewhere, and it is a deliberate first version
    ([ADR 0019](adr/0019-collaboration-foundations.md) deferred it; the ADR that would settle it does
    not exist). Formatting is not only a render change: it makes the stored body untrusted input on
    every surface that prints it — the thread, a notification sentence carrying a reviewer's note, and
    any future export — so it needs a decision about which dialect is allowed and where escaping
    happens, not just a template.

75. **Low — real-time updates are asynchronous and explicit, so two readers never see each other's
    unsaved work.** A second reader's write reaches a browser as a refresh and nothing more
    ([ADR 0026](adr/0026-a-live-update-is-a-refresh-and-never-a-page.md)), which means a draft is never
    shared while it is being written: the other reader sees nothing until it is applied, and a held
    refresh is dropped rather than queued. That is the accepted answer for an asynchronous
    with-explicit-apply workflow, and the alternative — a shared editing surface where two people type
    into one record — is a different product with a different failure mode, not a missing feature here.
    Worth recording so that a reader reporting "the other person was typing and I saw nothing" is
    answered with the decision rather than investigated as a bug.

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
    Re-verified against the tree on 2026-10-06, and one of this entry's three claims no longer
    holds. Still true:
    - `docs/development.md:186` says fixtures load "all content + tag fixtures", but
      `test/fixtures/` has no `relations.yml`, `ownerships.yml`, `relation_tags.yml`,
      `ownership_tags.yml`, or `universe_memberships.yml`. Tests create many of those records ad hoc.
    - `docs/README.md:25` advertises `docs/images-to-ai/`, which does not exist.
    No longer true: this entry reported that the development guide "calls `test/helpers` effectively
    empty", and `docs/development.md` no longer says anything of the kind — it does not mention the
    directory at all. `test/helpers/` in fact holds six test files, not the three this entry named.
    The root README's destructive `db:restart` warning was clarified and the dead `schema.txt` links
    removed on 2026-09-30; the fixture and `images-to-ai` issues are what remains open.

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

- **A remembered create says nothing about which story, scene, or section it would belong to.** The payload's
  scope column (`DraftChange#scope_attribute`) is dropped as plumbing on the drafts page, because the page is
  already inside the universe it would place the record in and a bare `story_id` is a number a reader cannot
  name. The list workspaces now show remembered creates too, and they drop it for the same reason — and
  additionally because a pending row is an unsaved record whose position and parent are the applier's to
  decide, so it is appended after the real rows and placed under no parent. An author reviewing twenty
  remembered scenes therefore sees twenty rows that say what each scene is called and nothing about where
  each one would land, and has to go to the record's own workspace to find out. A resolved name per create
  is a lookup the list would have to make per row, which is the shape
  [`conventions.md`](conventions.md#reading-a-drafts-changes) now refuses for the pages that draw a
  draft; the reasoning for reading a create
  as an unsaved model rather than a row is in [ADR
  0023](adr/0023-pending-changes-are-read-from-the-draft-and-drawn-as-badges.md).
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
- **Framework routes are broader than the current domain, and two of the three families are inert
  while the third is in use.** `config/application.rb:3` loads `rails/all`, which mounts 25 routes no
  view links to. They are not interchangeable, and reading them as one undifferentiated list is how a
  reader ends up deleting something load-bearing:
  - **Action Mailbox ingress** — nine `POST`/`GET` endpoints under `/rails/action_mailbox`. Inert
    today because `ActionMailbox::BaseController#ensure_configured` answers **404** unless
    `ActionMailbox.ingress` names the ingress, and that setting is `nil`. This is the one family with
    real residual risk: it is **one configuration line away** from exposing nine write endpoints, and
    nothing asserts it stays `nil`. A test that fails when `config.action_mailbox.ingress` becomes
    truthy would close that.
  - **`rails/conductor/action_mailbox`** — eight endpoints, guarded by
    `Rails::Conductor::BaseController#ensure_development_env`, which answers **403** outside
    development. Verified in production, not just assumed.
  - **Active Storage** — the blob/proxy/disk/direct-upload set. **These are load-bearing, not unused:**
    `HasPhoto` stores through `ActiveStorage::Blob.service` (`DiskService`), so these routes serve every
    record photo and the cropper. They must not be treated as dead weight.
  Action Text mounts no routes in this application. The application has no route allowlist and no
  production route-surface check, and `test/routing/route_action_contract_test.rb` deliberately
  **excludes** framework controllers rather than asserting anything about them — it decides membership
  by where a controller's own file lives, so a framework route is outside its scope by construction.

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
