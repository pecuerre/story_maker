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
for what that pass actually ran. The entries added on 2026-11-12 state their own evidence; that
review sampled important paths and did not prove the absence of other issues.

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

3. **Medium — a Spanish draft page can print the English fallback "a record".** A draft page rendered
   under `es` in `SpanishChromeTest` contained the exact English string "a record"; the only value
   with that text is `notifications.a_record`, whose Spanish entry is "un registro". The page may be
   choosing the English value before the request's locale reaches the notification sentence, or the
   text may be reaching the body through a path the visible notification list does not own. The
   negative Spanish-chrome assertion was removed from the status case so it does not claim a fix;
   re-read `NotificationsHelper#notification_sentence` and the draft page's layout before changing
   either.

4. **Medium — a private Universe's photo URL is a reusable bearer URL, not an access check.**
   `ApplicationHelper#record_photo_url` uses `url_for(photo.file)`, and Rails' mounted Active
   Storage blob and disk controllers do not run `UniverseAuthorization`. In a test on 2026-11-12,
   an owner opened a private Character page, then an unauthenticated request using the photo's
   signed blob URL followed the redirect and received the image with `200`. A person who obtained
   the URL while authorized can therefore share it or keep using it after access is revoked; guessing
   a valid signed URL is a different question. Check the serving path, cache behavior, and revocation
   policy before treating private photos as protected by Universe membership.

5. **Medium — a nested import symlink can escape the configured source root.**
   `StoryInterchange::ImportRoot#path_for` checks the selected folder's real path, but
   `StoryInterchange::Validator` and `Document.load` follow symlinks inside that folder without the
   same check. A source inside the root with `universe/README.md` linked to an outside Markdown file
   caused the preview's Universe name to come from that file in a 2026-11-12 test. The browser import
   is platform-admin-only, and exploitation requires control of a source tree or its symlinks; it can
   nevertheless expose files readable by the server to an operator or import them as content. The
   top-level check also does not pin the tree against changes between checking and reading it.

6. **Medium — a backup can combine rows from different moments.** `UniverseBackup::Archive` and
   `DataDump` read the tables, joins, projection, and photo bytes separately without a snapshot around
   the archive. A deterministic 2026-11-12 test inserted a tagged Character after the Character rows
   were read and before the join rows were read: the archive contained its tag join but not the
   Character. Concurrent edits can thus produce an internally inconsistent backup even though each
   individual query succeeds; database snapshotting and the independent photo-file lifecycle both
   need consideration.

7. **Medium — interchange export can reorder the Story's narrative sequence.**
   `StoryInterchange::Export#chapter_files` groups Scenes by Section, then puts ungrouped Scenes last;
   the importer assigns positions in chapter/file order. In a 2026-11-12 round-trip probe with Scene
   positions A, B, C and A/C in one Section, the validator read B, A, C. This is separate from the
   documented flattening of the Section hierarchy: a Story can interleave Sections or ungrouped
   Scenes, and importing the export changes their stored narrative order without warning.

8. **Medium — interchange export can produce duplicate slugs the importer refuses.** The application
   permits a Character and a Location in the same Universe to share a slug; the interchange validator
   requires entity and Plot slugs to be globally distinct. `StoryInterchange::Export` writes the
   model slugs as-is, so a valid Universe with that collision downloads successfully but fails
   validation with `duplicate record slug`. A 2026-11-12 fixture probe reproduced it. Resolve identity
   and references together rather than silently renaming only the file.

9. **Medium — a Scene's ordinary narration can make its exported source invalid.** Scene Element body
   text is not constrained to the interchange grammar. The exporter inserts it directly beneath
   `## Narration`, while `StoryInterchange::Document` treats any following `##` line as a new block.
   A saved narration containing `## A heading` produced the validator error `scene section ... is not
   a ... block` in a 2026-11-12 probe. Similar source grammar and reference delimiters need an explicit
   encoding or a refusal that tells the author before presenting the file as importable.

10. **Medium — interchange export silently drops a Scene's drafting contract.** The importer already
    reads the `DRAFTING CONTRACT` comment into `Scene#drafting_contract`, but
    `StoryInterchange::Export#scene_document` writes no such comment. A 2026-11-12 probe saved a
    contract and found the exported, parsed Scene's contract was `nil`. This is not a limitation of
    the interchange format, and the export's loss notes do not name it.

11. **Medium — forward chains of imported relative moments can lose computable dates.**
    `StoryInterchange::Importers::Events` creates every Event, then applies each relation once in
    source order. If A is one day after B, B is one day after C, and C has a concrete date, A is
    visited before B has acquired its date and is never revisited. A validated 2026-11-12 import
    produced `nil`, January 2, and January 1 for A, B, and C respectively. The temporal links remain,
    but A's computed start is missing; cycles and other relation shapes need a deliberate policy too.

12. **Medium — the backup truncates timestamp fractions.** `UniverseBackup::DataDump#attributes_for`
    calls `iso8601` without a precision, so `2026-11-12T12:30:00.123456Z` was written as
    `2026-11-12T12:30:00Z` in a 2026-11-12 probe. The table dump is therefore not a byte- or
    value-exact copy of timestamp columns, including version-relevant `updated_at` values. Restore
    does not yet exist; preserve and test the original precision before relying on a round trip.

13. **Medium — a missing stored photo file aborts the backup instead of being reported.**
    `DataDump#photo_files` reports a Photo with no attachment, but if the attachment and blob rows
    exist and the storage object is missing, `blob.download` raises `ActiveStorage::FileNotFoundError`.
    A 2026-11-12 probe simulated the storage failure and reproduced the exception, so no archive or
    manifest is delivered in that case.
    Decide whether to fail clearly or produce a partial archive with an explicit missing-file entry;
    do not call a partial result complete.

14. **Medium — the faction editor browser test is out of sync with its fields.**
    `test/system/modal_json_flow_test.rb:51` expects Name, Faction tags, Photo, Short summary, and
    Description, but the live editor also renders Background color and Foreground color after Name.
    It failed both in the full 2026-11-12 browser run and when run alone. The same behavior would fail
    CI's system-test job; the failure alone does not establish that the additional fields are unwanted.

15. **Medium — browser smoke tests failed intermittently in the full run.** On 2026-11-12,
    `PARALLEL_WORKERS=1 bin/rails test:system` also failed the dark-theme Map and Settings cases and
    two Scene Element dropdown cases. All four passed when rerun together serially. The full run's
    theme assertions saw light colors and the dropdown assertions did not find an open menu; the
    cause and whether a user-visible race exists remain unverified. Separate simultaneous reruns
    also hit SQLite locks, so concurrent system-test processes are not a valid isolation check.

16. **Footgun — `CI=1` gates partial Rails test runs too.** `test/coverage_helper.rb` sets
    `COVERAGE_GATE` solely from `ENV["CI"]`, with no check for a file or `-n` filter. On 2026-11-12,
    `CI=1 PARALLEL_WORKERS=1 bin/rails test test/models/session_test.rb` passed its 11 tests but exited
    2 for low coverage. Recent SimpleCov results may also be merged locally, so the resulting partial
    coverage is not necessarily that run's own. The GitHub full-suite job is a separate clean runner;
    this finding does not claim that its gate was bypassed.

17. **Footgun — public interchange downloads assemble a whole Universe on an unthrottled GET.**
    `StoryInterchangeExportsController#show` permits guests in a public Universe and invokes
    `StoryInterchange::Export#to_s`, which builds the complete file map and compressed archive in
    memory on each request. The mutation throttle excludes GETs and the read throttle applies only to
    API tokens, not browser guests. This creates a potentially expensive anonymous request as a
    Universe grows; no load test was run, so its practical capacity and deployment mitigations are
    not established.

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
