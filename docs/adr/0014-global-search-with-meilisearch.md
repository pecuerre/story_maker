# ADR 0014: Answer the top-bar search with Meilisearch, filtered by what the reader may read

- **Status:** Accepted
- **Date:** 2026-09-27
- **Related:** [`../architecture.md`](../architecture.md),
  [`../conventions.md`](../conventions.md),
  [`../development.md`](../development.md),
  [`../known_quirks.md`](../known_quirks.md),
  [0001](0001-universe-and-story-scope.md),
  [0005](0005-universe-access-levels.md),
  [0012](0012-client-side-verification-and-csrf.md)

## Context

The application had exactly one search: `SceneFilter` narrows one story's scene
list with SQL `LIKE`. Everything else — the characters, locations, events, items,
relations, ownerships, tags, and the story structure — had no way to be found
except by walking a list.

Two things were wanted from a top-bar search box: a dropdown that autocompletes
as someone types and looks into every object and every field, and a scope
dropdown to choose between the entire platform, the current universe, the current
story, and one kind at a time.

The first question was the search engine. SQLite is the only store, and the
owner asked for a real engine rather than SQL `LIKE`. The candidates were:

| Option | Cost |
| --- | --- |
| SQL `LIKE` over 19 tables | No new dependency, but "every field of every object" becomes a hand-written union per model, with no ranking, no typo tolerance, and no prefix search |
| Meilisearch | One service, one index, ranked and typo-tolerant answers |
| Elasticsearch / Solr / Meilisearch Cloud | The same as Meilisearch, hosted, with the data leaving the machine |

Meilisearch was chosen: it is a single binary, it needs no cluster, and it runs
locally with one `docker run`.

The second question was what happens when it is not there. The search box is in
the top bar, so it renders on every page, for guests, on the landing page. A
search that raised would take the page down with it.

## Decision

### One engine, reached through one client, degrading to a stated state

`Search.backend` is the whole surface: a real `Search::Client` when
`MEILISEARCH_URL` is set, and `Search::UnavailableBackend` when it is not. Every
engine failure is logged and re-raised as `Search::Unavailable`, which the
controller turns into a stated state — "Search is not available" on the results
page, an `available: false` payload for the dropdown — while the rest of the page
renders normally.

There is deliberately **no** SQL fallback. A fallback would mean two ranking
behaviours, two different answers to the same query, and no way to tell a reader
which one they were given. One code path is easier to test and easier to reason
about in an incident than two that are almost the same.

### Authorization is a filter, not a post-filter

A platform-wide search asks the engine only for documents whose universe the
reader may read: `universe_id IN [...]`, built from `Universe.visible_to(user)`.
That scope is the same rule `Ability` enforces — it is what
`Universe#readable_by?` is defined in terms of — so a private universe's records
are never fetched and then hidden. A reader with no readable universe is not
asked at all, because an unfiltered query would disclose the whole index.

The engine's API key never reaches the browser. The only request the client makes
is to this application's own endpoint, which computes the filter server-side. A
search-only key is therefore enough in a deployment, and the document store
should not be reachable from outside the application.

### Documents hold ids, not names, and their own path

A document is `{ id, kind, taxonomy, universe_id, story_id, title, body, url }`.

- **`universe_id`/`story_id`, not the universe's or story's name.** Renaming
  either would otherwise make every record that mentions it show a stale name and
  would need a reindex to fix. `Search::Catalog` resolves the displayed context in
  two queries at read time instead, whatever the page size.
- **`url`, because a hit is a link.** Making the engine return a bare id would
  push route knowledge into every view. A document's path embeds its own record's
  slug, which is assigned when the record is created; a universe's slug change is
  the one case that invalidates paths below it, and a rename queues
  `Search::ReindexUniverseJob` for exactly that.
- **A story-scoped record keeps both ids**, so a platform-wide filter can reach it
  without a join.
- **A universe or story name is not searchable.** Matching every record of a
  universe because someone typed its name would bury the record they meant.

### Writes are queued, and the index is derived data

`Searchable` enqueues `Search::IndexRecordJob` after commit, so a save never
blocks on — or fails because of — a search service, and the document is built at
commit time so the job writes the state that was committed rather than whatever
exists when it runs. A destroy enqueues a removal by id, because the record is
already gone.

`bin/rails search:reindex` is the bootstrap and the repair. It creates the index,
applies its settings, clears it, and writes every document in batches, awaiting
each task **and checking it**. That last part is not optional: Meilisearch refuses
a whole batch over one document it dislikes and answers with a task that looks
exactly like a successful one until it is read. During development a reindex
reported "indexed 214 documents" while the index held none, because every
document id used a `:` the engine does not allow. A reindex that does not check
its tasks cannot fail.

### The results page is the primary surface; the dropdown is the enhancement

The box is a plain GET form. Submitting it opens `/search` (or
`/u/:universe_slug/search`), which is shareable, works with scripting off, and is
where a result set can be explained — a count, a scope, a dropped value, an
unavailable engine. The dropdown asks the same URL for JSON and renders it in
place.

`SearchesController` skips the shared `set_current_story` callback and resolves
the current story itself. The shared callback remembers `params[:story_id]` in the
session, so without that skip, typing in the search box would silently switch the
story the whole workspace is working in. `Search::Query` then treats the story id
as a *boundary*: it is resolved against the current universe, dropped and reported
when it belongs to another one, and — importantly — it does not narrow the search
on its own, because the top-bar form always carries the current story so the
reader can pick "this story" without a page load.

### A scope is resolved, never trusted

Asking for this story with no story selected widens to the widest boundary that
does exist and says so, in the same way `SceneFilter` reports a section id from
another story. The request keeps `scope=story` in its URL so choosing a story is
one click, while the control shows the scope that was really searched. An
unrecognized scope is reported the same way; a *missing* one is not, because a
form that says nothing is not an error.

## Consequences

- A developer needs a Meilisearch to search at all. `bin/rails search:reindex` and
  `bin/rails search:status` are the tools, and the box says it is unavailable
  rather than pretending to be empty.
- The test suite does not need an engine. `SearchTestBackend` stands in for one
  and the suite asserts what the application does with an answer.
  `test/search/meilisearch_integration_test.rb` covers the engine's own contract
  and is opt-in, because that contract has real teeth and cannot be faked.
- CI does not run an engine. That is a real gap: nothing in the default suite
  proves the engine accepts our documents. The opt-in file is the mitigation, and
  it is run deliberately rather than continuously.
- A write that the engine refuses asynchronously is invisible to the job that
  queued it. See `docs/known_quirks.md`.
- The index holds descriptions and prose in a second store, so a deployment that
  runs Meilisearch somewhere else is exporting the universe's text to it. That is
  a decision to make per deployment, not per request.

## Alternatives rejected

- **SQL `LIKE` over every model.** No dependency, no second store, and no data
  leaving the machine — but no ranking, no prefix or typo tolerance, and a
  hand-maintained union for every field of every object. This remains the honest
  answer for a deployment that cannot run a service, which is why the unavailable
  state is a first-class answer rather than a crash.
- **SQLite FTS5.** Available in this application's SQLite build, so it would have
  added no dependency either. Rejected because a virtual table per searchable
  model means triggers or callbacks to keep it in step with the real tables, and
  drift there is as silent as drift in an external index.
- **Elasticsearch or Solr.** A cluster to operate for a single-user universe
  writer. Meilisearch is the same idea in one binary.
- **A SQL fallback behind the engine.** Rejected above: two answers to one
  question.

## Related documentation

- [`../features/search.md`](../features/search.md) — the search subsystem: the request, the
  scopes, the registry, the dropdown, and the contrast rules a browser test measures
- [`../conventions.md`](../conventions.md#routes) — the two search routes, and why serving two
  formats from one read is safe here
- [`../visual_design.md`](../visual_design.md#search) — the painted treatment of the box and panel
- [`../development.md`](../development.md#search-engine) — running the engine locally
- [0001](0001-universe-and-story-scope.md)
- [0005](0005-universe-access-levels.md)
- [0012](0012-client-side-verification-and-csrf.md)
