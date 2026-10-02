# DataFactor Improvement Guidance

## Purpose and report snapshot

This document preserves the actionable engineering advice from the DataFactor report received on
2026-09-25. The original message is in `tmp/data_factor_2026-09-25_story_maker_scored_61.1.eml`
(the `tmp/` directory is disposable; this document is the durable project knowledge).

The report measured a point-in-time repository snapshot with an overall score of **61.1**, a
reported offer threshold of 70, and an estimated gap of 8.9 points. Its volume signal was 33.1; it
also reported 7,232 lines of code, a roughly 1:3 test-to-source ratio, a median file size of 27
lines, no files over 500 lines, and three hardcoded-secret-like hits. These are historical signals,
not targets. Its category signals were:

| Area | Report signal | Durable interpretation |
|---|---:|---|
| Architecture & robustness | 54.0 | Rails layering and the `TimelineLayout` separation were positives; logging, error tracking, and health/metrics signals were weak. |
| Test coverage | 62.0 | A substantial Minitest suite existed, but no coverage tool or threshold was detected. |
| Security hygiene | 58.0 | Dependency audits were present, while credential-like literals were flagged. |
| Documentation & onboarding | 78.0 | README and architecture links were strong; a one-command container path and environment template were absent. |
| Code cleanliness | 72.0 | Small files and RuboCop were positives; taxonomy field-builder duplication was a maintenance concern. |
| History & maintenance | 38.0 | The report saw a 13-day, single-author history with no tags or releases. |
| Dependency health | 58.0 | `Gemfile.lock` and Dependabot were present; the report's JavaScript-lockfile observation must be checked against the current tree. |
| CI/CD maturity | 78.0 | Lint, security, unit/integration, and system jobs existed; no deploy or typecheck job was detected. |

The score, payout estimates, and category weights are **not a product specification, a promise of an
offer, or a reason to add ceremonial code**. The report is an automated snapshot and can be stale.
Always verify a finding against the current code, tests, configuration, and Git history before
starting work. Re-score after meaningful changes, not after cosmetic edits.

## Current reconciliation

Several observations in the report are already stale or have changed in this repository:

- The health endpoint is already routed as `GET /up` in `config/routes.rb`. Keep it available,
  silence its expected request log, and add/verify a regression test rather than adding a second
  health route.
- `bun.lock` is committed and CI/Docker use `bun install --frozen-lockfile`. The report's claim
  that no Bun lockfile existed does not describe the current tree. Preserve the lockfile. The whole
  graph in it is now audited in CI as well; see §6.
- The repository already has date-based changelog discipline, RuboCop, Brakeman, Bundler Audit,
  Importmap Audit, and a browser system-test job. The remaining gaps are enforcement and coverage
  of areas those checks do not exercise.
- The report's `package.json` lockfile observation, the exact test-file count, the exact commit
  span, and the exact score are historical measurements. Do not repeat them as current facts
  without checking the repository.
- The client-side code is no longer unchecked: the Stimulus controllers are linted with Biome and
  unit tested on Bun's runner, and the browser suite proves a real CSRF token is sent
  ([ADR 0012](adr/0012-client-side-verification-and-csrf.md)). What remains open there is breadth —
  the browser suite is a smoke suite, not exhaustive UI coverage — not tooling.
- Test coverage is now measured and gated in CI, so the report's "no coverage tool or threshold was
  detected" observation is stale. The threshold was chosen from a measurement rather than from the
  report's suggested 80%, which sits below this codebase's baseline. See
  [`development.md`](development.md#test-coverage) for the numbers, the exclusions, and what the
  percentage does not prove.

The report also does not replace the more urgent project findings in
[`known_quirks.md`](known_quirks.md). In particular, the tracked Kamal secret, taxonomy DOM XSS,
password-reset token logging, transport-security, seed-boundary, and other security/data-integrity
findings take priority over score-oriented changes. No secret value belongs in this document.

## Principles for future work

1. **Improve the product and its maintenanceability, not the score.** A useful vertical slice with
   tests, documentation, and safe operations is better than a no-op commit, a cosmetic release, or
   a dependency added only to satisfy a detector.
2. **Keep security and data integrity ahead of metrics.** Verify authorization, scope, secret
   handling, logging redaction, input encoding, and production boundaries before pursuing a
   polish item. Fix a critical/high known issue when it is in scope; otherwise leave it clearly
   visible in the backlog rather than silently expanding the task.
3. **Ship small, real increments.** Keep each change focused on one model, controller, helper,
   workflow, or operational concern. Pair behavior with its Minitest coverage in the same change,
   update the matching documentation, and add a dated `CHANGELOG.md` entry.
4. **Make evidence reproducible.** Run the smallest relevant test while iterating, then the full
   relevant suite for shared behavior. Record checks that were not run. Use locked dependency
   installs and clean-environment verification where practical.
5. **Prefer boring, inspectable operations.** SQLite and the database-backed Solid adapters do not
   require inventing external infrastructure for local development. Do not add a service, metric,
   framework, or type system unless a real use case and operational owner justify it.
6. **Do not game history or identity.** Continue natural development over time. Do not fabricate
   commits, backdate work, change Git identities, create fake teammate contributions, or add tags
   solely to change an automated history signal. Genuine teammate contributions should retain
   their own identities. If a release policy is later adopted, document it and make real releases
   rather than cosmetic tags.
7. **Keep temporary data out of production paths.** Demo data, demo credentials, and development
   loaders must not become production seeds or deploy-time behavior. Never run a destructive
   database reset without the owner's approval.
8. **Use the existing project boundaries.** Universe/story scope, authorization, response formats,
   route-key conventions, test helpers, and the three UI patterns in
   [`conventions.md`](conventions.md) remain authoritative. A quality
   improvement must not bypass them to make a metric look better.

## Recommended work packages

The following are the report's recommendations translated into project-sized, testable work. They
are intentionally not treated as automatic scope expansion. The owner chooses **NOW**, **LATER**, or
**NEVER** using [`backlog.md`](backlog.md).

### 1. Sustainable maintenance and paired tests — priority: ongoing/high signal

Continue landing real, small changes at a regular cadence. A weekly or biweekly rhythm is reasonable
when useful work exists, but cadence is not a quota. A feature and its regression tests should travel
together; do not accumulate a large untested batch and test it only at the end. Record notable work
in the date-based changelog. Preserve the repository's existing history and do not rewrite it for a
score.

For each completed slice, ask:

- Is the change useful to a writer or maintainer?
- Does the test exercise the behavior, authorization boundary, and failure path that changed?
- Is the matching documentation current?
- Can a reviewer understand the change from the diff and changelog without private context?

### 2. One-command containerized onboarding — priority: later/medium

Provide a reproducible `docker compose up` path that builds the existing image, prepares an
isolated SQLite database, persists the correct local data/storage paths, exposes the application
port, and passes a health check. Document it as an alternative to the `mise`/`bundle`/`bun` path in
the root README.

The compose design must be development-safe: do not run development data in a production
container, mount a developer's real production data, or claim a clean production boot. The current
Dockerfile is production-oriented; its `db:prepare` path now loads only production-safe seeds, so
use a development-specific service/command for demo universes and verify the exact startup sequence
before documenting Compose. Test from a clean checkout, including CSS assets, migrations,
and `/up`; report any Docker or browser limitation. A devcontainer is optional and should follow the
same environment and data-boundary rules.

### 3. Measured, enforced test coverage — priority: delivered

Delivered on 2026-10-01. SimpleCov is in the test group, started from `test/coverage_helper.rb`
before `config/environment` loads, measured with branch coverage over the application's own Ruby,
and gated in CI at 90% line / 75% branch against a measured baseline of 94.59% / 80.99%. The
email's suggested 80% was measured rather than adopted: it sits below this codebase's baseline and
would never have failed. [`development.md`](development.md#test-coverage) owns the local command,
the exclusions, and the limits; [`../CHANGELOG.md`](../CHANGELOG.md) records the delivery.

Two of the points the original recommendation listed still govern it:

- coverage must not be used to claim that untested interactions, especially the known
  modal/taxonomy issues, are safe. The system suite remains an initial smoke suite, not exhaustive
  UI coverage.
- the gate is deliberately **off** for a partial run (`bin/rails test <file>`, or `-n /pattern/`),
  which measures a fraction of the application by design. A gate that fires there makes the number a
  reason to avoid running a test at all.

### 4. Structured logging and runtime observability — priority: later/high signal

A deployed Rails application needs request IDs, structured and redacted logs, a useful health check,
and a deliberate error-reporting policy. The current `/up` route is the right health primitive;
verify it with a test and keep it free of private application data.

Before enabling a request formatter or an external error tracker:

- audit all log paths, including URL path segments such as password-reset tokens;
- preserve parameter filtering and redact request IDs/headers only when they cannot identify a user;
- never log passwords, cookies, reset tokens, DSNs, or unnecessary personal data;
- initialize error tracking only when an explicitly supplied environment variable is present;
- keep the DSN and credentials out of the repository and document the required deployment variable;
- decide whether a metrics endpoint is actually needed; if it is added, define authentication,
  cardinality, retention, and data-minimization rules instead of exposing model counts publicly.

A JSON formatter such as Lograge is a possible implementation, not a mandate to add a gem. Check
Rails 8 compatibility, structured Active Support events, log volume, and redaction before selecting
it. Add focused tests/configuration checks and run the security scans after the change.

### 5. Credential-like literals and environment documentation — priority: delivered

Delivered on 2026-10-02. The report flagged literal local/demo passwords in `db/data/lotr/users.yml`,
`db/data/dark/users.yml`, and `docs/smoke_test_stories.sh`, plus a missing environment template.
Those literals are gone: no manifest under `db/data/` states a password and the loader rejects one
that does. `Development::LocalPassword` takes the value from `UNIVERSE_MAKER_DEV_PASSWORD` or
generates one for the load and reports it, so the documented development login is still exact and
still reproducible. [`../db/data/README.md`](../db/data/README.md#development-credentials) owns
the contract; the smoke script's requirement is stated in
[`development.md`](development.md#smoke-test-end-to-end-over-http); [`../CHANGELOG.md`](../CHANGELOG.md)
records the delivery.

The rules the implementation follows, which stay in force:

- a local/demo password comes from an explicitly named environment variable, or from a value
  generated at runtime and printed with the exact command that reuses it; no real-looking
  fallback is retained in tracked code merely to satisfy a scanner;
- the smoke script fails clearly when its password is absent, and never prints or persists it;
- `.env.example` is a documented, value-free template behind an explicit, reviewed `.gitignore`
  unignore rule, and it says plainly that nothing in the boot path reads a `.env` file. A real
  `.env` is never created or modified as part of this work;
- demo data stays out of production seeds and deploy commands;
- the tracked `.kamal/secrets` finding is a separate security remediation: rotate it if it was
  exposed and remove it from version control through an approved process. Never reproduce its
  value in documentation, tests, logs, or chat.

Run Brakeman and the relevant tests after changing credential or logging paths. A clean Brakeman
result does not prove that a client-side DOM or log-redaction issue is absent.

### 6. Dependency, JavaScript, and container supply-chain checks — priority: delivered

Delivered on 2026-10-02. `bun.lock` was already committed and installed with `--frozen-lockfile`;
what was missing was the audit of the graph behind it. `bun audit` now runs in CI's `scan_js` job
beside `bin/importmap audit`, and it found what the advisory database had not been consulted for:
`bun.lock` resolved `brace-expansion` 5.0.9, two high and one moderate DoS advisory, reachable
through `nodemon > minimatch`. `bun audit fix` moved it to 5.0.12 in range, without touching
`package.json`, which is what makes the gate green rather than aspirational.

The vendored half is covered too. Importmap Audit reads a version out of a pin comment and never
looks at the file's bytes, so `config/vendored_javascript.yml` plus
`test/vendored_javascript_test.rb` prove that the vendored copy is the release `bun.lock` locks:
Bun verifies each tarball's sha512 on install, so a byte-identical comparison against
`node_modules` is a provenance answer with no network call. The pin comment, the resolved version,
and the `package.json` range are asserted to be one version.

Dependabot gained the `bun` ecosystem rather than `npm` — the npm ecosystem does not reliably
rewrite a Bun lockfile, so its PRs would fail the frozen install — plus a `docker` ecosystem for the
base image. A production-image build/boot check already existed but could not pass: `assets:precompile`
boots the production environment, which refuses to start without `APP_HOST`, `MAILER_FROM`, and
`SMTP_ADDRESS`, so `docker build` failed on every run. Those three names are now build arguments with
`.invalid` defaults. The image also stopped keeping the `test` bundle group next to `development` and
dropped `node_modules` after precompiling, and CI now inspects the built image to prove both. Kamal
configuration is validated in the suite
through Kamal's own loader rather than by running `bin/kamal config`, which prints secrets.
[`development.md`](development.md#lint--security-scans) owns the commands, the vendored-JavaScript
contract, and the CI job table; [`../CHANGELOG.md`](../CHANGELOG.md) records the delivery.

Two things stayed deliberately out, and the reasons still apply:

- no deploy job and no typecheck job. A real deployment still needs an owner-approved target,
  credentials, and a rollback plan, and the project still has no type-checking tool;
- the base image is still tag-pinned rather than digest-pinned, and GitHub Actions are still pinned
  to major tags. Digest pinning fights the Docker Dependabot ecosystem that is now enabled, so it
  remains an open finding in [`known_quirks.md`](known_quirks.md) rather than a change made here.

### 7. Reduce shared-helper duplication without behavior drift — priority: later/low signal

The report identified repeated field-builder logic in `app/helpers/modal_fields.rb` and
`app/helpers/tags_helper.rb`. The repository's small-file profile is a strength, so do not refactor
only to lower a line count. First characterize the serialized field/JSON contracts, form parameter
shapes, and browser behavior with focused tests. Then extract declarative descriptors or shared
helpers where it removes real drift risk, while preserving the established modal/taxonomy patterns,
JSON-only mutations, tag optionality, and accessible error states. Refactoring and bug fixes should
be separate, reviewable changes.

### 8. Documentation, onboarding, and releases — priority: ongoing

Keep `README.md`, `docs/development.md`, the docs index, and `CHANGELOG.md` synchronized with actual
commands and behavior. If the container path, coverage gate, environment template, or observability
configuration is implemented, document the exact local and CI commands, the required variables
(names and purpose only), the health endpoint, and the limitations.

The project currently has no release-version scheme. Do not invent tags or a semantic-version
history solely because the report mentions releases. If the owner adopts releases, make a deliberate
decision, document it (and an ADR if it changes the long-term workflow), and update the changelog
with real release history.

## Security and correctness prerequisites

The DataFactor score must never cause an agent to weaken or skip a project invariant. Before
starting a quality task, check the relevant entries in [`known_quirks.md`](known_quirks.md), especially:

- the tracked Kamal secret and rotation/remove process;
- taxonomy modal `innerHTML` XSS and stale serialized state;
- password-reset tokens in request logs;
- production TLS/cookie assumptions and mailer URL/SMTP configuration;
- environment-guarded demo loading and destructive database reset confirmation;
- JSON/HTML response contracts and cross-universe/cross-story authorization.

The report's credential warning is narrower than these issues. A higher automated score is not an
acceptable reason to leave a known critical/high finding open, and Brakeman's clean result does not
replace browser or log-redaction tests.

## How to use this guidance in a task

1. Read [`AGENTS.md`](../AGENTS.md), the matching project docs, this file when the task touches
   quality/operations, and the relevant known quirks.
2. Verify the report claim against the current repository. If it is stale, record the correction in
   the changelog or relevant doc rather than repeating it as a new bug.
3. Decide **NOW**, **LATER**, or **NEVER**. Put deferred work in [`backlog.md`](backlog.md) with a
   focused outcome and acceptance criteria; do not silently expand the current feature.
4. For a NOW item, implement one vertical slice with tests, security checks, documentation, and a
   changelog entry. Keep changes compatible with universe/story scope and authorization.
5. Run the smallest relevant checks, then the full relevant suite. For coverage, containers,
   logging, credentials, dependencies, or production boot, include the environment-specific check
   and report anything not run.
6. Re-score the repository after a meaningful batch if desired. Treat the new report as another
   snapshot, not as a reason to manufacture history or features.

## Acceptance checklist

A quality-improvement change is ready to hand off only when the applicable items are true:

- behavior and failure paths have Minitest coverage, with browser coverage for user-visible
  interaction changes;
- the smallest relevant tests and shared checks pass, and skipped checks are reported;
- no credential, token, cookie, private data, or deploy secret is introduced;
- logging, health, metrics, and error-reporting behavior is documented and privacy-conscious;
- dependency changes use committed lockfiles and reproducible installs;
- setup instructions work from a clean environment, or the limitation is clearly stated;
- the matching docs and dated changelog entry are updated;
- no unrelated refactor, dependency, release tag, or service was added solely for the score.

See also [`docs/adr/0006-data-factor-quality-guidance.md`](adr/0006-data-factor-quality-guidance.md)
for the accepted workflow decision, [`docs/README.md`](README.md) for the documentation index, and
[`CHANGELOG.md`](../CHANGELOG.md) for the project's real, non-cosmetic history.
