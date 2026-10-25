# Factions

[ADR 0034](../adr/0034-factions-are-universe-content.md) decides that a Faction is a world-building
record in its own right rather than a Character tag. This document owns the current profile and
taxonomy workflow; the schema is summarized in [data_model.md](../data_model.md).

## Scope and profile

A Faction belongs directly to one Universe and is shared by all of that Universe's Stories. It has a
required `name`, a `slug` generated from the name, and optional profile fields:

| Field | What it records |
|---|---|
| `mission` | The public mission — what the Faction says out loud |
| `actual_aims` | What it truly aims to achieve |
| `structure` | How the group is organized |
| `internal_divisions` | Disagreements or factions within the Faction |
| `resources` | What it can draw on |
| `would_never` | What the Faction would never do |
| `would_absolutely` | What it would absolutely do |

The profile fields are plain text. They have no required order or interpretation, and a blank field
means that the author has not recorded an answer. Factions are flat records; they do not have
`parent_id` or `position`.

Factions are managed at `/u/:universe_slug/factions`, with a list, a modal editor, and a read-only
details page at `/u/:universe_slug/factions/:id`. Create, edit, and delete use the JSON modal contract.
Deletion is a soft delete, so restoring a Faction also restores its tag assignments. Factions carry
the same optional Photo and Discussion support as other universe content.

## Faction tags

`FactionTag` is the Faction taxonomy, managed at `/u/:universe_slug/faction_tags`. It uses the shared
universe-scoped tag tree and editor: tags have colors, can be nested, and are optional on every
Faction. A grouping tag (`taggable: false`) remains in the taxonomy but is not offered for a new
assignment. A tag with `show_in_menu: true` becomes a tab on the Factions workspace and opens that
tag's details page. Existing Character tags and assignments are left untouched; there is no implicit
migration between the two taxonomies.

Both associations are universe-scoped and validated in the model. A corrupted or forged cross-Universe
assignment is hidden on association reads and rejected on writes. A tag's details page lists the
Factions that carry it; a grouping tag shows one section per direct child, like the other taxonomies.

## Access, collaboration, and search

Factions and FactionTags use the Universe's existing read/write access rules: public guests may read,
signed-in users may write, and private Universes require a member. In a draft-based Universe, JSON
mutations are remembered and applied through the existing draft path rather than written directly.

Factions and FactionTags are searchable. A Faction's search document uses its name as the title and
its profile fields as searchable body text; a FactionTag searches by name and description. Their
results are filtered by the same Universe visibility rule as all other content.

## Faction relationships

`FactionRelationship` records a directed link from one Faction to another. Direction is explicit:
`from_faction → to_faction`; a reverse relationship is a separate record and is never inferred. The
same Faction cannot be both endpoints, and both endpoints must belong to the relationship's Universe.
The optional name, description, and in-world date range record what the relationship means and when it
applies. The model is soft-deletable and has the standard photo and discussion support.

The list and modal editor live on the Relationships tab at `/u/:universe_slug/faction_relationships`.
Each relationship has a read-only details page; create, edit, and remove use the HTML redirect/re-render
flow, and draft-based Universes remember those mutations. The ordinary Universe access policy applies.
Its search document uses the optional name or directed endpoints as the title and its description as
searchable body text.

## Character membership

Characters may belong to zero, one, or several Factions. Membership is edited on the Character form;
the many-to-many membership rules and the Character profile are owned by
[characters.md](characters.md).

## Dark and LOTR examples

Each registered Universe manifest has `faction_tags.yml`, `factions.yml`, and
`faction_relationships.yml`. Tag definitions load before Factions, which load before Character
membership and faction relationships so symbolic references resolve in order. Dark demonstrates the
Sic Mundus–Erit Lux conflict; LOTR demonstrates the Fellowship's alliance with the White Council.

To check and reload both local demo Universes after changing these manifests:

```sh
UNIVERSE=dark bin/rails db:demo:check
UNIVERSE=lotr bin/rails db:demo:check
script/demo reset dark lotr
```

Sign in as `dark@dark` with the development password configured as
`UNIVERSE_MAKER_DEV_PASSWORD`, select Dark, and open `/u/dark/factions`. The isolated Compose
development workspace uses its volume's stored password and can be refreshed through the workflow in
[`development.md`](../development.md#required-workflow-after-editing-demo-yaml).
