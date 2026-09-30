# Global search

[ADR 0014](../adr/0014-global-search-with-meilisearch.md) records why there is no SQL fallback
behind this. The top bar's layout and the painted dropdown live in
[visual_design.md](../visual_design.md); running the engine locally is in
[development.md](../development.md#search-engine).

The top bar carries one search box, and it is a plain GET form before it is anything else.
`shared/_search_bar` is the one partial both the top bar and the results page render. `GET /search`
searches the whole platform; `GET /u/:universe_slug/search` keeps a universe-scoped search inside that
universe's URL, so the shared universe callbacks resolve and authorize the scope exactly as they do
for every other page of that universe. Both routes, and the `Accept` behaviour that makes search the
one flow serving two formats from a single read, are in
[conventions.md](../conventions.md#routes). `search_path_for(universe, query)` builds both, for a form
that must work on either.

`SearchesController#show` is the one read that answers in two formats:

- **HTML** is the results page: shareable, keyboard-reachable, usable with scripting off, and the
  only place a result set can be explained (the count, the scope, a dropped value, an engine that is
  not answering).
- **JSON** is the dropdown, asked for by `search_controller.js` as the reader types. It carries
  `available`, `reason`, `query`, `scope`, `scope_label`, `total`, `discarded`, `commands`, and
  `results`.

The read never writes, so it has no mutation path, no mass assignment, and nothing for a CSRF
token to protect. That is also why `searches` does not use `RequiresJsonMutationFormat`: it serves
both formats from one read-only action, which is not the ambiguous HTML-and-JSON *mutation* that
guard exists to forbid.

## Where each decision lives

| Concern | Where |
|---|---|
| The request: text, scope, story boundary, and every value that could not be used | `Search::Query` (`PARAMS`, `discarded`, `query_params`) |
| The scope dropdown: a boundary (platform / universe / story) or a kind ("only characters"), resolved rather than trusted | `Search::Scope` |
| Authorization and display: the filter sent to the engine, and the context names of each hit | `Search::Catalog` |
| Navigation destinations | `Search::Commands` |
| The engine, and the one place that speaks to it | `Search::Client` / `Search::UnavailableBackend` |
| Which models are indexed | `Search::Registry` |
| What one record contributes | the model's own `searchable` declaration (`Searchable`) |
| Rebuilding the index | `Search::Reindexer`, `bin/rails search:reindex` |
| When a save or destroy reaches the index | `Search::IndexRecordJob`, `Search::RemoveRecordJob` |

## Rules that must not drift

1. **The engine is reached through `Search.backend` and nowhere else.** A real `Search::Client` when
   configured, `Search::UnavailableBackend` when not. Every engine failure becomes
   `Search::Unavailable`, which the controller states rather than raises, because the box renders on
   every page. There is no SQL fallback: one query, one ranking, one answer. The state is stated twice
   over, in two registers: `Search::UnavailableBackend::REASON` is the **operator's** sentence and is
   what a log line, an exception message, and `bin/rails search:reindex` carry, while the page prints
   `searches.unavailable_reason` under a heading of its own — a reader's sentence, in the reader's
   language, naming the same environment variable and the same command.
2. **Authorization is a filter, not a post-filter.** `Search::Catalog` sends
   `universe_id IN [...]` built from `Universe.visible_to(user)` — the same rule `Ability`
   enforces — and a reader with no readable universe is not asked at all. The engine's key never
   reaches the browser.
3. **A search never changes the current story.** `SearchesController` skips `set_current_story`,
   because that callback would remember `params[:story_id]` in the session, and resolves the story
   itself. A story id alone is not a boundary: the scope decides that, so the top-bar form can
   carry the current story for a later scope choice without narrowing the default search.
4. **A scope is resolved, not trusted.** An unhonourable request widens to the boundary that exists
   and says so; the URL keeps what was asked for; the control shows what was searched.
5. **A value that cannot be used is dropped and reported**, in the `discarded` list and as a
   `flash.now[:alert]`, in the same spirit as `SceneFilter`. A missing scope is not an error; an
   unrecognized one is. `query_params` is the only source of the search in a link.
6. **Documents hold ids and their own path, never a universe's or story's name.** Displayed context
   is resolved per request by `Search::Catalog#describe`, so a rename needs no reindex.
7. **A model that becomes searchable declares it once**, next to its fields: `searchable kind:,
   title:, body:, route:, scope:, taxonomy:` plus `include Searchable`. Add the model to
   `Search::Registry::MODELS` in the same change, and if it is story-scoped without its own
   `story_id` (a Scene Element is the only one), give it its own `search_scope`. The test that walks
   the registry and builds every document is what keeps that list true.
8. **The reindex must check its tasks.** `Search::Reindexer` awaits each one and raises
   `Search::ReindexFailed` on a failure, because the engine refuses a whole batch over one document
   it dislikes and otherwise reports success while storing nothing.
9. **A label a reader sees is translated at read time; a value they act on is not.** A scope's
   `value` and a command's `id` travel in a URL and into the dropdown, so they are English in every
   locale; the label beside each is a key. That is why `Search::Scope::Option` holds no string at all —
   its label key *is* its value — and why a command's `title` is resolved per request and is also what
   the typed text is matched against, so the thing on screen is the thing searched.

## A result row shows the stored document title

`Search::Hit#title` is the document's own `title` field, read straight back out of the index, and a
document is **language-independent by design**: one index serves every reader. A record whose own label
is a sentence — an `Ownership` with no name, which is `"X owns Y"` — therefore shows that sentence in
the default locale on a result row, while its own list and its own page show the reader's language.

That is a decision, not an oversight, and the alternatives are worse:

- **Translate it in the model** and a document written during a Spanish request stores Spanish chrome,
  which every English reader of that universe then sees. Reindexing in a second language would change
  every document again.
- **Store the parts and compose at read time** — a second document field holding the two names, and a
  composer in `Search::Catalog` — so every surface agrees. It extends the `searchable` declaration for
  one sentence, needs a reindex to populate the field, and has to be extended again for `Event`'s
  chain of relationships before it is really general.
- **Leave the record's label out of the index** so no chrome is ever stored. Then an unnamed Ownership
  is unfindable by its endpoints, which is the only thing that identifies it.

The stored half of the contract is `Model#display_string`, and the read half is `Model#display_label`;
[`features/i18n.md`](i18n.md#a-record-label-that-is-also-a-search-documents-title) owns the rule. A
change to the default locale's `ownerships.display_label` is therefore an index-content change, and
`bin/rails search:reindex` is what makes an existing index agree with it.

## Both surfaces, one read

`searches/_scope_field` is one partial for both search surfaces, and the caller's optional `class`
is what says which one this is: the top bar passes `navbar-search-scope`, painted for the
always-dark navbar, and the results page passes nothing and gets the ordinary theme-aware form
control. A bar-only treatment hard-coded into the partial lands on a page that follows the theme,
so keep it in the caller's class.

`searches_helper.rb` supplies the rest: `search_scope_options` (which disables what the page cannot
honour), `search_selected_scope` (the *resolved* scope, so a widened search never displays a choice
that does not describe it), and `search_path_for(universe, query)`.

Every word on both surfaces is in `searches.*`, including the copy the two model-level classes read:
`searches.scopes.*` (an option's label, keyed by its value), `searches.kinds.*` (a result row's badge),
`searches.commands.*` (a destination's title), and `searches.discarded.*` (a value a request could not
use, translated where it is dropped so the controller's `to_sentence` joins them in the reader's
language). `test/controllers/searches_locale_test.rb` holds the rendered page in Spanish;
`test/models/search/{scope,query,commands,kinds}_test.rb` hold the four value objects.

## Client-side rules

Per [ADR 0012](../adr/0012-client-side-verification-and-csrf.md), `search_controller.js`:

- builds every node with DOM APIs — a result carries the author's own words, so it is never
  interpolated into `innerHTML`;
- keeps focus in the input while `aria-activedescendant` moves a cursor through the options;
- drops a stale answer to a question that has been retyped;
- asks for nothing before `Search::Dropdown::MINIMUM_LENGTH` characters;
- receives its strings from the server as a rendered JSON blob, not from a hardcoded English
  literal.

It has a `bun test` case in `test/javascript/search_controller_test.js` and a browser case in
`test/system/search_test.rb`.

## Painted rules that are measurements, not preferences

Two of these are asserted in a real browser by `test/system/search_test.rb`, because a color here is
something someone has to measure, not a value a stylesheet review can approve.

- **A highlight raises contrast; it never lowers it.** The matched run wears an opaque fill and an
  opaque text color, both declared in Sass next to the rest of the bar's colors. A translucent fill
  is resolved by the browser onto the panel beneath it, which turns a 35% amber into a brown the run
  is *harder* to read on than the near-white beside it — and it also picks up the row's hover tint,
  so the one run the reader is tracking moves under the cursor. The test holds the run to WCAG AA, to
  at least the legibility of the panel's dimmest line, and to a fill distinguishable from the panel.
- **Every option row is painted by the panel, never inherited from the page.** The controller names
  a row `navbar-search-#{kind}` — `command` in the "Go to" group, `result` in the "Results" group —
  so a kind missing from the row selectors keeps the theme's own anchor color: link blue on the bar's
  near-black panel, 2.6:1, in a row with no padding, no radius, and no cursor of its own. A kind
  nobody styled does not look like a slightly different row, it looks broken. A new kind joins the
  row selectors in the change that introduces it, the highlight is keyed on
  `.navbar-search-result-title` rather than on a kind so every marked run wears the same fill, and
  the test holds the *worst* option in the list to AA, the panel to one highlight fill, and the
  keyboard cursor to a visible change of surface.
- **Nothing inside the dropdown is positioned against the form.** The results list and the "See all
  results" link share one absolutely positioned wrapper (`.navbar-search-panel`), and it is the only
  thing placed against the form. The form is no taller than the field, because the results are out
  of flow, so a child positioned on its own resolves against the *field*: the link laid itself across
  the bottom of the input and hid the text being typed, along with the caret. A new part of the panel
  goes in that wrapper and sits in flow.

## Navigation links out of here

Every `universe_*` route helper takes named keys, **including from a model**. Search builds paths
from `app/models/concerns/searchable.rb` and `app/models/search/commands.rb`, which are outside any
request, so `universe_slug` is passed explicitly there rather than relied on from recall. A search
result's own link is the path stored in the document, not a route rebuilt at render time.
