# Known Quirks & Tech Debt

Verified **open** oddities in this codebase — things that look like bugs, are bugs, or will
surprise you. This file holds only open findings: when one is fixed, the whole entry moves to
[delivery_history.md](delivery_history.md) with the history of the fix, and no "this used to be
broken" note is left behind here. Index of all docs: [README.md](README.md).

**This file is not a log.** Findings are added and removed here; they are not annotated as they
leave. Which findings have left, when, and why is recorded in
[`delivery_history.md`](delivery_history.md) and [`../CHANGELOG.md`](../CHANGELOG.md), which own that
history — this file must never restate it, because a departure noted here is a second source of truth
that goes stale the moment the fix is reverted or re-landed. The same rule governs a finding that is
*corrected* rather than closed: the reasoning moves, the entry is simply rewritten.

## How the open list works

Every open finding is its own numbered entry with a name, so findings can be taken one at a time:
read one, decide **NOW / LATER / NEVER**, and close it without touching the others. Two labels
separate the kinds, and the label says how far the finding is from being a reachable defect.

- **Medium** — a reachable problem. Something is unproven, missing, or unverified where it matters
  today.
- **Footgun** — code-proven, but dependent on a product or deployment decision that has not been
  made, or not reachable through the current normal UI. Recorded so it is not mistaken for settled
  behavior, and so the change that trips it is made on purpose rather than by surprise.

**A number is a position in this list, not an identity.** Findings leave when they are fixed and the
list is renumbered from 1, so a number is reused: `3` today is not the finding `3` was yesterday, and
the list was last renumbered on 2026-10-15. **Never cite one from another document** — reference a finding
by its name, and cite the change that closed one through [`../CHANGELOG.md`](../CHANGELOG.md) or
[delivery_history.md](delivery_history.md). Entries in those two historical files keep the number a
finding had at the time and are not rewritten.

The findings were first gathered by an audit on 2026-09-24 against commit `8fcf4d4`, with the
DataFactor follow-ups checked against the tree on 2026-09-25; the list has been renumbered since
without being re-gathered, most recently on 2026-10-25. Entries are not re-verified by being written down, so **re-read a finding
against the code before acting on it** — see [Audit baseline and evidence](#audit-baseline-and-evidence)
for what that pass actually ran.

## Open findings

1. **Medium — CI proves a production image boots, but not a deployment, and the job setup is not
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

2. **Footgun — the Action Mailbox ingress routes are one configuration line from being live, and
   nothing asserts they stay closed.** `config.action_mailbox.ingress` is `nil`, which is the only
   reason the nine `POST`/`GET` endpoints under `/rails/action_mailbox` answer **404**:
   `ActionMailbox::BaseController#ensure_configured` refuses unless the setting names an ingress.
   Set it, and nine write endpoints are mounted. A test that fails when that setting becomes truthy
   would close this. The rest of the framework route surface — which families are inert, which are
   load-bearing, and why Active Storage must not be treated as dead weight — is in
   [architecture.md](architecture.md#routing--url-generation-the-sharp-edges).

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
