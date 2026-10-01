# Changelog

Universe Maker does not have release versions yet. This file is a date-based history of the
project instead, and it is the **short form**: one or two sentences per entry, naming the subject of
the change. It records application code, site/UI behavior, schema and data, tests, documentation,
configuration, security, and tooling.

The **long form** — the reasoning behind a change, the alternatives that were rejected, the
verification it went through, and the quirks and tech debt that have been resolved — lives in
[`docs/delivery_history.md`](docs/delivery_history.md). This project's earlier history, reconstructed
from the repository's Git history through 2026-09-25, moved there too. That file is a frozen
historical record and may disagree with the code today; this one is the index of what changed, when,
and under which label. Every entry here summarizes the matching entry in that file, so when a summary
is not enough, the history file is where the reasoning is.

Entries are grouped by calendar date in reverse chronological order; related changes from the same
day are consolidated into one entry. Within a date, entries are grouped by label in the legend order
below and, inside one label group, kept in reverse chronological order. A blank line separates two
label groups and one date section from the next, and never appears inside a group. Dates without
recorded project changes are omitted.

Labels used below:

- `added` — a new capability, model, workflow, or interface
- `changed` — behavior, architecture, data shape, or visual design was reworked
- `fixed` — a correctness, persistence, routing, or usability problem was resolved
- `security` — authentication, authorization, privacy, or data-integrity hardening
- `docs` — project knowledge, decisions, or contributor guidance changed
- `chore` — tests, fixtures, seed data, dependency, CI, or maintenance work
- `planned` — a documented future direction; not implemented in that entry

## 2026-10-02

- **[added]** **Structured runtime logging.** Every completed request now writes one JSON `request` event (`request_id`, method, filtered path, status, format, controller, action, duration) alongside the human-readable lines Rails already writes, and every reported exception writes a JSON `error` event (class, redacted message, bounded backtrace, severity, source, timestamp). Both are allowlists: no client IP, cookie, session, parameter, or account is emitted, and the password-reset token filter covers the new lines.
- **[added]** **Optional error tracking.** Setting `ERROR_TRACKING_DSN` to an https URL forwards unhandled errors to a collector as redacted JSON through `Net::HTTP`; with the variable absent nothing is initialized, no request leaves the process, and **no dependency is added**. A malformed value fails the boot, a collector that is down costs one log line and nothing else, and the DSN is itself scrubbed out of everything logged.
- **[added]** **Request id as the correlation key.** The request id now appears in the structured event, in the `request_id` log tag every line of the request already carries, and in the `X-Request-Id` response header, and it is published into `Rails.error`'s execution context so an error raised anywhere in a request is reported with the request that raised it.
- **[fixed]** **An unknown optional reference id is now a 422 field error instead of a 500.** A `parent_id`, `before_event_id`, `after_event_id`, or `simultaneous_event_id` that names nothing used to reach the write and come back as a foreign-key exception with no error summary; three model validations now answer with a message on the attribute that carried the id. This closes known quirk 19.
- **[chore]** `GET /up` now has a regression test: the health check is pinned in the test environment as well as in CI's production boot job, so the one route no other test would notice losing is covered.
- **[docs]** `architecture.md` records the runtime logging and observability contract — the two structured events, the request id as the correlation key, the error collector's authentication/cardinality/retention/privacy rules, and the deliberate absence of a metrics endpoint. The backlog item that asked for all of it is closed.

## 2026-10-01

- **[changed]** Every workspace with a tab strip now states what it holds in a sentence **below** the strip and above the list, not in the page header, so the header states only what identifies the page. Characters, Relations, Locations, Events, Items, Ownerships, the Timeline, and every taxonomy tree are on the new `shared/_content_intro`; the copy itself is unchanged.
- **[changed]** A taxonomy tag's identity card separates information from settings: the **description** takes the card's whole width instead of the column a photo leaves, and the **scope** and **colour** are one quiet `label: value` line at the card's bottom. What a scope means moved behind the scope line's info button — the same explanation, in a popover — so it is no longer read by every visitor.
- **[changed]** The **Timeline is the second tab of the Event workspace** rather than a sidebar entry of its own. The sidebar keeps one Events link, current across both tabs; the route and its URL are unchanged.
- **[added]** `popover_controller.js`, so an explanation can be attached to a control that is not otherwise interactive, with its title and content rendered by the server rather than written in JavaScript.
- **[fixed]** `db:demo:reset` and `db:restart` now rebuild the development database only: the drop and the create go through Active Record's per-configuration `drop`/`create` instead of `drop_current`/`create_current`, which widened to the test environment in development and emptied `storage/test.sqlite3` along with it. The scope is stated in `Development::DatabaseReset.db_configs`, and the reset no longer depends on a second database existing for its connection lifecycle.
- **[fixed]** `db:demo:reset` and `db:restart` rebuild through `Development::DatabaseReset`, which gives each phase its own connection lifecycle: `db:drop` unlinked the SQLite file while the process still held a connection to it, so the reset reported success and left no database at all whenever the second, test database was not also created.
- **[fixed]** That reset now runs the migration files instead of loading `db/schema.rb`, so amending a shipped migration takes effect on a fresh database — known quirk 55 — and it verifies the rebuilt database from the file before reporting success.
- **[added]** A **Start page** preference: a sign-in with nothing to return to lands on the universe and story the reader was last working in, on by default, and `/settings` has a third section for it because it is navigation state rather than display state.
- **[added]** The remembered destination is a signed browser cookie bound to the account that wrote it, and is re-resolved and re-authorized on every read, so a stale value answers the universes list instead of a dead or forbidden page.
- **[changed]** The universe page is a single column: the story list card sits above the Universe Bible card, and each one spans the full page width instead of sharing a row.
- **[security]** A GitHub fine-grained personal access token was pasted into `docs/backlog.md` by mistake and committed in `af2fcde`. The text is redacted; the owner reports it as read-only against a public repository, so this was a hygiene failure rather than a disclosure, and revoking it is a cheap precaution. No other secret-shaped string was found in the tracked tree.
- **[security]** **Sessions now end on a lifetime and are bound to the user agent.** A new `expires_at` column is the absolute deadline that use never extends and a new `last_used_at` drives an idle timeout, refreshed at most hourly; the session cookie expires with its deadline instead of being permanent; a refused session is destroyed; `PurgeExpiredSessionsJob` clears dead rows on a schedule; and `ApplicationCable::Connection` applies the same checks the request path does.
- **[security]** A session is bound to the **user agent** that created it and deliberately **not** to the IP address, because an address identifies a network rather than a person and mobile, VPN, and office/home switching all change it legitimately.
- **[added]** The `dark` development universe now holds **three stories** — `netflix-dark`, `netflix-darker`, and `bethesda-dark` — sharing one set of Characters, Locations, Items, and Events while each declares its own Sections, Section Tags, Scene Tags, and scene sequence, so the login → universe → story flow and a multi-story universe can be exercised by hand.
- **[added]** A browser test for the login → universe → story flow with several stories present, and loader coverage that the shared universe records and the story-scoped records stay separate.
- **[fixed]** The `migrations-from-zero` CI job now actually migrates from zero: it creates `schema_migrations` before `db:migrate` so the migration files execute instead of `db/schema.rb` being loaded, and a guard step fails the job if a `schema_sha1` was recorded. It previously reported all 36 migrations `up` while comparing the schema dump against itself.
- **[chore]** **Test coverage is measured and gated.** SimpleCov runs from `test/coverage_helper.rb` before Rails loads, with branch coverage over the application's own Ruby, and CI fails below 90% line / 75% branch against a measured baseline of 94.59% / 80.99%. The report's suggested 80% sits below the baseline and would never have failed, so it was measured rather than adopted. The gate applies only to a whole-suite run: a single file or an `-n` filter measures a fraction of the application by design and would fail spuriously, so it reports without gating. The browser suite writes its own report and gates nothing. Reports live in the already-ignored `tmp/`, and the HTML is uploaded from CI as the `coverage` artifact.
- **[chore]** A `production-boot` CI job builds the production image and requires `GET /up` to answer `200`, so a Dockerfile, asset-pipeline, or production-environment change that only breaks at boot fails in CI rather than on the server. It uses only throwaway values — a `.invalid` host and mailer address, and a per-run generated `SECRET_KEY_BASE` — and no real key, host, or address is in the repository. This closes the boot half of known quirk 36; Kamal configuration and production mailer delivery remain unverified.
- **[chore]** Coverage's `merge_subprocesses` is on because `parallelize(workers:)` forks one process per worker and a forked worker's coverage never reaches the parent without it — the report otherwise read a few percent with nothing to explain it.
- **[chore]** Coverage found three behaviours with no test at all, each now covered by asserting what it does rather than by padding: the **websocket connection**'s session rules (`ApplicationCable::Connection` had 0% and no test, and it is the only thing re-checking a copied session cookie once the handshake is accepted), the **search jobs**' handling of an engine that accepts a write and refuses it later, and both of `Search::ReindexUniverseJob`'s cases.
- **[chore]** The tag side of the tags DSL is `has_many_tagged`, not the misspelled `has_many_tagd`: the method, all eight tag models that declare it, and the five documents that name it are corrected. The duplicated fragment left in the same method's comment went with it.
- **[chore]** `test/services/development/database_reset_test.rb` runs the real reset in its own process against a database of its own and reads the rebuilt file straight from `sqlite_master`, so a reset that rebuilds nothing, omits a migration, or loads the schema dump fails instead of passing.
- **[chore]** That test also runs `db:demo:reset` with a development, test, and production database beside each other and no `DATABASE_URL` or `SKIP_TEST_DATABASE` — the shape in which the old scope reached the test database — and fails unless the test and production files keep their contents.
- **[chore]** The Dark manifests give **Bartosz** a Character record; the "Jonas meets Bartosz" Event already named him, and the two new stories need him to speak.
- **[docs]** The backlog item asking for measured test coverage and a CI gate is closed, and `development.md` records the local command, the exclusions, the thresholds, and what a line percentage does not prove.
- **[docs]** `known_quirks.md` records what the coverage measurement found and, equally, what a low number does not mean: `database_reset.rb` reads low because its test runs the reset in its own process, `search/client.rb` is verified out of band against a real engine, and `universe_authorization.rb`'s guest branches are unreachable while every controller still runs `require_authentication` first.
- **[docs]** The backlog item asking for the demo reset to stay inside the development database is closed, and `development.md` now records the reset's scope there and why it no longer depends on a second database for its connection lifecycle.
- **[docs]** The backlog question of whether to define a `code_style.md` is closed as **NEVER**: `.rubocop.yml`, `biome.json`, and `docs/conventions.md` already own Ruby, JavaScript, and code-pattern rules, and a fourth document would duplicate them.
- **[docs]** `development.md` records why the reset owns its connection lifecycle and why it migrates rather than loading the schema dump, and corrects the sections that described both as broken; known quirk 36 records what CI's `migrations-from-zero` job did and now does.
- **[docs]** `features/settings.md` documents the three preferences and why the start page is not Appearance; `architecture.md` and `data_model.md` record the remembered destination and the session columns; ADR 0017 and ADR 0018 state the decisions.
- **[docs]** Quirk 12 leaves `known_quirks.md` for the history file, and quirk 58 records a **pre-existing** system-test failure: Capybara's synthetic click misses controls inside the `position: fixed-top` navbar, which is why `authentication_test.rb`'s sign-out case has been failing before any of this work.

## 2026-09-30

- **[fixed]** `has_many_tags.rb`'s "include child tags" query no longer splices table and column names into a SQL string, so `bin/brakeman` reports no warnings and CI's `scan_ruby` job passes again. The join is built by Arel now, which also closes the backlog item that named the warning.
- **[fixed]** The `migrations-from-zero` CI job runs `db:drop`, `db:create`, and `db:migrate` as three separate processes; as one command, `db:drop` unlinked the SQLite file while the connection still pointed at it, so the migration wrote to the deleted inode and the next process found no schema.
- **[fixed]** The client-side i18n test no longer leaves its own four-key string table installed for the files that run after it, so `bun run test:js` passes whichever order Bun discovers the test files in.
- **[changed]** Every model's own validation message is a key, which was the last English a Spanish page could show.
- **[changed]** The four Stimulus controllers read their strings from the server, which finishes the internationalization work.
- **[changed]** The last three untranslated views are translated, and the search surface's own labels with them.
- **[changed]** A record's label and a search document's title are now two different things, and the reason is written down.
- **[changed]** The **Scene workspace** now renders in Spanish: the story-scoped `scenes/*` list and filter, Scene Details and its Element editor, the shared `new`/`edit` form, the Characters/Items/Locations tabs, both story taxonomies, the Sections workspace's ungrouped block, and a universe record's "Appears in scenes" section — 21 of the 100 ERB views, plus the controllers, helpers, and model labels they read.
- **[changed]** The **Universe Bible workspaces** now render in Spanish as well: `characters/*`, `locations/*`, `events/*`, `items/*`, `relations/*`, `ownerships/*`, the six universe-level `*_tags` indexes and their `show` pages, the modal editors those lists open, and the flash confirmations of the two workspaces that use the HTML redirect flow.
- **[changed]** The modal editors' field labels are translated where they are **produced**, not where they are printed.
- **[changed]** The residual duplication the heading-ownership test cannot see is removed — the same fact stated under two different headings, which is the case a heading test structurally cannot catch.
- **[changed]** The `db/data` guidance in `development.md` and `conventions.md` were a third and fourth statement of the same rules.
- **[changed]** `docs/development.md`'s "Scene delivery (complete)" no longer narrates what each delivery slice added.
- **[changed]** The documentation is reorganized around **one fact, one home**, and each feature now has a single document that owns its rules.
- **[changed]** `data_model.md` now keeps only the schema — tables, columns, indexes, constraints, the taxonomy matrix, soft delete, slugs, positions — and its Scene section is reduced to the two migration facts, with the behavior narrative left to the documents that own it.

- **[fixed]** The search dropdown's shortfall message is a plural now, so one character says "character" — the sentence used to be assembled in the controller, where no locale could choose a different form.
- **[fixed]** The **Relations and Ownerships rows** built their delete confirmation's record name as an English frame — `relation_name = "#{relation.character1.name} and #{relation.character2.name}"` — which the Universe Bible slice translated around but not in.
- **[fixed]** A **dismiss control clicked while a modal is still fading in is no longer dropped**, in both shared editors.
- **[fixed]** A **Relation or Ownership can now be named**, and a stored in-world time survives an edit.
- **[fixed]** The **Event editor** no longer offers the event being edited as one of its own `Happens before` / `Happens after` / `Same time as` references.
- **[fixed]** Deleting a **Character, Item, or Location** now says what it deletes.
- **[fixed]** Two translation defects on the same code path: a determiner a language agrees in gender cannot be derived from an interpolated noun, and a model-level `errors.add` message is chrome too — `Scene`'s five messages were still English literals.
- **[fixed]** Three Spanish sentences this surface exposed were ungrammatical in **both** languages, and both fixes are the same rule.
- **[fixed]** `config/locales/es.yml` was missing `errors.messages.required`, which Rails defines in English only, so a Spanish page rejecting a **missing** `belongs_to` raised `I18n::MissingTranslationData` while its other messages rendered. The key is added and the parity test's Rails-key check now covers it.
- **[fixed]** A `blank:` state that cannot be reached is a translation nothing renders, and it is worse than a missing one because a reviewer cannot tell it apart from a real state.
- **[fixed]** `TaggedRecordCounts` counted soft-deleted records, so a taxonomy's `(N characters)` pill kept a deleted record. Its grouped query is raw SQL, where the element model's `default_scope` does not apply, so the subquery now filters `deleted_at` alongside `universe_id`/`story_id`.
- **[fixed]** `SectionsController` and `LocationsController` had no format guard, so an HTML request committed the record and only then answered `406`. Both now include `RequiresJsonMutationFormat` on create/update/destroy, matching the eight controllers that already had it.
- **[fixed]** `config/locales/es.yml` carried **two** `errors:` blocks, and a repeated mapping key is not an error to Psych: the later value silently replaces the earlier one.
- **[fixed]** The translation parity test decided which keys the application owns by **namespace**, exempting all of `errors`, so the two keys this app owns beside Rails' own were never compared between the two locale files. Ownership is now decided **per key**, read from the framework' own locale files rather than a hardcoded list.
- **[fixed]** `docs/adr/README.md` did not mention `docs/features/`, so the eight feature documents were unreachable from the ADR index that 16 of 17 ADRs link to.
- **[fixed]** ADR 0014 (global search) was the only one of seventeen with no `## Related documentation` section, although `adr/README.md` and `0000-template.md` both require it; its cross-references lived in a header line instead. It now has the standard section and points at `features/search.md` as the search subsystem's home.
- **[fixed]** The Scene editor's workspace tabs were documented as two live links and two `aria-disabled` placeholders in three places, long after Items and Locations shipped.
- **[fixed]** `docs/architecture.md` cited "former quirk #18" for the sidebar count cache, but quirk 18 in `docs/delivery_history.md` is about mutation failures in editors; the sidebar-count finding is a separate, differently named heading.
- **[fixed]** `docs/conventions.md` said `HasManyTags` enforces the shared universe or story scope "for all seven content/tag pairs".
- **[fixed]** `docs/data_model.md` listed `db/data/star_wars/` as an existing universe directory alongside `dark` and `lotr`; only those two exist. `docs/development.md` still shows it, and is left as it is, because there it is explicitly annotated `# future universe data`.
- **[fixed]** Removed two dead links to `docs/schema.txt`, a file that does not exist, from `docs/data_model.md` and `docs/README.md`. The ownership graph and the per-table reference in `docs/data_model.md` already cover what that link promised.
- **[fixed]** `docs/conventions.md` carried its own errata in the body and a stale delivery promise about the Scene slices, long shipped. The Event taxonomy is now stated as current fact and the delivery sentence is gone.

- **[docs]** `docs/development.md` records why the CI migration commands must be separate processes, and that Bun runs every client-side test file in one process with shared module state.
- **[docs]** **The changelog was too detailed to be readable, and the fix was to split it in two rather than to trim it.**
- **[docs]** `docs/features/i18n.md` records the decision this slice settled: a search document's title is a record's label **in the default locale** while a view resolves `#display_label` in the reader's language, why `Relation` needs no second form, and what a change to the stored wording costs.
- **[docs]** `docs/features/i18n.md` records the three translation rules this surface settled: a determiner a language agrees in gender is its own interpolation beside the noun, a link inside a sentence is one `_html` key with the link as the interpolation, and a value object that is not a view resolves its keys with `I18n.t`.
- **[docs]** Known quirk 61 records that a dismiss control clicked while a modal is still fading in is silently dropped: **Cancel**, `btn-close`, Escape, and a backdrop click all resolve to the one Bootstrap instance `modal_form_controller.js` owns, so the first attempt does nothing and only the second closes the modal.
- **[docs]** `docs/features/i18n.md` records four more rules this surface settled: a frozen constant cannot hold a route-helper lambda, `label_key` is dropped from the serialized descriptor, a sentence decides its own determiner while a single-noun slot takes the singular, and a `form_with scope:` modal has no model to read attribute names from and must name its own labels.
- **[docs]** ADR 0007's deletion contract was written against the hard delete and does not describe the shipped soft delete.
- **[docs]** ADR 0015 claimed "Destroying the record's universe does remove them, because `Photo` belongs to it", and no such cascade exists: `Universe` declares no `has_many :photos`, its `soft_deletes` omits photos, and `db/schema.rb`'s foreign key has no `on_delete:`, so it is `NO ACTION` and would not cascade even on a hard delete.
- **[docs]** ADR 0016 no longer repeats ADR 0013's reasons for rejecting a `users.locale` column; it cites that ADR and states only what the locale adds — a queued password reset written in the reader's own language, and cookie precedence for a signed-out reader.
- **[docs]** Two things were checked and deliberately left alone, so they are not "fixed" later.
- **[docs]** Eleven smaller second statements were replaced by links to the owning section: the photo cropper and its `data:` transport, the `PhotoParams` splat and the grouped-tag badge map, the `PHOTO_FIELD` descriptor, the identity card's photo layout, the navbar entries and sidebar hues, the taxonomy row's overflow menu, the hover-reveal accessibility rule, the browser-theme premise, the `@layers` Timeline rule, and the amended-migration mechanism.
- **[docs]** `conventions.md` stated the identity card's photo layout **twice** — once in "Record details pages" and once in the Helpers list — and `visual_design.md` stated it a third time. Only the first survives; the other two link to it.
- **[docs]** Verified that this pass lost no content either: every distinctive class name, method name, shared partial, task name, and registry constant referenced by the five documents before the whole refactor is still referenced after it — 142 tokens, none missing.
- **[docs]** A measurement pass over the living documents now shows five remaining cross-document repeats of 14 or more words, down from more than fifteen pairs.
- **[docs]** Replaced the flat "read these five documents before changing code" list in `AGENTS.md` and `docs/README.md` with a subject-to-owner table.
- **[docs]** `docs/known_quirks.md` finding 37 tracked the dead `schema.txt` links; that clause is removed and the rest of the finding is kept open.
- **[docs]** `AGENTS.md` and `docs/README.md` now carry a subject-to-owner table that maps each subject — the five core documents plus the seven feature documents — to the document that owns it, and both state that a feature's rules live in exactly one `docs/features/` document.
- **[docs]** Three cross-references in two ADRs were repointed at their sections' new homes, so the reader is not sent to a section that no longer exists: ADR 0015's photo links now point at `features/photos.md` and `development.md#testing-record-photos`, and ADR 0007's soft-delete link now points only at `data_model.md`.
- **[docs]** `docs/development.md`'s `## Photos` heading is renamed `## Testing record photos`, so the test workflow keeps its home while the photo contract has one.
- **[docs]** Verified that the reorganization lost no content: every distinctive class name, method name, shared partial, and helper referenced by the four documents before the move is still referenced after it. `shared/_search_bar` and `TimelineController` were the only two mentions lost, and both were restored.
- **[docs]** The changelog's historical entries are now summaries: all 299 entries across the 22 recorded dates were reduced to one or two sentences each, derived from the long form rather than rewritten.

- **[chore]** The photo tests measure a stored image through the same libvips-then-ImageMagick pair `PhotoProcessing` uses, instead of shelling out to ImageMagick's `identify` and `convert`, which CI does not install — that is why the `test` and `system-test` jobs were red.
- **[chore]** Two checks now guard the validation messages only a *rejected* request can reach: `model_error_message_literals_test.rb` fails on a quoted string in `errors.add` or `message:`, and `spanish_chrome_test.rb` drives the failing requests and asserts the Spanish answer carries no English.
- **[chore]** `docs/adr_audit.md` — the point-in-time audit of all sixteen accepted ADRs against the code — was removed once its findings had been acted on, since it duplicated what this entry and the two ADR notes now record.
- **[chore]** Added `test/docs_test.rb`, which makes the documentation's own consistency a test rather than a convention nobody checks.
- **[chore]** The heading-ownership test ships with the documentation's existing duplication debt listed explicitly, naming both the heading and the documents that currently own it, so the suite is green while the debt is paid.
- **[chore]** `test/docs_test.rb` now also checks links **out of** historical records (`docs/adr/**`, `docs/delivery_history.md`).
- **[chore]** `KNOWN_DUPLICATED_HEADINGS` in `test/docs_test.rb` is now **empty**.

## 2026-09-29

- **[added]** The application can now be read in Spanish, and the language is a browser-owned preference chosen on the settings page.
- **[added]** Every "main" record and tag can now carry one optional photo: universes, stories, sections, scenes, characters, locations, items, events, relations, ownerships, and all eight tag models.

- **[changed]** The Universe and Story workspaces now render in Spanish as well: `universes/*` (index, show, new, edit, `_form`, `_universe`), `stories/*`, `memberships/*`, `sections/{index,show}`, `tags/index` (the taxonomy workspace), `timeline/index`, and the Universes, Stories, and Memberships controller flash and confirmation messages.
- **[changed]** The Sections workspace, the taxonomy workspace, and the Timeline read their copy from the locale too: the add-section action, the per-section delete confirmation, the per-taxonomy workspace copy, and the Timeline's event popover labels and relationship phrases.
- **[changed]** Application chrome now lives behind `t("dotted.key")` in `config/locales/en.yml`, with a Spanish `config/locales/es.yml` mirroring it.
- **[changed]** A missing translation is now a test failure rather than a silent English string on a Spanish page.
- **[changed]** A workspace's count label is now an I18n key rather than an English noun, so the plural comes from the locale instead of from an appended "s".
- **[changed]** On a tag page reached from a workspace menu tab, the tab strip now sits between the page header and the tag's identity card instead of below the card, so the navigation reads as one piece the way it does on every other workspace page.
- **[changed]** Non-taggable grouping tags now show each direct child tag with its own assigned records instead of flattening descendant results; the include-descendants checkbox remains on taggable tags.

- **[fixed]** The Timeline could draw arrows that contradicted its own layout (known quirk 24, now in `docs/delivery_history.md`).
- **[fixed]** A Timeline node is now reachable and understandable without a mouse (known quirk 46).
- **[fixed]** The browser suite is green again: four stale assertions in `test/system/tag_improvements_test.rb` and `test/system/taxonomy_tree_test.rb` were red before any new work started (known quirk 60, now in `docs/delivery_history.md`).
- **[fixed]** Two universes whose names slugify alike no longer fail with a `500`.
- **[fixed]** Signing in no longer leaves the visitor on the sign-in page.

- **[docs]** The docs described a Timeline pan/zoom interaction that has never existed: it was claimed from the feature's first commit (`fef94d1`) while `timeline_controller.js` only ever drew edges and popovers.
- **[docs]** The browser suite is red for a reason that is now written down instead of being rediscovered.
- **[docs]** Quirk 48 — a delegated admin demoting or removing their own membership — was already fixed earlier today but still listed as open.
- **[docs]** Added [ADR 0016](adr/0016-internationalization-and-browser-locale.md) for the translation contract: why the language is a cookie rather than a `User` column, why only chrome is translated, why a missing key fails instead of falling back to English, and why a value that travels in a URL is not translated.
- **[docs]** Documentation no longer cites a backlog item number, because a number is deleted from `docs/backlog.md` when its item completes and the citation then points at nothing.
- **[docs]** ADR 0007 claimed that every one of its mandatory deletion-confirmation templates was live.
- **[docs]** `AGENTS.md` and the development guide now require clarifying a request before coding starts.
- **[docs]** Updated the tag data model, workspace conventions, and development guide with the grouping, menu-navigation, and demo-data verification behavior.

- **[chore]** Dark demo data now calls the Character grouping tag **Factions** and pins both **Factions** and the assignable **Family Nielsen** tag in the workspace menu. Request tests cover grouped child results and the different workspace/taxonomy navigation paths.

- **[planned]** `docs/backlog.md`'s internationalization item is now written as ordered slices recording the measured string surface, instead of a one-line note, so the remaining work can be picked up one slice at a time.
- **[planned]** Backlog item 26 records a safety follow-up: `db:demo:reset` invoked Rails `db:drop`, which also dropped the local test database. The implementation remains deferred; approval for a development-data reset must never extend to test or production databases.

## 2026-09-28

- **[added]** Every content table with a user-facing delete action now carries a nullable `deleted_at`, and a delete marks that column instead of removing the row.
- **[added]** The settings page now has a **Go back** action in its header.
- **[added]** Every tag details page now has an **"Include records from child tags" toggle** (enabled by default).
- **[added]** Tags can now be **groupings that are not assignable**.

- **[changed]** Controllers now call `soft_delete` instead of `destroy!`, and `PositionedResourceOrder` soft-deletes through the same transaction that normalizes the remaining siblings' positions, so a soft-deleted record leaves the same contiguous gap a hard delete would.
- **[changed]** The top bar's **Settings** entry moved into the **account dropdown**, which is now the bar's only action and is rendered for every visitor: a signed-in reader sees their email, **Settings**, and **Log out**, while a guest sees **Log in** and **Settings** instead of a standalone login button.
- **[changed]** The taxonomy editor's field descriptors are now built by shared `ModalFields` helpers (`taxonomy_tag_fields` for every taxonomy, `content_tag_taxonomy_fields` for the four content tags) instead of eight hand-maintained copies, and the tag workspace config is declarative `TagsHelper` metadata with the mechanical keys derived from the type name.
- **[changed]** Flash messages are now **floating toasts fixed to the top-right corner** instead of in-page alerts.

- **[fixed]** Signing in from any page now returns the reader to **that page** instead of the landing page. The sign-in page remembers where it was opened from (a same-host referer), the same way a protected action already remembered the page that refused access; an external site cannot choose the destination.
- **[fixed]** Read-only empty taxonomy pages no longer instruct guests and read-only members to "Add" or drag records. Every remaining `shared/taxonomy_tree` caller now passes `read_only_empty_description`, so an empty taxonomy shows mutation copy only to writers (quirk 45).
- **[fixed]** The eight tag controllers no longer advertise `new` and `edit` routes that have no template or action.
- **[fixed]** A delegated admin could **demote or remove their own membership** and land on a bodyless `403` from the redirect that re-ran the authorization they had just lost. `MembershipsController` now refuses a self-mutation with a redirect and alert, and the view renders a "You" label instead of controls on the caller's own row.
- **[fixed]** Text typed into the top-bar search field **went dark the moment the field was focused**, because Bootstrap's `.form-control:focus` repaints `color` from the body color and outranks the plain class selector. The input's own `&:focus` block now restates the bar's text color.
- **[fixed]** The search box's **"Go to" rows were dark on dark** — the theme's link blue on the bar's near-black panel at 2.6:1 — because the controller names them `navbar-search-#{kind}` and the stylesheet only styled `result` and `message`. That row kind is now styled with the panel's own surface and text color.
- **[fixed]** The top-bar search box's **See all results** link was drawn across the bottom of the input, hiding the text and caret as soon as results arrived, because `bottom: 0` resolved against the field rather than the results. The dropdown and the link are now one `.navbar-search-panel` box, with the link in flow as its footer.

- **[security]** Changing a record's **owning scope no longer strands its dependents** in the old universe or story.
- **[security]** The seven **legacy tag join tables** now carry the **real foreign keys and a unique-pair index** the Scene-era join tables already had, so a duplicate or orphan join row is rejected by the database itself rather than only by the scoped association reads.

- **[docs]** `data_model.md` documents the `taggable` and `show_in_menu` tag columns, `universe_maker_conventions.md` states the shared tag-editor field builders and the `show_in_menu` tab rule, and `architecture.md` describes the batch-loaded tag badges on a tag's details page.
- **[docs]** `AGENTS.md` now requires checking [`known_quirks.md`](known_quirks.md) for a related open quirk before starting any [`backlog.md`](backlog.md) item and asking the owner whether to fix it in the same change, so a backlog task cannot silently inherit a known hole in the same model, table, controller, route, or code path.
- **[docs]** `visual_design.md` now says that both kinds of row in the panel wear the same row treatment and why the highlight is keyed on the title rather than on a row kind, and `universe_maker_conventions.md` states the rule behind it: every option row is painted by the panel and never inherits from the page, so a new kind joins the row selectors in the change that introduces it.
- **[docs]** `visual_design.md` describes the link as the panel's footer with the reason it is in flow, and `universe_maker_conventions.md` states the rule behind it: nothing inside the dropdown is positioned against the form, because anything that is resolves against a form no taller than the field.

- **[chore]** New `test/models/soft_deletable_test.rb` covers the default scope, the cascade, restore, the Section/Event nullify behavior, and the partial-unique-index re-creation rule; the scene-elements destroy test now asserts the element is soft-deleted and its speaker links are kept for restore.
- **[chore]** Fixtures set `taggable` and `show_in_menu`, both development universes exercise grouping and menu tags, and new cases cover the defaults, the editor dropdown filter, the workspace menu tab, the details-page badges, the modal checkboxes, and the read-only empty copy.
- **[chore]** CI now proves the migrations run from an empty database.
- **[chore]** A new `test/system/search_test.rb` case measures **every** option in the list instead of one named row: it composites the painted colors in the browser and holds the *worst* row — whichever kind it is — to AA, holds the panel to a single highlight fill across kinds, and holds the keyboard cursor to a visible change of surface.
- **[chore]** `test/system/search_test.rb` asserted nothing about where the panel's parts land, and four of its cases were intermittently failing: Stimulus resolves each controller through a dynamic `import()` and connects it on a later turn of the router, so a keystroke delivered in between is dropped and the box stays silent.

- **[planned]** `docs/backlog.md` items 20–25 now hold the full collaboration system plan: six phases covering universe collaboration modes (`direct`/`wikipedia`/`github`), per-record discussions, a draft/apply mutation system with per-record conflict resolution ("theirs"/"mine"), a GitHub-style review workflow for owner+admins, and in-app notifications.

## 2026-09-27

- **[added]** A **magic search bar** in the top bar, on every page and for guests.
- **[added]** The search itself is **Meilisearch**, behind one `Search::Client` and a `Searchable` model concern: 19 models declare, next to their own fields, what they contribute to the index (`searchable kind:, title:, body:, route:, scope:, taxonomy:`), and `Search::Registry` holds the list a reindex reads.
- **[added]** Search is a **read that answers in two formats** — the results page and the dropdown — which is a new response pattern for a controller with no mutation path at all, and the first read-only flow here to serve both.
- **[added]** A missing or broken engine is a **stated state, not a failure**: `Search.backend` is `Search::UnavailableBackend` when `MEILISEARCH_URL` is unset, every engine error is re-raised as `Search::Unavailable`, and the page or payload says so with the reason while the rest of the page renders.
- **[added]** A **Settings** page at `/settings` with vertical tabs, reached from one new **Settings** entry in the top bar next to the account menu and rendered for every visitor, guest included.
- **[added]** Dark mode. `AppTheme` holds the whole feature: two known names, `light` as the default, and one **signed** cookie (`um_theme`, a year, `HttpOnly`, `SameSite=Lax`, `Secure` in production) — no migration, no model, and no authorization.
- **[added]** Backlog slices **11.8, 11.9, and 11.10**, which complete **Epic 11 — Add Scenes to a Story** in every slice it specified.
- **[added]** `SceneItem` (`scene_items`: `scene_id` + `item_id` with real foreign keys, a unique pair index, and a nullable free-text `role`) is a join model for the same reason `SceneCharacter` is: the role is part of the decision, and a blank role means no role rather than an empty annotation.
- **[added]** `SceneLocation` (`scene_locations`, the same shape) with the **plural Locations** tab, because a Scene may use any number of places.
- **[added]** `SceneAppearances` and the **Appears in scenes of &lt;Story&gt;** section on the Character, Item, Location, and Event details pages: the reverse of the three workspace tabs, so a shared universe record can be traced forward into the Story's narrative sequence.
- **[added]** `test/models/scene_continuity_queries_test.rb` pins the shapes a later checker will read: several Scenes may depict one Event, narrative order is `position` even when in-world `datetime`s disagree, the Event reference and Scene datetime stay independent, one shared record can appear in many Scenes across Stories, and no query blends two Stories.
- **[added]** Connected development data for all three new models in `db/data/dark` and `db/data/lotr`: the same Item in two Scenes, two Items in one Scene, a Scene with three linked Locations, a nested Location beside a top-level one, populated and blank roles across all three tabs, and Scenes with no Item or Location so each empty state is reachable without inventing a record.
- **[added]** Backlog slices **11.6 and 11.7** — Scene Elements with Dialogue speakers, and Character presence in a Scene.
- **[added]** Participation in a Scene is read from its two independent sources — an explicit `SceneCharacter` link and a Character who speaks in a Dialogue Element — and reported as their **union** through the new `SceneParticipants` value object.
- **[added]** Connected development data for both new models in `db/data/dark` and `db/data/lotr`: a Scene with no Elements, a Dialogue whose speakers are not stored participants, a one-speaker and a three-speaker dialogue, two title-only Element blocks, a populated role, and two blank roles.
- **[added]** Closed known quirk 33 with a real client-side pipeline, recorded as [ADR 0012](adr/0012-client-side-verification-and-csrf.md).
- **[added]** `test/javascript/no_html_sink_test.js` fails when a new `innerHTML`/`outerHTML`/`insertAdjacentHTML`/`document.write` sink appears in `app/javascript` without a reviewed exception, so the DOM-API-only rule behind the resolved DOM-XSS finding is enforced rather than advisory.

- **[changed]** **`bin/dev` now starts the search engine too**
- **[changed]** `Procfile.dev` now carries `MEILISEARCH_URL` and `MEILISEARCH_API_KEY` on its `web` line, so `bin/dev` reaches a local engine without the developer exporting anything first.
- **[changed]** The light-only literal surfaces in the custom stylesheets became `--um-*` tokens (`--um-surface-raised`, `--um-row-hover`, `--um-surface-veil`, `--um-tag-badge-border`) with a `[data-bs-theme="dark"]` value, and every existing `--um-*` token that carried a light-only value is re-tinted there.
- **[changed]** All four Scene workspace tabs are now live links, so the tab shell renders no `aria-disabled` placeholder and no tab ever points at a route that does not exist.
- **[changed]** `shared/detail_section` accepts a pre-rendered `empty_action` for the empty case. The section's own block is the record list, which an empty section has no use for, so the two could not share it; existing callers pass no `empty_action` and are unaffected.

- **[fixed]** `bin/rails search:status` **crashed** in the state it exists to diagnose: it asked for a document count unconditionally, so a missing index raised `Search::Unavailable` instead of reporting the state. The count is now asked for only when the index exists, and the missing case is reported with the command that fixes it.
- **[fixed]** The search dropdown's **matched run was harder to read than the rest of the title**, which is the opposite of a highlight.
- **[fixed]** The top-bar search box's **scope** dropdown rendered as an opaque, square-cornered panel inside the rounded field: the bar declared `--bs-form-select-*` custom properties, but Bootstrap 5.3 compiles `.form-select` from Sass variables and never reads them, so the rule was a no-op. It now wears no surface of its own and uses the bar' own chevron.
- **[fixed]** Three **engine-contract bugs that failed silently**, found by running against the real engine rather than a stand-in: a `:` in a document id made it reject every batch, so a reindex reported 214 documents over an empty index, and a kind-based id let the eight taxonomies overwrite each other.
- **[fixed]** Search is available to guests and to read-only members: the top bar renders the box everywhere, and `Authentication` denies a request without an explicit `allow_unauthenticated_access`, so the search endpoint was redirecting every signed-out visitor to the sign-in form.
- **[fixed]** The settings form opts out of Turbo (`data: { turbo: false }`): Turbo Drive replaces the body and head but not attributes on the **root** element, so a Turbo submission stored the new theme and kept painting the old one.
- **[fixed]** `.navbar-actions` is now a flex row, so the new settings entry and the account menu sit side by side instead of stacking once the bar holds more than one action.
- **[fixed]** The development-data loader logged every join record as `Created SceneItem: record`, which made a load impossible to verify by reading its own output and applied to `SceneCharacter` since slice 11.7. It now names a link row by the records it joins (`Created SceneItem: scene.secrets -> item.jonas-key`).
- **[fixed]** A system-test click delivered before Stimulus and Turbo had connected was silently dropped on some machines, so a case that had not waited for the page to be interactive failed for a reason that had nothing to do with the flow under test — the existing Scene tests failed this way on a clean checkout.
- **[fixed]** Three defects the new unit tests found in the code they were written for: cancelling an inline taxonomy rename restored the author's unsaved text instead of the server's name, a `belongs_to` error keyed on `:parent` was labelled `parent` rather than the editor's **Parent tag** label, and a `422` body whose `errors` was not an object was read as an error on an attribute literally called `errors`.
- **[fixed]** The taxonomy editor's `fetch` always sent an `X-CSRF-Token` header, so a page without the meta tag would have sent the literal string `undefined` and been refused as an invalid token rather than a missing one. It now omits the header, as the flat-list modal already did.

- **[security]** Both new endpoints refuse an HTML mutation with `406` **before** anything is written, refuse a mutation without a valid CSRF token with `403` and write nothing, and resolve every record through the authorized Universe → Story → Scene path, so a foreign Scene, presence link, Item, or Location is a `404` rather than a cross-scope write.
- **[security]** Both new endpoints refuse an HTML mutation with `406` **before** anything is written, refuse a mutation without a valid CSRF token with `403` and write nothing, and resolve every record through the authorized Universe → Story → Scene path, so a foreign Scene, Element, presence link, or Character is a `404` rather than a cross-scope write.
- **[security]** A mutation that arrives without a valid CSRF token is now refused as a refusal rather than as a validation failure: `ApplicationController` answers `403` for a JSON request whose token Rails rejects, so the shared editor says the change was refused and keeps the author's input instead of reporting that the server explained nothing.

- **[docs]** `development.md` now states the one Sass rule the warning above exposed: the pinned compiler resolves no global built-in module namespace, so `color.mix` needs an explicit `@use "sass:color";` as the file's first rule, and the compile step silences only the `@import` deprecation, not the global-builtin one.
- **[docs]** `AGENTS.md` now states that the owner makes **every** commit and push: an agent codes, runs services, and resets the development database, and leaves the work in the working tree.
- **[docs]** New [ADR 0014](adr/0014-global-search-with-meilisearch.md) records why Meilisearch rather than SQL `LIKE`, SQLite FTS5, or a SQL fallback behind the engine, and what an engine outage, a rename, and an index rebuild each cost.
- **[docs]** New [ADR 0013](adr/0013-platform-settings-and-browser-theme.md) records why settings is browser-owned, server-rendered, and outside the universe workspace, and what a later per-account preference or instant toggle would have to change.
- **[docs]** `docs/architecture.md`, `docs/data_model.md`, `docs/conventions.md`, `docs/visual_design.md`, `docs/development.md`, `docs/known_quirks.md`, and ADR 0007 record the delivered Scene state: every route in the ADR's target-URL table is live, the third presence link, the plural Locations tab, `LocationPaths`, the `SceneAppearances` union and its story scoping, and the manual verification steps.
- **[docs]** `docs/architecture.md`, `docs/data_model.md`, `docs/conventions.md`, `docs/visual_design.md`, `docs/development.md`, and ADR 0007 record the delivered Scene slices, the hybrid response split, the two flat ordered sequences, the participation union, and the manual verification steps.
- **[docs]** `docs/known_quirks.md` now holds only open findings.
- **[docs]** `docs/development.md` documents the client-side commands, the test layout, and the `js-check` job; `docs/architecture.md` records the test-environment CSRF rule and the token in the editor data flow; `docs/universe_maker_conventions.md` states the client-side rules every editor follows.

- **[chore]** The CSS build is **warning-free again**: the two `mix()` calls that derive the top-bar search field's opaque surfaces were the project's last use of a deprecated global built-in, and this pinned Sass no longer resolves global built-in module namespaces, so `color.mix` has to be namespaced explicitly.
- **[chore]** The test environment now uses the `:test` queue adapter, so the suite can assert what a save would have indexed without running anything, and `test/support/search_test_backend.rb` stands in for the engine: it records the query it was asked and replays chosen hits, proving what the application does with an answer without pretending to search.
- **[chore]** `test/models/app_theme_test.rb` pins the theme whitelist and cookie contract, `settings_controller_test.rb` covers the page for a guest and for a signed-in user with no universe plus the redirect and every refusal path, `navigation_test.rb` pins the top-bar entry, and `csrf_mutation_test.rb` proves the new HTML mutation needs a token.
- **[chore]** New coverage for the delivered Scene slices: model tests for Scene items, Scene locations, `LocationPaths`, appearances, and continuity queries, controller tests for the Scene item, location, and appearance endpoints, and system tests for items, locations, and appearances.
- **[chore]** New client-side coverage: `test/javascript/scene_element_form_controller_test.js` and five cases for the shared modal controller's `move` action, bringing the Bun suite to 75 cases.
- **[chore]** Biome's first run reported twelve real problems, all fixed here: two self-assigning `window.location.href = window.location.href` reload fallbacks became `window.location.reload()`, and ten `forEach` callbacks that returned a value gained braced bodies.
- **[chore]** `@biomejs/biome` and `@happy-dom/global-registrator` are the project's first development-only JavaScript dependencies, pinned through the committed `bun.lock`; `bun install --frozen-lockfile` is clean, and `bun audit` reports no vulnerabilities across 116 packages.

## 2026-09-26

- **[added]** Completed backlog item 11.5, the shared modal reliability slice that Scene Elements depend on, recorded as [ADR 0011](adr/0011-modal-json-mutation-contract.md).
- **[added]** A rejected save is now visible, explained, and recoverable in the modal it came from.
- **[added]** A mutation that never went through a form — a row delete — or a request that failed outside a modal now reports itself in one page-level live region rendered by the layout beside the flash messages: a short confirmation is visually hidden and only announced, a failure renders a visible alert and takes focus, and the refreshed page starts empty again.
- **[added]** Completed backlog item 11.4.1, part (b) — the Scenes workspace gained a **Find scenes** search area, because a story can hold hundreds or thousands of scenes.
- **[added]** The filtered list keeps the story's canonical meaning.

- **[changed]** Delete in a JSON-only workspace is a first-class mutation instead of a Turbo form against a `204`.
- **[changed]** A JSON-only mutation controller can no longer commit behind its own error.
- **[changed]** The Sections workspace **Move scene** form now offers only the ungrouped scenes its own surface lists, and its source selector is labelled **Ungrouped scene** so the control matches the block it lives in.
- **[changed]** Completed backlog item 22. The top bar is now three links and the account menu, with no switcher dropdown: **Universe Maker** is the brand and the landing page, and **Universe: …** / **Story: …** are plain links to the current universe page and the current story page.
- **[changed]** Completed backlog item 23. Every list row now has one shape: a plain-text name with its tag badges and, where a count exists, a `.record-count` pill on the left, and a right-hand group holding an always-visible **Details** link followed by an always-visible `[…]` action menu.
- **[changed]** Completed backlog item 11.4.1, part (b) for the Sections workspace.

- **[fixed]** Closed known quirk 18 — a rejected mutation now explains itself in every editor instead of only announcing that something went wrong.
- **[fixed]** The other half of quirk 18 is closed for the two HTML-flow modal workspaces: Relations and ownerships render the shared `shared/_error_summary` twice, once on the page the author lands on and once inside the reopened editor, and serialize the rejected values into the trigger, so a refused form no longer has to be retyped from scratch.
- **[fixed]** Closed known quirk 32 — the browser suite had only covered the taxonomy tree and the Scenes workspaces, and its one flat-list test passed even while its mutation was committed and answered `406`.
- **[fixed]** Two defects in this work were found only by the browser coverage and are fixed here.
- **[fixed]** The flat-list modal committed a write and then answered `406 ActionController::UnknownFormat`, so a browser create or update saved the record, showed no error, and duplicated the record on a retry. Validation failures now reach the form instead of disappearing.
- **[fixed]** Deleting a row in Characters, Items, or Events left the row and the counts in the DOM until a manual reload, and a second click could target a missing record. The row is now removed and the page and sidebar counts refreshed from the server.
- **[fixed]** Two defects the new browser coverage found: opening a tag editor filled Rails' hidden companion field instead of the visible multi-select, and a multi-select whose name already ended in `[]` was given a second `[]`, so removing the last tag left the stored assignment in place.
- **[fixed]** A count on a row now says what it counts instead of showing a bare figure.

- **[docs]** Every place the list-row contract is written down was updated after the count-label and Sections-workspace changes, so the count pill, the ungrouped-only move form, and the badge wording are described the same way in `architecture.md`, `conventions.md`, `visual_design.md`, `data_model.md`, `development.md`, the ADR 0007 execution note, and the relevant code comments.
- **[docs]** Recorded the delivered slice in the Scene architecture (a new "The story's Scene list is filtered, never re-ordered" section), the conventions, the visual design, the development guide, and an ADR 0007 execution note that states how the "separate grouped outline" decision is now implemented.
- **[docs]** Adopted the known-quirks discipline for the shared backlog: `docs/backlog.md` now holds pending work only, and finished work leaves it.
- **[docs]** The backlog's finished items were removed — 12 (taxonomy modal XSS and stale state), 13 (tree insertion and reordering), 21 (taxonomy editor visuals), 22 (details pages), 23 (navigation and sidebar visual pass), plus the delivered Epic 11 slice write-ups — since each was already recorded in a changelog entry.
- **[docs]** Dropped the now-done backlog pointers from `docs/architecture.md` and from the `SectionsController#show` and `sections/show.html.erb` comments; they described shipped behavior as pending. No application behavior, schema, or data changed.

- **[chore]** Post-mutation browser assertions now use a shared `REFRESH_WAIT` in `ApplicationSystemTestCase`: a mutation ends in a full same-URL navigation, so the first assertion after one waits ten seconds instead of Capybara's two. It only changes how long a passing refresh may take.
- **[chore]** Reworked the Dark `db/data/dark/scenes.yml` sample data (12 scenes) so grouping and narrative order are visibly different things: three scenes share Season 1 / Episode 1, three are ungrouped — including one told last but set in 1953 and one unfinished title-only scene — and each remaining section keeps a single scene.

## 2026-09-25

- **[added]** Completed backlog item 22. Every standard element and every element tag now has its own read-only details page — Character, Location, Item, Event, Relation, Ownership, Section, and the Character, Relation, Location, Event, Item, Ownership, Section, and Scene tags.
- **[added]** `HasManyTags#tagged_records` (the scoped inverse association, ordered by name) backs each tag's page and cannot disclose another universe's or story's records.
- **[added]** Completed Epic 11 slice 11.4, Scene Tag taxonomy and assignment.
- **[added]** Scene Details and the canonical Scenes list now show preloaded Scene Tag badges, and the single HTML Scene editor can assign or clear optional same-story tags without changing narrative position.
- **[added]** Added model, request, authorization, routing, development-loader, helper, and focused browser coverage for the new taxonomy and assignment paths; updated the Scene architecture, data model, conventions, visual design, development guide, ADR execution note, and known-quirk boundary.
- **[added]** Completed Epic 11 slices 11.2 and 11.3, the Scene references and Section grouping work.
- **[added]** `Scene` now belongs to an optional `Section` (same Story) and an optional `Event` (same Universe).
- **[added]** The Scene editor gained **Organization** and **In-world time** fieldsets (Section selector with **Ungrouped** and depth-indented Section paths, Event selector with **None**, and a `datetime-local` field) plus explicit copy separating narrative order from in-world time, and a URL-backed **Scene Details / Characters / Items / Locations** tab shell.
- **[added]** Section grouping shipped with two complementary paths, as ADR 0007 specifies: the Scene Details form assigns a Scene to **Ungrouped** or one Section, and the Sections workspace gained a **Grouped scenes** outline that keeps the existing taxonomy tree.
- **[added]** `SectionPaths` builds every root-first Section ancestor path and the depth-indented selector options from one ordered query, so list pages never walk ancestors per Scene.
- **[added]** Completed Epic 11 slice 11.1, the core Scene vertical slice: a schema-only `scenes` migration (real `story_id` foreign key, indexed `position`, `slug`) and `Scene` model with a required Title, optional short description, and no `parent_id`.
- **[added]** Added story-scoped Scene routes and `ScenesController` on the HTML redirect/re-render flow: the canonical `/u/:universe_slug/s/:story_id/scenes` list with narrative-position badges and description previews, a full add/edit/delete journey, one shared editor form, and a keyboard- and touch-operable `move` action.
- **[added]** Populated the disposable LOTR development universe with world-building sample data so every content model is exercised: 7 characters and 8 character tags, 12 hierarchically nested locations and 6 location tags, 5 items and 5 item tags, 5 relations with symmetric/asymmetric relation tags, 5 ownerships with date ranges, and 6 events forming a chained timeline with event tags.
- **[added]** Created this date-based `CHANGELOG.md` and added a standing rule to record every future code, site, data, test, documentation, configuration, security, and tooling change.
- **[added]** Implemented ADR 0008's registry-driven development universe loader: shared model order, strict YAML/file/reference/scope validation, normalized sibling positions, explicit `db:demo:check/load/reset` tasks, and common YAML data for Dark and LOTR.

- **[changed]** Moved **Configuration** out of the left workspace sidebar and into the right utility sidebar, which was renamed from **Settings** to match.
- **[changed]** Completed backlog item 21, the taxonomy editor's visual pass.
- **[changed]** Completed backlog item 23. Placeholder navigation is flat disabled gray with no hover emphasis, matching its `aria-disabled` semantics.
- **[changed]** `UniverseScopeResolver` is now the single answer to which universe owns a record; `Ability#universe_for` and `ApplicationHelper#universe_for_record` both delegate to it instead of duplicating the walk, and it resolves Scene-owned and Section-owned records through their owner.
- **[changed]** Deleting a Section or an Event now nullifies its Scene references instead of being silent about it, and the Story, Section, and Event delete confirmations use the mandatory ADR 0007 consequence templates. Deleting a shared record still never removes a Scene.
- **[changed]** The shared tree accepts a per-node `confirm_message` and a `read_only_empty_description`, and the shared row actions accept a `confirm_text`, so destructive copy and read-only empty states come from the server. The Sections workspace read-only empty state no longer tells a read-only member to add or drag sections.
- **[changed]** `shared/_content_tabs` can render a tab without a destination as an `aria-disabled` placeholder, which keeps a workspace tab from becoming a dead link.
- **[changed]** The left-sidebar **Scenes** entry is now a real story-scoped link with its own cached count while a Story is selected, and stays an `aria-disabled` placeholder with the existing "select a story" prompt when no Story is current — it never falls back to the first Story.

- **[fixed]** Corrected the `UniverseDataLoaderTest` Dark story-name expectation to `Netflix Dark`.
- **[fixed]** Stopped `DevelopmentDataTasksTest` from calling `Rails.application.load_tasks` once per test.
- **[fixed]** `MaintainsSiblingPositions` no longer assumes a `parent_id`: flat sequences omit the ordering parent entirely, so a parentless flat record works through the shared service.
- **[fixed]** Gave `Story` two separate sidebar count cache entries. `menu_scene_count` uses its own `cache_scope`, so adding a second scalar metric can no longer overwrite the section count; `InvalidatesMenuCounts` takes an optional `cache_scope:` for exactly this case.
- **[fixed]** Added ADR 0009 and `PositionedResourceOrder`: positioned controller mutations now maintain hierarchical and explicitly flat sequences transactionally across create, move, reparent, and destroy, with focused service/controller tests and flat development-data metadata.
- **[fixed]** Completed backlog items 12 and 13: taxonomy parent/tag options and counts no longer remain stale, boundary insertion uses the actual list, native rename supports Enter/Space, and Move/Insert controls plus touch-visible targets provide non-drag editing. Added ADRs 0010 and focused keyboard/touch/system regressions.
- **[fixed]** Hardened event temporal references with same-universe validation, model and database self-reference checks, and safe cleanup when referenced events are deleted.
- **[fixed]** Hardened the development loader after review: reset tasks guard before any drop, environment overrides are test-only, association types/targets are validated, file/position contracts are strict, and incomplete schemas can be repaired by the reset path.

- **[security]** Registered `Scene` in the `Ability` content registry; Scenes resolve their Universe through `scene.story.universe`, so public read stays open to guests while every mutation still requires the shared universe read/write/admin policy. Cross-scope story/scene lookups return 404.
- **[security]** Removed `.kamal/secrets` from Git tracking, added an ignore rule and CI guard, restricted the preserved local file to mode `0600`, and documented that master-key rotation and history cleanup remain owner actions. The secret value was not read or changed.
- **[security]** Redacted password-reset tokens from Rails request paths, added no-store/no-referrer reset headers, strong-parameter validation, and regression coverage for blank resets and rendered multipart mail.
- **[security]** Made production mail/URL/SMTP settings explicit and fail-closed, enabled HTTPS redirects/HSTS behavior, restricted the production host allowlist, and marked the session cookie `Secure`; added mailer, cookie, and production-configuration coverage.
- **[security]** Rebuilt taxonomy dynamic fields and nodes with DOM APIs instead of `innerHTML`, added hostile-name browser coverage, and refreshed server-rendered taxonomy state after every successful mutation.
- **[security]** Added machine-readable Tom Select version metadata to the local importmap pin and a regression test, so `bin/importmap audit` includes Tom Select 2.6.2 instead of skipping it. Complete Bun/npm graph, vendored-file provenance, and Dependabot coverage remain separate follow-up work.
- **[security]** Hardened the authentication and request lifecycle: stale authentication cookies are invalidated, remembered story context is cleared at account boundaries, and password resets safely invalidate the current browser session.
- **[security]** Made the universe visibility flag explicit and non-null, centralized public/private read-write-admin authorization, and enforced same-universe/same-story scope on tag associations and reads. Private-universe non-members now receive the same 404 response as an unknown universe.
- **[security]** Removed development data from `db:seed`/`db:prepare` and added environment and confirmation guards to destructive development database tasks; CI now validates checked-in data manifests instead of replanting demo records.

- **[docs]** Updated the architecture, conventions, visual design, and development docs for the sidebar move: the left workspace sidebar is two universe/story scope blocks, and the right utility sidebar is the tools scope with a green **Universe tools** context block followed by **Configuration** (Tags plus the admin Members manager) and the reserved Collaboration, Analytics, and AI groups.
- **[docs]** Separated consecutive date sections with a blank line, so every `##` heading is surrounded by one. The regrouped layout had left a date's last entry flush against the next heading; the blank-line rule is now "between label groups and between dates, never inside a group".
- **[docs]** Regularized this file's layout: entries inside a date are now grouped by label in the legend order, and the only blank line inside a date is the one between two label groups.
- **[docs]** Removed the completed backlog item for the explicit development universe-data loader after verifying the delivered state: `Development::UniverseDataRegistry`/`UniverseDataLoader`, the guarded `db:demo:check/load/reset` tasks, and YAML-only `db/data/dark` and `db/data/lotr` manifests, whose `db:demo:check` runs both pass.
- **[docs]** Updated the architecture, data model, conventions, visual design, and development docs for the two slices, marked backlog items 11.2 and 11.3 complete, and refreshed the known-quirk entries for optional-reference errors and ownership-scope resolution.
- **[docs]** Made the demo-YAML lifecycle explicit across contributor and agent guidance: every add/delete/update under `db/data/**/*.yml` must be validated and followed by a local development database reset (plus create-only loads for any additional universes wanted locally).
- **[docs]** Distilled the 2026-09-25 DataFactor report into the agent guide, a durable quality guidance document, ADR 0006, focused backlog items, and verified follow-up quirks.
- **[docs]** Completed Epic 11 slice 11.0 as a documentation-only decision: ADR 0007 fixes story-owned narrative ordering, the Scene/Scene Element field contract, independent Event/time references, URL-backed workspace and JSON/HTML response boundaries, Section grouping, and the detailed deletion confirmations.
- **[docs]** Clarified the slice 11.0 review findings: Scene uses one Event-compatible datetime point, shared-record deletion copy now discloses existing dependent destroys, Scene destroy is explicitly HTML, and flat ordering must extend the existing positioned-controller concern rather than bypass it.

- **[chore]** Added a focused browser test for the sidebar scope hues: each context block must share the computed background of the section it introduces, the three scopes must stay visually distinct, and the right utility sidebar's context must be the greenish one.
- **[chore]** Added model, request, routing-independent, and focused browser coverage for the new details pages, the Details links and their counts, `TaggedRecordCounts`, `tagged_records`, and the sidebar structure; updated the architecture, conventions, visual design, data model, known-quirk annotations, and backlog entries.
- **[chore]** Added Scene Tag fixtures and connected nested/tagged/untagged Dark and LOTR development data, updated the shared loader registry, and verified both `db:demo:check` manifests.
- **[chore]** `Development::UniverseDataRegistry` loads `Scene` after `Event` so a Scene can reference a shared universe event, and the loader proves a Scene's Section belongs to the same story before writing.
- **[chore]** Documented that editing an applied migration silently does nothing on a fresh database in this project: Rails 8.1's `initialize_database` loads `db/schema.rb` when the database has no `schema_migrations` table, so the Scene references needed a new migration.
- **[chore]** Renamed the main development story in the `dark` universe to `netflix dark` (slug `netflix-dark`) and updated every story-scoped YAML reference so the universe and story are distinct in the UI.
- **[chore]** Added `scenes.yml` development data for the Dark (8 scenes) and LOTR (5 scenes) universes, including a title-only scene and explicit narrative positions, registered `Scene` as a flat story-scoped position group in the development-data registry, and added scene fixtures.
- **[chore]** Added model, request, routing, ability, menu-count, ordering-service, and browser coverage for the slice, and updated the architecture, data model, conventions, visual design, development, backlog, and known-quirks documentation.

- **[planned]** Documented the Epic 11 Scenes domain model, UX contract, delivery slices, tests, and development-data requirements in the shared backlog; the feature is not implemented yet.
- **[planned]** Kept the newly recorded soft-delete/recycle-bin idea as later work; it is not part of slice 11.0 and requires a separate persistence, restore, authorization, and relation-tracking decision before implementation.

## 2026-09-24

- **[added]** Added the initial browser system-test suite for sign-in/sign-out, universes and stories, story-scoped sections, character creation, and timeline navigation; CI now runs these tests and preserves failure screenshots.

- **[changed]** Refreshed the Bootstrap visual system and application shell with shared theme tokens, page headers, content surfaces, empty states, flash messages, row actions, taxonomy styling, and responsive layout improvements.
- **[changed]** Reorganized navigation into a clearer top bar, Universe Bible sidebar, Configuration/Tags area, Settings panel, and URL-backed workspace tabs for related records.

- **[fixed]** Made story URLs consistently use the short `/s/:id` shape and required explicit story scope for section and section-tag URLs; added a test guard against positional universe-scoped route-helper arguments.
- **[fixed]** Corrected event title/name/slug synchronization and restored predictable generated slugs for renamed records and relation/ownership composites.
- **[fixed]** Prevented story selections from surviving logout, account changes, password resets, or stale sessions; added universe-name validation and access-aware navigation/actions.
- **[fixed]** Normalized fixture slugs, corrected a visibility helper, and expanded regression coverage for routing, navigation, authentication, authorization, and workspace flows.

- **[security]** Added universe memberships with read, write, and admin levels, public/private universe visibility, authorization for all universe- and story-scoped content, and an admin-only membership manager.

- **[docs]** Added the agent guide, vision, ADRs, architecture/data-model/conventions/development references, known and resolved quirk records, and the shared backlog; removed vestigial code and refreshed the project README.

- **[chore]** Made migrations schema-only and consolidated the current schema history; expanded per-universe development data under `db/data/` and documented the disposable-data boundary.
- **[chore]** Repaired the GitHub Actions workflow, pinned reproducible Bun installs, and made Chrome/system-test setup and teardown more reliable.

## 2026-09-23

- **[added]** Added the project vision document and expanded the architecture, data-model, and development documentation around the new universe/story boundaries.

- **[changed]** Completed the multi-story Universe model: Universe is the top-level container, world-building records are shared at universe scope, and stories are selected and remembered explicitly rather than falling back to the first story.
- **[changed]** Made sections and section tags story-scoped, added the nested story routes, and tightened cross-story hierarchy and tag validation.
- **[changed]** Added Universe and Story context/switchers to the top bar and improved navigation for both the universe overview and story workspaces.
- **[changed]** Made tags optional on every content model and removed default-tag creation and required-tag validation so untagged records remain valid.

- **[fixed]** Repaired section-tag associations and data loaders after moving them under stories.
- **[fixed]** Cached sidebar entity counts and invalidated them after relevant committed writes, eliminating repeated count queries on every page.
- **[fixed]** Repaired taxonomy and navigation tests after the scope and naming changes.

- **[chore]** Consolidated migrations into schema-only create migrations, refreshed fixtures and tests, normalized the project to Bun, and made demo data available through universe directories.

## 2026-09-22

- **[changed]** Replaced the early per-content “type” taxonomies with hierarchical tags and standardized content-to-taxonomy links as many-to-many associations, updating models, controllers, views, routes, fixtures, migrations, and demo data together.
- **[changed]** Refined the left navigation and sidebar presentation as the taxonomy workspaces expanded.

## 2026-09-21

- **[changed]** Improved the sidebar and universe/story menu structure, labels, and visual presentation in preparation for the larger workspace redesign.

## 2026-09-15

- **[fixed]** Adjusted the application route shape to keep the new universe scope consistent across navigation and resource URLs.

## 2026-09-14

- **[changed]** Replaced the original Story-centered root with a Universe-centered domain across controllers, models, routes, views, deployment metadata, demo data, tests, and documentation.
- **[changed]** Added more navigation options while the top-level universe model was introduced.

## 2026-09-12

- **[added]** Added foreground-color support to taxonomy tags and the relevant editor/badge UI.

- **[changed]** Expanded the Dark development dataset and moved its seed records toward YAML files with ordered loaders and symbolic references for sections, content, taxonomies, relations, and ownerships.

- **[fixed]** Updated test fixtures and expectations to match the expanded YAML-backed data.

- **[chore]** Added and refreshed frontend dependency locks, fixtures, and tests during the data migration; the temporary Yarn setup was later replaced by the project-wide Bun standard.

## 2026-09-11

- **[added]** Made the Timeline functional with event layout, edges, popovers, and an interactive timeline controller.

- **[changed]** Added taxonomy colors, many-to-many element/taxonomy support, Tom Select pillbox multi-selects, slugs across models, and a refactored per-universe seed-data layout.
- **[changed]** Improved the left menu and interactive editors as the world-building workspaces became more complete.

- **[docs]** Added the Mozilla Public License 2.0 to the project.

## 2026-09-10

- **[added]** Added the first Event and Timeline models, routes, views, layout algorithm, and timeline styling.
- **[added]** Added entity counts to the navigation menus.

## 2026-09-09

- **[changed]** Refactored routes and the character workspace, improved the complete character view, and refreshed visual navigation and menus.

- **[fixed]** Repaired ownership persistence and taxonomy drag-and-drop behavior.
- **[fixed]** Corrected data/controller integration issues found while expanding the content workspaces.

## 2026-09-07

- **[added]** Added Ownerships and Ownership Types, including their controllers, views, routes, schema, fixtures, navigation entries, and tests.

## 2026-09-05

- **[changed]** Added conventional list/modal views for Characters and Items and improved the surrounding menu.

## 2026-09-04

- **[added]** Added Locations, Items, Characters, and Relations, together with their first taxonomy models, schema, controllers, views, routes, fixtures, and navigation.

- **[changed]** Organized migrations and taxonomy nodes, and made taxonomy selection required in the early content workflow (this was later relaxed when tags became optional everywhere).
- **[changed]** Improved menus and visual consistency across the growing workspace.

- **[fixed]** Repaired item persistence, taxonomy drag-and-drop, and associated tests.

## 2026-09-03

- **[added]** Added Sections and made Sections work as a taxonomy, completing and hardening the tree-based taxonomy editor.

- **[changed]** Improved seed data, test coverage, and menu organization around the new section hierarchy.

## 2026-09-02

- **[added]** Added Section Types and the first interactive taxonomy-tree editor.

- **[fixed]** Corrected route generation and the right-sidebar presentation.

## 2026-09-01

- **[added]** Established the Rails 8 application foundation with SQLite, Solid Cache/Queue/Cable, Docker/Kamal deployment files, CI/security tooling, Bootstrap, Sass/PostCSS, and the initial development workflow.
- **[added]** Added Users, Sessions, Stories, password reset, sign-in/sign-out, and the first Story CRUD workspace.

- **[changed]** Added story slugs, initial Dark/LOTR seed data, and the initial navigation shell.
