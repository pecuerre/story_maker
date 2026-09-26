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

## 2026-09-27

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
