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
  that no Bun lockfile existed does not describe the current tree. Preserve the lockfile.
- The repository already has date-based changelog discipline, RuboCop, Brakeman, Bundler Audit,
  Importmap Audit, and a browser system-test job. The remaining gaps are enforcement and coverage
  of areas those checks do not exercise.
- The report's `package.json` lockfile observation, the exact test-file count, the exact commit
  span, and the exact score are historical measurements. Do not repeat them as current facts
  without checking the repository.

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
   [`universe_maker_conventions.md`](universe_maker_conventions.md) remain authoritative. A quality
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

### 3. Measured, enforced test coverage — priority: later/medium

Add a coverage tool (SimpleCov is a reasonable starting point) to the test group, start it before
loading the Rails environment, measure a baseline, and publish the report from CI. The email's
suggested 80% minimum is a target to evaluate, not a number to assert without measuring the current
codebase. Set the threshold only after the baseline and the project's meaningful-behavior priorities
are understood; then add tests for uncovered behavior rather than padding files with assertions.

A useful implementation should:

- update `Gemfile.lock` through Bundler;
- fail CI when the agreed threshold is crossed, with a clear command and artifact;
- upload the HTML report (and, if useful, a machine-readable report) without committing generated
  coverage output;
- keep the test environment deterministic and avoid making parallel test processes race on the
  result file;
- document the threshold, exclusions, and local command;
- distinguish line coverage from meaningful request, authorization, failure, and browser coverage.

The current system suite is an initial smoke suite, not exhaustive UI coverage. Coverage must not be
used to claim that untested interactions, especially the known modal/taxonomy issues, are safe.

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

### 5. Credential-like literals and environment documentation — priority: now when touched/low risk

The report flagged literal local/demo passwords in `db/data/lotr/users.yml`,
`db/data/dark/users.yml`, and `docs/smoke_test_stories.sh`, plus a missing environment template.
These are synthetic development fixtures, but treat every credential-like string as potentially real
until reviewed. The project intentionally documents some synthetic logins for manual verification;
if a password source changes, update the exact development login and load instructions in the same
change rather than making the data impossible to reproduce.

- Require a local/demo password through an explicitly named environment variable, or generate a
  non-production value at runtime and print the exact command needed to use it. Do not retain a
  real-looking fallback in tracked code merely to satisfy a scanner.
- Make the smoke script fail clearly when its password is absent; do not print or persist it.
- Add `.env.example` only as a documented, value-free template. A future implementation may use a
  clear name such as `DEMO_USER_PASSWORD`, but must document that the app does not automatically
  load every `.env` file. The current `.gitignore` excludes `.env*`, so the template requires an
  explicit, reviewed unignore rule. Never create or modify a real `.env` file as part of this work.
- Do not put demo data in production seeds or deploy commands.
- Treat the critical tracked `.kamal/secrets` finding as a separate security remediation: rotate it
  if it was exposed and remove it from version control through an approved process. Never reproduce
  its value in documentation, tests, logs, or chat.

Run Brakeman and the relevant tests after changing credential or logging paths. A clean Brakeman
result does not prove that a client-side DOM or log-redaction issue is absent.

### 6. Dependency, JavaScript, and container supply-chain checks — priority: later/medium

The report's lockfile warning is outdated for the current tree: keep `bun.lock` committed and use
`--frozen-lockfile` in CI and Docker. The local Tom Select pin now includes machine-readable
`# @2.6.2` metadata, so Importmap Audit includes that direct package/version; the audit still does
not verify the provenance of the vendored bytes or cover the complete Bun/npm dependency graph.
That graph is not currently covered by the CI workflow. Consider a `bun audit` (or an equivalent
supported audit) step, inventory vendored assets, and add the appropriate npm/Bun and Docker
Dependabot ecosystems. Keep updates reviewable and reproducible rather than pinning arbitrary
versions.

A deploy job is not automatically an improvement: a real deployment requires an owner-approved
target, credentials, rollback plan, and Kamal validation. A container build/boot smoke test and
Kamal configuration validation may be safer first steps. Do not add a typecheck job until the
project adopts a type-checking tool; an empty or ceremonial typecheck job is not useful.

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
