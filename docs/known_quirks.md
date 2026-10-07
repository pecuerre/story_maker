# Known Quirks & Tech Debt

Verified **open** oddities in this codebase — things that look like bugs, are bugs, or will
surprise you. This file holds only open findings: when one is fixed, the whole entry moves to
[delivery_history.md](delivery_history.md) with the history of the fix, and no "this used to be broken"
note is left behind here. Severity labels distinguish reachable security/data-loss issues from
lower-priority hardening and contract decisions. Index of all docs: [README.md](README.md).

**This file is not a log.** Findings are added and removed here; they are not annotated as they
leave. Which findings have left, when, and why is recorded in
[`delivery_history.md`](delivery_history.md) and [`../CHANGELOG.md`](../CHANGELOG.md), which own that
history — this file must never restate it, because a departure noted here is a second source of truth
that goes stale the moment the fix is reverted or re-landed. The same rule governs a finding that is
*corrected* rather than closed: the reasoning moves, the entry is simply rewritten.

The numbered findings below were first gathered by an audit on 2026-09-24 against commit `8fcf4d4`,
with the DataFactor follow-ups checked against the tree on 2026-09-25. Entries are not re-verified by
being written down, so **re-read a finding against the code before acting on it** — see
[Audit baseline and evidence](#audit-baseline-and-evidence) for what that pass actually ran.

## Mutation, route, and data-contract observations

72. **Low — a draft is a linear set of changes, so branching, forking, and merging are refused rather
    than absent.** One open draft per author per universe is a partial unique index
    ([ADR 0022](adr/0022-an-editing-session-claims-the-browser-and-one-draft-stays-open.md)), so an
    author who wants to pursue two directions for one record cannot, and the second attempt is a
    refused write rather than a second line of work. Merging two drafts has no path at all: `apply`
    closes its draft on the first run, and `DraftApplier` takes one draft's changes. No ADR states what
    a branch is, so this is the only place that cost is written down; it is a refused write a reader
    will hit rather than a defect, and the product decision behind it has not been made.

74. **Low — a discussion message is plain text, so a reader who types markdown gets their own
    punctuation.** `discussion_messages.body` is plain text and the thread renders it as such, with no
    sanitizing step because there is no formatting step to sanitize: `**bold**`, `# heading`, and
    `- item` all appear verbatim in the message. This is reachable now and visible to any writer
    accustomed to a markdown editor elsewhere. [ADR 0019](adr/0019-collaboration-foundations.md) deferred
    it and no ADR has settled it, so this entry is where the cost lives. Formatting is not only a
    render change: it makes the stored body untrusted input on every surface that prints it — the
    thread, a notification sentence carrying a reviewer's note, and any future export — so it needs a
    decision about which dialect is allowed and where escaping happens, not just a template.

## Performance, test, and tooling observations

36. **Medium — CI proves a production image boots, but not a deployment, and the job setup is not
    exercised at all.** Three things a deployment depends on are unproven by any job or test:
    - **Solid Cache, Solid Queue, and Solid Cable are set up and never touched.** The boot check proves
      the container answers `/up`, not that a queued job runs, a cache entry lands, or a broadcast
      reaches a subscriber. These are database-backed in production, so a wiring mistake would only
      surface as a silently dead cache or a job that never executes.
    - **No deploy has ever been performed**, and neither the boot check nor the `config/deploy.yml`
      validation in `test/deployment/kamal_configuration_test.rb` exercises production mailer
      URL/SMTP behavior.
    - **`config/deploy.yml` is validated, not deployed.** Kamal's own loader runs on every test run
      because `bin/kamal config` cannot be used in CI — it prints resolved secrets — but loading a
      configuration is not the same as deploying it.

37. **Low — `test/fixtures/` has no file for five tables, and the tests that need those records build
    them inline.** `relations`, `ownerships`, `relation_tags`, `ownership_tags`, and
    `universe_memberships` are the five; every other persisted model has a fixture file. Closing this is
    not "add five files" — it is "add five files and rework the nine tests that read the *absence* of
    those records", which changes what those tests assert and therefore what they prove. The reasoning,
    including the attempted version that was reverted, is in
    [`delivery_history.md`](delivery_history.md); the pending work is in [`backlog.md`](backlog.md).

## Contract-dependent and future-feature footguns

These observations are code-proven but depend on a product/deployment decision or are not reachable
through the current normal UI. They are recorded so they are not mistaken for settled behavior:

- **Ability class checks are unsafe for future generic authorization code.** CanCan rules for
  content classes use instance blocks (`app/models/ability.rb:59-81`); a guest class-level
  `authorize!(:read, Character)` can be allowed even though an instance check is denied. Current
  `UniverseAuthorization` passes concrete universe objects, so no active route bypass was found.
  The content-class registry (`app/models/ability.rb:11-27`) is load-bearing twice over, since
  `RecordTarget` gates polymorphic record references through the same list, and
  `test/models/ability_test.rb` requires every persisted model to be content, authorized by another
  rule group, or listed there with a reason. The footgun itself is unguarded: nothing in the
  application prevents a future caller from authorizing a class, only `RecordTarget` declining to
  hand one out.
- **Two limits on the shared ownership adapter.** `UniverseScopeResolver` answers which universe owns
  a record for both `Ability#universe_for` and `ApplicationHelper#universe_for_record`, so
  record-level authorization and rendered mutation controls cannot drift; the adapter itself is in
  [`conventions.md`](conventions.md). Two things still have to be declared by a new model: one nested
  deeper than the `story`, `scene`, and `section` associations must define its own `#universe`, or it
  resolves to nothing and silently loses controls and checks; and the content-class registry is
  hard-coded, so a new model must be added to it or CanCan will not match a rule for it — that half
  is a failing test rather than a silent omission, see the entry above.

- **A remembered create says nothing about which story, scene, or section it would belong to.** The payload's
  scope column (`DraftChange#scope_attribute`) is dropped as plumbing on the drafts page, because the page is
  already inside the universe it would place the record in and a bare `story_id` is a number a reader cannot
  name. The list workspaces now show remembered creates too, and they drop it for the same reason — and
  additionally because a pending row is an unsaved record whose position and parent are the applier's to
  decide, so it is appended after the real rows and placed under no parent. An author reviewing twenty
  remembered scenes therefore sees twenty rows that say what each scene is called and nothing about where
  each one would land, and has to go to the record's own workspace to find out. The rules for what a
  pending row may read are in [`conventions.md`](conventions.md#pending-changes-in-a-list) and the
  reasoning for reading a create as an unsaved model rather than a row is in [ADR
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
- **The Action Mailbox ingress routes are one configuration line from being live, and nothing asserts
  they stay closed.** `config.action_mailbox.ingress` is `nil`, which is the only reason the nine
  `POST`/`GET` endpoints under `/rails/action_mailbox` answer **404**:
  `ActionMailbox::BaseController#ensure_configured` refuses unless the setting names an ingress. Set
  it, and nine write endpoints are mounted. A test that fails when that setting becomes truthy would
  close this. The rest of the framework route surface — which families are inert, which are
  load-bearing, and why Active Storage must not be treated as dead weight — is in
  [architecture.md](architecture.md#routing--url-generation-the-sharp-edges).

## Additional UI and interaction observations

50. **Low — dead PWA/UI assets still drift from the conventions.** The dynamic taxonomy modal now uses
    consistent heading/required-field semantics, but `app/views/pwa/manifest.json.erb` and
    `app/views/pwa/service-worker.js` have no route or layout link, and the PWA palette contains a
    `red` value that does not match the documented theme. These are low-priority cleanup/style
    inconsistencies.

57. **Low — a rename changes a slug, so a universe rename invalidates every path stored below
    it.** `HasSlug` regenerates a slug when a name changes, and each search document stores its own
    `url`, which embeds its record's slug and its universe's. A universe rename is therefore repaired
    by `Search::ReindexUniverseJob` (queued on `saved_change_to_slug?`), which is bounded but not
    instant: between the rename and the job, results in that universe link to a 404. Records that
    merely *mention* the universe are unaffected, because a document stores ids rather than names
    and the displayed context is resolved per request.

## DataFactor report follow-up observations (2026-09-25)

The 2026-09-25 DataFactor report identified several maintenance and onboarding gaps. They are
recorded here as open follow-ups, not as requirements to maximize an automated score. The distilled
policy is in [`data_factor_guidance.md`](data_factor_guidance.md) and the pending implementation work
is in [`backlog.md`](backlog.md).

52. **Medium — clean container onboarding is absent.** The repository has a production-oriented
    `Dockerfile` and a server entrypoint that runs `db:prepare`, but no root `docker-compose.yml`
    or devcontainer. A fresh clone therefore still depends on the documented host toolchain, and
    there is no clean-checkout proof that the image, SQLite paths, CSS assets, and `/up` work
    together. This is the **One-command containerized onboarding** item in
    [`backlog.md`](backlog.md); the compose path must not run development data in production.

## Audit baseline and evidence

The findings here were gathered by a non-destructive audit on 2026-09-24 against commit `8fcf4d4`. The
checks below are the evidence behind them. **The numbers are that pass's, not today's** — the suite has
grown by an order of magnitude since — and they are recorded so a reader can judge how a finding was
established, not as a capability list. The verification run for each later change is recorded in
[`delivery_history.md`](delivery_history.md).

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

That pass was an **observation record**: no application, test, configuration, dependency, or
generated-asset fix came out of it. Not run, and therefore not claimed: destructive development tasks
(`db:restart`, `db:reset`, `db:drop`, `db:seed`, `db:seed:replant`), demo-data loaders, Docker/Kamal
deployment, production SMTP delivery, and a live hostile-browser exploit. No production data or secret
value was modified; disposable test probes were rolled back or cleaned.
