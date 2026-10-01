# Delivery History

The detailed record of what changed in this project and why.
[`../CHANGELOG.md`](../CHANGELOG.md) carries the short form — one or two sentences per entry,
grouped by date and label — and this file carries the long form: the reasoning behind each
change, the alternatives that were rejected, and the verification it went through. The dated
entries below were reconstructed from the repository's Git history through 2026-09-25; the rest
moved here from that file and from the former `resolved_quirks.md` when the two were merged.

**This is a historical record, not documentation of the current system.** Like an ADR, it is
frozen: each entry states what was true when it was written, and it may disagree with the code
today. That is its value — it keeps the reasoning that the current code no longer explains. For
what the system does *now*, follow the subject's owner in the [index](README.md), or read the
code.

Two kinds of record live here:

- **Dated entries** — the project's history, newest date first. Inside one date, entries are
  grouped by label in the legend order [`../CHANGELOG.md`](../CHANGELOG.md) holds and kept in
  reverse chronological order.
- **Resolved quirks and tech debt** — findings that used to live in
  [known_quirks.md](known_quirks.md) and are fixed now. Each is organized around the original
  problem and its resolution. Only *open* findings belong in [known_quirks.md](known_quirks.md).

The label legend and the entry-format rules stay in [`../CHANGELOG.md`](../CHANGELOG.md). They
are linked rather than repeated, so there is one place to keep them current.

## Dated entries

### 2026-10-01

- **[added]** **"Remember last story": a sign-in returns to where the reader was working, and the
  preference that decides it has its own settings section.**
  The request was to land on the last universe and story after signing in, on by default, and it
  left the settings category to the implementer.

  The obstacle was that the application already remembers a story and that memory could not answer
  the question. `set_current_story` keeps a per-universe map in `session[:current_story_ids]`, and
  `Authentication` deliberately deletes it whenever a session starts or ends, is invalidated by a
  stale cookie, or is destroyed by a password reset. That is correct — it is what stops one
  account's story choices reaching the next account on the same browser — and it means the memory is
  gone before the next sign-in.

  Four decisions followed. **The preference is a third browser-owned signed cookie** (`AppStartPage`,
  `um_start_page`, two values, `remember` by default), following ADR 0013 exactly: no migration, no
  model, and it works for a guest on the landing page. **It gets its own section on `/settings`**
  rather than joining Appearance or Language, because a theme and a language change how a page is
  drawn and this changes which page is opened; the sections became a list (`SETTINGS_SECTIONS`) so
  that adding one stays a single declarative entry. **The remembered destination is separate state** —
  a second signed cookie holding the account id, universe slug, and story id — because mixing
  moving state into the durable preference would rewrite the preference on every page view.
  **The destination is bound to the account that wrote it and is re-authorized on every read.**
  `RememberedDestination.for` returns nothing unless the stored account id is the one signing in,
  then resolves live records, checks `readable_by?`, and finds the story *through that universe's
  own collection*. A signed cookie cannot be forged but it can be stale, so every way it can be
  unusable — no cookie, another account's cookie, a universe now private, a revoked membership, a
  deleted story — answers `nil`, which is the universes list a reader with no memory gets.

  Two boundaries were held deliberately. A page to return to still wins over the remembered
  story; the preference only answers "and when there is nothing to return to?". And **no fallback to
  the universe's first story** was introduced anywhere: ADR 0001 rules it out, a universe holds any
  number of stories, and the remembered value is the only story that may be a landing page because
  the reader chose it. The root path was also left alone — `/` is still where a universe is chosen
  and created.

  Sign-out deliberately does **not** forget the destination, which is the whole point, while the
  session-scoped map is still cleared at every session boundary.

  The browser work turned up a **pre-existing system-test failure** that is recorded as quirk 58
  rather than fixed here: `authentication_test.rb`'s sign-out case fails because Capybara's
  synthetic click misses a control inside the `position: fixed-top` navbar. It was verified to fail
  on an unmodified copy of `HEAD` before this work, and the application's sign-out is correct — the
  same click driven from the DOM reaches `/session/new`. `settings_start_page_test.rb` works around
  it with a scripted click rather than pretending the ordinary path works.

  See [ADR 0017](adr/0017-browser-owned-start-page-and-remembered-destination.md).

- **[security]** **Sessions now end on a lifetime and are bound to the user agent.** This resolved
  quirk 12, which is recorded in full under **Resolved quirks and tech debt** below.

- **[added]** **Two stories in the `dark` development universe.** `netflix-darker` and
  `bethesda-dark` now sit beside `netflix-dark`, sharing the universe's Characters, Locations,
  Items, and Events while each declares its own sections, section tags, scene tags, and scene
  sequence, with `position` restarting at 0 per story. This is what makes the login → universe →
  story flow and a universe that is not a single story exercisable by hand. `netflix-dark` stays
  first in `stories.yml` so it remains the story offered first, and `bethesda-dark` carries no
  photo so the "a Story without one" state is visible without inventing a record. Bartosz gained a
  Character record: the `Jonas meets Bartosz` Event already named him, and the new stories need him
  to speak.

### 2026-09-30

- **[chore]** **Four CI failures, and none of them was a flake: each was a place where the
  environment and the suite disagreed and the suite was the thing that had to change.**
  Run 36761947376 (`d2e20fe`) was red in five jobs — `js-check`, `test`, `system-test`,
  `migrations-from-zero`, and `scan_ruby` — and the job log needed admin rights, so every one was
  reproduced locally from a scratch clone before anything was changed.
  - **`js-check`: the client-side i18n test was order-dependent.** `test/javascript/i18n_test.js`
    installs its own four-key `ENGLISH` table with `beforeEach` and never put the real blob back, and
    Bun runs every file in `test/javascript/` in **one** process in filesystem-discovered order — which
    is alphabetical on one machine and something else on the next. Locally the i18n file ran near the
    end and the suite was green; on the runner it ran early and every controller assertion that reads
    a sentence received the raw key (`"shared.modal_form.unexplained"` instead of the words). Renaming
    the file so it ran first reproduced the runner's exact failure, which is what confirmed the cause
    rather than a theory about it. The fix is an `afterAll` that restores
    `test/javascript/fixtures/client_strings.en.json`; `docs/development.md` now states the shared-state
    rule so the next file does not reintroduce it.
  - **`test` and `system-test`: the photo tests measured the stored square with a tool CI does not
    install.** `photo_processing_test.rb` and `photo_test.rb` shelled out to ImageMagick's `identify`,
    and `photo_crop_test.rb` and `spanish_client_strings_test.rb` also drew their test image with
    `convert`. CI installs **libvips**, so `identify` returned nothing and the assertions read
    `Expected: 300, Actual: 0` — on a runner that had processed the photo correctly. The two system
    cases' `convert` calls raised `Errno::ENOENT` outright, which is where the 954 KB screenshot
    artifact came from. `test/support/photo_dimensions.rb` now asks the same two libraries
    `PhotoProcessing` chooses between, in the same order, so no test needs an image tool the
    application itself does not use, and the system tests attach the committed
    `test/fixtures/files/photo_one.jpg` instead of drawing one.
  - **`migrations-from-zero`: three rake commands in one process cannot drop a SQLite database.**
    `bin/rails db:drop db:create db:migrate` unlinks `storage/test.sqlite3` while the process still
    holds a connection to the deleted inode, so `db:migrate` read `schema_migrations` from that dead
    file, decided every migration was already up, and wrote nothing; the next process reported
    `Schema migrations table does not exist yet`. Each command is now its own `bin/rails` invocation.
    The same sequence in the **development** environment works, because `db:prepare`'s schema dump
    reconnects first — which is why `db:demo:reset` was never affected and this was not an
    application defect.
  - **`scan_ruby`: Brakeman was right about the shape and wrong about the risk.** `tagged_records_including_descendants`
    interpolated reflection-derived table and column names into a `joins("INNER JOIN …")` string, which
    reads like request input and is reported as a possible SQL injection. It is built by Arel now —
    `Arel::Nodes::InnerJoin` over an `Arel::Nodes::On` — so the names are quoted identifiers rather
    than spliced text. `config/brakeman.ignore` was the rejected alternative: a reviewed exception
    documents a risk that is not there, and this project prefers an allowlist for a genuine
    exception over a suppression for a false positive. This closed the pending item in
    [`backlog.md`](backlog.md) that named this warning and asked for the audit baseline in
    [`known_quirks.md`](known_quirks.md) to be corrected alongside it; that baseline now reads true
    again without an edit, since `bin/brakeman --no-pager` reports 0 warnings as it claims.
- **[chore]** **The photo tests measure a stored image through the same libraries the application
  uses.** `PhotoDimensions` (libvips first, ImageMagick second) replaces four shell-outs to
  `identify`/`convert` across `photo_test.rb`, `photo_processing_test.rb`, `photo_crop_test.rb`, and
  `spanish_client_strings_test.rb`. It raises `PhotoDimensions::Unreadable` rather than letting a
  library error escape, so `photo_test.rb`'s "the stored file must be a readable image" failure is
  still the failure a reader sees. See the `2026-09-30` CI entry above for why the shell-outs were
  there and what they cost.
- **[docs]** **The CI job table was three weeks stale and hid the bug that mattered.** `docs/development.md`
  listed a `data-check` job that no longer exists (the demo-manifest checks are steps inside `test`)
  and never listed `migrations-from-zero` at all, so the job added in `d1c31b1` was undocumented.
  The table now matches the workflow, `data-check`'s commands are attributed to `test`, and the reason
  the migration commands must be separate processes is stated next to them. The same document now
  records that Bun shares one process across `test/javascript/` and that a file installing the i18n
  table must restore it, and that `PhotoDimensions` is why an image library is a test prerequisite.

- **[docs]** **The short form had to stay a complete index, so every historical entry was
  summarized rather than left behind.** Splitting the file in two is only worth it if the short half
  still answers "what changed, and when" — a 34-line changelog that begins today is not an index, it
  is a stub, and the 22 dates of reconstructed history would be reachable only through the long
  form. All 299 historical entries now appear in `CHANGELOG.md` at one or two sentences, grouped by
  date and label in the order the legend defines.
  - **A summary can only be extracted, never written, unless a person reads it.** The build asserts
    that every non-hand-written entry is a **verbatim substring of its long twin**, which makes "the
    short form invented something" a build failure rather than a review question. 267 entries are
    mechanical: 113 kept whole because they were already terse, 6 kept as their own leading bold
    headline, and 148 reduced to their first sentence — with the following sentence appended when the
    first is a lead-in under 45 characters, which is how the `docs` entries that read
    "*…three rules this surface settled rather than leaving them in the diff:*" became readable.
  - **The 38 hand-written ones are the interesting part, and each failed a specific test.** Seventeen
    opened with an enumerated list longer than any summary should be. Six more described a `[fixed]`
    symptom without saying what was true afterwards — "*Text typed into the top-bar search field went
    dark the moment the field was focused*" — and the fix is the part a reader wants. An automated
    state-signal heuristic was tried for those and **rejected**: it flagged 23 entries of which only 8
    were genuinely symptom-only, because it cannot tell "*Repaired section-tag associations*" (a fix)
    from "*counted soft-deleted records*" (a symptom). Reading them was cheaper than tuning it.
  - **The reconstructed entries stayed thin.** `AGENTS.md` forbids inventing history, so an early
    entry that is one line is still one line; where a fact is now owned by a live document, that
    document is the better place to read it. Expanding those entries would have been writing history
    rather than recording it.
  - The short form obeys the layout rules the long form's early dates do not: label groups in legend
    order, one blank line between groups and none inside one, and every `##` date heading surrounded
    by blank lines. The long form keeps its original ordering untouched, because reordering a
    historical record to look tidy is a rewrite.
- **[docs]** **The changelog was too detailed to be readable, and the fix was to split it in two
  rather than to trim it.** One entry could run to forty-six lines: the reasoning, the rejected
  alternatives, the code paths, and the verification all landed in the same bullet, so the file that
  `AGENTS.md`, `docs/adr/README.md`, and `docs/backlog.md` all tell an agent to *cite* was a file
  nobody read end to end. The short form stays where every reference already pointed, and the long
  form moved to `docs/delivery_history.md`, where it is a frozen record like an ADR — allowed to
  disagree with the code, because its value is the reasoning.
  - **`docs/resolved_quirks.md` was merged into it, not kept beside it.** Both files were already
    frozen historical records of the same kind — what was decided, what used to be broken — so one
    historical file replaces two, and its quirks-and-debt half is what `known_quirks.md` already
    sent fixed findings to. `docs/known_quirks.md` is untouched: it holds 25 **open** findings
    (1 Critical, 14 Medium, 10 Low), which is pending work rather than history, and it keeps the
    opposite lifecycle. `AGENTS.md` requires it to be read *before* touching shared code, and
    `docs/README.md:59-61` is what separated the two files in the first place. The **open** and
    **resolved** halves cannot share one file, because only the resolved half may disagree with the
    code.
  - **Merging moved text; it never rewrote it.** The two bodies were combined programmatically
    rather than retyped, and all 3,604 source lines were verified present in the merged file
    afterwards. That was the point: `AGENTS.md` forbids rewriting historical entries, and the early
    history was reconstructed from Git rather than authored. Nothing was invented to make an entry
    look fuller, and the thin early entries stay thin — where a fact is owned by a live document now,
    that document is the place to read it.
  - **The merged file's heading levels are load-bearing.** `test/docs_test.rb` scans only two and
    three hashes for anchors, and a `####` heading is invisible to it, so the 55 quirk entries had to
    stay at `###` or `docs/architecture.md`'s link to
    `#sidebar-issued-count-queries-on-every-page-fixed` would have died. Its target is spelled
    `Sidebar issued COUNT queries on every page (fixed)`, where the odd capital `COUNT` is what
    produces the slug — that heading moved byte-identical, and "tidying" it would have broken a test
    for no reason. The 26 group headings became bold lead-ins so they group the entries without
    pushing them down a level, and the 22 date headings were demoted to `###` under `## Dated
    entries`, because no link anywhere targets a date.
  - **The file describes its own predecessors, so ten of its sentences had to be repointed.** The
    moved changelog text referred to `docs/resolved_quirks.md` while documenting the doc structure
    itself, so leaving those mentions would have left the new file citing a path that no longer
    exists. Two further references lived outside `docs/`: an ERB comment in the events index and a
    comment in `no_html_sink_test.js`. Neither renders, and both now name the file that exists.
  - `HISTORICAL_GLOBS` in `test/docs_test.rb` now holds `docs/delivery_history.md` in place of
    `docs/resolved_quirks.md`, so the merged file is still link- and anchor-checked but exempt from
    being a source of truth. Nothing guards the *drift* between a short entry and its long twin —
    `CHANGELOG.md` sits at the repository root, outside the glob the docs tests walk — so the rule
    written into `AGENTS.md` is that the long form is written only when the reasoning is worth
    keeping and no live document owns it.

- **[changed]** **Every model's own validation message is a key, which was the last English a
  Spanish page could show.** Twenty-six `errors.add` and `validates … message:` call sites across
  fifteen models wrote their sentence inline, so a rejected save rendered English inside an otherwise
  translated page — a Spanish taxonomy save answered `["Color de fondo must be a hex color like
  #d3d3d3"]`, with a Spanish attribute name in front of it. The four shared concerns
  (`Hierarchical`, `HasColor`, `HasManyTags`, `HasPhoto`), the three presence links, `SceneElement`,
  `Relation`, `Ownership`, `Photo`, and `UniverseMembership` all read a key now.
  - **A scope is a sentence, not a word.** `Hierarchical`'s parent and `HasManyTags`' assignment rows
    both built `"must belong to the same #{scope}"`, which hands a locale a frame it cannot
    reorder, contract, or gender. The two scopes are two sentences under `shared.errors.same_scope`
    now, and `Hierarchical#hierarchy_scope_error_key` returns a **key** so the three story-scoped
    models (`Section`, `SectionTag`, `SceneTag`) name the other key rather than each carrying its own
    copy of a word.
  - **A `validates` message is a callable, not a resolved string.** `HasColor` is the case that
    proves why: `included do` runs when the class loads, so `I18n.t` called there resolves once — in
    whichever locale happened to load the class first — and every later request validates against
    that one language. Rails evaluates a callable message per validation, which is where
    `I18n.locale` is the locale of the request being validated. The three presence models' uniqueness
    messages are callables for the same reason.
  - `SceneElement`'s refusal to keep speakers on a Narration interpolates the kind's **label**, not
    its value: `kind` is what the select stores and the browser matches on, so it stays `narration`
    in every language while the word beside it moves.
  - `UniverseMembership` and the memberships controller were writing the same sentence under two
    names; they now share `memberships.errors.is_universe_owner`.
- **[chore]** **Two checks now guard what neither could see.** A validation message is only reachable
  from a *rejected* request, which is why `TranslationsTest` (which compares the two locale files
  against each other) and `SpanishChromeTest` (which searched a rendered, i.e. successful, page for
  the English values the locale files define) both passed while twenty-six English messages shipped.
  - `test/models/model_error_message_literals_test.rb` is the server-side twin of
    `no_client_string_literals_test.js`: it fails when a quoted string reaches `errors.add` or a
    `validates` `message:`. A key read from a variable is deliberately **not** an offence, so
    `ClientStrings`, `Search::Kinds`, and `HasColor::HEX_COLOR_MESSAGE` stay as they are.
  - `test/controllers/spanish_chrome_test.rb` now drives the failing requests — a rejected taxonomy
    save, a rejected presence link, a rejected Element, and a rejected Relation that re-renders its
    form through `shared/_error_summary` — asserting both that the Spanish sentence is what came back
    and that the answer carries no English.
  - Both guards were verified to fail when their own regression is reintroduced.

- **[changed]** **The four Stimulus controllers read their strings from the server, which finishes
  the internationalization work.** `taxonomy_tree_controller.js`, `photo_crop_controller.js`,
  `modal_form_controller.js`, and `search_controller.js` each hardcoded about a dozen sentences of
  their own — a Spanish page had translated chrome and an English **Use this photo** button, in a
  modal the server never rendered. Each of those words is now a key.
  - `ClientStrings` (`app/models/client_strings.rb`) owns the list of keys a controller may read,
    resolves them against `I18n.locale` for the request being rendered, and serializes them into
    one JSON blob. The layout renders it as `<script type="application/json" id="client-strings">`
    on every page, because which controllers a page carries is not something the layout can know:
    the taxonomy tree builds a photo editor inside a modal it creates after load, so a value
    declared only by the view that owns a controller would be missing exactly where it is needed.
  - `app/javascript/i18n.js` is the only lookup. A missing key returns the key and warns rather
    than rendering English, interpolation is named and a missing value leaves its placeholder
    visible, and a controller never assembles a key from a value — so a value that travels in a URL
    cannot become a lookup that raises.
  - **A plural is the locale's choice, and this is the one genuinely new rule.** The blob is
    rendered once per page while the count is only known when a controller asks, so a pluralized
    key travels as its whole `{one:, other:}` hash and `t()` picks the form with `Intl.PluralRules`
    for the locale the blob names. The words are still the locale file's; only the choice among
    them moved, and a controller cannot express a `count === 1` because there is no way to write
    one. A third language with a richer plural rule needs no change here.
  - **A record-level error's subject is asked for, not derived.** Both editors hold a `model_param`
    (`scene_element`), which is a value — it also names the form field they post — so humanizing it
    in the browser would have put English in a Spanish page. `record_subject.*` holds one whole
    phrase per record type, for the same reason `shared.error_summary.heading` does: English
    supplies "the" in the phrase and Spanish has to.
  - Where a sentence named another sentence's word, it interpolates the other key rather than
    duplicating it: the photo editor's "then choose %{action}" carries the button's own label, and
    a sentence that mentions moving up or down is two keys rather than one frame with a spliced
    word, because `data-modal-form-direction` is a value.
  - `shared.record_error`, `shared.record_message`, and two status sentences are now shared between
    the two editors rather than duplicated, so a rejected save reads the same whichever editor
    refused it. The taxonomy tree's own wording for that heading changed with it.
  - Three enforcement gaps are closed, each covering what the others cannot see and each verified
    to fail when its own class of regression is reintroduced:
    `test/models/client_strings_test.rb` reads every `t()` call out of `app/javascript` and asserts
    it **both ways** — every key a controller reads is a key the server sends, and every key the
    server sends is one a controller reads, so a translation cannot quietly become unreachable;
    `test/javascript/no_client_string_literals_test.js` fails when a quoted string that reads as
    prose appears in `app/javascript` (a class list, an attribute name, a MIME type, and a
    `KeyboardEvent.key` value are names, not sentences); and
    `test/controllers/spanish_chrome_test.rb` asserts the negative a positive assertion cannot,
    that a Spanish **response body** contains none of the English sentences the locale files
    define. `test/system/spanish_client_strings_test.rb` then drives the same three editors in a
    real browser, because the words a controller prints were never in the response for a request
    test to read.
- **[fixed]** **"Type 1 more characters to search."** The search dropdown's shortfall message is a
  plural now, so the same `count` that said "characters" after one character says "character". The
  bug is what the i18n change existed to remove: the sentence was assembled in the controller, so
  no locale could choose a different form.
- **[changed]** **The last three untranslated views are translated, and the search surface's own
  labels with them.** `searches/show`, `searches/_commands`, and `searches/_scope_field` carried about
  25 English literals; every user-facing string on the search surface now comes from `searches.*`, which
  completes the server-rendered half of the internationalization work (0 of 100 views left). The strings
  that live in value objects rather than in a view moved with them, and each is resolved at read time
  rather than held in a constant, because a constant that called `t()` would be resolved once in
  whichever locale loaded the class first:
  - `Search::Scope::Option` no longer holds a label at all. Its label key **is** its own `value`, so
    `searches.scopes.characters` is `searches.scopes.<the query parameter>` and the dropdown, the note
    above the form, and the JSON answer's `scope_label` are one lookup apart — while the value in the
    URL stays `characters`, so a Spanish link to `?scope=characters` keeps working.
  - `Search::Kinds` holds the twelve bare kinds and the eight taxonomy compounds as keys, keyed by the
    `kind`/`taxonomy` **pair** the document carries. "Character tag" was composed as
    `"#{taxonomy} #{kind.downcase}"`, which is a word order a locale does not get to choose; the
    Spanish badge is now "Etiqueta de personaje", its own key. A kind or taxonomy this version does not
    know answers with its own value rather than with `humanize`, which was English chrome.
  - `Search::Commands`' destinations are named in the reader's language, and the typed text is matched
    against that same translated title — someone typing «personajes» is matched against «Personajes», so
    the thing on screen is the thing searched. A command's `id` stays a value, because it is what the
    dropdown marks the active option with. The one command whose subtitle is chrome rather than data
    ("Open universe") translates it at the call site.
  - `Search::Scope` and `Search::Query` translate each dropped value where they drop it, so the
    controller's `to_sentence` joins them in the reader's language instead of with English connectors.
  - The results page no longer prints `Search::UnavailableBackend::REASON` as its paragraph. That
    constant is the operator's sentence for a log line and a reindex report, and printing it under a
    heading this slice had just translated put English in a Spanish page; the page says the same thing
    with `searches.unavailable_reason` instead, and the two name the same environment variable and the
    same command.
  - The results page's empty answer no longer downcases the scope label. "Nothing in *This universe*
    matched" needed a lowercased label, and a lowercased label is a word order the locale does not get
    to choose; it is two sentences now, one carrying the scope as its subject and one doing the
    advising, with and without the platform hint depending on whether a universe is in scope.
  - `test/controllers/searches_locale_test.rb` holds the rendered page in Spanish;
    `test/models/search/{scope,query,commands,kinds}_test.rb` hold the four value objects, and
    `SearchTestBackend` grew a `total:` so a truncated result set's copy is covered rather than
    assumed.
- **[changed]** **A record's label and a search document's title are now two different things, and the
  reason is written down.** `Event#display_string` and `Ownership#display_string` are their models'
  `searchable title:`, so a document holds the string and one index serves every reader. Both now
  resolve through `I18n.with_locale(AppLocale::DEFAULT)`, and a new `#display_label` on each is the
  same ladder in the reader's language — so every view, helper, and serialized field reads
  `display_label`, and a Spanish request can no longer write Spanish chrome into the index. In the
  default locale the two are the same string, which is what makes the stored one safe, and
  `EventTest`/`OwnershipTest` hold the *stored* wording explicitly: changing `en.yml` is an
  index-content change and `bin/rails search:reindex` is what makes an existing index agree. Nothing
  has to be reindexed **now**: the stored strings are byte-for-byte the ones already in the index
  (`"X owns Y"`, `"before X"`, `"Event #12"`), and only the code producing them changed.
  Consequences worth stating:
  - `Relation` needs no second form. Its fallback is `A → B` — the neutral pair its list row already
    draws — so it has no `display_label` at all, and `ApplicationHelper#record_label` is the one place
    that order is written: `display_label`, then `display_string`, then `name`. Five shared partials
    (`_row_actions`, `_record_details`, `_tagged_record_list`, `record_details_link`, and the row-action
    confirmations) read that helper instead of repeating the fallback chain.
  - **A search result row still shows the stored document title**, so an Ownership with no name reads
    "Hannah owns Heirloom" in the results page of a Spanish reader. That is a decision, not a gap: the
    alternatives are a document that changes with the locale of whoever caused the write, an index
    extension for one sentence, or a record that cannot be found by its only identifier. The three
    options and the trade are recorded in `docs/features/search.md`.
  - `Event` was never the case the docs described: it indexes `name`, not its own label, so its
    `"before X"` phrases never reached the index. They were still chrome on every surface that shows an
    event — the Events list, the Scene's event picker, the Timeline popover, and the three temporal
    selects — and they moved to `events.display_label.*` together. `timeline.popover.before/after/
    simultaneous` and `timeline.event_placeholder` were the same English strings under a second owner
    and are deleted; the popover reads the Event's own keys, so "before" has one home.
- **[fixed]** The **Relations and Ownerships rows** built their delete confirmation's record name as an
  English frame — `relation_name = "#{relation.character1.name} and #{relation.character2.name}"` —
  which the Universe Bible slice translated around but not in. Both are `relations.endpoints` and
  `ownerships.endpoints` now, so the row's confirmation reads "Character one y Character two" in Spanish.
- **[docs]** `docs/features/i18n.md` records the decision this slice settled: a search document's title
  is a record's label **in the default locale** while a view resolves `#display_label` in the reader's
  language, why `Relation` needs no second form, and what a change to the stored wording costs. Its
  naming rules gain the two this surface showed: a sentence is not a frame, so a scope label is never
  spliced into one and lowercased; and a **search result badge** is its own surface and owns
  `searches.kinds.*`, where the Scenes tab strip reads the workspace's own title. The "Known gap"
  section now names only the four Stimulus controllers, since the record-label gap is decided and points
  at `features/search.md`; `features/search.md` gains a ninth rule (a label a reader sees is translated
  at read time, a value they act on is not) and the new
  [result-row section](features/search.md#a-result-row-shows-the-stored-document-title).
  `docs/backlog.md`'s internationalization item re-measures the remainder — **0 of 100 views**, ~51
  client-side strings, and the two shared `errors.add` messages — and the slice 27.5 entry is deleted;
  the remaining numbers were not renumbered.

- **[fixed]** A **dismiss control clicked while a modal is still fading in is no longer dropped**, in
  both shared editors. Every modal offers **Cancel**, a `btn-close` button, and Escape or a backdrop
  click, and all four resolve to the one Bootstrap instance the editor owns; `hide()` returns without
  doing anything while that instance is still transitioning in, so a dismiss landing in the opening
  transition left the dialog open and the control looking dead until a second attempt — one attempt
  late, and the first gave the reader nothing. `modal_form_controller.js` and
  `taxonomy_tree_controller.js` now wrap their own instance's `hide()` and re-issue a remembered intent
  on `shown.bs.modal`, before any focus is claimed, which is the same care the focus race on a
  rejected save already got. The flat-list editor also reads "already open" from `hidden.bs.modal`, so
  the window is only opened when `show()` will really show the dialog and a deferred dismiss can never
  be stranded. Known quirk 61, recorded while fixing quirk 47 and listed under the i18n slice that had
  to be delivered before 27.4, is fixed ahead of that slice; the taxonomy tree editor had the identical
  race on its own instance and the recorded finding did not name it. Four browser cases cover what
  only a browser can show — a **Cancel** and an Escape delivered in the same task as the open, the
  same for the tree editor, and the row-to-row editor journey the defect had blocked — and ten
  `bun test` cases cover the deferral in each controller.
- **[fixed]** A **Relation or Ownership can now be named**, and a stored in-world time survives an
  edit. Three silent contract drifts on the record/editor boundary, recorded as known quirk 30, are
  fixed together:
  - `Relation` and `Ownership` both carry an optional `name` that `display_string` and the composite
    slug prefer when set, but neither controller permitted it, neither modal had a Name field, and
    neither `*_fields_json` serialized it — so a name that arrived from `db/data` or a console could
    not be changed, renamed, or cleared through the interface. `:name` is now permitted, both editors
    carry an optional Name field with a hint saying so, and both serializers emit `name` so the row's
    editor is prefilled and a rejected entry keeps what was typed.
  - The in-world datetime serializers formatted with `%Y-%m-%dT%H:%M`, so opening an editor on a
    record whose stored time had a non-zero second and saving it again rewrote that column to zero
    seconds. `ApplicationHelper::DATETIME_LOCAL_FORMAT` (`%Y-%m-%dT%H:%M:%S`) is now the one format
    every editor value is built from, in `modal_fields.rb` and `scenes_helper.rb` alike, and every
    `datetime-local` control for those values carries `step: 1` — a control whose step is a whole
    minute cannot hold a second even when the value has one. Display formatting (`in_world_range`,
    the timeline, `scene_in_world_time`) is unchanged and stays minute-precision.
  - `RelationsController` and `OwnershipsController` redirected on PATCH and DELETE with Rails'
    default 302, against the documented `status: :see_other` for non-GET verbs in the HTML flow.
    Both now send 303; `create` is a POST, so its 302 is correct and stays.
  Making `name` writable exposed what clearing it did: `HasSlug#set_slug` resolves a blank or
  unslugifiable name to a random hex, so un-naming a Relation replaced its address with an arbitrary
  one and discarded the composite slug its demo-data references depend on. The new `OptionalName`
  concern gives both models one home for the rule — a blank name is stored as NULL, and a name with no
  slug of its own does not re-address the record. Renaming still renames.
- **[docs]** `docs/features/i18n.md` records the three rules this surface settled rather than leaving
  them in the diff: that **a determiner a language agrees in gender is its own interpolation**
  beside the noun, so `shared.detail_section.empty_title` takes `determiner:` as well as `label:`;
  that **a link inside a sentence is one `_html` key with the link as the interpolation** while the
  link's own text stays a key of its own; and that **a value object which is not a view resolves keys
  with `I18n.t`** — `SectionPaths#ungrouped_label`, `SceneFilter`'s discarded values (translated where
  they are dropped, so `to_sentence` joins them in the reader's language rather than with English
  connectors), and `Scene`'s `errors.add` messages, each starting lowercase because it is the tail of
  `errors.format`. The constant-holds-a-key rule now names `SceneElementsHelper` beside `ModalFields`,
  with the point that its descriptions stay keyed by the `kind` **value** because that is what the
  browser matches on. `docs/backlog.md`'s internationalization item carries re-measured counts
  (**3 of 100 views** — the three `searches/*` — and about 25 distinct strings, down from 21 and
  about 132), the two new general slice rules, and the slice 27.4 entry is deleted; the remaining
  numbers were not renumbered.
- **[docs]** **Known quirk 61** records that a dismiss control clicked while a modal is still fading in
  is silently dropped: **Cancel**, `btn-close`, Escape, and a backdrop click all resolve to the one
  Bootstrap instance `modal_form_controller.js` owns, and `hide()` returns while that instance is still
  transitioning in, so the first attempt does nothing and only the second closes the modal. Measured
  with Bootstrap 5.3.8 while fixing quirk 47; it reaches every modal workspace and is listed under the
  backlog slice that must be delivered before 27.4. It is recorded rather than fixed here because it is
  the shared editor's own pre-existing defect, not part of that slice. The claim that modals cannot be
  dismissed at all, which an earlier draft of this work repeated, is corrected: the modal does close,
  one attempt late.
- **[fixed]** The **Event editor** no longer offers the event being edited as one of its own
  `Happens before` / `Happens after` / `Same time as` references. `EventsController#index` sends every
  universe event because one modal form serves every row and a single server render cannot know which
  row is about to be edited, so the browser offered a choice `Event#cannot_reference_self` and the
  `events_*_event_not_self` check constraints always refuse. The three selects now declare
  `data-modal-form-exclude-self`, `shared/_row_actions` gives each row's trigger the
  `data-modal-form-record-id` that identifies it, and `modal_form_controller.js` detaches that one
  `<option>` and re-inserts it before the next row opens — the same shape the taxonomy tree already
  uses to keep a node out of its own `parent_id` select. The create trigger carries no id, so a create
  offers every event. The controller, the locales, and the Event model are otherwise unchanged: the
  model and the database stay the authority, so a hand-built or stale request is still refused.
- **[fixed]** Deleting a **Character, Item, or Location** now says what it deletes. The row menu
  defaults to the short `Delete <name>?` confirmation and Locations is a taxonomy tree whose fallback
  named only the record and its children, so the three surfaces that ADR 0007 has mandated
  consequence sentences for since 2026-09-25 were confirming a deletion that really does cascade —
  descendants, ownerships or relations, and Scene presence links — without naming any of it. Events,
  Scenes, Sections, and the Story and tag pages already rendered theirs. Characters and Items now
  pass `confirm_text` to `shared/_row_actions` and Locations passes a `confirm_message` lambda to the
  shared tree, which are the two channels the other surfaces already used, so the ADR's sentences are
  reproduced unchanged. The copy sits at `characters.delete_confirm`,
  `items.delete_confirm`, and `locations.delete_confirm` beside the workspace that is its only reader,
  in both locales; the record name is the author's own data, so it is interpolated, not translated.
  Request tests read the shipped attribute in `characters_controller_test.rb`, `items_controller_test.rb`,
  `locations_controller_test.rb`, and `universe_bible_locale_test.rb` (Spanish included), and the two
  browser `accept_confirm` blocks in `test/system/modal_json_flow_test.rb` now accept the confirmation
  the row sends.
- **[changed]** The **Scene workspace** now renders in Spanish as well: the story-scoped `scenes/*`
  list, its filter, Scene Details with its Element list and Element editor, the one form `new` and
  `edit` share, the Characters/Items/Locations tabs, both story taxonomies (`section_tags/*`,
  `scene_tags/*`), the Sections workspace's ungrouped block, `ScenesController`'s flash copy, and
  the "Appears in scenes" section on a universe record's own page — **21 of the 100 ERB views** and
  the controllers, helpers, and model labels they read. Three shared sentences stopped being
  duplicated rather than gaining a second home, the same way `shared.form.cancel` did in the
  Universe Bible slice: `sections.eyebrow` and the narrative-position badge are now
  `shared.eyebrow.story`/`shared.eyebrow.scene` and `shared.scene_position_aria` (the two
  Section-scene-list and three list/appearance readers), `events.form.none` became `shared.none`
  because the Scene form's event link needs the same word, and the Scenes tab strip now names its
  three siblings with **their** workspaces' titles (`characters.title`, `items.title`,
  `locations.title`) instead of a second copy of three words. `SectionPaths::UNGROUPED_LABEL` became
  `UNGROUPED_LABEL_KEY` plus a `#ungrouped_label` reader, because a constant that called `t()` would
  be translated once in whichever locale loaded the class first; the label it resolves has **one**
  home (`sections.ungrouped_label`), read by the list badge, the Section selector, the filter, and
  the ungrouped block, while `SceneFilter::UNGROUPED` stays the untranslated `ungrouped` query value.
  `SceneElementsHelper`'s two frozen constants now hold **keys** rather than English labels, because
  the kind descriptions are serialized into the modal and printed by a browser-side controller — so
  they cross the boundary already translated, still keyed by the `kind` value the browser matches on.
  Two sentences the templates had assembled from English fragments (`" — see the"` + link + `". Several
  scenes can depict the same event."`) became one `_html` key each, since fragments cannot be
  reordered; the link's own text stays a key so a translator still knows what it is called. 31
  request cases in `test/controllers/scene_workspace_locale_test.rb` read the rendered page, including
  the values that travel in a form field, an `<option>`, and a URL, which are asserted *not* to be
  translated alongside their labels.
- **[fixed]** Two defects this translation surfaced on the same code path, both about the word a
  locale cannot derive on its own:
  - **A determiner a language agrees in gender cannot be derived from an interpolated noun.**
    `shared.detail_section.empty_title` hardcoded the masculine *"Ningún"*, which reads correctly for
    the six Universe Bible record types and wrongly for the two new ones — *"Ningún sección lleva esta
    etiqueta"*. The key now takes a `determiner` from
    `shared.detail_section.determiners.none_masculine`/`none_feminine` beside its noun, which the eight
    callers state; the two English entries are identical because English has no such agreement.
  - **A model-level `errors.add` message is chrome too.** `Scene`'s five messages were English
    literals read by the Scene editor's error summary, so a rejected save answered in English inside a
    translated page. They are `scenes.errors.*` now, and `activerecord.attributes.scene` names `name`
    as **Title** and `datetime` as **In-world time** so an error agrees with the label above it — which
    is why two English assertions in `scenes_controller_test.rb` now read *"Title can't be blank"* and
    *"In-world time is not a valid date and time"*.
  A third question this raised was **not** a defect: `se ha <participio>` is the compound verbal form,
  so `scenes.flash` keeps the masculine participle its sibling workspaces' confirmations already use
  rather than the feminine one the subject's gender would suggest.
- **[changed]** The **Universe Bible workspaces** now render in Spanish as well: `characters/*`,
  `locations/*`, `events/*`, `items/*`, `relations/*`, `ownerships/*`, the six universe-level `*_tags`
  indexes and their `show` pages, the modal editors those lists open, and the flash confirmations of
  the two workspaces that use the HTML redirect flow. The six taxonomy pages now read the *same*
  `tags.types.<type>` copy the taxonomy workspace already used rather than a second hand-maintained
  list of the same sentences, so a page and its translations cannot drift apart, and each
  `record_label`/`all_label`/`records_title`/`unused_description` sits beside the name it belongs to.
  Three strings were not repeated per workspace because one home already owns them: the
  `Universe Bible` eyebrow is the left sidebar's own section heading and is read from `sidebar.*`, the
  count labels resolve the **root** record-type nouns with a `count:`, and `Cancel`/`Close` are one
  `shared.form` pair — which let the three already-delivered `form.cancel` keys
  (`universes`, `stories`, `memberships`) be removed rather than left as a second, third, and fourth
  home for the same word. `Relations` and `Ownerships` also gained the error-summary sentences their
  re-render path needed, and the row menu's `label` is now the record type's own name rather than an
  English literal. 29 request cases in `test/controllers/universe_bible_locale_test.rb` read the
  rendered page — including the values that travel in a form field, an `<option>`, and a URL, which
  are asserted *not* to be translated alongside their labels.
- **[changed]** The modal editors' field labels are translated where they are **produced**, not where
  they are printed. `ModalFields` serialized its descriptors into the taxonomy tree's
  `data-taxonomy-tree-modal-fields-value`, and a modal the *browser* builds from that JSON printed an
  English label in a Spanish page. The descriptors now carry `label_key:` and
  `ModalFields#modal_field` resolves it per request, which is the rule the i18n document states for
  every other constant: `PHOTO_FIELD` is frozen, so a `t()` inside it would have been resolved once,
  in whatever locale loaded the class first, and every later request would have rendered that one
  language. The key is dropped on the way out — it is how the label is found, not part of the
  contract, and shipping it in the serialized JSON would publish a key nothing renders. This also
  fixes the Sections tree, which had been reading the same English descriptors. Separately,
  `TagsHelper::CONTENT_WORKSPACE_TABS` stores a route helper's **name** rather than a lambda: a
  `freeze`d constant's lambdas capture the module, which has no route helpers, so the first attempt
  raised `undefined local variable or method 'universe_characters_path' for module TagsHelper` on
  every Universe Bible page. `shared/_row_actions` also had two hardcoded `Delete` labels while the
  taxonomy node beside it already used `shared.row_actions.delete`, and
  `shared/_menu_tag_content_tabs` was building its accessible name from `tag_type.titleize` — an
  English accident of the class name where the record type's own noun was what a reader needed.
- **[fixed]** Three Spanish sentences this surface exposed were ungrammatical in **both** languages, and
  both fixes are the same rule. `shared.error_summary.heading` ends in `"… prevented this %{subject} …"`
  in English, so an English `subject` is a bare noun; the Spanish sentence has no determiner to
  supply one and the Spanish subject was a bare noun too, which rendered *"2 errores impidieron
  guardar este relación"*. The determiner now belongs to the sentence: the Spanish heading carries
  none, and each workspace's `errors.subject` is the whole phrase (`esta relación`, `este acceso`,
  `access grant` in English). And `shared.detail_section.empty_title` took a label resolved with
  `count: 2` while the verb wanted one noun, giving *"No characters carry this tag"* and *"Ningún
  personajes lleva esta etiqueta"*; the label is now resolved at `count: 1` and the English reads
  *"No character carries this tag"*. `section_tags/show` and `scene_tags/show` still hardcode the
  old plural wording and are named in the Scene-workspace slice that owns them.
- **[fixed]** `config/locales/es.yml` was missing `errors.messages.required`, which Rails defines in
  English only, so a Spanish page that rejected a **missing** `belongs_to` — a Relation or Ownership
  submitted without one of its two records — raised `I18n::MissingTranslationData` while its *other*
  messages rendered correctly. It is the one message Rails' subset reaches that was not there, and
  `TranslationsTest`'s Rails-key check now covers it.
- **[fixed]** A `blank:` state that cannot be reached is a translation nothing renders, and it is worse
  than a missing one because a reviewer cannot tell it apart from a real state. Two were removed
  rather than translated: `events.show.facts.title_blank`, because the value is
  `title.presence || display_string` and `display_string` always answers (at worst `"Event #12"`), and
  `tags.show.color_blank`, because `bgcolor` is `NOT NULL` with a default. A Relation or Ownership
  error also stopped reading *"Character2 must exist"*, which was Rails humanizing a column name;
  `activerecord.attributes.relation` names it `Character 2` in both locales.
- **[docs]** `docs/features/i18n.md` records the four rules this surface settled rather than leaving
  them in the diff: why a frozen constant cannot hold a route-helper lambda, why `label_key` is
  dropped from the serialized descriptor, that **a sentence decides its own determiner** while **a slot
  that takes one noun takes the singular**, and that a `form_with scope:` modal has no model to read
  `human_attribute_name` from and must name its own labels while the `activerecord.attributes` entry
  is still required for its error messages. Its Known gap now also records the one model-level label a
  translation cannot close: `Event#`, `Relation#`, and `Ownership#display_string` are their models'
  `searchable title:`, so the string is stored in a **language-independent** search index and read
  back into a result row — translating them in the model would put one locale's chrome in that index
  and show it to a reader in another language. The decision to make is how a view resolves a
  translated label while the index keeps the stored one, which is named in the search slice.
  `docs/backlog.md`'s internationalization item carries re-measured counts (**21 of 100 views**, about
  132 distinct strings, down from 64 and about 440), the two new general slice rules, the correction
  that the slice's own text named the wrong controllers for the flash strings, and — at the owner's
  direction — a slice that must be delivered **before** the Scene workspace for the three open defects
  this translation surfaced: the Character/Item/Location delete confirmations, the Event temporal
  reference selector, and the Relation/Ownership parameter and datetime contract drift.

- **[changed]** The residual duplication the heading-ownership test cannot see is removed — the same
  fact stated under two different headings, which is the case a heading test structurally cannot
  catch. It was found by measuring repeated runs across the living documents rather than by reading,
  and the largest instance was that **routes were documented twice**: `architecture.md`'s "Routing &
  URL generation (the sharp edges)" and `conventions.md`'s "Routes" each carried the universe scope,
  the story nesting, the named-key rule, and the workspace URLs. `conventions.md` now owns route
  conventions, and `architecture.md` keeps only what happens *inside a request* — `universe_slug` being
  filled from recall, `Universe#to_param`, and a foreign `story_id` raising 404.
- **[changed]** The `db/data` guidance in `development.md` and `conventions.md` were a third and
  fourth statement of the same rules. `data_model.md` owns the layout, the registry, and the loader's
  validation; `development.md` owns the command workflow; and `conventions.md` keeps only the rule a
  model author needs — a new persisted model means a YAML file in every registered universe directory
  **and** a registry entry, in the same change.
- **[changed]** `docs/development.md`'s "Scene delivery (complete)" no longer narrates what each
  delivery slice added. That is history, the dated entries in `CHANGELOG.md` already hold it, and a
  planned slice number is not a durable reference. The section now points at `features/scenes.md` for
  the confirmed defaults and at the changelog for the order, keeping only the fact that the
  Scene-owned tables shipped as their own create migrations.
- **[changed]** The documentation is reorganized around **one fact, one home**, and each feature now
  has a single document that owns its rules. `docs/universe_maker_conventions.md` is renamed
  `docs/conventions.md` and keeps only the cross-cutting code patterns, and a new `docs/features/`
  directory holds one document per feature: `scenes`, `tags`, `search`, `navigation`, `photos`,
  `events`, `i18n`, and `settings`. The reorganization was driven by duplication that had already
  rotted: the Scene domain was documented in **four** documents at once (`conventions.md`,
  `architecture.md`, `data_model.md`, `visual_design.md`, roughly 760 lines in total), the list-row
  shape in three, record details pages in three, the navbar and both sidebars in three, photos in
  four, global search in three, and soft delete in three. Every defect found on 2026-09-30 was in a
  place where two documents both said something and one went stale, and none was in a topic only one
  document owned. `docs/features/scenes.md` is now the single Scene home, and the "participation is a
  union, never a sum" rule is stated once instead of five times.
- **[changed]** The reference/narrative split is applied. `data_model.md` keeps the schema — tables,
  columns, indexes, constraints, the taxonomy matrix, soft delete, slugs, positions — and no longer
  carries feature behaviour narrative; the Scene writing-model section there is reduced to the two
  facts that are about migrations (the schema-only `scenes` migration, and why an applied migration
  cannot be amended). `visual_design.md` keeps tokens, light/dark, typography, spacing, the shell,
  responsive behavior, accessibility, and the **painted** treatment of a view, and no longer restates
  behaviour rules: its search section is now the painted treatment with the rules and their reasons in
  `features/search.md`, its taxonomy section is the painted shape with the contract in
  `features/tags.md`, and its Scene section is the painted shape with the contract in
  `features/scenes.md`.

- **[fixed]** `TaggedRecordCounts` counted soft-deleted records, so every taxonomy's
  `(N characters)` pill kept a deleted record that was invisible everywhere else. It builds one
  grouped query in **raw SQL**, so the element model's `default_scope` does not apply, and a soft
  delete deliberately keeps both the row and its join-table rows so a restore is complete. The
  element subquery filtered `universe_id`/`story_id` but not `deleted_at`. Verified in the
  development database: soft-deleting a character tagged **Family Nielsen** left the count at 4 while
  the record was correctly hidden everywhere else. The exclusion is now restated in the query, beside
  the scope filter it already carried, and is conditional on the element table actually having a
  `deleted_at` column. The story-scoped taxonomies are covered by the same generated query, and
  `test/models/tagged_record_counts_test.rb` gained three cases: the count drops on a soft delete
  while the join row is kept, a restored record is counted again, and a story-scoped taxonomy
  behaves the same. This is what the Scene delete confirmation's "tag assignments … will be
  permanently removed" promises, and until now it was not true of the count the author sees.

- **[fixed]** Two JSON-only mutation controllers had no format guard, so an HTML request committed the
  record and only then answered `406` — the exact commit-behind-the-error failure ADR 0011 exists to
  prevent. `SectionsController` and `LocationsController` now `include RequiresJsonMutationFormat`
  and declare `before_action :require_json_mutation_format, only: %i[ create update destroy ]` after
  their record lookup, matching the eight controllers that already had it. `LocationsController#destroy`
  was the worse half: it was not even wrapped in `respond_to`, so an HTML `_method=delete` was
  accepted outright and soft-deleted the record. Neither controller has an HTML mutation surface —
  both are mutated only through the taxonomy tree, which sends `Accept: application/json` — so no
  legitimate path is refused. `test/controllers/modal_json_contract_test.rb` gained a case covering
  create and delete for both, verified to fail without the guard.
- **[fixed]** `config/locales/es.yml` carried **two** `errors:` blocks, and a repeated mapping key is
  not an error to Psych: the later value silently replaces the earlier one. The second block, holding
  the Rails `errors.format` / `errors.messages` subset, was discarding the application's own Spanish
  `unavailable_account` and `rate_limited` strings, so those two messages were never translated. The
  blocks are merged under one `errors:` key, and `test/models/translations_test.rb` now walks the
  parsed document for a repeated key at any depth and fails on one.
- **[fixed]** The translation parity test decided which keys the application owns by **namespace**,
  excluding all of `errors`, `datetime`, and `support`. Because this application owns
  `errors.unavailable_account` and `errors.rate_limited` beside Rails' own `errors.messages.*` and
  `errors.format`, those two were exempt from the two-file comparison: a key added to `en.yml` and
  forgotten in `es.yml` would have failed no test. Ownership is now decided **per key**, read from
  the framework's own locale files rather than a hardcoded list, so a Rails upgrade that adds or
  moves a subtree is classified correctly without editing the test. `I18n.exists?` cannot answer
  this question, because the application's own `en.yml` is merged into the `:en` backend and its keys
  answer `true` exactly like Rails' do.

- **[fixed]** `docs/adr/README.md` did not mention `docs/features/`, so the eight feature documents
  were unreachable from the ADR index that 16 of 17 ADRs link to. Its "current documentation" list
  now names all five core documents, the `features/` directory with its eight members, and
  `visual_design.md`, and states the split explicitly: an ADR explains why, the document that owns
  the subject explains what the current system does, and when they disagree the living document is
  right.
- **[fixed]** ADR 0014 (global search) was the only one of seventeen with no
  `## Related documentation` section, although `adr/README.md` and `0000-template.md` both require
  it; its cross-references lived in a header line instead. It now has the standard section and
  points at `features/search.md` as the search subsystem's home.

- **[fixed]** The Scene editor's workspace tabs were documented as two live links and two
  `aria-disabled` placeholders in three places, long after Items and Locations shipped. An assistant
  reading `docs/architecture.md` was told those two tabs had no destination and would not have
  added a link to them, while `docs/conventions.md` and the view itself
  (`app/views/scenes/_workspace_tabs.html.erb`) said all four were live. All three documents now
  state that **Scene Details**, **Characters**, **Items**, and **Locations** are live links, and the
  invariant that a tab is never a link to a route that does not exist is kept intact as its own
  sentence. `docs/adr/0007-story-owned-scenes-and-elements.md` was deliberately **not** changed: its
  status block already records that those routes "remained unrouted until their deliveries added a
  real destination", which is correct history, and an accepted ADR is not rewritten.
- **[fixed]** `docs/architecture.md` cited "former quirk #18" for the sidebar count cache, but quirk
  18 in `docs/delivery_history.md` is about mutation failures in editors; the sidebar-count finding
  is a separate, differently named heading. The link pointed at a heading that does not exist and at
  the wrong finding, so it now names the real target.
- **[fixed]** `docs/conventions.md` said `HasManyTags` enforces the shared universe or
  story scope "for all seven content/tag pairs". There are **eight** (`character`, `event`, `item`,
  `location`, `ownership`, `relation`, `scene`, `section`); it now says eight and points at the tag
  taxonomy matrix in `docs/data_model.md`, which lists all eight.
- **[fixed]** `docs/data_model.md` listed `db/data/star_wars/` as an existing universe directory
  alongside `dark` and `lotr`; only those two exist. `docs/development.md` still shows it, and is left
  as it is, because there it is explicitly annotated `# future universe data`.
- **[fixed]** Removed two dead links to `docs/schema.txt`, a file that does not exist, from
  `docs/data_model.md` and `docs/README.md`. The ownership graph and the per-table reference in
  `docs/data_model.md` already cover what that link promised.
- **[fixed]** `docs/conventions.md` carried its own errata in the body ("Correction of
  an older (wrong) note: **Event does have a `_tag` taxonomy**") and a stale delivery promise ("the
  accepted Scene contract adds the remaining documented Scene actions in later delivery slices",
  long shipped). The Event section now states the taxonomy as current fact, and the delivery sentence
  is gone; what happened when belongs in this changelog, not in a living rule.

- **[docs]** ADR 0007's deletion contract was written against the hard delete and does not describe the
  shipped soft delete. `SoftDeletable` walks only each model's declared `soft_deletes` list and never
  touches a HABTM join table, so a Scene's Scene Tag assignments and Dialogue speaker links, and a
  Character's tag assignments and speaker links, are **retained** — which is what makes a restore
  complete, and is already pinned for speaker links by
  `test/controllers/scene_elements_controller_test.rb` ("speaker links are kept so a restore brings
  them back"). ADR 0007 gains a dated execution note recording the divergence rather than having its
  Decision rewritten, `docs/features/scenes.md` stated the false cascade and now states the real
  contract, and `test/models/scene_test.rb` gains a soft-delete/restore case alongside the existing
  hard-delete one — which used `destroy!` and so proved only the contract that is no longer shipped.
- **[docs]** ADR 0015 claimed "Destroying the record's universe does remove them, because `Photo`
  belongs to it", and no such cascade exists: `Universe` declares no `has_many :photos`, its
  `soft_deletes` omits photos, and `db/schema.rb`'s foreign key has no `on_delete:`, so it is
  `NO ACTION` and would not cascade even on a hard delete. The claim is corrected in place and an
  audit note added, with the reason the cascade was **not** implemented: `photos` has no `deleted_at`
  and `Photo` is not soft-deletable, and a `Photo` can be deliberately shared with
  `HasPhoto#referenced_elsewhere?` already guarding that case. Making photos cascade is a product
  decision with a schema change attached, so it is left as one.

- **[docs]** ADR 0016 re-derived a decision ADR 0013 had already made. Its `users.locale` alternative
  opened with "Rejected for now, for the same reason `users.theme` was" and then repeated ADR 0013's
  three reasons and its "right answer if a preference has to follow an account across devices"
  conclusion verbatim. It now cites ADR 0013 for those reasons and states only what the locale adds:
  that a column would let a queued password reset be written in the reader's own language, and that
  the cookie would take precedence for a signed-out reader. The shared repeated runs between the two
  ADRs fell from three blocks to two, and the two that remain are the deliberate parallel structure
  that expresses "exactly like the theme".
- **[docs]** Two things were checked and deliberately left alone, so they are not "fixed" later.
  ADR 0007 and `features/scenes.md` share repeated wording, which is the intended ADR-explains-why /
  document-explains-what split rather than duplication. And `docs/known_quirks.md` appears to have
  out-of-order item numbers — 55 sits above 5, and 51–53 follow 59 — which is correct: items are
  grouped into severity sections that are each internally ascending, and the numbers are the
  original audit identifiers that are never renumbered or reused.

- **[docs]** Eleven smaller second statements were replaced by a link to the owning section: the
  photo cropper and its `data:` URL transport in `conventions.md`'s JavaScript-controllers list and
  photo-field paragraph; the `PhotoParams` splat and the grouped-tag badge map in the Helpers list;
  the `PHOTO_FIELD` descriptor; the identity card's two-column photo layout in `visual_design.md`; the
  navbar's entry list and the sidebar's three hues in `visual_design.md`; the taxonomy row's overflow
  menu; the hover-reveal accessibility rule in `features/navigation.md`; the "theme belongs to the
  browser, not to `Current`" premise; the `@layers` Timeline rule; the "change to either preference
  loads the whole document" rule; and the amended-migration mechanism, which `data_model.md` now
  points at `development.md` for.
- **[docs]** `conventions.md` stated the identity card's photo layout **twice** — once in "Record
  details pages" and once in the Helpers list — and `visual_design.md` stated it a third time. Only
  the first survives; the other two link to it.
- **[docs]** Verified that this pass lost no content either: every distinctive class name, method
  name, shared partial, task name, and registry constant referenced by the five documents before the
  whole refactor is still referenced after it — 142 tokens, none missing.
- **[docs]** A measurement pass over the living documents now shows five remaining cross-document
  repeats of 14 or more words, down from more than fifteen pairs. All five are single clauses each
  document needs for its own premise — a document that links to another still has to state the rule it
  is applying, and deleting that would leave the cross-reference unreadable. This is the floor, not
  remaining debt.
- **[docs]** Replaced the flat "read these five documents before changing code" list in `AGENTS.md`
  and `docs/README.md` with a subject-to-owner table. The old list named roughly 4000 lines as a
  prerequisite for any non-trivial change, which no reader and no assistant actually follows, so it
  functioned as a table of contents while presenting itself as a reading requirement. The new form
  answers the question a change actually asks — *which document owns this subject* — and states the
  two rules that make the index trustworthy: **one fact, one home**, and **a wrong duplicate is worse
  than a missing fact**, since a confident incorrect paragraph gets acted on while an absent fact
  sends the reader to the code.
- **[docs]** `docs/known_quirks.md` finding 37 tracked the dead `schema.txt` links; that clause is
  removed and the rest of the finding is kept open. Its own `docs/development.md:42-44` line
  reference had also drifted to unrelated prerequisite text, so the finding now names the document
  instead of stale line numbers. The still-open parts are unchanged: absent relation, ownership,
  relation-tag, ownership-tag, and membership fixtures; an advertised but absent
  `docs/images-to-ai/`; and `test/helpers` described as effectively empty when it holds three test
  files.
- **[docs]** `AGENTS.md` and `docs/README.md` now carry a subject-to-owner table that maps each subject
  — the five core documents plus the seven feature documents — to the document that owns it, and both
  state that a feature's rules live in exactly one `docs/features/` document.
- **[docs]** Three cross-references in two ADRs were repointed at their sections' new homes, so the
  reader is not sent to a section that no longer exists: ADR 0015's photo links now point at
  `features/photos.md` and `development.md#testing-record-photos`, and ADR 0007's soft-delete link now
  points only at `data_model.md`. These are navigational cross-references, not decisions, so no ADR
  reasoning was rewritten.
- **[docs]** `docs/development.md`'s `## Photos` heading is renamed `## Testing record photos`, so the
  test workflow keeps its home while the photo contract has one.
- **[docs]** Verified that the reorganization lost no content: every distinctive class name, method
  name, shared partial, and helper referenced by the four documents before the move is still
  referenced after it. `shared/_search_bar` and `TimelineController` were the only two mentions lost,
  and both were restored.

- **[chore]** `docs/adr_audit.md` — the point-in-time audit of all sixteen accepted ADRs against the
  code — was removed once its findings had been acted on, since it duplicated what this entry and the
  two ADR notes now record. It had also made `test/docs_test.rb` fail its index check, because a new
  document has to be listed in `docs/README.md`.

- **[chore]** Added `test/docs_test.rb`, which makes the documentation's own consistency a test
  rather than a convention nobody checks. It fails the suite when a relative Markdown link is dead,
  when a cross-document `#anchor` no longer matches a heading (using GitHub's slug rules), or when a
  section heading is owned by two documents. Each case was verified by deliberately introducing the
  defect and watching the matching test fail. `docs/adr/**` and `docs/delivery_history.md` are exempt
  from the heading-ownership and link checks, because a record of what was decided, or of what used
  to be broken, is allowed to disagree with the code now.
- **[chore]** The heading-ownership test ships with the documentation's existing duplication debt
  listed explicitly, naming both the heading and the documents that currently own it, so the suite
  is green while the debt is paid. The list may only shrink: a document dropping out of an entry
  keeps the suite green, while a **new** document joining one fails it, because the failure this
  test exists to catch is a fact gaining a second owner. The duplicated subjects it currently names
  are **Global search**, **List rows**, **Photos**, **Record details pages**, and **Soft delete**.
- **[chore]** `test/docs_test.rb` now also checks links **out of** historical records
  (`docs/adr/**`, `docs/delivery_history.md`). Exempting them entirely hid three dead anchors that the
  sections' moves created; a historical record is still exempt from the heading-ownership check,
  because a record of what was decided may not be made the second source of a fact, and from the
  index check, because it is not a living document.
- **[chore]** `KNOWN_DUPLICATED_HEADINGS` in `test/docs_test.rb` is now **empty**. The one-fact-one-home
  refactor resolved all five entries — **Global search**, **List rows**, **Photos**, **Record details
  pages**, and **Soft delete** — so the documentation has no known duplicated heading left and a fact
  gaining a second owner again now fails the suite. The two thin pointer sections that caused two of
  those entries were removed rather than renamed: `architecture.md` had nothing true left to say about
  photos, and the empty `Global search` stubs in `architecture.md` and `conventions.md` were folded
  into the sections they actually belong to.


### 2026-09-29

- **[fixed]** The Timeline could draw arrows that contradicted its own layout (known quirk 24, now in
  `docs/delivery_history.md`). `TimelineLayout` layered the events with a cycle-checked graph and then
  threw that graph away, rebuilding `@edges` from the raw `before_event`/`after_event` associations,
  so the drawing was free to disagree with the rows. An event whose dates ordered it after another
  while declaring itself *before* that other was placed on the lower row and drawn with an arrow
  running back up the page; two events naming each other drew an arrow in **both** directions; and an
  event marked simultaneous with another while also declaring a sequence relation to it got a dashed
  and a solid line between the same two nodes on the same row. `@layers` is now the single source of
  the rendered order and `@edges` is read back off it: a sequence edge is emitted only when the two
  events landed on strictly different rows with `from` above `to`, a simultaneous edge only when they
  share a row, and a relation named from both sides draws one arrow instead of two. A refused
  relation is **not** drawn reversed to match the rows — reversing would invent a relation the author
  never declared and hide the conflict — it is simply not drawn. No model validation was added, on
  purpose: a `before_event` that disagrees with approximate dates is legitimate author data, and the
  documented confidence order already says which signal wins. `test/models/timeline_layout_test.rb`
  grew from 4 to 11 cases covering conflicting dates/relations, a mutual-reference cycle, the
  simultaneous-plus-sequence overlap, and a reference outside the layout; direction is asserted
  against the row indices rather than a literal.
- **[fixed]** A Timeline node is now reachable and understandable without a mouse (known quirk 46).
  It rendered only the record's numeric id inside a focusable `<div tabindex="0">` with no role and
  no accessible name, so a screen reader announced a bare number for every event on the page, and its
  popover opened only on hover or focus. The node is a real `<button>` carrying an `aria-label` built
  by the new `TimelineHelper#event_node_aria_label` from the same `event_popover_title` the popover
  header uses, so the label and the popover cannot describe different events; the UA button chrome is
  reset in `_timeline.scss` so the node keeps its 40px circle and the author's tag colors, with a
  `:focus-visible` outline added now that it is genuinely focusable. The popover trigger became
  `hover focus click`, because a control meant to be operated needs a click path and a touch pointer
  never hovers. Covered by four new request cases and a new `test/system/timeline_test.rb`, which
  tabs forward from the preceding control, asserts focus actually lands on the node, and checks the
  popover opens on both focus and click.
- **[docs]** The docs described a Timeline pan/zoom interaction that has never existed: it was claimed
  from the feature's first commit (`fef94d1`) while `timeline_controller.js` only ever drew edges
  and popovers. `docs/architecture.md` and `docs/universe_maker_conventions.md` now describe the
  Timeline as the static layered view it is, and the pan/zoom feature itself is recorded as pending
  work in `docs/backlog.md` rather than left as a false claim.
- **[fixed]** The browser suite is green again: four stale assertions in
  `test/system/tag_improvements_test.rb` and `test/system/taxonomy_tree_test.rb` were red before any
  new work started (known quirk 60, now in `docs/delivery_history.md`). All four were test-side, so
  no application code changed. The workspace menu-tag tab is asserted with the `from=workspace` link
  it actually renders, and the test then follows the taxonomy tree's **Details** link for the same
  tag to cover the canonical path too. The four `find("button[aria-expanded='false']")` sites are
  scoped to `li[data-node-id] > .taxonomy-row` rather than the bare node, because a tag with
  children nests the child's own collapsed row menu inside the parent and the old scope matched two
  toggles. The page-header count badge is asserted against `universe.character_tags.count` and its
  `aria-label` instead of a literal, and what it counts is now stated in the conventions: every tag
  in the taxonomy, nested children included, which is why a create makes the badge go up.
- **[changed]** The Universe and Story workspaces now render in Spanish as well: `universes/*`
  (index, show, new, edit, `_form`, `_universe`), `stories/*`, `memberships/*`,
  `sections/{index,show}`, `tags/index` (the taxonomy workspace), `timeline/index`, and the
  Universes, Stories, and Memberships controller flash and confirmation messages. Keys are grouped
  by the surface that owns them (`universes.*`, `stories.*`, `memberships.*`, `sections.*`,
  `tags.*`, `timeline.*`). Notable decisions:
  - **A constant holds a key, not copy.** `TagsHelper`'s `UNIVERSE_TAG_METADATA` /
    `STORY_TAG_METADATA` now store `title_key:`/`description_key:`/… and `tag_workspace_base`
    resolves them for the request's locale. A constant that called `t()` at class-load time would
    have been built once, in whichever locale loaded the class first, and every later request would
    have rendered that one language. The scene taxonomy's per-tag delete confirmation is stored as a
    key and wrapped in a lambda at read time, because the tree calls it once per tag. The
    now-redundant `TAG_LABELS` constant is gone; the tab label is the same
    `tags.types.<type>.title` the workspace copy uses, so the two cannot drift.
  - **A URL, a query value, and a stored value stay untranslated.** `read`/`write`/`admin` still
    travel in the membership form field and are still stored verbatim; only the label beside them
    moved into `memberships.access_levels.*`. `UniverseMembership::ACCESS_LEVELS.keys.map { titleize }`
    appeared in three places and is now one helper, `membership_access_level_options`.
  - **A `form.submit` label is named rather than inherited.** Rails' default comes from
    `helpers.submit.*`, which is English only, so the Universe and Story forms pass their own
    labels (`Crear universo` / `Actualizar universo`, `Crear historia` / `Actualizar historia`).
    The same gap is closed for attribute names: `activerecord.attributes.{universe,story,
    universe_membership}.*` are defined in both locale files, so a Spanish form reads "Nombre"
    beside a Spanish validation message instead of "Name no puede estar en blanco".
  - **The three hand-rolled error blocks now render `shared/error_summary`.** The Universe form,
    the Story form, and the Members page each had their own `pluralize(errors.count, "error")`
    heading, which English-only `pluralize` made untranslatable. The Members page therefore reads
    "1 error impidió guardar este acceso:" rather than the old "1 error prevented access from being
    saved", and `test/system/membership_access_test.rb` was updated to the shared sentence.
  - **A sentence is written per language, not assembled around an interpolation.**
    "These records are shared by every story in X" became "Every story in X shares these records"
    / "Todas las historias de X comparten estos registros", because the English frame cannot be
    translated by substituting a name into it.
  - **Author data is still not translated**, and the tests say so: a universe name, a story
    description, and a tag name appear untranslated inside Spanish sentences throughout
    `test/controllers/workspace_locale_test.rb`.
  - **The four Stimulus controllers still hardcode their own English.** The taxonomy editor's
    built modal, the photo cropper, and the timeline popover trigger remain partly English on a
    Spanish page; that gap is the client-side slice's.
- **[changed]** The Sections workspace, the taxonomy workspace, and the Timeline read their copy
  from the locale too: the "Add section" action and the per-section delete confirmation that
  announces what happens to child sections and linked scenes, the per-taxonomy workspace copy, and
  the Timeline's per-event popover labels and relationship phrases in
  `TimelineHelper#event_popover_title`/`#event_popover_content`. The "before X" / "after X" /
  "same time as X" phrases are whole translated sentences with the related Event interpolated, so
  their word order can differ by language, and an Event with no title of its own falls back to a
  translated "Event #N" whose number is the record's id.
- **[added]** The application can now be read in Spanish, and the language is a browser-owned
  preference chosen on the settings page. `AppLocale` (`app/models/app_locale.rb`) follows exactly the
  contract `AppTheme` uses: two known names, English as the default, one signed cookie
  (`um_locale`), and a `normalize` on every read, so a forged or hand-edited cookie can only ever
  select a known locale. `ApplicationController#switch_locale` is an `around_action` that sets
  `I18n.locale` from it before any action runs, so a redirect's flash is already translated, and
  `I18n.with_locale` stops one request leaking its language onto the next request served by the same
  thread. The layout renders `<html lang>` from the same value, so the first paint is in the right
  language for a screen reader and for the browser's own hyphenation. Language is a second
  **section** of the existing settings page — `/settings?section=language` — rather than a second
  route, matching the query-parameter tab shape ADR 0013 already describes. Each option is labelled
  in its own language, so a reader who cannot read the current one can still find theirs, and the
  confirmation is written in the language that was just chosen. Both preferences are written by the
  same `PATCH` and validated independently, so a request that refuses one does not silently apply the
  other. See [ADR 0016](adr/0016-internationalization-and-browser-locale.md).
- **[added]** Every "main" record and tag can now carry one optional photo: universes, stories,
  sections, scenes, characters, locations, items, events, relations, ownerships, and all eight tag
  models. The image lives in its own `Photo` model (`app/models/photo.rb`) with one Active Storage
  attachment, and each of those eighteen tables gained a nullable, indexed `photo_id` through a
  shared `HasPhoto` concern — a record without a photo is completely normal, and no controller
  creates one. On a details page the square shows in the left part of the surface card with the
  identity beside it; a record without one renders exactly what it rendered before, because both
  branches share `shared/_record_details_identity`.
  A photo is always square. `photo_crop_controller.js` is a dependency-free canvas cropper that
  opens the chosen image in a square the author can drag, move with the arrow keys, or nudge with
  four real buttons, and confirms it as a `data:` URL in one ordinary form field — so the same
  control serves the JSON modals, the taxonomy editor's DOM-built modal, and the plain full-page
  forms without any of them changing how it submits. The server is still the authority:
  `PhotoProcessing` crops and resizes to 300×300 again, re-encodes as JPEG, and strips metadata, so
  the original upload is never stored, and the stored bytes are an image this application produced.
  Submitted bytes are checked against a content-signature allowlist (JPEG/PNG/GIF/WebP) and a size
  bound before an image library sees them, so a client that labels an SVG as `image/png` is refused.
  The request carries a cropped square or a remove flag, never a photo id, which makes a
  cross-universe assignment unreachable from the interface; a photo must still belong to the
  record's own universe, and one is destroyed only after the replacing transaction commits and only
  while nothing else still refers to it. A read-only member and a guest are offered no cropper at
  all. See [ADR 0015](adr/0015-record-photos.md).
- **[changed]** Application chrome now lives behind `t("dotted.key")` in `config/locales/en.yml`,
  with a Spanish `config/locales/es.yml` mirroring it. The application shell, the top bar, both
  sidebars, the shared partials (page header, empty state, row actions, record details, photo, flash,
  error summary, search bar, taxonomy tree and node, the detail and tab strips), the sign-in and
  password pages, the settings page, the password-reset mailer, the PWA manifest, `AppTheme`'s theme
  names and descriptions, and the sign-in, password-reset, and account-refusal controller messages
  are translated. Keys are grouped by the surface that owns the string rather than kept in one flat
  list. **Author-entered data is not translated**: record names, descriptions, tag names, and universe
  and story names stay exactly as their author wrote them. The six `section_*` keys that sat in
  `en.yml` and were read by nothing are gone.
- **[changed]** A missing translation is now a test failure rather than a silent English string on a
  Spanish page. `config.i18n.raise_on_missing_translations` is on in the test environment, and
  `test/models/translations_test.rb` compares the two locale files' key sets, interpolation
  placeholders, and plural forms, so a key added to one file and forgotten in the other fails the
  suite. It also checks that the hand-maintained Spanish subset of Rails' own strings
  (`errors.format`, `errors.messages.*`, `datetime.distance_in_words.*`, `support.array.*`, which Rails
  ships in English only) mirrors a key Rails really defines, so that block cannot rot into translating
  something the framework never asks for; and that no translation uses `locale`, `default`, `scope`, or
  `raise` as an interpolation name, because those are reserved I18n options — `t(key, locale:
  "Español")` asks I18n to translate *in* a locale called Español and raises `I18n::InvalidLocale`
  rather than interpolating anything.
- **[changed]** A workspace's count label is now an I18n key rather than an English noun, so the
  plural comes from the locale instead of from an appended "s". The record-type nouns live at the root
  of the locale files, which is why the fifty-odd existing `count_label: "character"` and
  `details_count_label: "scene"` call sites read as they did and needed no change;
  `ApplicationHelper#count_with_label` resolves them with a `count:`. A sidebar count is announced as
  the record type, a separate value from the visible label, so a link reading "Ownerships" is
  announced as "ownerships".
- **[changed]** On a tag page reached from a workspace menu tab, the tab strip now sits between the
  page header and the tag's identity card instead of below the card, so the navigation reads as one
  piece the way it does on every other workspace page. `shared/_record_details` takes an optional
  block rendered in that gap; the four menu tag pages pass their existing
  `shared/_menu_tag_content_tabs` render to it, and every other details page is unchanged. A tag
  opened from the taxonomy tree still has no tab strip and keeps the card directly under its
  header. Request and browser tests assert the block order in both cases.
- **[changed]** Non-taggable grouping tags now show each direct child tag with its own assigned
  records instead of flattening descendant results; the include-descendants checkbox remains on
  taggable tags. Child records and their other tag badges are batch-loaded. Workspace menu-tag links
  carry `from=workspace`, keeping the related tabs on tag details pages; taxonomy Details links
  remain canonical and do not show those tabs. Pinned Character tags are also present on Relations.
- **[fixed]** Two universes whose names slugify alike no longer fail with a `500`. A universe's slug
  is its public address (`/u/<slug>`) and is global, so `HasSlug` deriving it from the name made
  two names a collision — as did a name that happened to derive an address another universe already
  held. `universes.slug` carries a partial unique index but `Universe` validated nothing about it,
  so `UniversesController#create`/`#update` let the index raise `ActiveRecord::RecordNotUnique` out
  of an ordinary save. `Universe` now validates `slug` uniqueness with the index's own
  `deleted_at IS NULL` condition, the way `Story` already did, so a taken address is a `422` field
  error: it renders in the shared error summary for HTML and comes back as the documented error hash
  for JSON. The universe form gained an optional **Address slug** field so the collision is
  answerable without renaming the world; it renders blank on both forms, because a filled field wins
  for that save while a blank one leaves `HasSlug` to derive the address from the name. A blank slug
  is dropped in `universe_params` rather than assigned, because forwarding a cleared slug would make
  the callback regenerate the address from the name on an *unrelated* save — ticking **Private
  universe** would republish the universe under a new address and invalidate every path stored below
  it. Prefilling the field was rejected for the mirror-image reason: the callback replaces the value
  on a rename, so the form would have shown an address it was not going to use. The new field and
  its `Slug has already been taken` message are translated in both locales, and
  `errors.messages.taken` is now part of the hand-maintained Spanish subset of Rails' own strings.
  Model, request, locale, and browser tests cover the collision, the disambiguation, the unrelated
  save that must not republish the universe, and a soft-deleted universe releasing its address. The
  entry moved from `docs/known_quirks.md` to `docs/delivery_history.md`.
- **[fixed]** Signing in no longer leaves the visitor on the sign-in page. A wrong password sends
  the browser back to that same form, and the referer of that reload is the sign-in page (or the
  sign-in endpoint) itself; that URL was being remembered as the post-login destination, so the
  *next* correct password redirected straight back to the form. The account was authenticated the
  whole time, so the sign-in looked like it had done nothing and only navigating to a universe
  proved otherwise. `Authentication#authentication_page?` now refuses a sign-in or password URL as a
  destination — both where the referer is stored (`sessions#new`) and where it is used
  (`after_authentication_url`, so a value left in the cookie by the previous code cannot survive a
  deploy) — and the two documented outcomes hold: a visitor who was browsing as a guest returns to
  that page, and a visitor with nowhere to return to lands on the universe list. A remembered
  destination that the new session still cannot read no longer dead-ends on a bare 404: that single
  request now redirects to the universe list with an explanation, while every ordinary refusal keeps
  its documented status code. Request tests cover the mistyped-then-correct retry, the
  password-page destination, the refused destination and its one-request scope; browser tests cover
  the retry and the password-page journey.
- **[docs]** The browser suite is red for a reason that is now written down instead of being
  rediscovered. A complete `PARALLEL_WORKERS=2 bin/rails test:system` run is 117 tests / 1,501
  assertions with 2 failures and 2 errors, all four in `test/system/tag_improvements_test.rb` and
  `test/system/taxonomy_tree_test.rb`, and those two files reproduce all four on their own, so this
  is not the load flake described by known quirk 58: a workspace menu-tag link deliberately carries
  `from=workspace` while the test asserts the canonical path, a taxonomy row now holds two collapsed
  `aria-expanded='false'` toggles so `find` raises `Capybara::Ambiguous`, and a page-header badge
  counts the tag the test itself creates, so its expectation is one behind. The new known-quirks
  entry states the evidence and names the one thing worth confirming while fixing it — that the
  header count is meant to track live creation — and the internationalization item in
  [`backlog.md`](backlog.md) now carries a slice **before** the Universe Bible workspaces
  to fix them, because that slice is the one that edits the tag, taxonomy, and workspace-tab
  surfaces these tests assert on — with a red suite, a real regression cannot be told from an old
  failure.
- **[docs]** Quirk 48 — a delegated admin demoting or removing their own membership — was already
  fixed earlier today but still listed as open. The entry moved from `docs/known_quirks.md` to
  `docs/delivery_history.md`, which now records that the refusal is a stated redirect to the landing
  page with an alert, that the caller's own row no longer renders change and Remove controls, and
  that the bare `403` still stands for a signed-in non-administrator asking for an admin-only page.
  A follow-up verification block records the runs behind that entry.
- **[docs]** Added
  [ADR 0016](adr/0016-internationalization-and-browser-locale.md) for the translation contract:
  why the language is a cookie rather than a `User` column, why only chrome is translated, why a
  missing key fails instead of falling back to English, and why a value that travels in a URL is not
  translated. `docs/architecture.md`, `docs/universe_maker_conventions.md` (with a new
  **Translations** section listing the rules a new string has to follow), and `docs/visual_design.md`
  were updated to match, and `docs/adr/README.md` indexes the new record.
- **[planned]** `docs/backlog.md`'s internationalization item is now written as ordered slices
  recording the measured string surface, instead of a one-line note, so the remaining work can be
  picked up one slice at a time. The foundation and the application shell are no longer listed there
  — the entries above are the record of that delivery — and what remains is the Universe and Story
  workspaces, the Universe Bible workspaces, the Scene workspace, search, and the client-side
  strings. The slice text fixes the decisions that would otherwise be re-made inline: a value that
  travels in a URL stays untranslated while its label is translated, a count label is a key rather
  than a noun, an interpolation is never named `locale`, and author-entered data is never
  translated.
- **[docs]** Documentation no longer cites a backlog item number, because a number is deleted from
  `docs/backlog.md` when its item completes and the citation then points at nothing. `docs/adr/README.md`
  records the rule for future ADRs: cite the reference documentation or ADR holding the delivered
  behavior, the dated `CHANGELOG.md` entry for the delivery, or an open `known_quirks.md` entry, all
  of which survive completion; `docs/backlog.md` says the same from the other side. The stale
  references are removed across the ADRs and the docs that carried them. ADR 0007 no longer says
  soft deletion is "backlog item 20" — item 20 is now the collaboration-system plan and soft delete
  shipped on 2026-09-28 — and instead points at the `SoftDeletable` behavior documented in
  `data_model.md#soft-delete` and `architecture.md#soft-delete`, recording that the cascade contract
  above it (a Section ungroups its Scenes, an Event clears its temporal references) survived the
  change from hard to soft deletion. ADR 0007's execution notes are now titled by what each delivery
  added (core/references/Scene Tags, Elements and Character presence, Item/Location presence and
  appearances, the Scene and Section improvement pass) instead of by slice number, its Context and
  Consequences no longer refer to an "epic", and its flat-ordering cost now cites ADR 0009, which is
  where the flat mode is actually decided. ADR 0011 no longer opens by citing backlog item 11.5,
  ADR 0013's request is described directly instead of as "the backlog", and the "Slice 11.4
  clarification" notes in ADRs 0001 and 0005 are now named for the Scene Tag delivery they came from.
  ADR 0008's cost list no longer says the demo passwords are "a backlog item"; it names the
  security-hygiene work in `known_quirks.md`. The same slice-number removal covers `architecture.md`,
  `data_model.md`, `development.md`, `universe_maker_conventions.md`, `visual_design.md`,
  `known_quirks.md`, and `delivery_history.md` — the Scene delivery stages are described by what they
  added, the data-model table no longer carries an "implemented in 11.x" column, and the remaining
  `known_quirks.md` DataFactor pointers now name the pending item by its title rather than its
  number.
- **[docs]** ADR 0007 claimed that every one of its mandatory deletion-confirmation templates was
  live. It was not: Characters and Items pass no `confirm_text`, so
  `shared/_row_actions.html.erb` falls back to the short `Delete <name>?`, and the Locations taxonomy
  tree falls back to a generic message that names only the record and its children. Scene, Story,
  Section, and Event do show their mandated copy. The ADR now names the four that are and records the
  gap as known quirk 59, because each of those three models still cascades on delete — a Character
  soft-deletes its descendants, relations, ownerships, and presence links — and the confirmation a
  reader sees does not say so.
- **[docs]** `AGENTS.md` and the development guide now require clarifying a request before coding
  starts. Naming two unrelated items in one sentence is not approval to do both: the agent asks
  "A and B are not related, do you want to proceed with both or only one now?" A single item that
  touches several areas of the project and divides into independent pieces is large, so the agent
  asks "do you want to do everything now or do you want to split this task in slices/parts/chunks?"
  and brings a concrete slicing with the question. The question is skipped when the items are the
  same code path, when the request already answers it, or when the answer is obvious from the
  repository and can be stated as an assumption. Intake settles the shape of the request and is
  separate from the existing **NOW / LATER / NEVER** decision about work found outside its scope.
- **[docs]** Updated the tag data model, workspace conventions, and development guide with the
  grouping, menu-navigation, and demo-data verification behavior.
- **[chore]** Dark demo data now calls the Character grouping tag **Factions** and pins both
  **Factions** and the assignable **Family Nielsen** tag in the workspace menu. Request tests cover
  grouped child results and the different workspace/taxonomy navigation paths.
- **[planned]** Backlog item 26 records a safety follow-up: `db:demo:reset` invoked Rails `db:drop`,
  which also dropped the local test database. The implementation remains deferred; approval for a
  development-data reset must never extend to test or production databases.

### 2026-09-28

- **[added]** Every content table with a user-facing delete action now carries a nullable `deleted_at`,
  and a delete marks that column instead of removing the row. The shared `SoftDeletable` concern
  (`app/models/concerns/soft_deletable.rb`) adds a default scope that hides soft-deleted records from
  every ordinary query, `soft_delete`/`restore` to mark and unmark a record, `deleted?`, and
  `with_deleted`/`only_deleted` scopes to opt back in. A model declares the associations that cascade
  with `soft_deletes :assoc` — a Universe soft-deletes its stories, characters, tags, and memberships,
  a Story its sections and scenes, a Scene its elements and presence links, a Character its relations,
  ownerships, and presence links — so deleting a parent soft-deletes its whole subtree. A Section's
  scenes are ungrouped and an Event's temporal references are cleared, matching the hard-delete
  contract. The unique indexes that would otherwise block re-creating a record with the same key are
  partial (`WHERE deleted_at IS NULL`), and the matching model validations carry the same condition.
- **[added]** The settings page now has a **Go back** action in its header. The page remembers where
  it was opened from (a same-host referer), so finishing a theme change returns the reader to the page
  they were on rather than to the landing page. The destination survives a theme save and is
  refreshed on each visit, and an external site cannot choose it.
- **[added]** Every tag details page now has an **"Include records from child tags" toggle**
  (enabled by default). When on, the "X with this tag" list also shows records carrying any
  descendant tag, so a parent tag like "Factions" can list characters tagged with its children
  like "Sic Mundus" and "Erit Lux". The toggle is a checkbox that auto-submits via GET; all
  eight tag types (character, location, item, event, relation, ownership, section, scene) support it.
- **[added]** Tags can now be **groupings that are not assignable**. Every tag carries a `taggable`
  flag (default `true`); a tag with `taggable: false` stays in the taxonomy tree and on records that
  already carry it, but it is no longer offered in an element's tag editor — so a "Factions" tag can
  group "Sic Mundus" and "Erit Lux" without itself being assignable to a character. Character, Location,
  Item, and Event tags additionally carry a `show_in_menu` flag (default `false`); a tag with
  `show_in_menu: true` appears as a tab on its workspace page and links to that tag's own details page,
  the same view the taxonomy tree's Details link opens. A tag's details page now also shows **every
  tag badge next to each listed record**, not just the tag being viewed.
- **[changed]** Controllers now call `soft_delete` instead of `destroy!`, and `PositionedResourceOrder`
  soft-deletes through the same transaction that normalizes the remaining siblings' positions, so a
  soft-deleted record leaves the same contiguous gap a hard delete would. A soft delete cascades to
  the model's declared associations, so deleting a Universe soft-deletes its whole subtree; the
  sidebar menu counts and the search index are updated on soft delete and restore.
- **[changed]** The top bar's **Settings** entry moved into the **account dropdown**, which is now the
  bar's only action and is rendered for every visitor: a signed-in reader sees their email,
  **Settings**, and **Log out**, while a guest sees **Log in** and **Settings** instead of a standalone
  login button.
- **[changed]** The taxonomy editor's field descriptors are now built by shared `ModalFields` helpers
  (`taxonomy_tag_fields` for every taxonomy, `content_tag_taxonomy_fields` for the four content tags)
  instead of eight hand-maintained copies, and the tag workspace config is declarative `TagsHelper`
  metadata with the mechanical keys derived from the type name. This removes the field/URL drift risk
  tracked as quirk 54 and is what let `taggable` and `show_in_menu` land in one place per helper.
- **[changed]** Flash messages are now **floating toasts fixed to the top-right corner** instead of
  in-page alerts. Success toasts auto-dismiss after 4 seconds; error toasts after 10 seconds. Both
  can be closed manually. The flash partial renders once in the layout outside the page flow, and
  a new `flash_toast_controller.js` Stimulus controller manages the dismiss timers. The page-level
  mutation-status live region (for non-modal failures like row deletes) is unchanged.
- **[fixed]** Signing in from any page now returns the reader to **that page** instead of the
  landing page. The sign-in page remembers where it was opened from (a same-host referer), the same
  way a protected action already remembered the page that refused access; an external site cannot
  choose the destination.
- **[fixed]** Read-only empty taxonomy pages no longer instruct guests and read-only members to
  "Add" or drag records. Every remaining `shared/taxonomy_tree` caller now passes
  `read_only_empty_description`, so an empty taxonomy shows mutation copy only to writers (quirk 45).
- **[fixed]** The eight tag controllers no longer advertise `new` and `edit` routes that have no
  template or action. The routes are restricted to `index/show/create/update/destroy`, the dead `new`
  actions are removed, and the taxonomy node's vestigial `data-edit-url`/`data-create-url` attributes
  are gone — a row's only URL surface is `data-update-url` and the Details link (quirk 20, tag half).
- **[fixed]** A delegated admin could **demote or remove their own membership** and be left
  staring at a bodyless `403`: the membership page rendered change and remove controls on every
  row, including the caller's own, and the post-mutation redirect re-ran the admin-only
  authorization they had just lost. `MembershipsController` now refuses a self-mutation with a
  redirect back to the landing page and an alert, and the membership view renders a "You" label
  instead of change/remove controls on the caller's own row. The owner was already protected by a
  hardcoded row; request tests cover self-demotion, self-removal, and the hidden own-row controls.
- **[fixed]** Text typed into the top-bar search field **went dark on the bar's own dark
  background the moment the field was focused** — i.e. for as long as someone was actually typing
  into it. `.navbar-search-input` painted the bar's near-white text color, but Bootstrap's own
  `.form-control:focus` repaints `color` from the page's body color and carries one more
  pseudo-class than the plain class selector, so it won on specificity while the field had focus.
  The bar stays dark in both page themes, so a light-theme body color landed almost unreadable on
  it. The input's own `&:focus` block now restates the bar's text color alongside the
  background/box-shadow resets it already carried, the same way the scope select's `:focus` block
  already did.
- **[fixed]** The search box's **"Go to" rows were dark on dark** — the theme's own link blue on the
  bar's near-black panel, 2.6:1, in a row that had no padding, no radius, and no cursor of its own. The
  controller names a row `navbar-search-#{kind}`, and the stylesheet only styled `result` and `message`,
  so the one group the reader reaches for first (a destination, before any record) was left with
  whatever the *page* paints an anchor with: the panel does not inherit the bar's near-white, it sits
  inside a light page's `<body>`, so a row kind nobody styled silently became the theme's blue. The
  matched run in such a row was worse still — Bootstrap's own `mark`, a white box carrying the same
  blue as its text, in a panel whose every other highlight is amber. Commands and results now share one
  row treatment (block row, bar text, padding, radius, hover and keyboard-cursor tint), and the
  highlight is keyed on `.navbar-search-result-title` rather than on a kind, so a run in a destination
  title wears the same amber as a run in a record title. A kind added later has to be named in the row
  selectors in the change that introduces it, and `docs/visual_design.md` and
  `universe_maker_conventions.md` now say so.
- **[fixed]** The top-bar search box's **See all results** link was drawn across the bottom of the
  search field, so the text being typed — and the caret with it — disappeared the moment results
  arrived. The link was absolutely positioned against the form and then moved with `bottom`, and the
  form is no taller than the field because the results are out of flow, so `bottom: 0` resolved to
  the bottom edge of the *input* rather than to the foot of the results. The dropdown and the link
  are now one box (`.navbar-search-panel`) carrying one surface: the list scrolls inside the same
  24rem cap and the link is its footer, in flow beneath the results, so it is below them by
  construction rather than by a distance the browser has to be told. The box's surface is applied
  only while something is shown, so a closed search box leaves no empty sliver of panel under the
  field, and an engine that is unreachable — which has no answer to open — leaves no empty footer
  under its message.

- **[security]** Changing a record's **owning scope no longer strands its dependents** in the old
  universe or story. A model probe could move a parent Location to another universe while its child
  stayed behind, violating the graph-wide scope rules in ADR 0001; `Hierarchical` now rejects a
  `universe_id`/`story_id` change while child records exist, and `HasManyTags` rejects one while
  join rows still link the record, so a move that would orphan a subtree or a tag assignment is
  refused with a field error. Relation and Ownership endpoints were already covered by their
  same-universe validators, and web controllers never permitted scope ids, so this closes the
  model/import/console/association-API half. Unassociated records can still be moved — the
  menu-count cache tests rely on exactly that.
- **[security]** The seven **legacy tag join tables** (`characters_character_tags`,
  `events_event_tags`, `items_item_tags`, `locations_location_tags`, `ownerships_ownership_tags`,
  `relations_relation_tags`, `sections_section_tags`) now carry the **real foreign keys and a
  unique-pair index** the Scene-era join tables already had, so a duplicate or orphan join row is
  rejected by the database itself instead of only by the scoped association reads. One migration
  adds both constraints to each table and `db/schema.rb` is regenerated; the scoped HABTM
  declarations and the development-data loader are unchanged, and both development universes
  still load.

- **[chore]** New `test/models/soft_deletable_test.rb` covers the default scope, the cascade, restore,
  the Section/Event nullify behavior, and the partial-unique-index re-creation rule; the scene-elements
  destroy test now asserts the element is soft-deleted and its speaker links are kept for restore.
- **[chore]** Fixtures set `taggable`/`show_in_menu` on the tag fixtures, both development universes
  exercise grouping and menu tags (Dark: Family/Faction/Job, Indoor/Outdoor, Treasure, Social; LOTR:
  Race/Allegiance, Geographic, Artifact/Weapon, Conflict), and new model/controller/request/system
  cases cover the defaults, the editor dropdown filter, the workspace menu tab, the details-page
  badges, the modal checkboxes, and the read-only empty copy.
- **[chore]** CI now proves the migrations run from an empty database. A new `migrations-from-zero`
  job drops, creates, and migrates the test database from scratch, asserts every migration is up,
  and fails if the checked-in `db/schema.rb` differs from what the migrations produce — so a
  migration that was edited in place, or a schema dump that was not regenerated, is caught instead
  of silently loading the old shape. The local `bin/ci` runner gained the same from-zero step. The
  production-boot half of the finding (a clean image boot with the four production databases and a
  dummy master key) is deliberately not done here.
- **[chore]** A new `test/system/search_test.rb` case measures **every** option in the list instead of
  one named row: it composites the painted colors in the browser and holds the *worst* row — whichever
  kind it is — to AA, holds the panel to a single highlight fill across kinds, and holds the keyboard
  cursor to a visible change of surface. That is what makes the fix a guard rather than a patch: a kind
  that loses its row treatment again fails here, and the failure names the row and the ratio
  (`the navbar-search-command row "Go toCharactersUniverse one" is only 2.62:1 against the panel`)
  with a screenshot that is the reported bug. The compositing math the color cases share is now one
  constant instead of a copy per probe.
- **[chore]** `test/system/search_test.rb` asserted nothing about where the panel's parts land, and
  four of its cases were intermittently failing: Stimulus resolves each controller through a dynamic
  `import()` and connects it on a later turn of the router, so a keystroke delivered in between is
  dropped and the box stays silent. The shared `assert_stimulus_loaded` cannot cover that — it waits
  for a `stimulus-loading` class the pinned Stimulus never sets, so it is satisfied as soon as the
  page is parsed. `search_box` now waits for the controller instance to be *connected* before a case
  types, which is what lets a silent box mean "no answer" here rather than "asked too early"; three
  consecutive runs of the file are green where two of three runs of the previous revision failed
  three or four cases each. A new case reads the field, the panel and the link in one browser
  evaluation and fails if the link starts above either bottom edge; against the previous stylesheet
  it fails by 34.5px, and the failure screenshot is the reported bug exactly. The same case also holds
  a closed panel to zero height — without the conditional surface it measures 4px, an empty strip under
  the field on every page of the application — and the unavailable case now asserts there is no
  "See all results" link under a message that has no answer to open.
- **[docs]** `data_model.md` documents the `taggable` and `show_in_menu` tag columns,
  `universe_maker_conventions.md` states the shared tag-editor field builders and the `show_in_menu`
  tab rule, and `architecture.md` describes the batch-loaded tag badges on a tag's details page.
- **[docs]** `AGENTS.md` now requires checking [`known_quirks.md`](known_quirks.md) for a
  related open quirk before starting any [`backlog.md`](backlog.md) item and asking the
  owner whether to fix it in the same change, so a backlog task cannot silently inherit a known
  hole in the same model, table, controller, route, or code path.
- **[docs]** `visual_design.md` now says that both kinds of row in the panel wear the same row treatment
  and why the highlight is keyed on the title rather than on a row kind, and `universe_maker_conventions.md`
  states the rule behind it: every option row is painted by the panel and never inherits from the page,
  so a new kind joins the row selectors in the change that introduces it.
- **[docs]** `visual_design.md` describes the link as the panel's footer with the reason it is in
  flow, and `universe_maker_conventions.md` states the rule behind it: nothing inside the dropdown is
  positioned against the form, because anything that is resolves against a form no taller than the
  field.
- **[planned]** `docs/backlog.md` items 20–25 now hold the full collaboration system plan: six phases
  covering universe collaboration modes (`direct`/`wikipedia`/`github`), per-record discussions, a
  draft/apply mutation system with per-record conflict resolution ("theirs"/"mine"), a GitHub-style
  review workflow for owner+admins, and in-app notifications. Each phase is broken into deliverable
  slices with their own tests, docs, and changelog entries. Decisions recorded: discussions are
  configurable per model via a `HasDiscussion` concern; the draft system is a universe-level setting
  that does not replace direct writes by default; reviewers are owner+admins; conflict detection is
  per-record using `updated_at` as a version stamp. Deliberately deferred: per-field conflict
  detection, real-time collaborative editing, markdown in discussions, email notifications, draft
  branching/forking, and draft merging.

### 2026-09-27

- **[added]** A **magic search bar** in the top bar, on every page and for guests. It is a plain GET
  form first — submitting it opens `/search`, or `/u/:universe_slug/search` inside a universe — so the
  answer is shareable, reachable by keyboard, and works with scripting off; the dropdown is only the
  enhancement of that, asking the same URL for JSON as the reader types. A **scope** dropdown narrows
  the search to the **entire platform**, **this universe** (the default inside one), **this story**, or
  a single kind — only universes, stories, characters, locations, items, events, relations, ownerships,
  sections, scenes, or tags — and a kind search follows the page, so "only characters" means this
  universe's characters inside a universe and the readable ones on the landing page. Alongside the
  records, a **Go to** group offers the destinations the reader can reach: this universe's pages, its
  stories and their Sections/Scenes, or the universes they may open. That closes backlog item 8
  (command palette) together with item 21. The box is a form with a real `role="combobox"`: focus
  stays in the input while `aria-activedescendant` moves a cursor through the options, Enter follows
  the active one, Escape closes the list and then hands the key back, one live region announces the
  count, and a stale answer to a retyped question is dropped rather than rendered.
- **[added]** The search itself is **Meilisearch**, behind one `Search::Client` and a `Searchable`
  model concern: 19 models declare, next to their own fields, what they contribute to the index
  (`searchable kind:, title:, body:, route:, scope:, taxonomy:`), and `Search::Registry` holds the
  list a reindex reads. A document holds `universe_id`/`story_id` and never a universe's or story's
  *name*, so a rename needs no reindex and cannot show a stale name — `Search::Catalog` resolves the
  displayed context in two queries per request — and it holds its own `url`, so a result is a link
  without any view rebuilding routes. A universe's or story's name is deliberately not searchable:
  context is not content. Writes are queued (`Search::IndexRecordJob` after commit, a removal by id on
  destroy), so a save never blocks on a search service; `bin/rails search:reindex` is the bootstrap
  and the repair, and `bin/rails search:status` says what the engine holds.
- **[added]** Search is a **read that answers in two formats** — the results page and the dropdown —
  which is a new response pattern for a controller with no mutation path at all, and the first
  read-only flow here to serve both. It skips the shared `set_current_story` callback and resolves the
  current story itself, because that callback *remembers* `params[:story_id]`: without the skip,
  typing in the search box would silently switch the story the whole workspace is working in. A story
  id on its own is not a boundary — the scope decides that — so the top-bar form can carry the current
  story for a later scope choice without narrowing the default search.
- **[added]** A missing or broken engine is a **stated state, not a failure**: `Search.backend` is
  `Search::UnavailableBackend` when `MEILISEARCH_URL` is unset, every engine error is re-raised as
  `Search::Unavailable`, and the page or payload says so with the reason while the rest of the page
  renders. There is deliberately no SQL fallback — one query, one ranking, one answer — and the
  authorization rule is applied as a **filter sent to the engine** (`universe_id IN [...]` from
  `Universe.visible_to`, the same rule `Ability` enforces) rather than as a post-filter, so a private
  universe's records are never fetched and then hidden, and a reader with no readable universe is
  not asked at all. The engine's key stays server-side.
- **[changed]** **`bin/dev` now starts the search engine too**, as a third process beside `web` and
  `css`, and the engine no longer lives in `/tmp`. The engine used to be launched by hand as a
  detached background process, which produced three recurring failures: a stale engine outliving the
  session that started it (one such engine was still holding port 7700 long after its terminal closed,
  and re-parented onto `systemd --user`, which is what made it look unkillable), an engine silently
  missing after a reboot because `/tmp` had been cleared, and two engines fighting over the port when
  the second one exited immediately. Under foreman it starts, logs as `meilisearch.1`, and stops on
  `Ctrl-C` with everything else. The **data path is now `tmp/meili-data`**, inside the repository and
  out of git (`.gitignore` covers `/tmp/*`); it is derived data, so `bin/rails tmp:clear` may delete
  it and `search:reindex` rebuilds it. The documented install route moved from `/tmp/meilisearch` to
  `~/.local/bin/meilisearch`, and the Procfile names the bare command `meilisearch` rather than an
  absolute path — a tracked file must not carry one machine's path, and this way the line reads
  correctly for a Homebrew install, a `cargo` install, or a hand-placed binary alike. The
  `--master-key` on that line is the same local-only value the `web` line passes as
  `MEILISEARCH_API_KEY`, so the two cannot drift. `web` and `meilisearch` start concurrently, so a
  request in a session's first moments can get the honest "Search is not available" state until the
  engine says `Server listening on`; nothing falls back to SQL. `docs/development.md` records the
  one-time setup, the by-hand command, and both failure modes.
- **[changed]** `Procfile.dev` now carries `MEILISEARCH_URL` and `MEILISEARCH_API_KEY` on its `web`
  line, so `bin/dev` reaches a local engine without the developer exporting anything first. There is
  no `.env` loader in this application — `bin/dev` runs foreman with `--env /dev/null` — so a variable
  set in a shell is invisible to a `bin/dev` session, and a bare `bin/rails server` still sees neither
  source. The key is the same local-only value `docs/development.md` already publishes, never a
  deployed credential. `docs/development.md` now also documents a **non-Docker** route to the same
  pinned `v1.54` engine, for a machine that can neither run a container nor install one: the official
  static binary needs no privileges, where rootful Docker needs `sudo` and rootless Docker needs user
  namespaces that a locked-down host denies outright.
- **[fixed]** `bin/rails search:status` **crashed** in the state it exists to diagnose. It asked the
  engine for a document count unconditionally, but the engine answers `stats` for an index that was
  never created with `index_not_found`, which `Search::Client` honestly re-raised as
  `Search::Unavailable` — so the command a person is told to run *first* when search returns nothing
  died with a stack trace, immediately after printing `Index exists: false`. The count is now asked
  for only when the index exists, and the missing case is reported as the state it is, with the
  command that fixes it. Covered by `test/tasks/search_tasks_test.rb`, which pins all three outcomes
  (no index, indexed, unconfigured engine).
- **[fixed]** The search dropdown's **matched run was harder to read than the rest of the title**, which
  is the opposite of a highlight. The fill was `rgba(255, 193, 7, .35)`, and 35% amber over the
  panel's near-black `#1b1f27` resolves to a muddy brown around `#6a571b` — a box that was only 2.4:1
  against the panel behind it, so the reader could not even see where the match began, and white text
  on that brown is 6.9:1 where the unmarked near-white title beside it is 15.7:1. The run the reader
  was hunting for was therefore the *least* legible thing on the panel, dimmer even than its own
  context line, and the brown smear read as a redaction across the middle of the name. The run now
  wears the full-strength amber with the app's own `$dark` on top of it, 9:1 and unmistakably a
  highlight, with both colors **opaque** on purpose: a translucent fill also picks up the row's hover
  tint from `.navbar-search-result:hover` beneath it, so the one run the reader is tracking would be
  the one run that moved under the cursor. The new `test/system/search_test.rb` case is the first
  thing in this suite that measures a color rather than a class, because legibility is the only
  outcome here that a stylesheet cannot assert: it composites the mark and the line it sits in the
  way the browser really paints them and holds the run to AA, to being at least as legible as the
  panel's dimmest line, and to a fill that is actually distinguishable from the panel.
- **[fixed]** The top-bar search box's **scope** dropdown rendered as an opaque, square-cornered panel
  inside the rounded search field — two controls wearing one outline, and a light box on an always-dark
  bar. The bar declared `--bs-form-select-*` custom properties, but Bootstrap 5.3 compiles
  `.form-select` from Sass variables and never reads them, so the rule was a no-op: the select kept the
  page's background, text, and chevron. It now wears no surface of its own — no fill, no border except
  the hairline that divides it off, the bar's own chevron (Bootstrap's is a per-theme literal, and the
  bar is dark in both themes), and the field's trailing curve, so a hover follows the pill and the
  field's own `:focus-within` border is the focus state for everything inside it. The shared
  `searches/_scope_field` partial now takes the surface from the caller's optional `class`, so the
  results page's copy of the same control stays the ordinary theme-aware form control;
  `test/controllers/searches_controller_test.rb` holds both sides of that split, and the Search sections
  of `visual_design.md` and `universe_maker_conventions.md` state the treatment and the rule. The field
  also declares `color-scheme: dark`, and the field and scope colors are **opaque** rather than a
  translucent white overlay, because the *open* option list is painted by the browser: it takes the
  panel color from the element's own background and the rest of its palette from the used color scheme.
  Bootstrap sets that scheme only on `[data-bs-theme="dark"]`, so a `transparent` background — or a
  translucent one, which is the state the control is in when the list opens — left the bar's near-white
  options on a light panel. The opaque colors are the overlay composited onto the bar in Sass, because
  CSS cannot resolve an overlay onto the surface beneath it. The list's exact panel color and highlighted
  row remain the browser's, since styling them in full would mean a custom listbox and losing the plain
  GET form that works without scripting.
- **[fixed]** Three engine-contract bugs that failed **silently**, all found by running against a
  real Meilisearch rather than a stand-in: a document id containing `:` is rejected by the engine, which
  refused *every* batch, so a reindex reported "indexed 214 documents" over an empty index — ids are
  now built from the model name, and `test/models/searchable_test.rb` holds every declared model to
  the engine's character rules and to id uniqueness (a kind-based id made the eight taxonomies
  overwrite each other: 214 written, 161 stored). `Search::Reindexer` now also *checks* each task it
  awaits and raises `Search::ReindexFailed`, because a refused write is otherwise indistinguishable
  from a successful one. And `Array(hash)` converts a Hash into pairs, which broke a single-document
  upsert. `Search::UnavailableBackend#upsert` had the same mistake.
- **[fixed]** Search is available to guests and to read-only members: the top bar renders the box
  everywhere, and `Authentication` denies a request without an explicit
  `allow_unauthenticated_access`, so the search endpoint was redirecting every signed-out visitor to
  the sign-in form. A dropped scope or story is also no longer reported as an empty result: the
  request widens to the boundary that exists, keeps what was asked for in the URL, and the control
  shows what was really searched — a box that displayed "this story" as a *disabled, selected* option
  described a search that was not happening. A one-character query now offers no commands either, so
  the dropdown and the page cannot give two different answers to one question.
- **[chore]** The CSS build is **warning-free again**. The two `mix()` calls that derive the top-bar
  search field's opaque surfaces were the project's last use of a deprecated global built-in, and
  Sass's advice (`color.mix`) is only reachable here through an explicit `@use "sass:color"`: this
  pinned compiler no longer resolves the global built-in *module* namespaces at all, so the
  namespaced function is not optional. `_application_custom.scss` now loads the module on its first
  line, before the `:root` rule it opens with, because `@use` cannot follow a style rule. The
  compiled `app/assets/builds/application.css` is byte-identical to the build before the change —
  `color.mix`'s weight is the share of the first color, exactly as `mix`'s was, and the two
  variables already held `8%`/`18%` — so no color moved and the search bar's browser-measured
  contrast is unchanged; `test/system/search_test.rb` (12 runs, 122 assertions) passes.
- **[chore]** The test environment now uses the `:test` queue adapter, so the suite can assert what a
  save would have indexed without running anything, and `test/support/search_test_backend.rb` stands
  in for the engine: it records the query it was asked and replays chosen hits, proving what the
  application does with an answer without pretending to search. `test/search/meilisearch_integration_test.rb`
  is the deliberate exception — skipped without `SEARCH_INTEGRATION=1` — and covers the engine's own
  contract, which cannot be faked and which CI deliberately does not run. The navbar's search field is
  labelled **Search Universe Maker** so a page with two search fields (the Scenes filter has its own)
  no longer offers two fields announced as "Search", and `test/system/scene_filter_test.rb` addresses
  its own filter by id. `Searchable` sits in `app/models/concerns/` with the other five concerns, and
  the related value objects are grouped under the `Search` namespace, which
  `universe_maker_conventions.md` now states as the convention for both.
- **[docs]** `development.md` now states the one Sass rule the warning above exposed: the pinned
  compiler resolves no global built-in module namespace, so `color.mix` needs an explicit
  `@use "sass:color";` as the file's first rule, and the compile step silences only the `@import`
  deprecation, not the global-builtin one.
- **[docs]** `AGENTS.md` now states that the owner makes **every** commit and push: an agent codes,
  runs services, and resets the development database, and leaves the work in the working tree. Staging,
  amending, and history rewriting are named explicitly (`git add`, `commit`, `push`, `tag`, `merge`,
  `rebase`, `checkout --`, `stash`) because a staging or stashing command can quietly reshape what the
  owner is about to commit, and reading history (`git log`, `git diff`, `git status`) stays expected.
- **[docs]** New [ADR 0014](adr/0014-global-search-with-meilisearch.md) records why Meilisearch
  rather than SQL `LIKE`, SQLite FTS5, or a SQL fallback behind the engine, and what an engine outage,
  a rename, and an index rebuild each cost. `architecture.md` gains a **Global search** section (the
  parts, and the four rules that must not drift), a row in the response-format table, and the routing
  edges; `universe_maker_conventions.md` gains a **Global search** section; `development.md` gains the
  engine setup, the three environment variables, the reindex/status commands, and two checklist steps
  for a new model; `visual_design.md` describes the box and the panel; and `known_quirks.md` records
  the two open search costs (a refused write invisible to its job, and a universe rename invalidating
  stored paths until the repair runs) plus a pre-existing one found while verifying this work: the
  browser suite is unreliable on a saturated machine, where SQLite's busy timeout surfaces through
  Capybara as unrelated-looking failures. That was reproduced on a pristine checkout of `aa224a2`
  (10 failures, 41 errors) and is green with `PARALLEL_WORKERS=2`.
- **[added]** A **Settings** page at `/settings` with vertical tabs, reached from one new **Settings**
  entry in the top bar next to the account menu and rendered for every visitor, guest included. The
  first and only section is **Appearance**, and its only control is **Theme**: a radio group of **Light**
  and **Dark** labelled cards, each with a swatch of that theme's page color, saved by a plain
  full-page form. The section list is declarative (`settings_tabs` plus `shared/_settings_navigation`,
  the same URL-backed tab pattern as `shared/_content_tabs` turned vertical), so the next section is
  one entry plus its panel. Settings is deliberately **not** a Configuration entry in the right
  utility sidebar: it is a platform page outside `/u/:universe_slug` that skips the universe callbacks
  and `authorize_universe_access`, because a display preference belongs to the browser rather than to
  a universe and must work on the landing page and signed out.
- **[added]** Dark mode. `AppTheme` holds the whole feature: two known names, `light` as the default,
  and one **signed** cookie (`um_theme`, a year, `HttpOnly`, `SameSite=Lax`, `Secure` in production) —
  no migration, no model, and no authorization. The application layout writes
  `<html lang="en" data-bs-theme="…">`, so Bootstrap's own dark variables apply on the **first
  paint** with no client-side script and no flash of the wrong palette; an unknown, unsigned, or
  hand-edited cookie value resolves to the default on every read and write, so nothing but a known
  theme can reach the document. `test/system/settings_theme_test.rb` proves in a real browser that
  Bootstrap's variables actually follow the attribute, which is the part a request test cannot see.
- **[fixed]** The settings form opts out of Turbo (`data: { turbo: false }`). Turbo Drive replaces the
  body and head but not attributes on the **root** element, so a Turbo submission stored the new
  theme and kept painting the old one — caught by the browser test, not by the request suite. Any
  future client-side theme switch has to set `document.documentElement` itself.
- **[fixed]** `.navbar-actions` is now a flex row, so the new settings entry and the account menu sit
  side by side instead of stacking once the bar holds more than one action.
- **[changed]** The light-only literal surfaces in the custom stylesheets became `--um-*` tokens
  (`--um-surface-raised`, `--um-row-hover`, `--um-surface-veil`, `--um-tag-badge-border`) with a
  `[data-bs-theme="dark"]` value, and every existing `--um-*` token that carried a light-only value is
  re-tinted there. Each scope keeps its hue across themes — universe blue, story crimson, tools green —
  so a block still reads as the same scope. Author-chosen data colors (tag badges, timeline nodes) are
  deliberately untouched.
- **[docs]** New [ADR 0013](adr/0013-platform-settings-and-browser-theme.md) records why settings
  is browser-owned, server-rendered, and outside the universe workspace, and what a later per-account
  preference or instant toggle would have to change. `architecture.md` (routing, response formats,
  request lifecycle, top bar), `universe_maker_conventions.md` (routes, the form and vertical-tab
  patterns, top-bar and right-sidebar navigation), `visual_design.md` (the Settings page shape and the
  full light/dark token table), and `development.md` (manual verification) follow it.
- **[chore]** `test/models/app_theme_test.rb` pins the theme whitelist and the cookie contract,
  `test/controllers/settings_controller_test.rb` covers the page for a guest and a signed-in user with
  no universe, the redirect, the refusal of an unknown theme, a missing parameter, and a forged cookie,
  `test/integration/navigation_test.rb` pins the top-bar entry on the landing page and inside a
  universe (and its absence from both sidebars), and `csrf_mutation_test.rb` proves the new HTML
  mutation is refused without a token and accepted with one.
- **[added]** Backlog slices **11.8, 11.9, and 11.10**, which complete **Epic 11 — Add Scenes to a
  Story** in every slice it specified. Item presence, Location presence, and the reverse continuity
  links are delivered; the epic now leaves `docs/backlog.md` and its delivered state lives here and
  in [ADR 0007](adr/0007-story-owned-scenes-and-elements.md).
- **[added]** `SceneItem` (`scene_items`: `scene_id` + `item_id` with real foreign keys, a unique
  pair index, and a nullable free-text `role`) is a join model for the same reason `SceneCharacter`
  is: the role is part of the decision, and a blank role means no role rather than an empty
  annotation. The **Items** tab is its own canonical read page with add, role-edit, and remove
  through the shared modal contract from [ADR 0011](adr/0011-modal-json-mutation-contract.md).
  Unlike the Characters tab it has one participation source, so every row is a stored link and the
  row list, the page count, and the count a mutation changes are the same rows.
- **[added]** `SceneLocation` (`scene_locations`, the same shape) with the **plural Locations** tab,
  because a Scene may use any number of places. It is the only Scene workspace whose rows are
  hierarchical, so a linked place is named with its full ancestor path (`Winden / Nielsen House /
  Martha Room`) and the picker is depth-indented in root-first order. The new `LocationPaths` value
  object builds both from one ordered universe query, the same shape as `SectionPaths` and
  `SceneTagPaths`; the row *list* stays a flat name order, because the path is what disambiguates
  two places with the same name. An Item and a Location are shared universe records, so linking one
  records that a Scene uses it and never copies it or its nested places.
- **[added]** `SceneAppearances` and the **Appears in scenes of &lt;Story&gt;** section on the
  Character, Item, Location, and Event details pages: the reverse of the three workspace tabs, so a
  shared universe record can be traced forward into the Story's narrative sequence. It reports the
  **union** of a stored presence link, a derived Dialogue speaker, and an `event` reference — one
  row per Scene, never a sum — in Scene `position` order, with **Linked**, **Speaks in N element(s)**,
  and **Depicted** listed separately so the reason is never collapsed into one word. The section is
  read-only navigation, so it renders for every access level, and it is scoped to `Current.story`:
  a Scene has no Universe-level URL, so with no Story selected the section says so and offers the
  story list rather than falling back to the Universe's first Story.
- **[added]** Analyzer-oriented query coverage in `test/models/scene_continuity_queries_test.rb` for
  the shape a later checker will read: several Scenes may depict one Event and none is merged,
  narrative order is Scene `position` even when in-world `datetime`s say the opposite, the Event
  reference and the Scene datetime stay independent, one shared record can appear in many Scenes
  across Stories, an appearance query never blends two Stories, and every Scene-owned world link
  stays inside the Scene's own Universe.
- **[added]** Connected development data for all three new models in `db/data/dark` and
  `db/data/lotr`: the same Item in two Scenes, two Items in one Scene, a Scene with three linked
  Locations, a nested Location beside a top-level one, populated and blank roles across all three
  tabs, and Scenes with no Item or Location so each empty state is reachable without inventing a
  record. The loader's reference order is now Scene → SceneElement → SceneCharacter → SceneItem →
  SceneLocation.
- **[changed]** All four Scene workspace tabs are now live links, so the tab shell renders no
  `aria-disabled` placeholder and no tab ever points at a route that does not exist. The Scenes list
  keeps exactly the two count pills it has (Element and participant); Item and Location counts are
  deliberately absent, because they would cost an extra grouped query per page and the tabs are
  where that detail belongs.
- **[changed]** `shared/detail_section` accepts a pre-rendered `empty_action` for the empty case. The
  section's own block is the record list, which an empty section has no use for, so the two could
  not share it; existing callers pass no `empty_action` and are unaffected.
- **[fixed]** The development-data loader logged every join record as `Created SceneItem: record`,
  which made a load impossible to verify by reading its own output and applied to `SceneCharacter`
  since slice 11.7. It now names a link row by the records it joins
  (`Created SceneItem: scene.secrets -> item.jonas-key`).
- **[security]** Both new endpoints refuse an HTML mutation with `406` **before** anything is
  written, refuse a mutation without a valid CSRF token with `403` and write nothing, and resolve
  every record through the authorized Universe → Story → Scene path, so a foreign Scene, presence
  link, Item, or Location is a `404` rather than a cross-scope write. `Item` and `Location` declare
  their presence links from their side with `dependent: :delete_all`, so deleting one removes its
  links and never a Scene, and the ADR's `Item` and `Location` deletion confirmations are now live.
  A same-Universe target is proved in the model, in the controller, and by real foreign keys plus a
  unique pair index in the database. The reverse section adds no new surface: it is read-only
  navigation rendered on a page the shared authorization has already allowed, and every link it
  emits carries an explicit `story_id`.
- **[docs]** `docs/architecture.md`, `docs/data_model.md`, `docs/universe_maker_conventions.md`,
  `docs/visual_design.md`, `docs/development.md`, `docs/known_quirks.md`, and
  [ADR 0007](adr/0007-story-owned-scenes-and-elements.md) record the delivered state: every
  Scene-owned route in the ADR's target-URL table is live, the third presence link, the plural
  hierarchical Locations tab, `LocationPaths`, the `SceneAppearances` union and its story scoping,
  and the manual verification steps. `docs/known_quirks.md` findings 19 and 23 now name the new
  constrained join tables and the covered presence-link paths. The Epic 11 entry is deleted from
  `docs/backlog.md`, and item 9 keeps only the adjacent ideas the epic deliberately did not decide.
- **[chore]** New coverage for the delivered slices: `test/models/scene_item_test.rb`,
  `test/models/scene_location_test.rb`, `test/models/location_paths_test.rb`,
  `test/models/scene_appearances_test.rb`, `test/models/scene_continuity_queries_test.rb`,
  `test/controllers/scene_items_controller_test.rb`,
  `test/controllers/scene_locations_controller_test.rb`,
  `test/controllers/scene_appearances_section_test.rb`, `test/system/scene_items_test.rb`,
  `test/system/scene_locations_test.rb`, and `test/system/scene_appearances_section_test.rb`. The
  request cases cover the full public/private read-write-admin matrix for both tabs, including
  cross-scene, cross-story, and cross-universe link management; the browser cases cover the modal
  add/edit/remove round trip, the duplicate explained in the modal, the ancestor path, the
  read-only member, and the unselected-story prompt. `test/fixtures/scene_items.yml` and
  `test/fixtures/scene_locations.yml` link the same shared record into two Scenes, and the shared
  suites (`ability_test`, `universe_scope_resolver_test`, `csrf_mutation_test`,
  `modal_json_contract_test`, `scenes_controller_test`, and the development-data registry and
  loader tests) were widened rather than forked. No client-side code changed, so `bun run check:js`
  is unchanged at 75 cases.
- **[added]** Backlog slices **11.6 and 11.7** — Scene Elements with Dialogue speakers, and
  Character presence in a Scene. `scene_elements` stores a flat ordered block of a Scene's prose
  (`kind` restricted to `narration`/`dialogue` in the model *and* by a database check constraint,
  never a column named `type`; a required **Title**; an optional plain-text **Content**; a
  contiguous `position` inside its own Scene), plus the `scene_element_speakers` join for a
  Dialogue's speakers. `scene_characters` is a join model with a nullable free-text `role`, because
  the role is part of the decision. The Element list and its modal render on Scene Details; the
  Characters tab is its own canonical read page. Both flows reuse the shared modal contract from
  [ADR 0011](adr/0011-modal-json-mutation-contract.md) rather than building a second editor, and
  the Elements endpoint is JSON-only, so `modal_form_controller.js` gained a `move` action that
  issues the `PATCH` and performs the same-URL refresh a save performs — a JSON-only ordered row has
  no Turbo form to follow, exactly like a JSON-only delete. A Dialogue must name at least one
  same-Universe speaker, Narration may keep none, and a Dialogue becomes Narration only through the
  modal's explicit "remove the speakers" confirmation, which clears them in the same atomic request.
  The **Characters** tab is a URL-backed workspace tab now; **Items** and **Locations** remain
  `aria-disabled` placeholders.
- **[added]** Participation in a Scene is read from its two independent sources — an explicit
  `SceneCharacter` link and a Character who speaks in a Dialogue Element — and reported as their
  **union** through the new `SceneParticipants` value object. A Character who both participates and
  speaks is one participant carrying two labels, never two rows and never a double count, and
  speaking never creates a stored presence row. The Scenes list gained an Element count and a
  participant count, each read for the whole page in one grouped query.
- **[added]** Connected development data for both new models in `db/data/dark` and `db/data/lotr`:
  a Scene with no Elements, a Dialogue whose speakers are not stored participants, a one-speaker and
  a three-speaker dialogue, two title-only Element blocks, a populated role, and two blank roles. The
  development-data registry gained a `:scene` scope, so a Scene-owned record declares its `scene:`
  and the loader resolves its Universe through it, groups Element positions inside their own Scene,
  and keeps the reference order Scene → SceneElement → SceneCharacter.
- **[fixed]** A system-test click delivered before Stimulus and Turbo had connected was silently
  dropped on some machines, so a case that had not waited for the page to be interactive failed for
  a reason that had nothing to do with the flow under test — the existing Scene tests failed this way
  on a clean checkout. `ApplicationSystemTestCase#visit` now waits for the `stimulus-loading`
  readiness signal after every navigation, so the wait lives in the base class instead of in each
  case.
- **[security]** Both new endpoints refuse an HTML mutation with `406` **before** anything is
  written, refuse a mutation without a valid CSRF token with `403` and write nothing, and resolve
  every record through the authorized Universe → Story → Scene path, so a foreign Scene, Element,
  presence link, or Character is a `404` rather than a cross-scope write. A same-Universe speaker or
  presence target is proved in the model, in the controller, and by real foreign keys plus a unique
  pair index in the database.
- **[docs]** `docs/architecture.md`, `docs/data_model.md`, `docs/universe_maker_conventions.md`,
  `docs/visual_design.md`, `docs/development.md`, and
  [ADR 0007](adr/0007-story-owned-scenes-and-elements.md) record the delivered slices, the
  hybrid response split, the two flat ordered sequences, the participation union, and the manual
  verification steps. `docs/known_quirks.md` findings 22 and 23 now name the second flat sequence
  and the two new constrained join tables.
- **[chore]** New client-side coverage: `test/javascript/scene_element_form_controller_test.js` and
  five cases for the shared modal controller's `move` action, bringing the Bun suite to 75 cases.

- **[added]** Closed known quirk 33 with a real client-side pipeline, recorded as
  [ADR 0012](adr/0012-client-side-verification-and-csrf.md). The Stimulus controllers now have
  unit tests on Bun's built-in test runner (`bun run test:js`, 62 cases in `test/javascript/`) that
  run in a happy-dom DOM, and Biome (`bun run lint:js`) checks them and the controllers in a new
  `js-check` CI job. `test/javascript/setup.js` provides the DOM and stubs `@hotwired/stimulus` and
  `bootstrap`, because the application serves both from the import map rather than `node_modules` —
  the tested controller is the file the browser loads, with no second copy of the framework.
- **[added]** `test/javascript/no_html_sink_test.js` fails when a new
  `innerHTML`/`outerHTML`/`insertAdjacentHTML`/`document.write` sink appears in `app/javascript`
  without a reviewed exception, so the DOM-API-only rule behind the resolved DOM-XSS finding is
  enforced rather than advisory.
- **[fixed]** Three defects the new unit tests found in the code they were written for. Cancelling
  an inline taxonomy rename restored the author's unsaved text instead of the name the server had
  rendered, so a row could show a name the database did not have. A `belongs_to` error keyed on
  `:parent` was labelled `parent` instead of the editor's own **Parent tag** label, even though the
  message was placed on the right control. A `422` body whose `errors` was not an object was read as
  an error on an attribute literally called `errors` instead of as a response that explains nothing.
  Each has a unit test, and the cancelled-rename case also has a browser regression.
- **[fixed]** The taxonomy editor's `fetch` always sent an `X-CSRF-Token` header, so a page without
  the meta tag would have sent the literal string `undefined` and been refused as an invalid token
  rather than a missing one. It now omits the header, as the flat-list modal already did.
- **[security]** A mutation that arrives without a valid CSRF token is now refused as a refusal
  rather than as a validation failure: `ApplicationController` answers `403` for a JSON request
  whose token Rails rejects, so the shared editor says the change was refused and keeps the author's
  input instead of reporting that the server explained nothing. `test/controllers/csrf_mutation_test.rb`
  and `test/system/csrf_token_test.rb` turn forgery protection on for their own window and prove
  that the page's `csrf-token` meta tag is sent by both `fetch` implementations, accepted by the
  server, and that a missing or forged token is refused with nothing written — the browser cases by
  removing the meta tag, the request cases by replaying the token a real page published.
- **[docs]** `docs/known_quirks.md` now holds only open findings. Every "former finding was fixed"
  paragraph was removed and its history already recorded in `docs/delivery_history.md`, the dated
  follow-up verification log moved there as a **Verification history** section, and the 2026-09-24
  audit baseline is labeled as the evidence behind the findings rather than a capability list.
  Quirk 33 itself moved to `docs/delivery_history.md`. The rules stay in `AGENTS.md` and are now
  stated in the file itself: a fixed entry is moved whole, and nothing about it is left behind.
- **[docs]** `docs/development.md` documents the client-side commands, the test layout, and the
  `js-check` job; `docs/architecture.md` records the test-environment CSRF rule and the token in the
  editor data flow; `docs/universe_maker_conventions.md` states the client-side rules every editor
  follows.
- **[chore]** Biome's first run reported twelve real problems, all fixed here: two self-assigning
  `window.location.href = window.location.href` reload fallbacks became `window.location.reload()`,
  and ten `forEach` callbacks that returned a value gained braced bodies. Linting is deliberately
  not formatting — the controllers keep their hand-written style.
- **[chore]** `@biomejs/biome` and `@happy-dom/global-registrator` are the project's first
  development-only JavaScript dependencies, pinned through the committed `bun.lock`;
  `bun install --frozen-lockfile` is clean, and `bun audit` reports no vulnerabilities across 116
  packages.

### 2026-09-26

- **[fixed]** Closed known quirk 18 — a rejected mutation now explains itself in every editor
  instead of only announcing that something went wrong. The taxonomy tree's modal editor renders the
  server's `422` the same way the flat-list modal does: a focused `danger` summary plus the message
  on the control that caused it, with an association error (`parent`) resolved to the `parent_id`
  field it belongs to. Its single-field paths — inline rename, create, move, delete — now announce
  the server's own message instead of a generic sentence, and the editor claims focus back when a
  rejection arrived while the modal was still opening.
- **[fixed]** Closed the other half of quirk 18 for the two HTML-flow modal workspaces. Relations and
  ownerships re-render their index after a refused submission, so they now render the new shared
  `shared/_error_summary` twice: once on the page the author lands on, once inside the editor, and
  they serialize the rejected values into the trigger that reopens it — the **Add** trigger for a
  rejected create, and only the row being edited for a rejected update. A refused form no longer
  has to be retyped from scratch. The same summary is now the one shared model error summary, used by
  the flat-page forms as well.
- **[fixed]** Closed known quirk 32 — the browser suite had only covered the taxonomy tree and the
  Scenes workspaces, and its one flat-list test passed even while its mutation was committed and
  answered `406`. Each previously uncovered journey now has focused coverage: a rejected relation
  that reopens with its values, an ownership created through the modal, the row and editor at a 390px
  viewport, granting and refusing universe access (including a read-only member's access notice and
  the admin-only Members page), the whole password-reset journey with its mismatched-confirmation and
  invalid-token paths, and a rejected taxonomy edit. The suite grew from 39 to 50 browser tests.
- **[fixed]** Two defects in this work were found only by the browser coverage and are fixed here.
  A new taxonomy controller method initially reused the name of an existing one, silently replacing
  its label builder, so every taxonomy editor raised a `TypeError` and no modal opened — the
  symptom looked like flaky browser input rather than a name collision. And Bootstrap's focus trap
  focuses the dialog when a modal finishes opening, so a save rejected during the opening transition
  lost the error summary's focus.
- **[chore]** Post-mutation browser assertions now use a shared `REFRESH_WAIT` in
  `ApplicationSystemTestCase`: a mutation ends in a full same-URL navigation, so the first assertion
  after one waits ten seconds instead of Capybara's two. It only changes how long a passing refresh
  may take.

- **[added]** Completed backlog item 11.5, the shared modal reliability slice that Scene Elements
  depend on, recorded as [ADR 0011](adr/0011-modal-json-mutation-contract.md). A modal page now
  declares its own mutation contract with `data-modal-form-response-value`, and the flat-list modal
  (`modal_form_controller.js`) submits JSON itself: the form's own field names go out as
  `application/x-www-form-urlencoded` with `Accept: application/json` and the CSRF token, and the
  verb comes from the form's `_method`, so create and update share one path. Relations and
  ownerships keep the documented HTML redirect/re-render flow and declare `html`; nothing is
  intercepted there. `test/controllers/modal_json_contract_test.rb` pins the declared mode, the error
  region, the submit target, and the row's delete control for all five modal workspaces, so a new
  page cannot drift back to the old submission.
- **[added]** A rejected save is now visible, explained, and recoverable in the modal it came from. A
  `422` error hash is rendered as a focused `danger` summary at the top of the modal body **and** next
  to the control that caused it, with `aria-invalid` and `aria-describedby`; a record-level message
  and a rejection with no field of its own are summarized only. A model reports an association
  rejection on the association (`before_event`) while the form field is the foreign key
  (`before_event_id`), so both spellings resolve to the same control — the "an event cannot point at
  itself" rejection now appears on **Happens before**. While a request is in flight the submit button
  is disabled with a spinner and the form is `aria-busy`; a request that never reached the server, a
  `403`, a `5xx`, and an unreadable body each report their own wording. The modal stays open with
  the entered values, and the error summary keeps focus: a save rejected while the modal is still
  opening does not lose the summary to Bootstrap's own focus trap, and a submit button that has just
  been disabled does not pull focus back to the dialog. Eight browser regressions cover the whole
  path, including a 390px viewport.
- **[added]** A mutation that never went through a form — a row delete — or a request that failed
  outside a modal now reports itself in one page-level live region rendered by the layout beside the
  flash messages: a short confirmation is visually hidden and only announced, a failure renders a
  visible alert and takes focus, and the refreshed page starts empty again.
- **[changed]** Delete in a JSON-only workspace is a first-class mutation instead of a Turbo form
  against a `204`. `shared/_row_actions` takes an explicit `delete_via:`: a JSON row's Delete is a
  button the modal controller issues, with the same mandatory consequence copy in
  `data-modal-form-confirm`, and a `404` is treated as "already gone" and refreshes rather than
  reporting a failure. After any successful create, update, or delete the controller performs a
  same-URL Turbo visit, so rows, page counts, and cached sidebar counts come from one fresh server
  render rather than a local update that can drift.
- **[changed]** A JSON-only mutation controller can no longer commit behind its own error. The new
  `RequiresJsonMutationFormat` concern gives one guard, added to `CharactersController`,
  `ItemsController`, `EventsController`, and `SceneTagsController` (which had its own copy), that
  answers `406 Not Acceptable` for a request that does not ask for JSON **before** anything is
  written, as an explicit `before_action` so the callback order stays visible. The response matrix
  itself is unchanged.

- **[fixed]** The flat-list modal committed a write and then answered `406 ActionController::UnknownFormat`,
  so a browser create or update saved the record, showed no error, and duplicated the record on a
  retry. Validation failures now reach the form instead of disappearing.
- **[fixed]** Deleting a row in Characters, Items, or Events left the row and the counts in the DOM
  until a manual reload, and a second click could target a missing record. The row is now removed and
  the page and sidebar counts refreshed from the server.
- **[fixed]** Two smaller defects the new browser coverage found. Opening the editor filled Rails'
  hidden companion field instead of the visible multi-select, so a tag picker looked empty in the
  modal even though the record had tags. And a multi-select whose name already ends in `[]` was given
  a second `[]`, which made the "clear the last tag" blank unparseable, so removing the last tag left
  the stored assignment in place; an empty multi-select now sends exactly one explicit blank value.
  The old Character smoke test could also pass on a committed-but-`406` write; the row now only
  appears after a real `201`, and the new regressions assert the refreshed counts.
- **[added]** Completed backlog item 11.4.1, part (b) — the Scenes workspace gained a **Find scenes**
  search area, because a story can hold hundreds or thousands of scenes. The new `SceneFilter` value
  object owns the whole query contract on the canonical index URL: `q` (case-insensitive text over
  the title and short description, with `%`/`_` matched literally), `section_id` (a Section of this
  story or the explicit `ungrouped` group), `scene_tag_id` (a Scene Tag of this story — the scene
  "type" label, since `Scene` has no type column), and inclusive in-world `from`/`to` **days**. A
  filter value that cannot be used is dropped and reported on the page instead of quietly emptying
  the list: a Section or Scene Tag from another story, or a date that is not an ISO day. A scene
  without an in-world time is never inside a date range. Filtering is reading, so the search area is
  rendered for writers, read-only members, and guests on a public universe and adds no mutation
  control. Active filters stay in the URL, a plain form submission is redirected once to the
  canonical query, and a reorder or delete inside a narrowed list returns to the same filter.
- **[added]** The filtered list keeps the story's canonical meaning. The narrative-position badge and
  the "of N" total come from one aggregate query over the whole sequence rather than from the
  filtered rows, and Move up/Move down are disabled from the story's real first and last position, so
  a narrowed list can neither renumber a scene nor disable a move that has a neighbour. A filter that
  matches nothing now has its own empty state — **No scenes match these filters**, with the active
  filters repeated and a **Clear filters** action — which is never reused for a story without scenes.
  Added value-object, request, helper, and browser coverage, including a guest filtering with the
  keyboard alone at a 420px width.

- **[changed]** The Sections workspace **Move scene** form now offers only the ungrouped scenes its
  own surface lists, and its source selector is labelled **Ungrouped scene** so the control matches
  the block it lives in. This supersedes the same-day 11.4.1(b) note below that the form offered
  every scene of the story: a grouped scene is now put back to Ungrouped from its own Section's page,
  where the scene editor carries the Section selector, so nothing became unreachable. The form is not
  rendered at all when every scene is grouped, instead of offering an empty selector. Request and
  browser coverage now assert that a grouped scene is never offered, that the badge states the
  subset, and that the ungroup path goes through the scene editor.
- **[changed]** Completed backlog item 22. The top bar is now three links and the account menu, with
  no switcher dropdown: **Universe Maker** is the brand and the landing page, and **Universe: …** /
  **Story: …** are plain links to the current universe page and the current story page. A scope link
  carries `.active` together with `aria-current="page"` only on the page it points at, so the bar
  never claims a scope that is not being viewed, and the story link exists only while a story is
  current instead of rendering a "Select" placeholder. Changing universes and creating one happen on
  the landing page, and changing stories happens on the universe page, which lists them with an
  **Open** action each; because removing the Story dropdown would otherwise have lost the only
  create entry point, the universe page header gained **New story** for writers, and the navbar's
  now-dead `nav_universes` helper was removed, so the top bar issues no query at all.
- **[changed]** Completed backlog item 23. Every list row now has one shape: a plain-text name with
  its tag badges and, where a count exists, a `.record-count` pill on the left, and a right-hand
  group holding an always-visible **Details** link followed by an always-visible `[…]` action menu.
  Locations, Sections, and every tag tree lost their hover-only `opacity: 0` menu, and the Scenes
  list gained the **Details** link every other list already had, so a read-only member and a guest
  can reach a scene's page from the list. The count is no longer part of the Details label: it is
  rendered by the new `record_count_badge(count, label)` next to the name it belongs to, which keeps
  the link label short in a long list and makes counts comparable across rows. The taxonomy node
  serializes the count onto the node, so cancelling an inline
  rename rebuilds the rename button with the count intact instead of silently dropping it.
  Browser coverage pins the no-hover visibility of both halves of a row, the count's return after a
  cancelled rename, and the read-only Scene row.
- **[changed]** Completed backlog item 11.4.1, part (b) for the Sections workspace. A Section is a
  group, not a record with a scenes list of its own, so the surface below the tree is now
  **Ungrouped scenes**: it lists only the scenes that belong to no section, says how many are grouped,
  and points at each Section's own page (already shipped) for the rest. Grouping a scene therefore
  removes it from that list instead of duplicating it, and the selector-driven **Move scene** form
  still offers every scene of the story because regrouping is how a grouped scene comes back. The
  `scenes/_section_outline` partial is now `scenes/_ungrouped_scenes`, and `SectionPaths#ids` exposes
  the ids the list already loaded so a filter value can be validated without a second query.

- **[fixed]** A count on a row now says what it counts instead of showing a bare figure. The taxonomy
  and Section pills read `Family Nielsen (4 characters)` and `Episode 1 (3 scenes)` rather than `4`
  and `3`, because a number beside a name is ambiguous as soon as a list has more than a few rows.
  `record_count_text(count, label)` formats it and `record_count_badge(count, label)` renders the
  pill; the visible text is the pill's own accessible name, so nothing is announced twice, and the
  tree controller still restores the pill from server-formatted text when a rename is cancelled. The
  **Ungrouped scenes** badge above that list likewise reads `3 ungrouped scenes` rather than `3`, so a
  subset count is never mistaken for the story's own scene count.

- **[docs]** Updated every place the list-row contract is written down after the count-label and
  Sections-workspace changes, so the count pill, the ungrouped-only move form, and the badge wording
  are described the same way in each: `docs/architecture.md` (the "List rows" section and the
  Sections-workspace paragraph), `docs/universe_maker_conventions.md`, `docs/visual_design.md` (its
  list-row rules, the taxonomy-tree row, the Scene workspace, and the accessibility list),
  `docs/data_model.md`, `docs/development.md`'s manual checks, the ADR 0007 execution note, and the
  `TaggedRecordCounts` / `tags_helper` comments. The same-day 11.4.1(b) changelog entry is left as
  written and the new entry above states what superseded it.
- **[docs]** Recorded the delivered slice in the Scene architecture (a new "The story's Scene list is
  filtered, never re-ordered" section), the conventions, the visual design, the development guide,
  and an ADR 0007 execution note that states how the "separate grouped outline" decision is now
  implemented. `db/data/README.md` and the development guide's manual verification steps describe the
  new sample data, the search area, and the ungrouped-only Sections list.
- **[docs]** Adopted the known-quirks discipline for the shared backlog: `docs/backlog.md` now holds
  pending work only, and finished work leaves it. The rule is written into the backlog header,
  `AGENTS.md`, and `docs/README.md`: in the change that delivers an item, add the dated changelog
  entry and then delete the item, with no "completed" prose, archive heading, or status marker left
  behind. The changelog is the only record of delivered work. Remaining item numbers are never
  renumbered or reused.
- **[docs]** Cleaned the backlog accordingly. Removed the already-finished items 12 (taxonomy modal
  XSS/stale state), 13 (taxonomy tree insertion and reordering), 21 (taxonomy editor visuals), 22
  (details pages for every element and tag), and 23 (navigation/sidebar visual pass), plus the
  delivered write-ups for Epic 11 slices 11.0-11.4 and the finished 11.4.1(b) sub-bullet; all of
  them were already recorded in the 2026-09-25 changelog entries. The open work is unchanged: items
  2-11, 11.4.1, slices 11.5-11.10, items 14-20, and the FUTURE WORK list. The remaining references
  to slice 11.0 now cite ADR 0007 and the epic's target domain model, which also states the
  one-or-more-speaker rule for Dialogue directly, and the epic's definition of done now says a
  delivered slice is deleted from the delivery-slices list after its changelog entry.
- **[docs]** Dropped the now-done backlog pointers from `docs/architecture.md` and from the
  `SectionsController#show` and `sections/show.html.erb` comments; they described shipped behavior
  as pending. No application behavior, schema, or data changed.

- **[chore]** Reworked the Dark `db/data/dark/scenes.yml` sample data (12 scenes) so grouping and
  narrative order are visibly different things: three scenes share Season 1 / Episode 1, three are
  ungrouped — including one told last but set in 1953 and one unfinished title-only scene — and each
  remaining section keeps a single scene. Two scenes now also share one Event, and the loader tests
  assert the grouped/ungrouped shapes and the flashback ordering.

### 2026-09-25

- **[added]** Completed backlog item 22. Every standard element and every element tag now has its
  own read-only details page — Character, Location, Item, Event, Relation, Ownership, Section, and
  the Character, Relation, Location, Event, Item, Ownership, Section, and Scene tags. A content page
  identifies the record and states which related information will appear later; a tag page lists the
  records carrying it; a Section page lists the scenes grouped under it, each still showing its
  narrative position (this also completes backlog 11.4.1(b)). Every flat-list row and taxonomy node
  renders a `Details (N records)` link that repeats the record name and count in its accessible
  name, and the new pages are composed from the shared `record_details`, `detail_facts`,
  `detail_section`, and `tagged_record_list` partials so each record type can keep adding
  information to the same URL. Details pages are HTML-only, guest-readable on a public universe,
  and render no mutation control; a record from another universe or story is a 404.
- **[added]** `HasManyTags#tagged_records` (the scoped inverse association, ordered by name) backs
  each tag's page and cannot disclose another universe's or story's records.
  `TaggedRecordCounts.for(tags)` answers "how many records carry each tag" with one grouped query,
  because the scoped HABTM sides have an instance-dependent scope and cannot be eager loaded or
  grouped through Active Record; the Section tree's scene counts come from one
  `group(:section_id).count`. `Relation#display_string` and `Ownership#display_string` fall back to
  their two endpoints, so a link record with its optional name still has a readable label in row
  actions, delete confirmations, and its details page.
- **[added]** Completed Epic 11 slice 11.4, Scene Tag taxonomy and assignment. Added the
  story-scoped `SceneTag` schema/model and constrained `scenes_scene_tags` join, registered the
  model and story-scoped routes, and exposed **Configuration → Tags → Story Tags → Scene tags** as
  a hierarchical, colored, JSON-mutation taxonomy workspace alongside Section tags. Scene Tag
  mutations reject non-JSON requests before the positioned service can commit a record.
- **[added]** Scene Details and the canonical Scenes list now show preloaded Scene Tag badges, and
  the single HTML Scene editor can assign or clear optional same-story tags without changing
  narrative position. Public read, private read/write/admin authorization, same-story validation,
  untagged title-only Scenes, and the existing taxonomy DOM/accessibility hardening are preserved.
- **[added]** Added model, request, authorization, routing, development-loader, helper, and focused
  browser coverage for the new taxonomy and assignment paths; updated the Scene architecture, data
  model, conventions, visual design, development guide, ADR execution note, and known-quirk boundary.
- **[added]** Completed Epic 11 slices 11.2 and 11.3, the Scene references and Section grouping
  work. A schema-only `AddSceneReferencesToScenes` migration added the optional `section_id`,
  `event_id`, and single-point `datetime` to `scenes` with real foreign keys, a `datetime` column
  using Event-compatible storage, and a `[story_id, section_id]` index beside the existing
  narrative-order index.
- **[added]** `Scene` now belongs to an optional `Section` (same Story) and an optional `Event`
  (same Universe). Same-Story and same-Universe scope is validated in the model, so a malformed
  `section_id`/`event_id` renders a documented `422` field error through the ordinary editor instead
  of a foreign-key `500`, and an unparseable in-world time is reported rather than being silently
  cast to `nil`; the editor re-renders the submitted value so a rejected entry is never cleared.
  The event link and the in-world time stay fully independent, and several Scenes may reference the
  same Event.
- **[added]** The Scene editor gained **Organization** and **In-world time** fieldsets (Section
  selector with **Ungrouped** and depth-indented Section paths, Event selector with **None**, and a
  `datetime-local` field) plus explicit copy separating narrative order from in-world time, and a
  URL-backed **Scene Details / Characters / Items / Locations** tab shell. The three not-yet-routable
  tabs render as `aria-disabled` placeholders, so no tab ever links to a route that does not exist.
  Scene Details is now the canonical inspectable page for the group, the linked event, and the
  formatted in-world time.
- **[added]** Section grouping shipped with two complementary paths, as ADR 0007 specifies: the
  Scene Details form assigns a Scene to **Ungrouped** or one Section, and the Sections workspace
  gained a **Grouped scenes** outline that keeps the existing taxonomy tree. One selector-driven
  form (`PATCH /u/:universe_slug/s/:story_id/scenes/group`) moves a Scene between Ungrouped, a
  Section, and another Section; the target is resolved through the current Story, so a foreign or
  unknown Section is a `404` and the flash always states that the narrative position did not change.
  Drag-and-drop is not offered, so the move works by keyboard and on touch.
- **[added]** `SectionPaths` builds every root-first Section ancestor path and the depth-indented
  selector options from one ordered query, so list pages never walk ancestors per Scene. The global
  Scenes list now labels each row with its nested Section path or an explicit **Ungrouped**
  indicator, and grouping provably never changes `position`.
- **[added]** Completed Epic 11 slice 11.1, the core Scene vertical slice: a schema-only `scenes`
  migration (real `story_id` foreign key, indexed `position`, `slug`) and `Scene` model with a
  required Title, optional short description, and no `parent_id`. A Story now owns its contiguous
  narrative-order Scenes, maintained transactionally in flat mode by `PositionedResourceOrder`
  with the Story as scope owner.
- **[added]** Added story-scoped Scene routes and `ScenesController` on the HTML redirect/re-render
  flow: the canonical `/u/:universe_slug/s/:story_id/scenes` list with narrative-position badges,
  short-description previews, a full add/edit/delete journey, the stable Scene editor shell
  (Scene Details is the canonical inspectable page and one shared `_form` is the only editor), and
  a member `move` action driven by keyboard- and touch-operable Move up/Move down controls that
  are disabled at the sequence boundaries. Section/Event/datetime, tags, Elements, and world links
  are intentionally not routed yet.
- **[added]** Populated the disposable LOTR development universe with world-building sample data so
  every content model is exercised: 7 characters and 8 character tags, 12 hierarchically nested
  locations and 6 location tags, 5 items and 5 item tags, 5 relations with symmetric/asymmetric
  relation tags, 5 ownerships with date ranges, and 6 events forming a chained timeline with event
  tags. Added loader coverage asserting the counts, tag and location parentage, ownership links,
  and the event chain.
- **[added]** Created this date-based `CHANGELOG.md` and added a standing rule to record every
  future code, site, data, test, documentation, configuration, security, and tooling change.
- **[added]** Implemented ADR 0008's registry-driven development universe loader: shared model
  order, strict YAML/file/reference/scope validation, normalized sibling positions, explicit
  `db:demo:check/load/reset` tasks, and common YAML data for Dark and LOTR.

- **[changed]** Moved **Configuration** out of the left workspace sidebar and into the right
  utility sidebar, which was renamed from **Settings** to match. **Tags** now opens the shared
  taxonomy workspace from the right column, beside the admin-only **Members** access manager, and
  the left column is left with the two universe/story scope blocks only. The right sidebar's
  **Universe tools** block became a real `sidebar-context--tools` scope header wearing the muted
  green `--um-scope-tools` pair, so all three scope blocks now read the same way; the section-header
  hue moved from a `.right-sidebar` container selector to the explicit `sidebar-section--tools`
  modifier already used for the other scopes. **Tags** is rendered unconditionally, so a guest or
  read-only member keeps the taxonomy entry while **Members** stays admin-only.
- **[changed]** Completed backlog item 21, the taxonomy editor's visual pass. A taxonomy row now
  carries only the name, the **Details** link, and one overflow menu holding Add child, Insert
  before/after, Move up, Move down, Edit, and Delete. Move up/Move down became disabled menu items
  at the sequence boundaries instead of row buttons, the name is sized to its own text so only
  hovering the name itself starts an inline rename, and the tree's first insert target no longer
  hangs over the hint paragraph. The reported "the tag disappears when I rename" behavior was not
  reproducible on the current tree (an inline rename sends only `name`, and the modal editor
  re-populates the tag selector from the record's own values), so it is now locked in by a
  permanent browser regression for both paths instead of a code change. The Stimulus controller's
  dead JavaScript copy of the row builder was removed, so the row layout has one owner.
- **[changed]** Completed backlog item 23. Placeholder navigation is flat disabled gray with no
  hover emphasis, matching its `aria-disabled` semantics. The universe page replaced the "Story
  collection" card with the universe's actual story list, each with an **Open** action, and keeps
  **All stories** in the header; the "Browse stories" button was removed because the list it led to
  is now on that page, and the page reuses the navbar's memoized story list so it adds no query and
  no `COUNT`. The left sidebar is now three scoped blocks — current universe context, Universe
  Bible, current story context, Story workspace, Configuration — where each context is followed by
  the section it introduces: universe blue, story muted crimson (deliberately not the danger red
  reserved for destructive actions), and Configuration plus the right utility sidebar green.
- **[changed]** `UniverseScopeResolver` is now the single answer to which universe owns a record;
  `Ability#universe_for` and `ApplicationHelper#universe_for_record` both delegate to it instead of
  duplicating the walk, and it resolves Scene-owned and Section-owned records through their owner.
  A model nested deeper defines its own `#universe` delegation.
- **[changed]** Deleting a Section or an Event now nullifies its Scene references instead of being
  silent about it, and the Story, Section, and Event delete confirmations use the mandatory ADR 0007
  consequence templates. Deleting a shared record still never removes a Scene.
- **[changed]** The shared tree accepts a per-node `confirm_message` and a `read_only_empty_description`,
  and the shared row actions accept a `confirm_text`, so destructive copy and read-only empty states
  come from the server. The Sections workspace read-only empty state no longer tells a read-only
  member to add or drag sections.
- **[changed]** `shared/_content_tabs` can render a tab without a destination as an `aria-disabled`
  placeholder, which keeps a workspace tab from becoming a dead link.
- **[changed]** The left-sidebar **Scenes** entry is now a real story-scoped link with its own
  cached count while a Story is selected, and stays an `aria-disabled` placeholder with the
  existing "select a story" prompt when no Story is current — it never falls back to the first
  Story. The story overview links to both Sections and Scenes.

- **[fixed]** Corrected the `UniverseDataLoaderTest` Dark story-name expectation to
  `Netflix Dark`. Commit `0a236a9` renamed the `dark` universe's development story to
  `Netflix Dark` (slug `netflix-dark`) in `db/data/dark/stories.yml` but asserted the lowercase
  `netflix dark`, so the full `bin/rails test` run had one standing failure since that commit. Only
  the assertion was wrong; the manifest name and slug were already correct and are unchanged.
- **[fixed]** Stopped `DevelopmentDataTasksTest` from calling `Rails.application.load_tasks` once
  per test. That call re-ran the Rakefile and re-loaded every bundled gem's rake files, and gem
  rake files are not idempotent, so each parallel `bin/rails test` worker re-defined
  `Cssbundling::Tasks::LOCK_FILES` and printed `already initialized constant` warnings. The test
  now loads only this application's own `lib/tasks/*.rake`, memoized once per process, which still
  registers `db:demo:check`, `db:demo:load`, and `db:demo:reset`. `bin/rails test` output is now
  warning-free; the registered task set and every assertion are unchanged.
- **[fixed]** `MaintainsSiblingPositions` no longer assumes a `parent_id`: flat sequences omit the
  ordering parent entirely, so a parentless flat record works through the shared service.
- **[fixed]** Gave `Story` two separate sidebar count cache entries. `menu_scene_count` uses its own
  `cache_scope`, so adding a second scalar metric can no longer overwrite the section count;
  `InvalidatesMenuCounts` takes an optional `cache_scope:` for exactly this case.
- **[fixed]** Added ADR 0009 and `PositionedResourceOrder`: positioned controller mutations now
  maintain hierarchical and explicitly flat sequences transactionally across create, move,
  reparent, and destroy, with focused service/controller tests and flat development-data metadata.
- **[fixed]** Completed backlog items 12 and 13: taxonomy parent/tag options and counts no longer
  remain stale, boundary insertion uses the actual list, native rename supports Enter/Space, and
  Move/Insert controls plus touch-visible targets provide non-drag editing. Added ADRs 0010 and
  focused keyboard/touch/system regressions.
- **[fixed]** Hardened event temporal references with same-universe validation, model and database
  self-reference checks, and safe cleanup when referenced events are deleted.
- **[fixed]** Hardened the development loader after review: reset tasks guard before any drop,
  environment overrides are test-only, association types/targets are validated, file/position
  contracts are strict, and incomplete schemas can be repaired by the reset path.

- **[security]** Registered `Scene` in the `Ability` content registry; Scenes resolve their Universe
  through `scene.story.universe`, so public read stays open to guests while every mutation still
  requires the shared universe read/write/admin policy. Cross-scope story/scene lookups return 404.
- **[security]** Removed `.kamal/secrets` from Git tracking, added an ignore rule and CI guard,
  restricted the preserved local file to mode `0600`, and documented that master-key rotation and
  history cleanup remain owner actions. The secret value was not read or changed.
- **[security]** Redacted password-reset tokens from Rails request paths, added no-store/no-referrer
  reset headers, strong-parameter validation, and regression coverage for blank resets and rendered
  multipart mail.
- **[security]** Made production mail/URL/SMTP settings explicit and fail-closed, enabled HTTPS
  redirects/HSTS behavior, restricted the production host allowlist, and marked the session cookie
  `Secure`; added mailer, cookie, and production-configuration coverage.
- **[security]** Rebuilt taxonomy dynamic fields and nodes with DOM APIs instead of `innerHTML`,
  added hostile-name browser coverage, and refreshed server-rendered taxonomy state after every
  successful mutation.
- **[security]** Added machine-readable Tom Select version metadata to the local importmap pin and a
  regression test, so `bin/importmap audit` includes Tom Select 2.6.2 instead of skipping it.
  Complete Bun/npm graph, vendored-file provenance, and Dependabot coverage remain separate follow-up
  work.
- **[security]** Hardened the authentication and request lifecycle: stale authentication cookies
  are invalidated, remembered story context is cleared at account boundaries, and password resets
  safely invalidate the current browser session.
- **[security]** Made the universe visibility flag explicit and non-null, centralized
  public/private read-write-admin authorization, and enforced same-universe/same-story scope on
  tag associations and reads. Private-universe non-members now receive the same 404 response as
  an unknown universe.
- **[security]** Removed development data from `db:seed`/`db:prepare` and added environment and
  confirmation guards to destructive development database tasks; CI now validates checked-in data
  manifests instead of replanting demo records.

- **[docs]** Updated the architecture, conventions, visual design, and development docs for the
  sidebar move: the left workspace sidebar is two universe/story scope blocks, and the right
  utility sidebar is the tools scope with a green **Universe tools** context block followed by
  **Configuration** (Tags plus the admin Members manager) and the reserved Collaboration,
  Analytics, and AI groups. The two left context blocks now state only their scope and the current
  name, so the docs no longer promise a visibility/access/story-count line under the universe name
  or section/scene counts and a description under the story name; those facts live on the navbar
  and the story's own pages.
- **[docs]** Separated consecutive date sections with a blank line, so every `##` heading is
  surrounded by one. The regrouped layout had left a date's last entry flush against the next
  heading; the blank-line rule is now "between label groups and between dates, never inside a
  group".
- **[docs]** Regularized this file's layout: entries inside a date are now grouped by label in the
  legend order, and the only blank line inside a date is the one between two label groups. The
  earlier free-floating blank lines existed solely under 2026-09-25, where they separated work
  batches (epic slices) rather than anything structural, and one of them was doubled by accident.
  All 106 entries were reordered only; no entry text, date, or label was changed.
- **[docs]** Removed the completed backlog item for the explicit development universe-data loader
  after verifying the delivered state: `Development::UniverseDataRegistry`/`UniverseDataLoader`,
  the guarded `db:demo:check/load/reset` tasks, and YAML-only `db/data/dark` and `db/data/lotr`
  manifests, whose `db:demo:check` runs both pass. Remaining backlog numbers were intentionally
  left unchanged, and the two internal "backlog item 1" references in the Scene slices now cite
  [ADR 0008](adr/0008-explicit-development-universe-loader.md) directly. No application code,
  schema, or data changed.
- **[docs]** Updated the architecture, data model, conventions, visual design, and development docs
  for the two slices, marked backlog items 11.2 and 11.3 complete, and refreshed the known-quirk
  entries for optional-reference errors and ownership-scope resolution.
- **[docs]** Made the demo-YAML lifecycle explicit across contributor and agent guidance: every
  add/delete/update under `db/data/**/*.yml` must be validated and followed by a local development
  database reset (plus create-only loads for any additional universes wanted locally). YAML is the
  source of truth, UI-only records are intentionally discarded, and loaded rows must be verified
  before demo data is reported as available.
- **[docs]** Distilled the 2026-09-25 DataFactor report into the agent guide, a durable quality
  guidance document, ADR 0006, focused backlog items, and verified follow-up quirks. The guidance
  keeps the report directional, reconciles stale health/lockfile signals, prioritizes real tested
  work over score gaming, makes security, privacy, and development-data boundaries explicit, and
  clarifies the destructive `db:restart` warning in the root README.
- **[docs]** Completed Epic 11 slice 11.0 as a documentation-only decision: ADR 0007 fixes
  story-owned narrative ordering, the Scene/Scene Element field contract, independent Event/time
  references, URL-backed workspace and JSON/HTML response boundaries, Section grouping, and the
  detailed deletion confirmations. No Scene schema, routes, controllers, views, fixtures, or demo
  data were added.
- **[docs]** Clarified the slice 11.0 review findings: Scene uses one Event-compatible datetime
  point, shared-record deletion copy now discloses existing dependent destroys, Scene destroy is
  explicitly HTML, and flat ordering must extend the existing positioned-controller concern rather
  than bypass it.

- **[chore]** Added a focused browser test for the sidebar scope hues: each context block must
  share the computed background of the section it introduces, the three scopes must stay
  visually distinct, and the right utility sidebar's context must be the greenish one. The
  navigation and workspace-tab integration tests now look for **Tags** in the right sidebar,
  including a guest case that keeps **Tags** while **Members** stays admin-only, and the record
  details browser test asserts each left context block by its scope label and current name instead
  of by the removed counts and description.
- **[chore]** Added model, request, routing-independent, and focused browser coverage for the new
  details pages, the Details links and their counts, `TaggedRecordCounts`, `tagged_records`, and
  the sidebar structure; updated the architecture, conventions, visual design, data model,
  known-quirk annotations, and backlog entries. The taxonomy system tests now wait for Stimulus's
  `stimulus-loading` readiness signal before clicking, instead of racing the connection.
- **[chore]** Added Scene Tag fixtures and connected nested/tagged/untagged Dark and LOTR
  development data, updated the shared loader registry, and verified both `db:demo:check` manifests.
- **[chore]** `Development::UniverseDataRegistry` loads `Scene` after `Event` so a Scene can reference
  a shared universe event, and the loader proves a Scene's Section belongs to the same story before
  writing. `db/data/dark/scenes.yml` and `db/data/lotr/scenes.yml` now exercise grouped, ungrouped,
  event-only, datetime-only, and shared-event Scenes, and the local development database was rebuilt
  and verified.
- **[chore]** Documented that editing an applied migration silently does nothing on a fresh
  database in this project: Rails 8.1's `initialize_database` loads `db/schema.rb` when the database
  has no `schema_migrations` table, so the Scene references needed a new migration. The finding and
  its consequence are recorded in `known_quirks.md` and `development.md`.
- **[chore]** Renamed the main development story in the `dark` universe to `netflix dark` (slug
  `netflix-dark`) and updated every story-scoped YAML reference so the universe and story are
  distinct in the UI.
- **[chore]** Added `scenes.yml` development data for the Dark (8 scenes) and LOTR (5 scenes)
  universes, including a title-only scene and explicit narrative positions, registered `Scene` as
  a flat story-scoped position group in the development-data registry, and added scene fixtures.
- **[chore]** Added model, request, routing, ability, menu-count, ordering-service, and browser
  coverage for the slice, and updated the architecture, data model, conventions, visual design,
  development, backlog, and known-quirks documentation.

- **[planned]** Documented the Epic 11 Scenes domain model, UX contract, delivery slices, tests,
  and development-data requirements in the shared backlog; the feature is not implemented yet.
- **[planned]** Kept the newly recorded soft-delete/recycle-bin idea as later work; it is not part
  of slice 11.0 and requires a separate persistence, restore, authorization, and relation-tracking
  decision before implementation.

### 2026-09-24

- **[added]** Added the initial browser system-test suite for sign-in/sign-out, universes and
  stories, story-scoped sections, character creation, and timeline navigation; CI now runs these
  tests and preserves failure screenshots.

- **[changed]** Refreshed the Bootstrap visual system and application shell with shared theme
  tokens, page headers, content surfaces, empty states, flash messages, row actions, taxonomy
  styling, and responsive layout improvements.
- **[changed]** Reorganized navigation into a clearer top bar, Universe Bible sidebar,
  Configuration/Tags area, Settings panel, and URL-backed workspace tabs for related records.

- **[fixed]** Made story URLs consistently use the short `/s/:id` shape and required explicit
  story scope for section and section-tag URLs; added a test guard against positional
  universe-scoped route-helper arguments.
- **[fixed]** Corrected event title/name/slug synchronization and restored predictable generated
  slugs for renamed records and relation/ownership composites.
- **[fixed]** Prevented story selections from surviving logout, account changes, password resets,
  or stale sessions; added universe-name validation and access-aware navigation/actions.
- **[fixed]** Normalized fixture slugs, corrected a visibility helper, and expanded regression
  coverage for routing, navigation, authentication, authorization, and workspace flows.

- **[security]** Added universe memberships with read, write, and admin levels, public/private
  universe visibility, authorization for all universe- and story-scoped content, and an admin-only
  membership manager.

- **[docs]** Added the agent guide, vision, ADRs, architecture/data-model/conventions/development
  references, known and resolved quirk records, and the shared backlog; removed vestigial code and
  refreshed the project README.

- **[chore]** Made migrations schema-only and consolidated the current schema history; expanded
  per-universe development data under `db/data/` and documented the disposable-data boundary.
- **[chore]** Repaired the GitHub Actions workflow, pinned reproducible Bun installs, and made
  Chrome/system-test setup and teardown more reliable.

### 2026-09-23

- **[added]** Added the project vision document and expanded the architecture, data-model, and
  development documentation around the new universe/story boundaries.

- **[changed]** Completed the multi-story Universe model: Universe is the top-level container,
  world-building records are shared at universe scope, and stories are selected and remembered
  explicitly rather than falling back to the first story.
- **[changed]** Made sections and section tags story-scoped, added the nested story routes, and
  tightened cross-story hierarchy and tag validation.
- **[changed]** Added Universe and Story context/switchers to the top bar and improved navigation
  for both the universe overview and story workspaces.
- **[changed]** Made tags optional on every content model and removed default-tag creation and
  required-tag validation so untagged records remain valid.

- **[fixed]** Repaired section-tag associations and data loaders after moving them under stories.
- **[fixed]** Cached sidebar entity counts and invalidated them after relevant committed writes,
  eliminating repeated count queries on every page.
- **[fixed]** Repaired taxonomy and navigation tests after the scope and naming changes.

- **[chore]** Consolidated migrations into schema-only create migrations, refreshed fixtures and
  tests, normalized the project to Bun, and made demo data available through universe directories.

### 2026-09-22

- **[changed]** Replaced the early per-content “type” taxonomies with hierarchical tags and
  standardized content-to-taxonomy links as many-to-many associations, updating models,
  controllers, views, routes, fixtures, migrations, and demo data together.
- **[changed]** Refined the left navigation and sidebar presentation as the taxonomy workspaces
  expanded.

### 2026-09-21

- **[changed]** Improved the sidebar and universe/story menu structure, labels, and visual
  presentation in preparation for the larger workspace redesign.

### 2026-09-15

- **[fixed]** Adjusted the application route shape to keep the new universe scope consistent
  across navigation and resource URLs.

### 2026-09-14

- **[changed]** Replaced the original Story-centered root with a Universe-centered domain across
  controllers, models, routes, views, deployment metadata, demo data, tests, and documentation.
- **[changed]** Added more navigation options while the top-level universe model was introduced.

### 2026-09-12

- **[added]** Added foreground-color support to taxonomy tags and the relevant editor/badge UI.

- **[changed]** Expanded the Dark development dataset and moved its seed records toward YAML files
  with ordered loaders and symbolic references for sections, content, taxonomies, relations, and
  ownerships.

- **[fixed]** Updated test fixtures and expectations to match the expanded YAML-backed data.

- **[chore]** Added and refreshed frontend dependency locks, fixtures, and tests during the data
  migration; the temporary Yarn setup was later replaced by the project-wide Bun standard.

### 2026-09-11

- **[added]** Made the Timeline functional with event layout, edges, popovers, and an interactive
  timeline controller.

- **[changed]** Added taxonomy colors, many-to-many element/taxonomy support, Tom Select pillbox
  multi-selects, slugs across models, and a refactored per-universe seed-data layout.
- **[changed]** Improved the left menu and interactive editors as the world-building workspaces
  became more complete.

- **[docs]** Added the Mozilla Public License 2.0 to the project.

### 2026-09-10

- **[added]** Added the first Event and Timeline models, routes, views, layout algorithm, and
  timeline styling.
- **[added]** Added entity counts to the navigation menus.

### 2026-09-09

- **[changed]** Refactored routes and the character workspace, improved the complete character
  view, and refreshed visual navigation and menus.

- **[fixed]** Repaired ownership persistence and taxonomy drag-and-drop behavior.
- **[fixed]** Corrected data/controller integration issues found while expanding the content
  workspaces.

### 2026-09-07

- **[added]** Added Ownerships and Ownership Types, including their controllers, views, routes,
  schema, fixtures, navigation entries, and tests.

### 2026-09-05

- **[changed]** Added conventional list/modal views for Characters and Items and improved the
  surrounding menu.

### 2026-09-04

- **[added]** Added Locations, Items, Characters, and Relations, together with their first taxonomy
  models, schema, controllers, views, routes, fixtures, and navigation.

- **[changed]** Organized migrations and taxonomy nodes, and made taxonomy selection required in
  the early content workflow (this was later relaxed when tags became optional everywhere).
- **[changed]** Improved menus and visual consistency across the growing workspace.

- **[fixed]** Repaired item persistence, taxonomy drag-and-drop, and associated tests.

### 2026-09-03

- **[added]** Added Sections and made Sections work as a taxonomy, completing and hardening the
  tree-based taxonomy editor.

- **[changed]** Improved seed data, test coverage, and menu organization around the new section
  hierarchy.

### 2026-09-02

- **[added]** Added Section Types and the first interactive taxonomy-tree editor.

- **[fixed]** Corrected route generation and the right-sidebar presentation.

### 2026-09-01

- **[added]** Established the Rails 8 application foundation with SQLite, Solid Cache/Queue/Cable,
  Docker/Kamal deployment files, CI/security tooling, Bootstrap, Sass/PostCSS, and the initial
  development workflow.
- **[added]** Added Users, Sessions, Stories, password reset, sign-in/sign-out, and the first
  Story CRUD workspace.

- **[changed]** Added story slugs, initial Dark/LOTR seed data, and the initial navigation shell.

## Resolved quirks and tech debt

### Quirk 12: sessions had no expiry or source binding (fixed)

**Then:** a session row recorded who it belonged to and which client created it, and nothing about
when it would end. The finding was recorded as Medium and named four symptoms:

- Sign-in created a **permanent** cookie while the row it named had no deadline, so a stolen session
  cookie stayed usable until the owner signed out, reset their password, or was deleted. The cookie
  outliving the row was the norm rather than an edge case: a permanent cookie lives about twenty
  years.
- The `sessions` table had **no expiry or last-used field**, so nothing could tell an abandoned
  session from an active one.
- Lookup **validated neither the recorded IP address nor the user agent**, even though both were
  being written.
- Old rows had **no cleanup path at all**, so the table grew without bound.

**Fix:** two columns, `expires_at` and `last_used_at`, with the policy on the `Session` model
(`IDLE_TIMEOUT` two weeks, `ABSOLUTE_TIMEOUT` one year, `LAST_USED_REFRESH_INTERVAL` one hour). The
two limits answer two different questions and were kept as two different kinds of rule: the idle
limit is measured from `last_used_at` and moves with use, the absolute limit is measured from
creation and never moves, so no amount of activity can push it back. `last_used_at` is refreshed on a
coarse interval rather than per request, because a timestamp written on every page view would make
each request a write for a precision nobody can observe. The cookie now carries `expires_at` as its
expiry instead of being permanent, so the browser stops presenting a credential the server has
already stopped honouring. A refused session is destroyed rather than merely ignored, and
`PurgeExpiredSessionsJob` removes dead rows on a daily schedule — which nothing depends on, since an
expired session is refused on its next request whether or not its row exists.

**The binding decision was the owner's, and it is the part worth recording.** The obvious fix binds a
session to both the IP address and the user agent, and the IP half is a trap: an address identifies a
**network**, not a person. Mobile connections change it routinely, a VPN changes it on every
reconnect, office and home networks differ, and a corporate proxy puts several people behind one
address. Binding to it would sign out legitimate readers at the moments they least expect it, and the
failure would look like a broken application rather than a security decision. The user agent is the
part of "source" that actually differs when a cookie is replayed somewhere else, so the session is
bound to it and the address is recorded for diagnostics only. A request test changes the stored
address and asserts the session survives, so the intent cannot be quietly reversed later.

Two things the original finding did not name turned out to matter:

- **`ApplicationCable::Connection` resolves sessions outside the controller's authentication
  concern.** Without applying the same two checks there, a websocket opened with a cookie the
  request path would already have refused would still be accepted, and the request-time checks would
  be theatre.
- **A row with no recorded user agent, or no recorded lifetime, is left alone.** It cannot be
  checked, and refusing to match a missing value against a present one would end sessions for a
  reason that has nothing to do with the client presenting them. This is why both columns are
  nullable and why the migration sets no default: a schema change must not sign everybody out.

See [ADR 0018](adr/0018-session-lifetime-and-user-agent-binding.md).

**Resolved vestigial code**

### `ApplicationController#default_url_options` was a no-op (fixed)

**Then:** `ApplicationController` overrode `default_url_options` and called `super.merge()` with no
options, while the universe slug was supplied by Rails request recall.

**Fix:** the redundant override was removed. URL helpers continue to use the standard Rails
behavior and request recall; no application-specific `universe_slug` option is needed.

### Unused Hello Stimulus controller (fixed)

**Then:** `app/javascript/controllers/hello_controller.js` was an untouched Rails scaffold
controller. No view or application code used it; the import map's controller glob only made the
unused file discoverable.

**Fix:** the controller was deleted. The Stimulus eager loader now registers only the controllers
used by the application.

### Vestigial current-universe path wrappers (fixed)

**Then:** `SectionsController` and the section/event tag controllers carried private
`current_universe_*_path` wrappers. The plural wrappers were unused, and the singular wrappers
only forwarded to route helpers used to build JSON URLs.

**Fix:** the wrappers were removed. JSON responses now call the appropriate route helper directly,
so URL behavior is unchanged without the dead indirection.

### Root README was Rails scaffold boilerplate (fixed)

**Then:** the root `README.md` still contained the generated Rails placeholder, leaving no useful
entry point for the project.

**Fix:** the root README now provides a concise project overview, quick start, test commands, and
links to the detailed documentation in `docs/`, which remains the source of truth.

### Former quirk #54: taxonomy field-builder duplication (fixed)

**Then:** `app/helpers/modal_fields.rb` held eight near-identical `*_tag_taxonomy_fields` helpers and
`app/helpers/tags_helper.rb` held eight near-identical workspace-config blocks, so adding one field or
URL to every taxonomy meant editing eight copies that could drift from each other and from the routes.
The DataFactor report flagged the duplication as a maintenance drift risk rather than a correctness
finding.

**Fix:** the shared editor fields are now built by `ModalFields#taxonomy_tag_fields` (every taxonomy)
and `ModalFields#content_tag_taxonomy_fields` (the four content tags, which add `show_in_menu`), with
`extra_fields` for the relation tag's `symmetric`/`inverse`. The workspace config is declarative
`TagsHelper` metadata (`UNIVERSE_TAG_METADATA`/`STORY_TAG_METADATA`) with the mechanical keys —
`model_param`, the field-descriptor helper, the tag URLs, the count label — derived from the type name.
Adding a field to every taxonomy is now a change in one helper. The serialized field/JSON contract and
the three UI patterns are unchanged, and the extraction is what let `taggable` and `show_in_menu` land
in one place per helper.

**Resolved conventions**

### Positional path-helper arguments in universe routes (resolved as an enforced convention)

**Then:** `universe_story_sections_path(story)` looks like a natural nested-resource call, but
Rails assigns positional arguments to dynamic segments from left to right. The Story is therefore
assigned to `universe_slug`; outside request recall this raises a missing-`story_id` error, and in
some scoped requests it can silently produce a URL with the wrong universe segment.

**Resolution:** the route shape remains explicit (`/u/:universe_slug/s/:story_id/...`) and all
universe-scoped route-helper calls use named keys. `test/routing/universe_route_helper_arguments_test.rb`
parses Ruby and ERB sources and fails CI if an application or test call supplies positional
arguments to a `universe_*_path`/`universe_*_url` helper. Rails still permits positional arguments
in its generic API; this project-level guard prevents that footgun in its own code.

**Resolved correctness issues**

### Former quirks #1–#3: Universe authorization and public/private access (fixed)

**Then:** `Ability` was unused and its universe rule referenced the nonexistent `user_id` column.
Universe-scoped controllers had no authorization callback, and `UniversesController` allowed
anonymous access to every universe action. `private: true` therefore hid a universe from the index
but did not protect its slug URL, and anonymous creation fell back to `User.first`.

**Resolution:** Universe Maker now has an explicit three-level access policy. `UniverseMembership`
stores read/write/admin membership for private universes and optional delegated public admins;
the owner is always admin. `Ability` defines the same rules for universes and every universe- or
story-scoped content class, and `UniverseAuthorization` applies them after resolving the universe
but before loading stories or content. Public universes allow guest read and signed-in write;
private universes allow only owners/members, with 404 for every non-member (including guests) and
403 for insufficient collaborator access. Guests attempting public-universe mutations are
redirected to sign in. The membership manager is available to universe admins at
`/u/:universe_slug/members`.

### Former quirk #6: nullable universe visibility failed open (fixed)

**Then:** `universes.private` allowed NULL and the policy treated NULL like false. A hidden universe
could therefore be readable by guests and writable by any signed-in user when reached directly by
slug.

**Resolution:** `Universe` now requires an explicit boolean, only an explicit `false` grants the
public baseline, and any ambiguous legacy value is handled as private by the policy. A schema-only
migration makes the column `NOT NULL`; it deliberately refuses to guess whether an existing NULL
row was public or private, so an older database must have those rows resolved explicitly before
migration. Tests cover validation, the database constraint, and fail-closed instance policy.

### Former quirk #7: HABTM tags could cross universe/story scope (fixed)

**Then:** all seven content/tag HABTM associations were unscoped. Four content models had no
same-scope validation at all, the other three validated only the content-to-tag direction, and
crafted `*_tag_ids` parameters could attach a private-universe tag to public content. Unscoped
inverse reads could also disclose corrupt foreign rows.

**Resolution:** every `HasManyTags` declaration now requires an explicit `:universe_id` or
`:story_id` scope. The concern applies that scope to both association directions and validates the
in-memory target so ID writers and inverse assignments fail normal model/controller saves with a
422 contract. Corrupt foreign join rows are hidden by scoped reads; the separate lack of database
join constraints remains tracked in the open quirks.

### Former quirk #13: anonymous private-universe enumeration (fixed)

**Then:** an unknown slug returned 404, but a guest request for an existing private universe was
redirected to sign-in. The different response disclosed that the slug existed.

**Resolution:** the shared `UniverseAuthorization` concern now converts every private-universe
read denial to the same 404 used for an unknown slug, before any story or content lookup. Public
guest reads remain public, and public guest mutations still use the normal sign-in redirect.

### Former quirk #14: story context survived authentication boundaries (fixed)

**Then:** the Rails session's `current_story_ids` map survived logout, account switching, current-user
password reset, and stale database sessions. A later account on the same browser could inherit a
story selection.

**Resolution:** authentication start, logout, current-user password reset, and stale-cookie handling
now clear the complete remembered-story map. They also remove invalid authentication cookies and
reset `Current.session` where appropriate. Tests preserve ordinary same-session story memory while
covering logout, direct account switching, reset, and stale-session cleanup.

### Former quirk #15: referenced events caused foreign-key 500s (fixed)

**Then:** restrictive self-foreign keys made `destroy!` fail when another event referenced the target
through `before_event`, `after_event`, or `simultaneous_event`. Universe destruction could fail for
the same reason. The self-reference validator compared only foreign-key IDs, so an unsaved event
could evade it.

**Resolution:** `Event` now declares all three incoming reference collections with
`dependent: :nullify`, so normal event and universe destruction releases references before deleting
the target. A referrer that existed only to point at the deleted event is removed first, preserving
`must_be_identifiable` for every retained row. `cannot_reference_self` checks both object identity
and the foreign-key id, while three schema-only check constraints close the insert-time gap where
SQLite assigns the new ID only during the write. Model and request tests cover every reference
direction, relation-only cleanup, universe destruction, unsaved/future-ID self-links, and direct
database writes.

### Universe-scoped content was not authorized (fixed)

**Then:** every content controller only scoped records with `Current.universe`; knowing a universe
slug was enough to read or mutate its content.

**Resolution:** all universe-scoped controllers now pass through the shared universe authorization
callback, and their existing association scopes preserve the universe/story boundary. The
`Ability` object also checks the corresponding content instances, so a permission granted for a
universe applies consistently to all of its components.

### Private universes were readable and mutable by slug (fixed)

**Then:** private universes were excluded from listings but `universes#show`, content routes, and
mutations did not apply visibility, and anonymous universe creation selected the first user as
owner.

**Resolution:** `Universe.visible_to` includes explicit memberships, `set_universe` uses
`find_by!`, private show/content requests pass through the shared policy, and universe creation
requires a real signed-in `Current.user` as owner. Public/private visibility is editable only by a
universe admin.

### `ApplicationHelper#visible?` always returned `true` (fixed)

**Then:** `ApplicationHelper#visible?` (`app/helpers/application_helper.rb`) computed the
controller comparison and discarded it, then returned literal `true`. The redesigned sidebar did
not call the helper, so the bug did not affect current navigation, but it made the helper unsafe
for future visibility decisions.

**Fix:** the stray test-only `true` was removed. The helper now returns the result of
`controllers.include?(controller.controller_name)`.

### HasSlug treated generated slugs as explicit on updates (fixed)

**Then:** `HasSlug#set_slug` checked `slug.present?` before checking whether `name` changed. Every
persisted record normally has a slug, so renaming any model normalized and preserved its old slug;
the `name_changed?` regeneration branch was effectively unreachable. This affected all models
that include `HasSlug`.

**Fix:** the callback now uses Rails 8 dirty tracking. A slug explicitly changed on the current save
wins; otherwise a changed name regenerates the slug; unrelated saves preserve the existing slug.
Unslugifiable values receive a random fallback so the non-null database constraint is respected.

### Relation/Ownership composite slugs were bypassed by HasSlug (fixed)

**Then:** `Relation` and `Ownership` registered their composite-slug callbacks after
`HasSlug#set_slug`. For unnamed records, the generic callback assigned a random slug first, so the
intended `character-tag-character` / `character-tag-item` slug was usually never generated.

**Fix:** both callbacks now run with `prepend: true`, before the generic `HasSlug` callback. Omitted
and blank names produce the documented composite slug, untagged records omit the optional tag
segment, and an explicitly supplied slug still wins for that save. Composite slugs remain
creation-time snapshots when endpoints or tags change; a name change follows the normal
name-based slug rule.

### Event name drifted when its title was renamed (fixed)

**Then:** `Event#set_name` ran only on create, so changing an event's `title` left the legacy
`name` field at its original value. `HasSlug` also ran before `set_name` during creation, which
could make a new event receive a random slug instead of one derived from its title.

**Fix:** `set_name` now runs before `HasSlug` on create and whenever the title changes. The title is
copied to `name`, and `HasSlug` regenerates the slug when that name changes.

### Former quirk #26: a duplicate universe name raised an uncaught uniqueness exception (fixed)

**Then:** a universe's slug is its public address (`/u/<slug>`) and is global, and `HasSlug`
derives it from the name. Two universes whose names slugify alike therefore collide — as does a
name that happens to derive an address another universe already holds. `universes.slug` carries a
partial unique index, but `Universe` validated nothing about it, so `UniversesController#create`
and `#update` let the index raise `ActiveRecord::RecordNotUnique` out of an ordinary save and the
author got a `500` instead of a stated reason. The form offered no way out either: it accepted no
slug, so the only recovery was to invent a different universe name.

**Fix:** `Universe` validates `slug` uniqueness with the same `deleted_at IS NULL` condition the
index uses (as `Story` already did for its own partial index), so a taken address is an ordinary
`:slug` field error — a `422` that renders in the shared error summary, or the documented `422`
error hash in the JSON contract — instead of a driver exception. The universe form gained an
optional **Address slug** field so the collision is answerable without renaming the world, and
`universes_controller`'s strong parameters accept it.

**The field is blank on both forms, and that is the whole point.** `HasSlug` already gives an
explicitly supplied slug priority for the save on which it is supplied, so a filled field republishes
the universe where the author asked, while a blank one leaves the callback to derive the address
from the name. The alternative — prefilling the field with the current address — would have shown a
value that the callback silently replaces on a rename, and forwarding the blank field as a cleared
attribute would have been worse: `HasSlug` would regenerate the slug from the name on an
*unrelated* save, so ticking **Private universe** would republish the universe under a new address
and invalidate every path stored below it. A blank slug is therefore dropped in
`universe_params` and the attribute is never assigned, and a request test pins that behaviour. A
refused save is the one case that shows a value: the form keeps the address the author typed, since
this field is the answer to the error being shown, and discards a derived one it never received.

### CI system-test job had no tests (fixed)

**Then:** the CI workflow ran `test:system`, but the repository had no `test/system` directory.
The command had no browser tests to execute (and could not load the missing test directory), so it
could not provide browser-level coverage and the screenshot artifact had nothing to capture.

**Fix:** added `test/application_system_test_case.rb` and an initial system-test suite covering
sign-in/sign-out, universe and story creation, story-scoped section navigation, character creation
through the modal editor, and workspace navigation to the timeline. The existing CI job now runs
real browser tests and retains its failure screenshots.

### System tests reused Chrome profile state (fixed)

**Then:** system tests reused one browser process across cases. Chrome's password/autofill state could
survive the Capybara session reset and intermittently clear the sign-in fields, producing a failure at
the intermediate email-field assertion.

**Fix:** `ApplicationSystemTestCase` now quits the browser after each test, before Capybara resets
its session pool. Each case starts with a fresh Chrome profile while preserving the normal Rails
screenshot teardown order.

### Building on an association leaked unsaved records into views (fixed)

**Then:** `Current.universe.stories.new(...)` added the new, unsaved `Story` to the `has_many`
association's in-memory target. A view that iterated the association during the same request could
encounter the object with `id: nil` and fail while generating a story URL.

**Fix:** `StoriesController` now builds the form object with
`Story.new(universe: Current.universe)` in both `new` and `create`, assigning the parent without
mutating `Current.universe.stories`. A controller regression test loads the association and verifies
that the unsaved form object is absent from its target.

### Sections URL did not make the story scope explicit (fixed)

**Then:** the story-scoped sections refactor left the universe-level `/u/:universe_slug/sections`
path as a dead end, while the replacement used the verbose `/stories/:story_id` segment.

**Fix:** stories are mounted at the short `/s` path, and sections and section tags are available
only at explicit story-scoped URLs such as `/u/:universe_slug/s/:story_id/sections`. The
universe-level sections URL is intentionally not routed; no compatibility alias is provided.

### Sidebar issued COUNT queries on every page (fixed)

**Then:** the left sidebar called `.count` for sections, characters, relations, locations, events,
items, and ownerships on every rendered page. A selected story therefore caused seven database
count queries on every request, even though the values changed only when content changed.

**Fix:** `Universe#menu_counts` now stores all six universe-level values together in one
`Rails.cache` entry, while `Story#menu_section_count` stores the selected story's value in a second
entry. `InvalidatesMenuCounts` expires the affected entry from model `after_commit` callbacks when
a counted record is created or destroyed (and when a record moves to another scope), so controller,
seed, console, and dependent-destroy writes all stay correct. It tracks every intermediate scope
during a multi-save transaction, and cache misses inside open transactions are never written, so
rollbacks cannot leave stale data. Owner destruction removes its own entry, `db:restart` clears the
cache after recreating the database, and a one-hour expiry is a safety net for rare cache-fill races
or maintenance writes that bypass callbacks. Production continues to use the existing Solid Cache
store; Redis is not required.

### Default-tag assignment crashed on tagless universes (fixed)

**Then:** `CharactersController#create` (and the location/item equivalents) did
`...character_tags.order(:id).first.id if ids.empty?` — a `NoMethodError` on `nil` when the
universe had no tags yet (tag fixtures/seeds normally prevented this), and it force-tagged
records the user had deliberately left untagged. `SectionsController#create` used
`Story#default_section_tag`, which lazily created a tag named *"Section"*.

**Fix:** tags became optional on every content model, so all default-tag fallbacks were removed
and `Story#default_section_tag` was deleted as dead code. Creating a record without tags simply
saves it untagged — a tagless universe (or story) is now a normal state, not a crash.

### Two lockfiles and a mismatched CSS watcher (fixed)

**Then:** `bun.lock` and `yarn.lock` coexisted, while `package.json` and the Rails CSS build used
Bun. `Procfile.dev` still launched the watcher with `yarn watch:css`, creating two possible package
managers and requiring Yarn for a workflow whose actual build commands call Bun.

**Fix:** Bun is now the only JavaScript package manager. `yarn.lock` was removed, `Procfile.dev`
uses `bun run watch:css`, Bun is pinned in `mise.toml`, and the development documentation names
`bun.lock` as the source of truth. CI and the Docker build install the pinned Bun version and use
`bun install --frozen-lockfile` in reproducible environments.

### Universes could be saved without a name (fixed)

**Then:** `Universe` had no validations, so a missing or blank name passed validation even
though other named records rejected it.

**Fix:** `Universe` now validates that `name` is present. Model and request tests cover the
validation and reject universe creation without a name; the existing form error handling renders
the validation message.

### Migrations mixed schema changes with application-data work (fixed)

**Then:** two later migrations backfilled and copied live records when moving sections and section
tags under stories. Those migrations referenced application models (`Story`, `Section`, and
`SectionTag`), so old migrations could break when model code changed. The database also had a
multi-step schema history rather than one current definition per model.

**Fix:** database data is disposable and is reconstructed from `db/data/`, so migrations are now
schema-only and the history is consolidated into one create migration per persisted model. The
story slug and the `story_id` foreign keys are defined directly in the corresponding create
migrations; the record-copying migrations were removed. Existing databases must be recreated with
`bin/rails db:restart`, which migrates the schema and then reloads `db/data/` through `db:seed`.
This historical workflow was later replaced by [ADR 0008](adr/0008-explicit-development-universe-loader.md):
`db:restart` is now schema-only and `db:demo:reset` is the explicit data-loading reset.

### Deleting a section tag silently un-tagged its sections (fixed, in two steps)

**Then:** section tags were universe-wide while sections were story-scoped, so a tag could be
deleted even though stories still referenced it.

**Fix, step 1 (scoping):** tags belong to a story — the `CreateSectionTags` migration defines
`story_id` directly, plus a `Section` validation that all `section_tags` share the section's story.
A tag can no longer be deleted from under *another* story.

**What remained:** deleting a tag still dropped the join rows of its own story, and the
affected sections only noticed at their **next save** (`section_tags` presence validation) —
a deferred, silent failure. The same applied to every tag model (character/location/item/event/
relation/ownership tags).

**Fix, step 2 (no presence validation):** `HasManyTags` no longer adds
`validates association, presence: true`, so tags are optional on **every** content model.
Deleting a tag simply leaves its records untagged, which is valid — no deferred failure, nothing
breaks at the next save, and no controller force-assigns a default tag to compensate.

### Fixture slugs did not match the normalized slug format (fixed)

**Then:** fixture rows explicitly stored underscore-separated slugs such as `section_one`, while
`HasSlug.slugify` normalizes underscores to dashes. Because fixtures load directly, a class-level
finder such as `Section.section_one` searched for `section-one` and could not find the row.

**Fix:** all fixture `slug` values now use the same dash-separated format as application-created
records. Fixture labels and association references remain unchanged, and a regression test verifies
that a fixture is reachable through its normalized class-level finder.

### `404` vs `RecordNotFound` in tests (resolved as a test convention)

**Then:** `config.action_dispatch.show_exceptions = :rescuable` causes an out-of-scope
`ActiveRecord::RecordNotFound` raised during a request to be rendered as HTTP 404, so an
`assert_raises` expectation around the request would not observe the exception.

**Resolution:** request tests assert the externally visible response with
`assert_response :not_found`; only direct model or lower-level lookups assert
`ActiveRecord::RecordNotFound`. The test configuration remains `:rescuable` because it reflects
the response behavior users receive.

### Former quirk #4: Disposable universe data was coupled to `db:seed` (resolved)

**Then:** `db/seeds.rb` loaded a hard-coded Dark/LOTR list, Dark and LOTR had separate Ruby/YAML
loaders, missing or unknown data files were not governed by one registry, and the development
loader bypassed the documented sibling-position contract. A fresh `db:prepare` could therefore
load temporary users and data into a database that was not being used for local development.

**Resolution:** `db/seeds.rb` now loads only production-safe files under `db/seeds/`.
`Development::UniverseDataLoader` uses the shared `Development::UniverseDataRegistry` for model
order, file names, and supported universes; it validates references and scope before writing,
normalizes hierarchical positions, and is invoked only through explicit tasks. `db:demo:check` is
read-only in development/test, while `db:demo:load` and `db:demo:reset` require development.
The old per-universe Ruby loaders were removed and LOTR now uses the same YAML format as Dark.

### Former quirk #16: `db:restart` had no environment or confirmation guard (resolved)

**Then:** `db:restart` dropped, recreated, migrated, and seeded without checking `Rails.env` or an
explicit acknowledgement. The task description alone could not prevent a production invocation.

**Resolution:** `db:restart` now runs only in development with `CONFIRM_DB_RESET=1` and resets schema
without loading demo data. `db:demo:reset` has the same explicit confirmation and additionally
requires a registered `UNIVERSE` before dropping the database; it never invokes `db:seed`.

### Importmap Audit ignored the local Tom Select pin (fixed)

**Then:** `config/importmap.rb` mapped the bare `tom-select` import to
`vendor/javascript/tom-select.js` without a version annotation. Although the vendored file
identified itself as Tom Select `v2.6.2`, `bin/importmap audit` does not read version banners from
JavaScript files. It printed an "Ignoring tom-select" notice and did not include the direct package
in its npm advisory request.

**Resolution:** the local pin now carries the recognized `# @2.6.2` metadata comment.
`test/importmap_audit_test.rb` verifies that Importmap Audit sees the version and no longer emits
the warning. This closes the direct Tom Select audit blind spot; complete Bun/npm graph coverage,
vendored-file provenance checks, and Dependabot configuration remain separate follow-up work.

**Resolved security and interaction findings (2026-09-25)**

### Former quirk #5: Kamal secrets were tracked (repository containment fixed; rotation pending)

The current tree adds `/.kamal/secrets` to `.gitignore`, removes the path from the Git index while
preserving the local file, restricts the local file to mode `0600`, and adds a CI guard that fails
if the path is tracked. The secret value was never read or reproduced. This does not rotate the
master key or remove prior copies from Git history, forks, CI artifacts, or backups; those are
explicit owner actions before deployment and remain recorded in `known_quirks.md`.

### Former quirk #8: taxonomy stored DOM XSS (fixed)

The taxonomy Stimulus controller now constructs options, fields, nodes, labels, descriptions, and
ARIA values with DOM APIs. User-controlled values are assigned as text or attributes and are never
interpolated into `innerHTML`. The browser regression stores a hostile option name, reopens another
node's editor, and verifies that the name remains text with no injected image/marker element.

### Former quirk #9: password-reset tokens in Rails request logs (fixed for application logs)

`PasswordResetPathFilter` redacts the dynamic `/passwords/:token` path segment in Rails' filtered
request path, including failed update targets, while ordinary `/passwords/new` remains readable.
Password-reset responses also set `Cache-Control: no-store` and `Referrer-Policy: no-referrer`.
Upstream proxy/access logs and browser history remain deployment responsibilities and are called
out in the production documentation.

### Former quirks #10 and #11: placeholder mail/URL and unenforced TLS (fixed in configuration)

Production now fails closed without `APP_HOST`, `MAILER_FROM`, and `SMTP_ADDRESS`; uses HTTPS
mailer URLs, explicit SMTP settings, and a non-placeholder sender; enables `assume_ssl` and
`force_ssl`; restricts the host allowlist; preserves `/up`; and sets the session cookie `Secure`.
A dummy production boot and configuration assertions passed. Real certificate/proxy setup and SMTP
provider delivery were not run and remain deployment verification steps.

### Former quirk #22: positioned sibling gaps and partial normalization (fixed for application paths)

`PositionedResourceOrder` now owns transactional create, move, reparent, and destroy maintenance,
locks the persisted scope owner, supports explicit flat mode, and is covered by service and
controller regressions. `Hierarchical` also normalizes siblings after direct model destroys. Raw
SQL/import and future flat direct-model paths remain a documented residual under
`known_quirks.md`; ADR 0009 records the boundary.

### Former quirk #25: blank password reset false success (fixed)

Password reset updates now use strong parameter expectations. Blank/malformed submissions return a
bad-request response without changing the digest or destroying sessions, and the controller test
covers that behavior.

### Former quirks #41–#44: stale taxonomy state and inaccessible insertion/reordering (fixed)

Successful taxonomy mutations now perform a same-URL Turbo visit, refreshing serialized
parent/tag descriptors, hierarchy state, page counts, and sidebar counts. Separators use their
actual list and position, including first/last boundaries. Native rename buttons support Enter and
Space; Move up/Move down and Insert before/Insert after provide pointer, touch, and keyboard paths;
touch media rules expose the controls and use 44px insertion targets. Browser regressions cover
hostile names, stale options/counts, root boundaries, keyboard activation, and narrow viewports.

### Former quirks #17 and #40: the flat-list modal committed behind a 406 and left stale rows (fixed)

**Then:** `modal_form_controller.js` only rewrote the form's action and method, so a browser create
or update reached a JSON-only controller as HTML. `respond_to` raised
`ActionController::UnknownFormat` **after** the record had been saved: the write committed, the
caller received `406 Not Acceptable`, validation errors never reached the form, and a retry created a
duplicate. Separately, the shared row Delete was a Turbo `button_to` against a destroy action that
answered a bare `204 No Content`, so Turbo had no replacement to apply and the row plus its counts
stayed in the DOM until a manual reload. The browser suite passed anyway, because the Character smoke
test asserted the row after a later navigation instead of looking at the mutation.

**Fix:** [ADR 0011](adr/0011-modal-json-mutation-contract.md) defines the shared modal contract. A
modal page declares `data-modal-form-response-value="json"|"html"`; in `json` mode the controller
submits the form itself as `application/x-www-form-urlencoded` with `Accept: application/json` and
the CSRF token, using the form's `_method` for the verb. A `422` error hash is rendered in a focused
summary and next to the control that caused it (association errors resolve to their foreign-key
field), the modal stays open with the entered values, and the submit button is never left disabled. A
request that never landed, a `403`, a `5xx`, and an unreadable body each report their own message.
Delete is issued by the same controller and a successful create, update, or delete performs a
same-URL Turbo visit, so rows, page counts, and cached sidebar counts come from one server render.
`RequiresJsonMutationFormat` makes the four flat-list and Scene Tag controllers refuse a non-JSON
mutation with `406` **before** writing, so the original duplicate-on-retry hazard cannot come back.
The mandatory deletion consequences now travel in `data-modal-form-confirm` on the new control.

`test/controllers/modal_json_contract_test.rb` pins the declared mode, the error region, the submit
target, and the row's delete control for all five modal workspaces, and asserts that an HTML mutation
to a JSON-only endpoint changes nothing. `test/system/modal_json_flow_test.rb` covers the browser
behavior: a real JSON create with refreshed counts, a record-level `422`, a field error rendered on
its control, a request that never reaches the server, a delete that fails and one that removes the row
and its counts, clearing the last tag, and a 390px viewport. Two smaller defects were found by that
coverage and fixed in the same change: the modal filled Rails' hidden companion field instead of the
multi-select (so a tag picker looked empty), and a multi-select name that already ends in `[]` was
given a second `[]`, which made the "clear the last tag" blank unparseable and left the old
assignment in place.

The taxonomy editor's rejection copy and the relation/ownership re-render still do not show a field
error summary; that gap is still open in
[`known_quirks.md`](known_quirks.md).

### Former quirk #18: mutation failures were not rendered in every editor (fixed)

**Then:** three editors reported a rejected save in three different inadequate ways. The taxonomy
tree's modal announced "The changes could not be saved." and closed nothing, but never rendered the
error hash it had been sent, and its single-field paths (inline rename, create, move, delete) used
the same generic wording for every server message. Relations and ownerships re-rendered their index
with `422` and nothing else: no model error summary, and the rejected entry discarded, so an author
had to retype it.

**Fix:** the one error-rendering contract now covers all of them.
`taxonomy_tree_controller.js` renders a `422` inside the editor the same way the flat-list modal
does — a focused `danger` summary plus the message on the control that caused it, resolving an
association error to its foreign-key field, because the hierarchy scope validation reports on
`:parent` while the field is `parent_id`. Its inline paths announce the server's own message when
the body carries one. The relations and ownerships workspaces keep the HTML re-render flow, and now
render the shared `shared/_error_summary` twice: once on the page the author lands on and once
inside the editor, with the rejected values serialized into the trigger that reopens it — the **Add**
trigger for a rejected create, and only the row being edited for a rejected update, so no other row
is affected.

Two things the browser coverage caught while doing this. The new taxonomy method
`errorFieldLabel` was first named `fieldLabel`, which silently replaced the controller's existing
`fieldLabel(field, id, className)` label builder; every taxonomy editor that opened raised
`TypeError: ((intermediate value) || attribute).replace is not a function` and no modal appeared at
all, which looked like flaky input rather than a name collision. And Bootstrap's focus trap focuses
the dialog when a modal finishes opening, so a save rejected during the opening transition lost the
error summary's focus; the editor now claims it back on `shown.bs.modal`.

Request coverage asserts the `422` error-hash shape and that a rejected entry reaches the trigger
that reopens the editor. Browser coverage lives in `test/system/modal_html_flow_test.rb` and
`test/system/taxonomy_tree_test.rb`.

### Former quirk #32: browser coverage was concentrated on the taxonomy tree (fixed)

**Then:** the browser suite exercised the taxonomy tree and the Scenes workspaces, so the flat-list
modals, relations, ownerships, memberships, and the password-reset journey were untested. The one
flat-list test passed even while its mutation was committed and answered `406`, because it asserted
the row after a later navigation.

**Fix:** each of those journeys now has a focused file or case:
`modal_json_flow_test.rb` (JSON create with refreshed counts, a record-level `422`, a field error on
its control, a request that never reaches the server, a delete that fails, a delete that removes the
row and its counts, clearing the last tag, and a 390px viewport), `modal_html_flow_test.rb` (a
rejected relation that reopens with its values, an ownership created through the modal, and the
row/editor at a 390px viewport), `membership_access_test.rb` (granting a level, an unknown address
refused with its reason, a granted member writing without reaching the Members page, and a read-only
member seeing the access notice and no mutation), `password_reset_test.rb` (the whole reset journey,
the mismatched confirmation, and an invalid token), and a rejected taxonomy edit in
`taxonomy_tree_test.rb`.

The suite grew from 39 to 50 browser tests. The request tests keep the exact status codes, which a
browser cannot see: `page.status_code` is only implemented by Capybara's rack-test driver, so the
membership browser test asserts the visible refusal instead and the request test owns the `403`.
Membership and password-reset browser coverage proves the visible behavior only; the request and
model tests remain the authority for authorization, tokens, and rate limiting.

### Hover-only row actions and an `aria-current`-less top bar (fixed)

**Then:** two related accessibility gaps shared one entry in
[`known_quirks.md`](known_quirks.md). A taxonomy row (Locations, Sections, and every tag tree)
revealed its action menu only on hover, through a `opacity: 0; pointer-events: none` rule that a
focus/touch media query had to undo. The top bar's universe and story dropdowns marked the current
item with a visual `.active` class and no `aria-current` on the link, so the current scope was
announced by color alone. The Scenes list also had no Details link, and the taxonomy Details link
carried its count as parenthesized text.

**Fix:** the top bar is now three links — the brand to the universes landing page, plus
**Universe:** and **Story:** as plain links to their own pages — with no switcher dropdown, and a
scope link carries `.active` together with `aria-current="page"` only on the page it points at.
Every list row follows one shape: a plain-text name with its tags and a `.record-count` pill on the
left, and an always-visible **Details** link followed by the action menu on the right. The count
moved out of the link into `record_count_badge`, which names what it counts ("(4 characters)"), and
the taxonomy node serializes that text onto the node
so the tree controller can restore the rename button exactly as the server rendered it when a rename
is cancelled. Browser regressions cover the no-hover visibility of both halves of the row, the
count's return after a cancelled rename, and the read-only Scene row.

Tag-color contrast validation remains open and is recorded in
[`known_quirks.md`](known_quirks.md).

### Former quirk #45: read-only empty taxonomy pages instructed users to add or drag records (fixed)

**Then:** the shared `shared/_taxonomy_tree` partial had a read-only empty-state fallback, but the
Locations and taxonomy views passed explicit writer copy containing "Add"/"drag" instructions, so
guests and read-only members saw mutation instructions even though no mutation controls were rendered.
The Sections workspace had already been fixed by passing both `empty_description` and the new
`read_only_empty_description` local; the remaining callers still needed it.

**Fix:** every remaining `shared/taxonomy_tree` caller now passes `read_only_empty_description`, so an
empty taxonomy shows mutation copy only to writers and a read-only "No … are defined yet." message to
guests and read-only members. A system regression signs in as a read-only member of a private universe
with no tags and asserts the read-only copy appears while the writer copy does not.

**Resolved Timeline findings (2026-09-29)**

### Former quirk #24: Timeline output could contradict its layer ordering (fixed)

**Then:** `TimelineLayout` built a DAG of "happens no later than" relations, refused any edge that
would close a cycle (`reachable?`), and layered the events by longest path. It then threw that graph
away and rebuilt `@edges` from the raw `before_event`/`after_event`/`simultaneous_event` associations,
so the arrows the view drew did not have to agree with the rows it drew them across. Three
reachable contradictions, all confirmed by probe before the fix:

- An event whose dates ordered it after another, while declaring itself *before* that other, was
  placed on the lower row by the dates and then drawn with an arrow running back up the page.
- Two events each naming the other (`A.after_event = B`, `B.after_event = A`) produced **both**
  directions as drawn arrows: a cycle in the drawing that the graph had already refused.
- An event that was `simultaneous_event` with another *and* declared a sequence relation to it was
  drawn on the same row with both a dashed "same time" line and a solid one-directional arrow.

Nothing validated against this, and no test covered conflicting dates and relations, so the drawing
was the only place the contradiction could surface.

**Fix:** `@layers` is the single source of the rendered order, and `@edges` is now read back off it.
`build_edges`/`push_edge` emit a sequence edge only when the two events ended up on **strictly
different** rows with `from` above `to`, and a simultaneous edge only when they share a row — which
union-find guarantees. A relation the graph refused is therefore not drawn at all. It is deliberately
**not** drawn reversed to "match" the rows: reversing would invent a relation the author did not
declare and hide the conflict. A relation named from both sides is de-duplicated, so it draws one
arrow rather than two.

No model validation was added, on purpose. A `before_event` contradicting the dates is a legitimate
author state — dates are frequently approximate in a story bible, and the declared relation is often
the truer one. Rejecting it at save time would refuse data the application previously accepted; the
documented confidence order (full ranges → start dates → end dates → explicit relations) already
says which signal wins, and the drawing now simply follows it.

`test/models/timeline_layout_test.rb` grew from 4 to 11 cases. The new ones cover: a relation the
dates contradict (drawn nothing, layers unchanged), a relation the dates agree with (still drawn),
a mutual `after_event` cycle (exactly one arrow, asserted against the row indices rather than a
literal), simultaneous-plus-sequence on the same pair (only the simultaneous edge), a relation named
from both sides (one arrow), and a reference to an event outside the layout. The suite asserts
direction by looking up each endpoint's row, so a future change to the layering fails the test rather
than quietly invalidating it.

### Former quirk #46: Timeline nodes had no accessible name, and the docs promised pan/zoom (fixed)

**Then:** each node rendered only the record's numeric id inside a focusable `<div tabindex="0">`,
with no role and no accessible name — a screen reader announced a bare number for every event on the
page. The popover that carried the real description opened only on `hover focus`. Separately,
`architecture.md` and the conventions both described a pan/zoom interaction for
`timeline_controller.js` that **never existed**: the controller only ever drew SVG edges and
popovers, from its first commit (`fef94d1`) onward. The docs described an intended feature as
shipped behavior.

**Fix**, in two halves because the finding bundled two unrelated things:

- **The accessible name.** A node is now a real `<button>` with an `aria-label` built by
  `TimelineHelper#event_node_aria_label` from the same `event_popover_title` the popover header uses,
  so the label and the popover cannot describe different events. The button's UA chrome (padding,
  border) is reset in `_timeline.scss` so the node keeps its documented 40px circle and the author's
  tag colors; a `:focus-visible` outline was added since the node is now genuinely focusable. The
  popover trigger became `hover focus click`: a `<div>` could rely on hover, but a control that is
  meant to be operated needs a click path too, and a touch pointer never hovers.
- **The docs.** `architecture.md` and the conventions no longer claim pan/zoom; both now state that
  the Timeline is a static layered view. Per the owner's decision the pan/zoom interaction itself is
  **not** built — it is recorded as pending work in [`backlog.md`](backlog.md) rather than left as a
  false claim in the docs.

Coverage, per [ADR 0012](adr/0012-client-side-verification-and-csrf.md): four request cases in
`test/controllers/timeline_controller_test.rb` assert the node is a `button` with the expected label,
that the id-placeholder fallback is labelled correctly for a title-less event, that no `tabindex` is
left behind, and that the trigger includes `click`; the Spanish label is asserted in
`workspace_locale_test.rb`. The new `test/system/timeline_test.rb` covers what only a browser can
show: tabbing forward from the control before the timeline really lands focus on the node
(`document.activeElement`), the popover opens on focus alone, it opens on click, and an empty
timeline draws no nodes. `timeline_controller.js` itself is unchanged, so its `bun test` cases still
cover the drawn geometry unchanged.

**Resolved interaction findings (2026-09-29)**

### Former quirk #60: four browser assertions in the tag and taxonomy suites were stale (fixed)

**Then:** `bin/rails test:system` was red before any new work started, from four assertions in
`test/system/tag_improvements_test.rb` and `test/system/taxonomy_tree_test.rb` that no longer
matched documented behavior. They reproduced in isolation on an idle machine, so they were not the
load sensitivity in quirk 58, and a red browser suite is exactly the state in which a real
regression cannot be told from an old failure.

- `tag_improvements_test.rb:16` asserted the canonical tag path after clicking a workspace menu-tag
  tab. A workspace tag link deliberately carries `from=workspace`
  ([conventions](conventions.md), flat-list pattern) so the tag page can preserve that
  navigation without trusting a `Referer` header. The app was right; the expectation was stale.
- `tag_improvements_test.rb:60` and `taxonomy_tree_test.rb:302` called
  `find("button[aria-expanded='false']")` inside a `li[data-node-id]`. A tag with children nests the
  child's `li` — and therefore the child's own collapsed row menu — inside the parent's, so the
  scope matched two toggles and raised `Capybara::Ambiguous`. The row grew a second control when
  grouping tags began listing their own children; the selector was never narrowed.
- `taxonomy_tree_test.rb:22` expected a page-header `.badge` of `3` where the page shows `4`. The
  badge is the taxonomy's own tag count (`TagsHelper` passes `count: ordered_records.length`), and
  `character_tag_one`, `character_tag_two`, and the nested `character_tag_child` are three tags
  before the test creates a fourth, so the header was correct and the literal was stale.

**Fix:** all four were test-side; no application code changed.

- The workspace tab is asserted with the `from=workspace` link it actually renders, and the test
  then follows the taxonomy tree's **Details** link for the same tag to confirm the canonical path
  is the same page without the origin. Both navigation styles are now covered where the
  convention is recorded.
- Every `find("button[aria-expanded='false']")` in the taxonomy suites is scoped to
  `li[data-node-id] > .taxonomy-row`, matching the existing convention in the same files, so a
  parent node's click cannot land on a child's menu. The four sites that used the bare node scope
  were narrowed, not only the two that were raising.
- The header badge is asserted against `universe.character_tags.count` and its `aria-label`, instead
  of a literal, so the test states the contract — the count is the taxonomy's tags, nested children
  included, and it tracks live creation because a create performs a same-URL Turbo visit.

The header count's meaning is now stated where it is documented, in
[conventions](conventions.md) under the taxonomy-tree pattern: the badge is every tag
in the taxonomy, children included, not the number of root rows.

### Former quirk #59: deleting a Character, Item, or Location announced none of the consequences ADR 0007 records (fixed)

**Then:** `shared/_row_actions` defaults to the short `Delete <name>?` confirmation, and the
Characters and Items workspaces passed no `confirm_text` of their own, so the mandatory templates in
[ADR 0007](adr/0007-story-owned-scenes-and-elements.md) were never rendered for those two.
Locations is a taxonomy tree and passed no `confirm_message`, so its delete fell back to the tree
controller's generic `Delete <name> and its children?`, which names the record and its descendants
but not the Scene presence links. Events, Scenes, Sections, and the Story and tag pages already
rendered their full templates.

The deletes themselves were correct: each model declares its own cascade, and a Character, Item, or
Location already soft-deleted its descendants, ownerships or relations, and presence links. Only the
confirmation a reader saw was silent, which is the exact unannounced-cascade risk the `confirm_text`
partial was written to prevent. The ADR's 2026-09-27 execution note had already narrowed its
"every confirmation template above is live" claim to the four that were.

**Fix:** all three surfaces now render the ADR's sentences, unchanged.

- Characters and Items pass `confirm_text` to `shared/_row_actions`, which serializes it as the modal
  controller's `data-modal-form-confirm` — the same channel Events already used.
- Locations passes a `confirm_message` lambda, which `shared/_taxonomy_tree` serializes per node as
  `data-confirm-message` for `taxonomy-tree#remove` to confirm on. That is the channel Section and
  SceneTag already used, so no JavaScript changed and the controller's generic message stays as the
  fallback for an unrendered node.
- The copy lives at `characters.delete_confirm`, `items.delete_confirm`, and
  `locations.delete_confirm`, beside the workspace that is its only reader, and each is the ADR
  sentence with `%{name}` interpolated. The record name is the author's own data, so it is
  interpolated rather than translated; both locales carry each string.

Four request tests read the rendered confirmation: `characters_controller_test.rb`,
`items_controller_test.rb`, and `locations_controller_test.rb` assert the English copy on the attribute
the page actually ships (`data-modal-form-confirm` for the two flat rows, `data-confirm-message` for
the tree node), and `universe_bible_locale_test.rb` asserts the Spanish Item and Location copy. Two
assertions elsewhere read the old short sentence and were updated to the full template:
`modal_json_contract_test.rb` (which is what pins the JSON-only row's delete copy at all) and the two
`accept_confirm` blocks in `test/system/modal_json_flow_test.rb`, which now accept whatever the row
sends because the copy's content is a request-test concern.

### Former quirk #47: the Event edit selector offered the event itself as a temporal reference (fixed)

**Then:** `EventsController#index` put every universe event in `@events_for_select`, and the modal's
three temporal selects rendered that whole list. One modal form serves every row of the Events list,
so a single server render cannot know which row is about to be edited — but the browser still offered
the row being edited inside all three of **Happens before / Happens after / Same time as**. Picking it
was accepted by the browser and refused by `Event#cannot_reference_self`, and by the
`events_*_event_not_self` check constraints behind it.

**Fix:** the option list is now the browser's half of the same rule the model already enforces.

- A select opts in on the control itself with `data-modal-form-exclude-self`, and the row's identity
  travels on its trigger as `data-modal-form-record-id`, which `shared/_row_actions` now emits. This is
  the same shape `taxonomy_tree_controller.js` already uses to keep a node out of its own `parent_id`
  select, and it is client-side for the same reason: the tree builds one modal per node, and the flat
  list builds one modal for the whole page.
- `modal_form_controller.js#excludeEditedRecord` detaches exactly the one option that belongs to the
  row being opened and `restoreExcludedOptions` re-inserts it, in the place the server rendered it,
  before the next row opens. The create trigger carries no id, so a create offers every event.
- `EventsController` is unchanged: it still sends every universe event, which is the only correct thing
  for a form shared by every row.
- **The option list is never rebuilt from a cached copy**, and that is a finding rather than a style
  choice. The first implementation rebuilt each select with `replaceChildren` from a cached array, and
  the existing `a record-level 422 keeps the modal open` browser case immediately failed with a stale
  element reference. The cause was not Capybara: `replaceChildren` on a `<select>` loses which option
  the control holds, so the *create* form came up with `before_event_id` set to a real event, which
  satisfied `must_be_identifiable`, saved, and replaced the page under the test. Detaching one option
  cannot disturb the others' selection.
- The model validation, the three database constraints, and the `422` path are untouched, so a request
  built by hand — a stale page, a crafted POST — is still refused.

Coverage: five cases in `test/javascript/modal_form_controller_test.js` (the edited row's own option is
dropped, an undeclared select is untouched, the next row gets it back, a create offers everything, and a
create after an edit restores the option), one request test in `events_controller_test.rb` for the
declared contract on the rendered page, and one request test there for the hand-built self reference
still being a `422` keyed on `before_event`. Two browser cases in `test/system/modal_json_flow_test.rb`
replace the one that used to drive the browser into the self-reference: they assert that the editor for
an event does not offer that event, that a create still offers both, and that a create's select is
empty. **A coverage change worth stating plainly:** the removed browser case was the only end-to-end
proof that an association-keyed error (`before_event`) lands on the foreign-key control
(`before_event_id`). That mapping is now unreachable through the Events modal — which is the point of
the fix — and it keeps its unit case in `modal_form_controller_test.js`
(`resolves an association error to its foreign-key field`), while the real-browser proof that a `422`
renders in the summary, on the offending control, and takes focus is `scene_elements_test.rb`'s
"a dialogue with no speaker is refused in the modal, which stays open".

### Former quirk #48: delegated admins could demote or remove themselves into a blank 403 (fixed)

**Then:** the Members workspace rendered the access-level select and the Remove button on every
membership row, including the caller's own, and `MembershipsController#update` and `#destroy` had no
self-membership check. A delegated admin could therefore set their own level down to `write` or `read`,
or soft-delete their own row. The mutation redirected to `universe_memberships_path`, which is
admin-only (`universe_access_for_request` answers `:admin` for every `memberships` action), so the
redirect immediately failed the very authorization the author had just given up: `rescue_from
CanCan::AccessDenied` answers the documented bare `403`, and the browser landed on a bodyless page
with no explanation and no link forward. The owner was never exposed, because the owner is not a
membership at all and its row is hardcoded.

**Fix:** a self-mutation is refused before it is applied. `MembershipsController#own_membership?`
compares the target membership's user with `Current.user`, and both actions redirect to the landing
page with an alert (`memberships.flash.own_change_refused`, `memberships.flash.own_removal_refused`)
instead of redirecting to a page the author can no longer open. The view stops offering the controls
in the first place: the caller's own row keeps its access badge and shows a "You" label where the
change form and the Remove button would be, and another member's row is unaffected. A self-demotion
is now a stated refusal rather than a successful mutation with an unexplained dead end.

The bare `403` is deliberately unchanged for the case it was written for: a signed-in member who is
not an administrator asking for an admin-only page still gets the documented status code. The fix is
that the application no longer *produces* that state through its own UI.

Four request tests in `test/controllers/memberships_controller_test.rb` cover the refused
self-demotion (level unchanged, alert, redirect to the landing page), the refused self-removal (the
row is still there), the absence of change and Remove controls on the caller's own row, and the
presence of both controls on another member's row. No browser test was added: the change is
server-rendered ERB with no client-side path, and the request suite asserts the same markup the
browser would render.

### Former quirk #30: JSON/field contracts had several silent omissions (fixed)

**Then:** three drifts on the contract between a record and the editor that writes it, none of which
was an authorization failure and all of which were invisible to a reader.

- **`Relation` and `Ownership` could not be given a name.** Both models carry an optional `name` that
  `display_string` and the composite slug both *prefer* when it is set, so a named record is labelled
  by its name everywhere — but neither `relation_params` nor `ownership_params` permitted it, neither
  modal had a Name field, and neither `*_fields_json` serialized it. A name could arrive from
  `db/data` or a console and then be impossible to change, rename, or clear through the interface.
- **Stored seconds were discarded on the way to the editor.** `event_fields_json`,
  `relation_fields_json`, and `ownership_fields_json` formatted with `%Y-%m-%dT%H:%M`, and
  `scene_datetime_field_value` did the same, so opening an editor on a record whose stored time had a
  non-zero second and saving it again rewrote that column to zero seconds. `scenes_helper` repeated
  the same truncation in its own helper, so fixing only `modal_fields.rb` would have left Scene as the
  odd one out.
- **The HTML flow answered `302` where the matrix documents a 303.** `RelationsController` and
  `OwnershipsController` redirected on PATCH and DELETE with Rails' default, against the documented
  `status: :see_other` for non-GET verbs. Every other controller in the HTML flow — universes, stories,
  scenes, memberships — already sent it.

**Fix, in three parts:**

- **The name is now part of the contract.** `:name` is permitted by both controllers, both modals
  carry an optional Name field with a hint saying it is optional, and both serializers emit `name`, so
  the row's editor is prefilled with the stored value and a rejected entry keeps what was typed. The
  field is deliberately *not* `required`: the endpoints remain the reliable label, and
  `display_string` falls back to them.
- **A stored second survives an edit.** `ApplicationHelper::DATETIME_LOCAL_FORMAT`
  (`%Y-%m-%dT%H:%M:%S`) is now the one format every in-world editor value is built from, in
  `modal_fields.rb` and in `scenes_helper.rb` alike. It is deliberately a *different* constant from
  `DATE_FORMAT`, which is what a reader is shown; that one stays minute-precision. Every
  `datetime-local` control for those values now carries `step: 1`, because a control whose step is a
  whole minute cannot hold a second even when the value it is handed has one — the serializer and the
  control have to agree, or the browser drops the value the server serialized. Display formatting
  (`in_world_range`, the timeline, `scene_in_world_time`) is unchanged.
- **PATCH and DELETE answer `see_other`.** `create` is a POST, so its 302 is correct and stays.

**A defect the first fix exposed, fixed with it.** Making `name` writable revealed what happens when
it is *un*writable-to: `HasSlug#set_slug` regenerates the slug on every name change, and resolves a
blank or unslugifiable name to a random hex. So clearing a Relation's name replaced its address with
`"4a45ea13"` and discarded the composite slug its demo-data references and class-level lookup depend
on. The new `OptionalName` concern (`app/models/concerns/optional_name.rb`) gives both models one home
for the rule, because they are the only two with an optional name: a blank name is stored as NULL
rather than `""`, and a name that has no slug of its own does not re-address the record. Renaming to a
name that *does* slugify still renames; `Relation` and `Ownership` had no test for clearing or
unslugifiable names before, and now have four cases each.

Coverage: `test/helpers/modal_fields_helper_test.rb` is new and pins the serialized hand-off itself —
the three serializers keep a stored second, `relation`/`ownership` carry `name`, an unset value
serializes as `nil`, and the two datetime formats are distinct. The request tests own what a page
ships: `relations_controller_test.rb`, `ownerships_controller_test.rb`, and `events_controller_test.rb`
each assert `step='1'` on the datetime controls and that the row's trigger carries the stored seconds;
the relations and ownerships files also cover the name being created, prefilled, renamed, cleared, and
`see_other` on PATCH/DELETE. `scenes_controller_test.rb` gained a real open-and-save round trip for a
stored second, `scenes_helper_test.rb` covers the same at the helper, and
`universe_bible_locale_test.rb` asserts the Spanish Name label and that neither field is marked
required.

### Former quirk #61: a dismiss control clicked while the modal was still fading in was silently dropped (fixed)

**Then:** every modal editor offers three ways out — the `btn-close` button, the footer's **Cancel**,
and Escape or a backdrop click — and all of them resolve to the one Bootstrap instance the controller
owns. Bootstrap's `Modal#hide()` returns immediately while that instance is transitioning in, which is
the whole window the opening transition occupies, so a dismiss landing there was dropped without a
word: the modal stayed open, the control looked dead, and only a second attempt closed it. Measured
on 2026-09-30 with Bootstrap 5.3.8 — immediately after `show()` the instance reports
`{isShown: true, isTransitioning: true}`, a **Cancel** click leaves the modal open, and the same click
a second later closes it. The window is wider than the dialog's own 150ms fade: the backdrop fades in
first, and only then does Bootstrap mark the dialog shown and fire `shown.bs.modal`, so the state that
is dropped spans both transitions.

It was invisible to a pointer user, who waits a fraction of a second, and it took the first Escape a
keyboard reader pressed the moment the dialog appeared. It reached every modal workspace, and it was
also why no browser case could open a second editor on the same page: Capybara clicks as soon as the
element exists, so the click landed inside the transition and the first editor kept covering the list.

**Fix:** both editors wrap the instance's own `hide()` instead of intercepting four triggers. While
the dialog is opening, an intent is remembered and re-issued on `shown.bs.modal`, before any focus is
claimed — the same care the focus race on a rejected save already gets.

`modal_form_controller.js` opens that window only when `show()` will really show the dialog. Bootstrap's
`show()` returns without doing anything while the dialog is already open, and no `shown.bs.modal` would
follow to close a window opened anyway, which would have replaced a dismiss that arrives one attempt
late with a dialog that cannot be dismissed at all. So "already open" is read from the dialog's own
events, not guessed: `hidden.bs.modal` clears it. The first version of this fix inferred it from the
previous open alone, and the browser case that dismisses one row's editor and opens the next row's
caught the difference — the second editor no longer deferred, because nothing had marked the first one
closed.

The taxonomy tree editor builds its own `.modal fade` with the same `btn-close`, **Cancel**, Escape,
and backdrop, and had the identical race on its own instance. The recorded finding named only the
shared editor; the owner chose to fix both in the same change, and the two fixes are the same shape.

Coverage: six cases in `test/javascript/modal_form_controller_test.js` — a dismiss during the opening
is honoured once it has opened, one after it has opened is not deferred, the open that replaces the row
supersedes a dismiss it never delivered, an open that does not re-show the dialog still leaves it
dismissable, a dismissal lets the next open defer its own dismiss again, and a deferred dismiss claims
no focus for the dialog that is closing — and four in `test/javascript/taxonomy_tree_controller_test.js`,
which add that a repeated dismiss is honoured once and that a deferred dismiss beats the focus a
rejected save would have claimed. Four of the six and three of the four fail without the fix.

In the browser, `test/system/modal_json_flow_test.rb` and `test/system/taxonomy_tree_test.rb` deliver the
dismiss in the same task as the open through `execute_script`, because Capybara cannot: a case that waits
for the control to be actionable clicks in a later task, which is past the window. The flat-list file
also covers Escape, the dismiss a keyboard reader reaches for, and the row-to-row case the quirk itself
blocked. Each of the same-task cases waits for `shown.bs.modal` and then `hidden.bs.modal` to be
recorded on the body, so "the editor is not on the page" cannot be satisfied by the fraction of a second
before it has finished opening — which is how the first version of these cases passed against the
unfixed code.

**Resolved client-side verification and CSRF findings (2026-09-27)**

### Former quirk #33: client-side code had no tests, no linter, and an unverified CSRF path (fixed)

**Then:** the security-sensitive half of every mutation lived in Stimulus controllers with nothing
checking it. `package.json` had only the CSS build and watch scripts, there were no JavaScript
spec files, and no JavaScript linter, so a controller regression surfaced as a browser test that
already looked green or as a production report. The test environment also disabled
`allow_forgery_protection`, so nothing proved that a `fetch` from those editors carried a token at
all, and Brakeman does not read client-side code.

**Fix:** [ADR 0012](adr/0012-client-side-verification-and-csrf.md) records the decision.

- `bun run test:js` runs Bun's built-in test runner over `test/javascript/`, one file per
  controller, in a happy-dom DOM. `test/javascript/setup.js` provides that DOM and replaces
  `@hotwired/stimulus` and `bootstrap` with minimal stubs, because the application serves both from
  the import map rather than `node_modules`; `bunfig.toml` preloads it. The 62 cases cover the
  request the editors build (token, verb, payload, cleared multi-select), the `422` rendering
  contract, the page-level status region, the drawn Timeline geometry, and the taxonomy row builders
  with a hostile name.
- `bun run lint:js` runs Biome's recommended rules over `app/javascript` and `test/javascript` in
  the new `js-check` CI job. Linting is not formatting: the controllers keep their hand-written
  style.
- `test/javascript/no_html_sink_test.js` fails when a new `innerHTML`/`outerHTML`/
  `insertAdjacentHTML`/`document.write` sink appears in `app/javascript` without a reviewed
  exception, which keeps the DOM-API-only rule from former quirk #8 enforceable.
- `test/controllers/csrf_mutation_test.rb` and `test/system/csrf_token_test.rb` wrap their own
  window in `with_forgery_protection` (`test/test_helpers/forgery_protection_test_helper.rb`).
  Between them they prove that the page's `csrf-token` meta tag is sent by both `fetch`
  implementations, that the server accepts it, and that a missing or forged token is refused with
  `403` and writes nothing — the browser cases do it by removing the meta tag, the request cases by
  replaying the token a real page published.
- A JSON mutation whose token is refused now answers `403` instead of the generic `422` page
  (`ApplicationController`), so the shared editor reports a refusal and keeps the author's input
  rather than claiming the server explained nothing. HTML requests keep Rails' own handling.

The new unit tests also found three defects in the code they were written for, all fixed here:
cancelling an inline taxonomy rename restored the author's unsaved text instead of the name the
server had rendered, a `belongs_to` error keyed on `:parent` was labelled `parent` instead of the
editor's own **Parent tag** label, and a `422` body whose `errors` was not an object was read as an
error on an attribute literally called `errors`. The taxonomy editor's `fetch` also always sent an
`X-CSRF-Token` header, so a page without the meta tag would have sent the literal string
`undefined`; it now omits the header, as the flat-list modal already did. The linter's first run
reported the two self-assigning reload fallbacks and ten `forEach` callbacks that returned a value,
all replaced with `window.location.reload()` and braced bodies.

The deliberately unchanged part: `allow_forgery_protection` is still off for the fast request suite,
so a new mutation path has to be added to one of the two CSRF files on purpose. The browser suite
also remains an initial smoke suite, not exhaustive UI coverage.

**Verification history**

The dated runs below recorded what was checked after each resolved entry. They are kept as evidence
that a fix was verified, not as a description of today's capabilities; the current commands are in
[`development.md`](development.md).

**Follow-up verification (2026-09-27, client-side verification and CSRF — quirk 33)**

- `bun run lint:js` (Biome 2.5.14, recommended rules) — clean over 13 files. Its first run reported
  12 real findings, all fixed in this change.
- `bun run test:js` — 62 tests, 170 assertions, 0 failures, across 4 files.
- `bin/rails test` — 526 tests, 3,185 assertions, 0 failures, 0 errors, 0 skips.
- `bin/rails test:system` — 54 tests, 636 assertions, 0 failures, 0 errors, 0 skips
  (`SE_CHROME_NO_SANDBOX=1`, which this machine needs).
- `bin/rubocop` — 215 files, no offenses.
- `bin/brakeman --no-pager` — 0 security warnings.
- `bin/bundler-audit`, `bin/importmap audit`, `bun audit` — no known vulnerabilities; `bun audit`
  now covers 116 packages including the two new dev dependencies.
- `bun install --frozen-lockfile` — clean against the updated `bun.lock`, which is what CI uses.

Not run: `UNIVERSE=dark|lotr bin/rails db:demo:check` (no `db/data` manifest, schema, or seed file
changed), a destructive `db:demo:reset`/`db:load`, Docker/Kamal build or deployment, production SMTP
delivery, a clean migration-from-zero job, and a browser pass against loaded development data. The
`js-check` CI job itself was not executed here: the same two commands were run locally with the
pinned Bun 1.4.2 that the job installs.

**Follow-up verification (2026-09-25)**

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

**Follow-up verification (2026-09-25, Tom Select audit metadata)**

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
remain open under the "Complete dependency, JavaScript, and container supply-chain checks" item in
[`backlog.md`](backlog.md). No destructive database, container, deployment, or browser
operations were run for this tooling-only fix.

**Follow-up verification (2026-09-25, ordering/security/taxonomy hardening)**

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

**Follow-up verification (2026-09-25, Scene core)**

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
changed in this delivery), `db:demo:reset`/`db:demo:load` (destructive, needs approval), a browser
manual pass against loaded development data, Docker/Kamal deployment, and any production SMTP or
proxy verification.

**Follow-up verification (2026-09-25, Scene references and grouping)**

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

**Follow-up verification (2026-09-25, Scene Tag)**

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
recorded in the Scene references and grouping verification section.

**Follow-up verification (2026-09-25, Dark story-name test fix)**

- `bin/rails test` — 440 tests, 2,552 assertions, 0 failures, 0 errors, 0 skips. This clears the
  standing failure recorded in the Scene references/grouping and Scene Tag verification sections
  above. The assertion
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

**Follow-up verification (2026-09-25, cssbundling rake constant warnings)**

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

**Follow-up verification (2026-09-26, shared modal JSON reliability)**

- `bin/rails test` — 516 tests, 3,110 assertions, 0 failures, 0 errors, 0 skips.
- `bin/rails test:system` — 39 tests, 492 assertions, 0 failures, 0 errors, 0 skips on three
  consecutive full runs, including the new Character/Item/Event modal regressions.
  `SE_CHROME_NO_SANDBOX=1` was used because this machine blocks Chrome's user namespace. During
  development one run behaved as if no real mouse input reached the page (dropdown and button clicks
  were ignored) and was not reproducible afterwards; the same symptom appeared in the untouched
  taxonomy suite, so it was an environment problem, not an application one. That work uncovered two
  real races in the new error path, both fixed and both covered: the browser moves focus off a
  submit button that has just been disabled, and Bootstrap's own focus trap focuses the dialog when
  a modal finishes opening, so a save rejected during the opening transition lost the error
  summary's focus to it.
- `bin/rubocop` — 209 files, no offenses.
- `bin/brakeman --no-pager` — 0 security warnings.
- `node --check app/javascript/controllers/modal_form_controller.js` — passed.
- `git diff --check` — clean.

Not run: `bin/bundler-audit`, `bin/importmap audit`, and `bun audit` (no dependency, importmap pin,
or vendored asset changed in this delivery), `db:demo:reset`/`db:demo:load` (destructive, needs
approval; no `db/data` manifest changed either), Docker/Kamal deployment, and a manual browser pass
outside the automated system suite.

**Follow-up verification (2026-09-26, error UI in every editor, quirks 18 and 32)**

- `bin/rails test` — 521 tests, 3,149 assertions, 0 failures, 0 errors, 0 skips.
- `bin/rails test:system` — 50 tests, 596 assertions, 0 failures, 0 errors, 0 skips, on four
  separate full runs of the final code (with `SE_CHROME_NO_SANDBOX=1`, which this machine needs).
  The suite grew by 11 browser tests.
- `bin/rubocop` — 212 files, no offenses.
- `bin/brakeman --no-pager` — 0 security warnings.
- `node --check` for `modal_form_controller.js` and `taxonomy_tree_controller.js` — passed.
- `git diff --check` — clean.

Two notes for whoever reads the failure history of this file, because both were real and only one
of them was the application's fault. First, a long stretch of intermittent browser failures in this
session was diagnosed as dropped input and turned out to be a method-name collision in the new
taxonomy code: the three tests that click **Edit** in a row menu failed every time, which looks like
an input problem and was not. Second, a genuinely intermittent input problem also exists here: in
some full runs Chrome delivers no `mousedown`/`click` to the page at all, and the affected failures
land in pre-existing tests (`SceneTagsTest`, `WorkspaceNavigationTest`) with "the row/modal never
appeared" symptoms. A recurrence of that shape should be re-run once before it is believed.

The browser suite can also only assert what a browser can see: `page.status_code` exists only on
Capybara's rack-test driver, so the membership browser test asserts the visible refusal and the
request test owns the exact `403`.

Not run: `bin/bundler-audit`, `bin/importmap audit`, and `bun audit` (no dependency, importmap pin,
or vendored asset changed), `bun run build:css` (no SCSS change), `db:demo:reset`/`db:demo:load`
(destructive, needs approval; no `db/data` manifest changed), Docker/Kamal deployment, and a manual
browser pass outside the automated suite.

**Follow-up verification (2026-09-29, stale browser assertions — quirk 60)**

- `PARALLEL_WORKERS=1 bin/rails test test/system/tag_improvements_test.rb
  test/system/taxonomy_tree_test.rb` — before: 17 runs, 185 assertions, 2 failures, 2 errors. After:
  17 runs, 208 assertions, 0 failures, 0 errors, 0 skips. The extra assertions are the
  `from=workspace` href, the canonical Details-link path, and the badge `aria-label`.
- `PARALLEL_WORKERS=2 bin/rails test:system` — 117 tests, 1,524 assertions, 0 failures, 0 errors,
  0 skips. The full browser suite is green, which is the point of the entry: a regression in a later
  change is now distinguishable from one of these four.
- `bin/rubocop test/system/tag_improvements_test.rb test/system/taxonomy_tree_test.rb` — 2 files,
  no offenses.

Not run: `bin/rails test` and `bin/rails test:system`'s non-browser companions were not extended
because no application, model, or view code changed — the four edits are test expectations and
selectors, and the full browser suite is the suite that covers them. Also not run:
`bin/brakeman --no-pager`, `bin/bundler-audit`, `bin/importmap audit`, and `bun audit` (no
authorization rule, route, dependency, importmap pin, or schema changed), `bun run check:js` (no
client-side code changed), `UNIVERSE=dark|lotr bin/rails db:demo:check` (no `db/data` manifest
changed), and `db:demo:reset`/`db:restart`/Docker/Kamal deployment (destructive, needs approval).

**Follow-up verification (2026-09-29, membership self-mutation — quirk 48)**

- `bin/rails test` — 1,060 tests, 6,338 assertions, 0 failures, 0 errors, 7 skips.
- `bin/rails test test/controllers/memberships_controller_test.rb` — 14 tests, 60 assertions,
  0 failures, 0 errors, 0 skips.
- `bin/rubocop` — 324 files, no offenses.
- `git diff --check` — clean.

Not run: `bin/rails test:system` (the fix is server-rendered ERB with no client-side path, and the
request suite asserts the markup the browser would render), `bin/brakeman`, `bin/bundler-audit`,
`bin/importmap audit`, and `bun audit` (no authorization rule, route, dependency, importmap pin, or
schema changed in this delivery), `UNIVERSE=dark|lotr bin/rails db:demo:check` (no `db/data`
manifest changed), and `db:demo:reset`/`db:restart`/Docker/Kamal deployment (destructive, needs
approval).

**Follow-up verification (2026-09-29, universe address uniqueness — quirk 26)**

- `bin/rails test` — 1,074 tests, 6,395 assertions, 0 failures, 0 errors, 7 skips.
- `bin/rails test test/models/universe_test.rb test/models/translations_test.rb` — 24 tests,
  195 assertions, 0 failures, 0 errors, 0 skips.
- `bin/rails test test/controllers/universes_controller_test.rb` — 28 tests, 101 assertions,
  0 failures, 0 errors, 0 skips.
- `bin/rails test test/controllers/workspace_locale_test.rb` — 26 tests, 310 assertions,
  0 failures, 0 errors, 0 skips.
- `PARALLEL_WORKERS=2 bin/rails test:system` — 117 tests, 1,501 assertions, **2 failures, 2 errors**,
  0 skips. All four are pre-existing and in a surface this change does not touch, and they were
  recorded as the stale browser assertions finding in [`known_quirks.md`](known_quirks.md) and
  fixed the same day; see [Former quirk #60](#former-quirk-60-four-browser-assertions-in-the-tag-and-taxonomy-suites-were-stale-fixed)
  and its verification section below.
  (`test/system/tag_improvements_test.rb:16,60` and `test/system/taxonomy_tree_test.rb:22,302`:
  a workspace tab link that deliberately carries `from=workspace`, a taxonomy row that now holds two
  collapsed toggles, and a page-header badge that counts the tag the test itself creates). Both
  files reproduce all four on their own
  (`PARALLEL_WORKERS=2 bin/rails test test/system/tag_improvements_test.rb test/system/taxonomy_tree_test.rb`
  — 17 tests, 185 assertions, 2 failures, 2 errors), and none of them creates, renames, or updates a
  universe. An earlier full run on the same day also reported three further errors that did not
  reappear, which is the load sensitivity known quirk 58 describes.
- `PARALLEL_WORKERS=1 bin/rails test test/system/universe_story_test.rb` — 2 tests, 27 assertions,
  0 failures, 0 errors, 0 skips. The first run failed the pre-existing creation journey on an
  "All stories" navigation that never arrived; the identical run passed on re-run with no change,
  which is the flake recorded as known quirk 58 and the reason a single browser run is not read as
  a verdict.
- `bin/brakeman --no-pager` — 1 weak-confidence SQL-injection warning in
  `app/models/concerns/has_many_tags.rb:109`, a string-interpolated `joins` of table and column
  names taken from the model's own reflections. Pre-existing, and unrelated to this change.
- `bin/rubocop` — 324 files, no offenses.
- `git diff --check` — clean.

Not run: a manual browser pass outside the automated suite (no browser was attached to the
session that made this change), `bin/bundler-audit`, `bin/importmap audit`, and `bun audit` (no
dependency, importmap pin, or vendored asset changed), `bun run check:js` (no client-side code
changed), `UNIVERSE=dark|lotr bin/rails db:demo:check` (no `db/data` manifest changed; the two
registered universes keep distinct addresses), and `db:demo:reset`/`db:restart`/Docker/Kamal
deployment (destructive, needs approval).

**Follow-up verification (2026-09-29, Timeline layering and node accessibility — quirks 24 and 46)**

- `bin/rails test` — 1,084 tests, 6,428 assertions, 0 failures, 0 errors, 7 skips.
- `bin/rails test test/models/timeline_layout_test.rb` — 11 tests, 23 assertions, 0 failures,
  0 errors, 0 skips (4 tests before this change).
- `bin/rails test test/controllers/timeline_controller_test.rb` — 4 tests, 14 assertions, 0 failures,
  0 errors, 0 skips.
- `bin/rails test test/controllers/workspace_locale_test.rb` — includes the new Spanish
  `aria-label` assertion; green.
- `bun run check:js` — 137 tests across 8 files, 0 fail, 361 assertions.
  `timeline_controller.js` is unchanged, so its drawn-geometry cases are the same six as before.
- `bun run build:css` — Sass + PostCSS/autoprefixer clean; the built `.timeline-node` rule carries
  the `padding: 0` reset. `app/assets/builds/` is gitignored and was not edited by hand.
- `bin/rubocop` — 325 files, no offenses.
- `bin/brakeman --no-pager` — the one pre-existing weak-confidence SQL-injection warning in
  `app/models/concerns/has_many_tags.rb:109`, a string-interpolated `joins` of the model's own
  reflected table and column names. Unrelated to this change and already recorded above.
- `PARALLEL_WORKERS=1 bin/rails test test/system/timeline_test.rb` — 4 tests, 39 assertions,
  0 failures, 0 errors, 0 skips. Covers keyboard focus landing on the node, the popover opening on
  focus and on click, the node's computed geometry, and the empty timeline.
- `PARALLEL_WORKERS=1 bin/rails test test/system/timeline_test.rb test/system/workspace_navigation_test.rb`
  — 6 tests, 80 assertions, 0 failures, 0 errors, 0 skips.
- `PARALLEL_WORKERS=2 bin/rails test:system` — 120 tests, ~1,550 assertions, 1 failure and 1 error
  across the two runs, and **not the same two each time**: the first run failed
  `scene_locations_test.rb` (a Role field that appended to its existing value instead of replacing
  it), the second failed `scene_elements_test.rb` (a truncated Content field and a missing
  `.entity-row`). Both files are unmodified by this change and neither touches the Timeline; each
  reproduces green in isolation
  (`PARALLEL_WORKERS=1 bin/rails test test/system/scene_elements_test.rb test/system/scene_locations_test.rb`
  — 11 tests, 149 assertions, 0 failures, 0 errors, 0 skips). This is the load sensitivity recorded as
  known quirk 58: the shape is a partially-typed field and a row that never appeared, and the
  affected files move between runs, which is what distinguishes it from a real regression. Do not
  "fix" a test that failed this way — re-run it with fewer workers first.

Not run: `bin/bundler-audit`, `bin/importmap audit`, and `bun audit` (no dependency, importmap pin,
or vendored asset changed), `UNIVERSE=dark|lotr bin/rails db:demo:check` and
`db:demo:reset`/`db:restart` (no `db/data` manifest changed; the reset tasks are destructive and
need approval), Docker/Kamal deployment, and a manual browser pass outside the automated suite. The
pan/zoom interaction was not built, so there was no client-side interaction to verify beyond the
node's own focus/click/geometry coverage.

**Follow-up verification (2026-09-30, Event temporal self-reference — quirk 47)**

- `bin/rails test test/controllers/events_controller_test.rb test/controllers/modal_json_contract_test.rb`
  — 26 tests, 183 assertions, 0 failures, 0 errors, 0 skips (4 new cases: the declared contract on the
  rendered page, and the hand-built self reference).
- `bun test test/javascript/modal_form_controller_test.js` — 40 tests, 99 assertions, 0 failures
  (35 before this change; five new cases and one new assertion).
- `bun run check:js` — 142 tests across 8 files, 0 fail, 367 assertions. Biome rejected the first
  version of `restoreExcludedOptions` for a `forEach` callback that returned `insertBefore`'s value;
  the callback now has a block body.
- `bin/rails test` — 1,130 tests, 6,887 assertions, 0 failures, 0 errors, 7 skips.
- `bin/rubocop` — 327 files, no offenses.
- `bin/brakeman --no-pager` — 0 errors, plus the one pre-existing weak-confidence SQL-injection warning
  in `app/models/concerns/has_many_tags.rb:109` recorded above.
- `SE_CHROME_NO_SANDBOX=1 PARALLEL_WORKERS=1 bin/rails test test/system/modal_json_flow_test.rb` — 9
  tests, 116 assertions, 0 failures, 0 errors, 0 skips. `SE_CHROME_NO_SANDBOX=1` is required on this
  machine because the AppArmor user-namespace policy blocks Chrome's sandbox;
  `test/application_system_test_case.rb` documents that.
- `SE_CHROME_NO_SANDBOX=1 PARALLEL_WORKERS=2 bin/rails test:system` — 122 tests, 1,572 assertions,
  **0 failures, 0 errors**, 0 skips. A first run of the same command reported 14 failures and 8 errors,
  and they were not the same set on a second pass: a sign-in path that landed on `/` instead of
  `/session/new`, a `.modal.show` that never opened, a half-typed Scene Element field. That is the load
  sensitivity known quirk 58 describes, on a surface this change does not touch. Do not "fix" a test
  that failed this way — re-run it with fewer workers first.

Two things found while doing this, neither fixed here and neither part of the finding:

- **A dismiss control clicked while the modal is still fading in is silently dropped.** I first read
  this as "a modal in this application cannot be dismissed", which is wrong: a **Cancel** click and a
  direct `bootstrap.Modal.getInstance(...).hide()` both work — one attempt late. The instance reports
  `{isShown: true, isTransitioning: true}` immediately after `show()`, and Bootstrap's `hide()`
  returns while it is transitioning in, so the first click does nothing. That is recorded as
  **quirk 61** and referenced from the backlog slice that must be delivered before 27.4. It is also why
  no browser case can open a second editor on the same page: Capybara clicks as soon as the element
  exists, so the click lands inside the transition and the first modal keeps covering the list.
- I lost the first draft of the two browser cases to a `git checkout --` during that investigation and
  re-applied them; the file in the tree is the reviewed version and `git diff` shows only those two
  tests plus the helper.

**Follow-up verification (2026-09-30, deletion confirmations — quirk 59)**

- `bin/rails test` — 1,128 tests, 6,876 assertions, 0 failures, 0 errors, 7 skips.
- `bin/rails test test/controllers/characters_controller_test.rb test/controllers/items_controller_test.rb
  test/controllers/locations_controller_test.rb test/controllers/modal_json_contract_test.rb
  test/controllers/universe_bible_locale_test.rb test/models/translations_test.rb` — 78 tests,
  801 assertions, 0 failures, 0 errors, 0 skips.
- `bin/rails test test/docs_test.rb` plus the five other locale/ADR-adjacent controller suites
  (`sections`, `workspace_locale`, `events`, `universe_bible_locale`, `translations`) — 137 tests,
  1,275 assertions, 0 failures, 0 errors, 0 skips. `translations_test` is the check that matters most
  here: the three new keys exist in both locale files, carry the same `%{name}` interpolation, and
  the Events comment that claimed it was "the one delete confirmation of these six workspaces that
  states its own cascade" is no longer a claim.
- `PARALLEL_WORKERS=2 bin/rails test test/system/modal_json_flow_test.rb` — 8 tests, 107 assertions,
  0 failures, 0 errors, 0 skips. Its two delete journeys now accept whatever confirmation the row
  sends; the confirmation's content is a request-test concern, and the request tests read it.
- `PARALLEL_WORKERS=2 bin/rails test:system` — 121 tests, 1,559 assertions, 0 failures, **1 error**:
  `scene_locations_test.rb:79`, a `.modal.show` that never opened while typing into the Location
  picker. That file is unmodified and does not touch a delete confirmation; it reproduces green on
  its own (`PARALLEL_WORKERS=1 bin/rails test test/system/scene_locations_test.rb` — 6 tests,
  73 assertions, 0 failures, 0 errors, 0 skips), which is the load sensitivity known quirk 58
  describes and the same shape recorded in the Timeline verification above.
- `bun run check:js` — 137 tests across 8 files, 0 fail, 361 assertions. No JavaScript changed:
  `taxonomy_tree_controller.js` reads the same `data-confirm-message` attribute Section and SceneTag
  already read, and the Locations page now populates it.
- `bin/rubocop` — 327 files, no offenses.
- `bin/brakeman --no-pager` — 0 errors and the one pre-existing weak-confidence SQL-injection warning
  in `app/models/concerns/has_many_tags.rb:109`, a string-interpolated `joins` of the model's own
  reflected table and column names. Unrelated to this change and already recorded above.

Not run: `bin/bundler-audit`, `bin/importmap audit`, and `bun audit` (no dependency, importmap pin,
or vendored asset changed), `UNIVERSE=dark|lotr bin/rails db:demo:check`,
`db:demo:reset`/`db:restart`, Docker/Kamal deployment (no `db/data` manifest or schema changed; the
reset tasks are destructive and need approval), and a manual browser pass outside the automated suite.
The three changed confirmations were not observed in a hand-driven browser: the copy is server-rendered
into an attribute and every suite that reads it asserts the rendered value, so a browser could only
show the modal controller passing that attribute to `window.confirm`, which
`test/system/modal_json_flow_test.rb` already exercises for a Character row.

**Follow-up verification (2026-09-30, deferred modal dismiss — quirk 61)**

- `bun test test/javascript/modal_form_controller_test.js` — 46 tests, 108 assertions, 0 failures
  (40 before this change; six new cases).
- `bun test test/javascript/taxonomy_tree_controller_test.js` — 24 tests, 72 assertions, 0 failures
  (20 before this change; four new cases).
- `bun run check:js` — 152 tests across 8 files, 0 fail, 382 assertions. Four of the six new cases in
  `modal_form_controller_test.js` and three of the four in `taxonomy_tree_controller_test.js` fail with
  the deferral disabled, and the `hidden.bs.modal` case fails again when that handler is removed.
- `bin/rails test` — 1,154 tests, 6,997 assertions, 0 failures, 0 errors, 7 skips.
- `SE_CHROME_NO_SANDBOX=1 PARALLEL_WORKERS=1 bin/rails test test/system/modal_json_flow_test.rb
  test/system/taxonomy_tree_test.rb` — 25 tests, 322 assertions, 0 failures, 0 errors, 0 skips. Each of
  the three same-task cases fails with the deferral disabled, with `expected to find css
  "body[data-dismiss-closed='yes']"`: the dialog finished opening and never closed, which is the defect
  stated as an assertion.
- `SE_CHROME_NO_SANDBOX=1 PARALLEL_WORKERS=2 bin/rails test:system` — 128 tests, 1,652 assertions,
  0 failures, 0 errors, 0 skips.
- `bin/rubocop` — 329 files, no offenses.
- `bin/brakeman --no-pager` — 0 errors and the one pre-existing weak-confidence SQL-injection warning
  in `app/models/concerns/has_many_tags.rb:109` recorded above.

Two findings from doing this, both fixed here:

- **The first browser cases passed against the unfixed code.** `assert_no_selector ".modal.show"` is
  satisfied by the fraction of a second before the dialog has finished opening, and the dialog does not
  carry `show` until after the backdrop's own fade has run — a dismiss delivered in the same task as
  the open arrives before either. Each case now records `shown.bs.modal` and then `hidden.bs.modal` on
  the body and waits for both, which is what makes "it closed" mean something.
- **The second row's editor stopped deferring.** The window was first opened from the previous open's
  state alone, and nothing marked a dismissed dialog closed, so the next open believed the dialog was
  still open: Bootstrap's `show()` was then a no-op, no `shown.bs.modal` would ever close the window,
  and the next dismiss was dropped exactly as before. It surfaced only because the row-to-row browser
  case the defect had blocked could finally be written. That state now comes from `hidden.bs.modal`.

Not run: `bin/bundler-audit`, `bin/importmap audit`, and `bun audit` (no dependency, importmap pin, or
vendored asset changed), `UNIVERSE=dark|lotr bin/rails db:demo:check`, `db:demo:reset`/`db:restart`
(no `db/data` manifest or schema changed; the reset tasks are destructive and need approval), and a
manual browser pass outside the automated suite. Reduced motion was not exercised: the window this fix
closes is the opening transition itself, and the fix does not depend on which transition produced it.
