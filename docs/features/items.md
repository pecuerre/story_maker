# Items

Items are Universe-owned records shared by every Story in that Universe. Their workspace is the flat
list at `/u/:universe_slug/items`, and each record's own page is `/u/:universe_slug/items/:id`. The
table, hierarchy, positions, and soft-delete cascade are summarized in
[data_model.md](../data_model.md); the flat-list and modal patterns they follow are in
[conventions.md](../conventions.md).

## Item profile

An Item records its name, its place in the hierarchy, optional tags, a photo, a short summary,
and one Markdown description. Every field except `name` is optional, and none changes what an Item
is.

| Field | What it records |
|---|---|
| `name` | The object's name |
| `item_tags` | Optional Universe-scoped Item Tags |
| `parent` | The item this one belongs to, if any; the reverse is its children |
| `summary` | One line shown in the list and at the top of the details page; plain text that may carry a reference |
| `description` | The full profile, written in Markdown |

There are deliberately no separate what-it-does, how-it-is-used, side-effects, origin, value,
cannot, constraints, history, or jargon columns: those are `##` sections inside `description`, which
keeps the form short and lets the author choose the shape of an object's profile. A blank summary or
description means that the author has not recorded an answer.

The summary is one line of plain text and is never rendered as Markdown, but it accepts the same
`[[kind:slug]]` references as the description. The Items list shows **only** the summary as its
row's second line, with each reference reduced to the record's name and never a link, the same rule
the Character and Faction lists follow ([characters.md](characters.md#references-in-a-summary)); an
Item with no summary has no second line, because the full profile belongs to the details page. On
the details page the summary appears at the top with its references linked, above the rendered
description.

The description is stored as Markdown and rendered on the details page: `##` becomes a heading,
`**text**` becomes bold, and lists, tables, fenced code, and blockquotes keep their written form. The
dialect and the `[[kind:slug]]` reference syntax are the shared description dialect owned by
[characters.md](characters.md#links-inside-a-description) and implemented by `MarkdownDescription`.
An Item may therefore link a Character, Faction, Location, another Item, a Scene or Plot, or a canon
rule; a canon citation keeps its ledger id as the label (`[[canon:K47]]` reads as `K47`), while every
other kind is labeled with the record's name.

The editor is the Items modal, opened from a row in the list or from the details page's **Edit item**
control: it offers the name, the tag selector, the photo, the short summary, and the Markdown
description, in that reading order, in the same wide, scrollable dialog the other flat-list record
editors use. The summary and description are read-only outside the editor, like the rest of the
workspace.

## Ownership and history

Who owns an Item is **not** a profile field and is never typed onto the Item. Ownership is a dated
`Ownership` record linking a Character to an Item, so it is corrected by adding or closing a record
rather than by editing a sentence that would go stale. An ownership with no `to_date` is an open
interval and the Character still holds the item; one with a `to_date` is closed and the Character no
longer does.

The details page states both readings as facts, and each list row repeats them: the characters whose
ownership is still open are named under **Currently owned by**, and the characters whose ownership
has ended are named under **Previously owned by**. `ItemsHelper#item_current_owners` and
`#item_historical_owners` resolve the two lists, and both are the single source of that wording.

The description's `## History` section is the authored prose about past uses and events. It is
deliberately separate from the ownership records: the records answer who held the item and when,
while the prose answers what happened around it.

## Finding an item

Item text search covers the name, the short summary, and the description, so a writer who remembers
only that an object came from a particular forge or cannot cross running water still finds it through
the prose that now records it. The Items list's `q` filter covers the same columns. The filter
contract itself is in [list_filters.md](list_filters.md).

The read-only JSON API at `/api/u/:universe_slug/items` returns the name, summary, description, tag
ids, parent id, and position.

## Sample item records

Both checked-in development universes include populated short summaries and a mix of full and blank
descriptions, so the list and the details page can be read full and empty. `db/data/dark/items.yml`
describes the Jonas Key, the Tannhaus Clockwork Device, the St Christopher Medal, the Sphere Machine,
and the God Particle; `db/data/lotr/items.yml` describes the One Ring, Sting, Andúril, Belthronding,
and the Ring of Barahir, leaving Belthronding thin. The One Ring links a canon rule in its
description and a Character in its summary, so the shared reference dialect is visible on an item
page and in a list row.

After changing either manifest, validate and reload both development universes with the workflow in
[development.md](../development.md#required-workflow-after-editing-demo-yaml):

```sh
script/demo check dark
script/demo check lotr
script/demo reset dark lotr
```

Then sign in as `dark@dark` (or `lotr@lotr`) with the development password from `.env`, open
`/u/dark/items`, and choose **Jonas Key** to read a full description beside its recorded owners, or
**The God Particle** for a thin one. `/u/lotr/items` and **The One Ring** show the same page in the
other universe.
