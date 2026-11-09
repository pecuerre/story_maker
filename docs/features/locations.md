# Locations

Locations are Universe-owned records shared by every Story in that Universe. Their workspace is the
hierarchical tree at `/u/:universe_slug/locations`, and each record's own page is
`/u/:universe_slug/locations/:id`. The table, its parent and position rules, and its soft-delete
cascade are summarized in [data_model.md](../data_model.md); the hierarchy, tags, editor, and page
patterns they follow are in [conventions.md](../conventions.md).

## Workspace tabs

The Locations workspace is three tabs reached through the shared tab strip: **Locations** (the
hierarchical tree described below), **Routes**, and **Map**. Each tab is a separate request with its
own canonical URL — `/u/:universe_slug/locations`, `/u/:universe_slug/routes`, and
`/u/:universe_slug/map` — so the left sidebar keeps one **Locations** entry and it stays current on
all three. Routes and Map are universe-scoped world-building records rather than separate sidebar
sections; their page contracts are in [routes.md](routes.md) and [map.md](map.md).

## Location profile

A Location records its name, its place in the hierarchy, optional tags, a photo, a short summary,
and one Markdown description. Every field except `name` is optional, and none changes what a
Location is.

| Field | What it records |
|---|---|
| `name` | The place's name |
| `location_tags` | Optional Universe-scoped Location Tags |
| `parent` | The place this one sits inside, if any; the reverse is its children |
| `summary` | One line shown in the tree row and at the top of the details page; plain text that may carry a reference |
| `description` | The full profile, written in Markdown |

There are deliberately no separate sensory, layout, significance, history, or access columns: those
are `##` sections inside `description`, which keeps the form short and lets the author choose the
shape of a place's profile. A blank summary or description means that the author has not recorded
an answer.

The summary is one line of plain text and is never rendered as Markdown, but it accepts the same
`[[kind:slug]]` references as the description. The Locations tree shows **only** the summary as its
row's second line, with each reference reduced to the record's name and never a link, exactly as the
Character, Faction, and Item lists do ([characters.md](characters.md#references-in-a-summary)); a Location
with no summary has a one-line row, because the full profile belongs to the details page. On the
details page the summary appears at the top with its references linked, above the rendered
description.

The description is stored as Markdown and rendered on the details page: `##` becomes a heading,
`**text**` becomes bold, and lists, tables, fenced code, and blockquotes keep their written form. The
dialect and the `[[kind:slug]]` reference syntax are the shared description dialect owned by
[characters.md](characters.md#links-inside-a-description) and implemented by `MarkdownDescription`.
A Location may therefore link a Character, Faction, Item, another Location, a Scene or Plot, or a
canon rule; a canon citation keeps its ledger id as the label (`[[canon:K47]]` reads as `K47`), while
every other kind is labeled with the record's name.

The editor is the shared hierarchical tree modal, opened in the same wide, scrollable dialog the
flat-list record editors use. It reads name, parent, tags, photo, short summary, description in that
order. A writer's details page carries an **Edit location** control that opens the same editor in
place, with the record and its descendants kept out of its own parent selector. The summary and
description are read-only outside the editor, like the rest of the tree.

## Search, filter, and API

Location text search covers the name, the short summary, and the description. The Locations list's
`q` filter covers the same columns, so a writer who remembers only that a place smelled of pipeweed
or was controlled by a particular faction still finds it through the prose that now records it. The
filter contract itself is in [list_filters.md](list_filters.md).

The read-only JSON API at `/api/u/:universe_slug/locations` returns the name, summary, description,
tag ids, parent id, and position.

## Who is here

The details page answers "who is at this place" from the Scenes of the current Story that link it,
one row per Scene in narrative order. Presence is never stored on the Location: the same place holds
different people at different moments, so a stored answer would be wrong for every Scene but one.
`LocationPresence` reads the answer, and the [Scene participation union](scenes.md#participation-is-a-union-never-a-sum)
is what defines an individual.

Each row names:

- **The Scene's use of the place** — the author's free-text `SceneLocation.role`, such as "setting"
  or "arrives at". It describes how the Scene uses the Location, not why a person is there.
- **Factions present** — the union of the participants' Faction memberships. There is no
  Scene-Faction link ([ADR 0033](../adr/0033-meetings-use-events-and-scene-presence.md)), so a
  faction appears only through a present member, and its membership is read as it is now rather than
  as it was at that moment.
- **Notable individuals and why they are here** — every participant from the Scene's union of stored
  `SceneCharacter` links and derived Dialogue speakers. An individual's free-text link `role` is the
  stated reason. A linked person with no role says "no role recorded", and a derived speaker says
  "speaks in this scene", because neither has a stored reason to show.

The section is read-only and renders for every access level. It is scoped to `Current.story` and
never falls back to another Story: with no current Story it asks for one, and a Location with no
Scene in the selected Story says so. A Scene that links several Locations reports the same
participants for each of them, because a `SceneCharacter` names the Scene rather than one of its
places; splitting a scene is how an author separates two groups at two places.

The query count is fixed per page, so a Location used in one Scene costs the same as one used in all
of them.

## Sample records

Every checked-in development universe includes both populated and blank summaries and descriptions,
so the tree and the details page can be read full and empty. `db/data/dark/locations.yml` describes
Winden, Jonas House, Jonas Room, Winden Cave, and Winden Forest; `db/data/lotr/locations.yml`
describes The Shire, Hobbiton, Rivendell, and Moria, leaving the other places blank. Winden Cave
links a Character and a canon rule in its description, and its summary carries the same two
references so the row's plain-text rendering is visible; Rivendell links a canon rule and a
Character in the description, so the shared reference dialect is visible on a place page.

After changing either manifest, validate and reload both development universes with the workflow in
[development.md](../development.md#required-workflow-after-editing-demo-yaml):

```sh
script/demo check dark lotr
script/demo reset dark lotr
```

Then sign in as `dark@dark` (or `lotr@lotr`) with the development password from `.env` and open
`/u/dark/locations`, and choose a described place's **Details** page to read it.

The same universes' `db/data/<universe_slug>/scene_locations.yml` and `scene_characters.yml`
already place Characters at described places. Select a Story, open **Jonas House** or **Rivendell**,
and the **Who is here** rows show the participants, reasons, and factions recorded by those Scenes.
