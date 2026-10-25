# List filters

One home for the contract **every** in-list filter shares. Every in-list filter in the application
follows it; the Scenes, Characters, Items, Events, Relations, and Ownerships lists each carry their
own keys, and so do Locations and all nine tag taxonomies, and each workspace makes its own
decisions about them. The Scene filter's are in
[`scenes.md`](scenes.md#the-list-the-filter-and-the-ordering).

## What a list filter is

`ListFilter` (`app/models/list_filter.rb`) is a **value object**. It reads only the query keys its
subclass declares in `PARAMS` and never assigns them to a model, so a filtered list stays a plain
HTML GET with no mutation path, no mass assignment, and nothing for a CSRF token to protect. It is
the same kind of object as `Search::Query` and `Search::Scope`, and for the same reason: the request
is already parsed into something whose unusable values can be collected and reported rather than
guessed at.

The request side is `FilteredListQuery`
(`app/controllers/concerns/filtered_list_query.rb`). The split is the one the search query already
uses ([`search.md`](search.md#where-each-decision-lives)): the filter is a value object, and the
controller does the one thing a controller alone can, which is build a URL.

## The two halves of a filter

| Concern | Where |
|---|---|
| The recognized keys, what each means, and what it validates against | the subclass's `PARAMS` and `#resolve` |
| What the narrowed list is | the subclass's `#apply` |
| The canonical keys really in effect | the subclass's `#query_params` |
| Which orders the list offers, and how one is validated and applied | the subclass's `SORTS` and `DEFAULT_SORT` |
| Free text, free text across a record's linked endpoints, a tag, an inclusive day range, a value resolved from a loaded list, the chosen order | `ListFilter`, shared |
| Slicing the query, the one-shot canonical redirect, carrying the filter through an in-list mutation, reporting a drop | `FilteredListQuery` |
| What each value means to the reader | the workspace's own helper |

A subclass declares its keys and writes three methods, and inherits the rest.
`test/models/list_filter_test.rb` holds a complete worked filter — over `Character`, so it shares no
table, scope, or fixture with the Scene filter — which is the shape a new workspace copies.

## Two questions a list asks, not one

`active?` means **something is in effect**. `narrowed?` means **something that selects records** is in
effect. Only a sort separates them, and it is worth the distinction because two behaviours ask the
second question rather than the first:

- An empty result needs the "nothing matched" message, not the empty-database one. A sort cannot make a
  list empty, so a reader who only reordered it is never told nothing matched.
- A filtered list stops showing the reader's own pending rows. A sort selects nothing, so a reader who
  only reordered the list still sees the pending work they can act on.

`narrowed?` is `query_params` with the sort key taken out, which is why a filter with no sort answers
the same as `active?` and needs no special case.

## Rules a filter must not break

1. **A value is validated against a list the index already loaded.** The controller already has the
   story's Sections, the universe's tags, or the workspace's parent records in hand for the list and
   the form. Resolving a filter value against those costs no query and means a foreign or unknown id
   **cannot reach the query at all**, rather than reaching it and returning nothing.
2. **A value that cannot be used is dropped and reported.** Never swallowed, and never left to empty
   the list into looking like a reader's own mistake. It is dropped because guessing at an
   unresolvable value would answer a question the reader did not ask. The report is an
   `alert` flash joined with `to_sentence`.
3. **A dropped value is not carried into the URL.** `query_params` is the only source of the filter in
   a link or a redirect, and it holds what is really in effect. A request that asked for a value the
   filter dropped is reported, not redirected with the value still in the address bar.
4. **The report is translated where the value is dropped.** The filter is not a view and does not
   include the view's `translate` helper, so it calls `I18n.t` against the request's locale — the same
   call `Event`'s own `errors.add` messages make. The controller must join the reports **after**
   translation, or a sentence would be assembled with one language's connectors around another's
   words. See [`i18n.md`](i18n.md#a-value-object-that-is-not-a-view).
5. **`active?` means something is really in effect.** It is derived from `query_params`, not from
   whether the request carried a key, so a request whose only value was dropped renders an unfiltered
   list and says the value was ignored.
6. **A filter narrows; a sort orders.** A workspace decides its own order and may offer the reader a
   choice, but the choice is resolved against an allowlist and is applied by
   `ListFilter#sorted`. Three rules hold wherever it appears:
   - **An order clause is never taken from the request.** `SORTS` maps a query value to a column
     order, and a value outside it is dropped and reported like any other unusable value. A hand-edited
     URL must not be able to name a column.
   - **An order is a read-time choice and nothing else.** It is never written, so it cannot renumber a
     maintained sequence or contradict the order a drag control in the same workspace writes. A
     workspace whose list is a flat view of a hierarchy must not offer its `position` as a sort, because
     that position is a sibling order inside one branch and interleaving branches by it means nothing.
   - **Every order ends with the same tiebreaker.** Two records that tie on the chosen column would
     otherwise swap between two requests, so one shared link would show a different list each time it
     was opened.

   The default order is never spelled out in the URL: it is what the link means when `sort` is absent,
   so carrying it would put a reader's ordinary bookmark into every address bar. A positioned sequence
   such as the Scene list keeps its own order and offers no sort at all — see
   [`scenes.md`](scenes.md#the-list-the-filter-and-the-ordering).
7. **A null is never inside a range.** A record with no value in the compared column is excluded
   while a bound is set: it has nothing to compare.
8. **A `LIKE` from a search box is literal text.** SQLite's `LIKE` ignores ASCII case, which is what
   a search box needs, and `%` and `_` are escaped with an explicit `ESCAPE` character, so an
   author's percent sign is a character to find rather than a pattern matching everything. The
   columns are qualified with their table, because a narrowed relation may carry a join.
9. **Text that names what the record links is reached through the link, not the record.** A
   `Relation`'s label is `"A → B"` and an `Ownership`'s is a sentence; neither is stored, so the
   words a reader types for them are on the endpoint records. `ListFilter#narrowed_by_linked_text`
   searches the record's own columns and the named columns of each `belongs_to` endpoint, **by
   subquery rather than by a join**, so `#sorted`'s unqualified `ORDER BY id` stays unambiguous. A
   label the model composes in Ruby — `Ownership`'s translated sentence — cannot be matched in any
   language and is deliberately not faked.

## The empty result and the empty list are different sentences

Every filtered list keeps these apart, and they are the single most common thing a new list gets
wrong:

- An **empty database** — a story with no scenes, a universe with no characters — says the workspace
  has none, and offers the action that creates the first one. Only a writer is told to add one.
- An **empty result** says which filters produced nothing, **repeats the active filters so the reader
  can see which value emptied the list**, and offers **Clear filters**. It never offers "add one",
  because the workspace is not empty and a create action beside that message is answering the wrong
  question.

The active filters are also repeated as text above a narrowed list that *did* match, for the same
reason: a result set is otherwise ambiguous about what produced it.

Every summary is **its own key** rather than one frame with the field name interpolated, because
"Section: Chapter one" is a different sentence in each language than "In-world from 2026-09-11". The
summaries live in a helper rather than on the filter because most of their values come from the
workspace's own path objects — a Section's full ancestor path — which a filter has no business
holding.

A chosen order is summarized too, and for the same reason the empty result repeats its filters: a
reader who reordered a list and got fewer rows back has to be able to see that the order was applied
and was not the reason the list is short.

## A filtered list stays filtered

A universe that remembers changes appends the records the reader's own draft would create and badges
the ones it would edit or delete
([ADR 0023](../adr/0023-pending-changes-are-read-from-the-draft-and-drawn-as-badges.md)). A
remembered create has **no id**, so it cannot satisfy a filter on any column the author did not
submit. A filtered list therefore shows no pending rows at all; they are the unfiltered list's own —
and a list the reader only **sorted** keeps them, because an order selects nothing.

Decided once for every workspace, and settled in
[`backlog.md`](../backlog.md): the alternative of keeping them with a count puts a row outside the
filter the reader just applied, and matching them on payload values is the only option that can put
one in a result set, which needs the filter to read a draft payload rather than a record.

## Trees keep the order they were dragged in

Locations and every tag taxonomy are trees rather than flat lists: their rows are positioned by
dragging, and `HierarchyIndex` hard-codes `[position, id]`. A reader-chosen sort would show an order
the drag control contradicts, so **a tree offers no sort**: `ListFilter#sortable?` answers false,
`sort` is nil, and a tree's URL never carries a `sort` key. A tree's filter narrows by text and, for
Locations, by its own tag; it never reorders the tree.

The filter area of a tree lives in `shared/_taxonomy_tree` rather than in a workspace partial: one
search area, an optional tag select (tags carry no tags of their own), and no order control. The
pending rows a draft would create render as `.taxonomy-pending` nodes after the real roots, not as
rows, and a filtered tree shows none of them — a remembered create names no record, so it cannot
match a text or tag filter.

The header badge of a tree reads the **narrowed count**: how many records the filters show, not how
many the taxonomy holds. That is one count instead of two — the per-taxonomy views used to issue a
fresh `.count` while `TagsController` read `hierarchy.records.length` — and it matches the flat
lists, which show what the reader is looking at. A filtered tree that matched nothing shows the
no-match state: which filters produced nothing, repeated as text, and a way to clear them.

## What adding a filter to a workspace takes

1. A `ListFilter` subclass declaring its `PARAMS`, its `#resolve`, `#query_params`, and `#apply`, plus
   `SORTS` and `DEFAULT_SORT` when the workspace lets a reader choose an order. Nothing else, unless
   the workspace needs a narrowing this contract does not have.
2. `include FilteredListQuery` and `filters_list_with MyFilter, only: %i[ index …mutations… ]`.
   The mutation actions are named deliberately: an in-list mutation carries the filter back, so
   reordering or deleting inside a narrowed list does not dump the author on the full one. A
   workspace whose mutations are JSON-only and answer with no redirect names only `index`, because
   the browser refreshes the URL the reader is already on.
3. `#filtered_list_path_with`, the one thing the concern cannot know — where this list's own URL is.
4. A search area over the canonical URL, a `flash_discarded_filter_values` call, the two empty
   states, and a summaries helper.
5. Keys in **both** locale files, in the workspace's own `*.filter.*` namespace.
6. Tests, and the pending-row rule above in the index view.

## What this contract does not decide

- **Which fields to filter on.** That is the workspace's, from the fields its model already exposes.
- **Which orders to offer.** `SORTS` is the workspace's. The rules an order has to obey are the ones
  above; the choices are the model's business.
- **The boundary.** `Search::Scope` resolves what "this universe" means; a list filter is already
  inside the boundary its controller resolved from `Current.universe` or `Current.story`, and never
  widens or re-resolves it.
- **Whether a workspace sorts.** A positioned sequence has one order that means something and offers
  no sort; a flat list may offer one. That is a per-workspace decision, and `ListFilter` answers
  `sortable?` so a caller does not have to remember which filters have sorts.
- **Pagination.** Nothing here pages. A list narrows; whether it also pages is its own decision, and
  a filter that assumed one would be wrong the moment a workspace adds it.
