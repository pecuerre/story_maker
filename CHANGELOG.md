# Changelog

Universe Maker does not have release versions yet. This file is a date-based history of the
project instead. It records application code, site/UI behavior, schema and data, tests,
documentation, configuration, security, and tooling. Entries are grouped by calendar date in
reverse chronological order; related commits from the same day are consolidated into summaries.
Within a date, entries are grouped by label in the legend order below and, inside one label group,
kept in reverse chronological order. A blank line separates two label groups and one date section
from the next, and never appears inside a group. The initial history was reconstructed from the
repository's Git history through 2026-09-25. Dates without recorded project changes are omitted.

Labels used below:

- `added` — a new capability, model, workflow, or interface
- `changed` — behavior, architecture, data shape, or visual design was reworked
- `fixed` — a correctness, persistence, routing, or usability problem was resolved
- `security` — authentication, authorization, privacy, or data-integrity hardening
- `docs` — project knowledge, decisions, or contributor guidance changed
- `chore` — tests, fixtures, seed data, dependency, CI, or maintenance work
- `planned` — a documented future direction; not implemented in that entry

## 2026-09-29

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
  all. See [ADR 0015](docs/adr/0015-record-photos.md).
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
- **[docs]** Updated the tag data model, workspace conventions, and development guide with the
  grouping, menu-navigation, and demo-data verification behavior.
- **[chore]** Dark demo data now calls the Character grouping tag **Factions** and pins both
  **Factions** and the assignable **Family Nielsen** tag in the workspace menu. Request tests cover
  grouped child results and the different workspace/taxonomy navigation paths.
- **[planned]** Backlog item 26 records a safety follow-up: `db:demo:reset` invoked Rails `db:drop`,
  which also dropped the local test database. The implementation remains deferred; approval for a
  development-data reset must never extend to test or production databases.

## 2026-09-28

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
- **[docs]** `AGENTS.md` now requires checking [`docs/known_quirks.md`](docs/known_quirks.md) for a
  related open quirk before starting any [`docs/backlog.md`](docs/backlog.md) item and asking the
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

## 2026-09-27

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
- **[docs]** New [ADR 0014](docs/adr/0014-global-search-with-meilisearch.md) records why Meilisearch
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
- **[docs]** New [ADR 0013](docs/adr/0013-platform-settings-and-browser-theme.md) records why settings
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
  in [ADR 0007](docs/adr/0007-story-owned-scenes-and-elements.md).
- **[added]** `SceneItem` (`scene_items`: `scene_id` + `item_id` with real foreign keys, a unique
  pair index, and a nullable free-text `role`) is a join model for the same reason `SceneCharacter`
  is: the role is part of the decision, and a blank role means no role rather than an empty
  annotation. The **Items** tab is its own canonical read page with add, role-edit, and remove
  through the shared modal contract from [ADR 0011](docs/adr/0011-modal-json-mutation-contract.md).
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
  [ADR 0007](docs/adr/0007-story-owned-scenes-and-elements.md) record the delivered state: every
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
  [ADR 0011](docs/adr/0011-modal-json-mutation-contract.md) rather than building a second editor, and
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
  [ADR 0007](docs/adr/0007-story-owned-scenes-and-elements.md) record the delivered slices, the
  hybrid response split, the two flat ordered sequences, the participation union, and the manual
  verification steps. `docs/known_quirks.md` findings 22 and 23 now name the second flat sequence
  and the two new constrained join tables.
- **[chore]** New client-side coverage: `test/javascript/scene_element_form_controller_test.js` and
  five cases for the shared modal controller's `move` action, bringing the Bun suite to 75 cases.

- **[added]** Closed known quirk 33 with a real client-side pipeline, recorded as
  [ADR 0012](docs/adr/0012-client-side-verification-and-csrf.md). The Stimulus controllers now have
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
  paragraph was removed and its history already recorded in `docs/resolved_quirks.md`, the dated
  follow-up verification log moved there as a **Verification history** section, and the 2026-09-24
  audit baseline is labeled as the evidence behind the findings rather than a capability list.
  Quirk 33 itself moved to `docs/resolved_quirks.md`. The rules stay in `AGENTS.md` and are now
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

## 2026-09-26

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
  depend on, recorded as [ADR 0011](docs/adr/0011-modal-json-mutation-contract.md). A modal page now
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

## 2026-09-25

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
  [ADR 0008](docs/adr/0008-explicit-development-universe-loader.md) directly. No application code,
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

## 2026-09-24

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

## 2026-09-23

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

## 2026-09-22

- **[changed]** Replaced the early per-content “type” taxonomies with hierarchical tags and
  standardized content-to-taxonomy links as many-to-many associations, updating models,
  controllers, views, routes, fixtures, migrations, and demo data together.
- **[changed]** Refined the left navigation and sidebar presentation as the taxonomy workspaces
  expanded.

## 2026-09-21

- **[changed]** Improved the sidebar and universe/story menu structure, labels, and visual
  presentation in preparation for the larger workspace redesign.

## 2026-09-15

- **[fixed]** Adjusted the application route shape to keep the new universe scope consistent
  across navigation and resource URLs.

## 2026-09-14

- **[changed]** Replaced the original Story-centered root with a Universe-centered domain across
  controllers, models, routes, views, deployment metadata, demo data, tests, and documentation.
- **[changed]** Added more navigation options while the top-level universe model was introduced.

## 2026-09-12

- **[added]** Added foreground-color support to taxonomy tags and the relevant editor/badge UI.

- **[changed]** Expanded the Dark development dataset and moved its seed records toward YAML files
  with ordered loaders and symbolic references for sections, content, taxonomies, relations, and
  ownerships.

- **[fixed]** Updated test fixtures and expectations to match the expanded YAML-backed data.

- **[chore]** Added and refreshed frontend dependency locks, fixtures, and tests during the data
  migration; the temporary Yarn setup was later replaced by the project-wide Bun standard.

## 2026-09-11

- **[added]** Made the Timeline functional with event layout, edges, popovers, and an interactive
  timeline controller.

- **[changed]** Added taxonomy colors, many-to-many element/taxonomy support, Tom Select pillbox
  multi-selects, slugs across models, and a refactored per-universe seed-data layout.
- **[changed]** Improved the left menu and interactive editors as the world-building workspaces
  became more complete.

- **[docs]** Added the Mozilla Public License 2.0 to the project.

## 2026-09-10

- **[added]** Added the first Event and Timeline models, routes, views, layout algorithm, and
  timeline styling.
- **[added]** Added entity counts to the navigation menus.

## 2026-09-09

- **[changed]** Refactored routes and the character workspace, improved the complete character
  view, and refreshed visual navigation and menus.

- **[fixed]** Repaired ownership persistence and taxonomy drag-and-drop behavior.
- **[fixed]** Corrected data/controller integration issues found while expanding the content
  workspaces.

## 2026-09-07

- **[added]** Added Ownerships and Ownership Types, including their controllers, views, routes,
  schema, fixtures, navigation entries, and tests.

## 2026-09-05

- **[changed]** Added conventional list/modal views for Characters and Items and improved the
  surrounding menu.

## 2026-09-04

- **[added]** Added Locations, Items, Characters, and Relations, together with their first taxonomy
  models, schema, controllers, views, routes, fixtures, and navigation.

- **[changed]** Organized migrations and taxonomy nodes, and made taxonomy selection required in
  the early content workflow (this was later relaxed when tags became optional everywhere).
- **[changed]** Improved menus and visual consistency across the growing workspace.

- **[fixed]** Repaired item persistence, taxonomy drag-and-drop, and associated tests.

## 2026-09-03

- **[added]** Added Sections and made Sections work as a taxonomy, completing and hardening the
  tree-based taxonomy editor.

- **[changed]** Improved seed data, test coverage, and menu organization around the new section
  hierarchy.

## 2026-09-02

- **[added]** Added Section Types and the first interactive taxonomy-tree editor.

- **[fixed]** Corrected route generation and the right-sidebar presentation.

## 2026-09-01

- **[added]** Established the Rails 8 application foundation with SQLite, Solid Cache/Queue/Cable,
  Docker/Kamal deployment files, CI/security tooling, Bootstrap, Sass/PostCSS, and the initial
  development workflow.
- **[added]** Added Users, Sessions, Stories, password reset, sign-in/sign-out, and the first
  Story CRUD workspace.

- **[changed]** Added story slugs, initial Dark/LOTR seed data, and the initial navigation shell.
