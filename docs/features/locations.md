# Locations

Locations are Universe-owned records shared by every Story in that Universe. Their workspace is the
hierarchical tree at `/u/:universe_slug/locations`, and each record's own page is
`/u/:universe_slug/locations/:id`. The table, its parent and position rules, and its soft-delete
cascade are summarized in [data_model.md](../data_model.md); the hierarchy, tags, editor, and page
patterns they follow are in [conventions.md](../conventions.md).

## Location profile

The Location editor records the place's name, description, optional tag assignment, parent, photo,
and any number of optional profile answers. Every profile answer is plain text, and every one may be
left blank; none is validated for presence, and none changes what a Location is.

| Field | What it records |
|---|---|
| `sensory_sight`, `sensory_sound`, `sensory_smell`, `sensory_taste`, `sensory_touch` | What the place looks, sounds, smells, tastes, and feels like |
| `layout_structure`, `layout_key_areas`, `layout_pathways`, `layout_entrances_exits`, `layout_points_of_interest` | How the place is arranged and what a visitor can reach |
| `significance` | Why the place matters |
| `history_significant_events`, `history_past_occupants`, `history_changes` | What happened here, who was here before, and how it changed |
| `access_controlled_by`, `access_granted_how`, `access_security`, `access_restrictions` | Who holds the place and how one gets in |

`Location::PROFILE_FIELDS` is the single ordered list those answers are read from. The editor's
fields, the details page's facts, the list filter's text columns, the search body, and the API all
read it, so a new column is added to the list and appears everywhere rather than needing five
separate edits.

An empty answer renders the shared blank copy on the details page, never an empty row. The profile is
read-only outside the editor: like the rest of the tree, a Location is changed through its modal.

## Search, filter, and API

Location text search covers the name, the description, and every profile answer. The Locations list's
`q` filter covers the same columns, so a writer who remembers only that a place smelled of pipeweed
or was controlled by a particular faction still finds it. The filter contract itself is in
[list_filters.md](list_filters.md).

The read-only JSON API at `/api/u/:universe_slug/locations` returns every profile field beside the
existing identity values.

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

Every checked-in development universe includes both populated and blank profile answers, so the
details page can be read full and empty. `db/data/dark/locations.yml` profiles Winden, Jonas House,
Jonas Room, Winden Cave, and Winden Forest; `db/data/lotr/locations.yml` profiles The Shire,
Hobbiton, Rivendell, and Moria, leaving the other places blank.

After changing either manifest, validate and reload both development universes with the workflow in
[development.md](../development.md#required-workflow-after-editing-demo-yaml):

```sh
script/demo check dark lotr
script/demo reset dark lotr
```

Then sign in as `dark@dark` (or `lotr@lotr`) with the development password from `.env` and open
`/u/dark/locations`, and choose a profiled place's **Details** page to read it.

The same universes' `db/data/<universe_slug>/scene_locations.yml` and `scene_characters.yml`
already place Characters at profiled places. Select a Story, open **Jonas House** or **Rivendell**,
and the **Who is here** rows show the participants, reasons, and factions recorded by those Scenes.
