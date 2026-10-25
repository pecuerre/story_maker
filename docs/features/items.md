# Items

Items are Universe-owned records shared by every Story in that Universe. Their workspace is the flat
list at `/u/:universe_slug/items`, and each record's own page is `/u/:universe_slug/items/:id`. The
table, hierarchy, positions, and soft-delete cascade are summarized in
[data_model.md](../data_model.md); the flat-list and modal patterns they follow are in
[conventions.md](../conventions.md).

## Item profile

The Item editor records the object's name, description, optional tag assignment, parent, photo, and
any number of optional profile answers. `description` is the answer to **what it is**; every other
answer is a separate plain-text field, and every one may be left blank. None is validated for
presence, and none changes what an Item is.

| Field | What it records |
|---|---|
| `description` | What the item is |
| `what_it_does` | What it does |
| `how_it_is_used` | How it is used |
| `side_effects` | What using it causes beyond its purpose |
| `origin` | Where it comes from |
| `value` | What it is worth, in money or otherwise |
| `cannot` | What it cannot do |
| `constraints` | Limits or restrictions on its use |
| `history` | Past uses or significant events involving it |
| `jargon` | The names and terms the world uses for it |

`Item::PROFILE_FIELDS` is the single ordered list the profile answers are read from. The editor's
fields, the details page's facts, the list filter's text columns, the search body, and the API all
read it, so a new column is added to the list and appears everywhere rather than needing five
separate edits.

An empty answer renders the shared blank copy on the details page, never an empty row. The profile is
read-only outside the editor: like the rest of the workspace, an Item is changed through its modal.

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

The `history` profile answer is the authored prose about past uses and events. It is deliberately
separate from the ownership records: the records answer who held the item and when, while `history`
answers what happened around it.

## Finding an item

Item text search covers the name, the description, and every profile answer, so a writer who
remembers only that an object came from a particular forge or cannot cross running water still finds
it. The Items list's `q` filter covers the same columns. The filter contract itself is in
[list_filters.md](list_filters.md).

The read-only JSON API at `/api/u/:universe_slug/items` returns every profile field beside the
existing identity values.

## Sample item records

Both checked-in development universes include populated and blank profile answers, so the details
page can be read full and empty. `db/data/dark/items.yml` profiles the Jonas Key, the Tannhaus
Clockwork Device, the St Christopher Medal, the Sphere Machine, and the God Particle;
`db/data/lotr/items.yml` profiles the One Ring, Sting, Andúril, Belthronding, and the Ring of Barahir,
leaving most answers on Belthronding blank.

After changing either manifest, validate and reload both development universes with the workflow in
[development.md](../development.md#required-workflow-after-editing-demo-yaml):

```sh
script/demo check dark lotr
script/demo reset dark lotr
```

Then sign in as `dark@dark` (or `lotr@lotr`) with the development password from `.env`, open
`/u/dark/items`, and choose **Jonas Key** to read a full profile beside its recorded owners, or
**The God Particle** for a thin one. `/u/lotr/items` and **The One Ring** show the same page in the
other universe.
