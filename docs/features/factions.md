# Factions

[ADR 0034](../adr/0034-factions-are-universe-content.md) decides that a Faction is a world-building
record in its own right rather than a Character tag. This document owns the current profile and
taxonomy workflow; the schema is summarized in [data_model.md](../data_model.md).

## Scope and profile

A Faction belongs directly to one Universe and is shared by all of that Universe's Stories. It has a
required `name`, a `slug` generated from the name, and two optional profile fields:

| Field | What it records |
|---|---|
| `summary` | One line shown in the Faction list and at the top of its details page; plain text, references included |
| `description` | The full profile, written in Markdown |

The description is stored as Markdown and rendered on the details page: `##` becomes a heading,
`**text**` becomes bold, and lists, tables, fenced code, and blockquotes keep their written form. The
dialect and the `[[kind:slug]]` reference syntax are the shared description dialect owned by
[characters.md](characters.md#links-inside-a-description) and implemented by `MarkdownDescription`.
The summary accepts the same references, linked on the details page and named without a link in a
list row, as [characters.md](characters.md#references-in-a-summary) describes. Both the summary and
the description are part of the Faction's searchable body.

There are deliberately no separate mission, aims, structure, divisions, or resources columns: those
are `##` sections inside `description`, so the form stays short and the author chooses the shape of
the profile. A blank field means that the author has not recorded an answer. Factions are flat
records; they do not have `parent_id` or `position`.

Factions are managed at `/u/:universe_slug/factions`, with a list, a modal editor, and a read-only
details page at `/u/:universe_slug/factions/:id`. Create, edit, and delete use the JSON modal contract.
A writer's details page carries an **Edit faction** control that opens the same modal. Deletion is a
soft delete, so restoring a Faction also restores its tag assignments. Factions carry the same
optional Photo and Discussion support as other universe content.

## Characters in a Faction

The details page lists the Characters affiliated with the Faction after its description. The list is
read-only navigation: a reader can open each Character's page, but membership is edited on the
Character form, not here. The membership rules and the Character profile are owned by
[characters.md](characters.md).

The section renders for every access level, because a reader who may see the Faction may see the
Characters in the same Universe. A Faction with no affiliated Character says so rather than showing an
empty box.

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
its summary and description as searchable body text; a FactionTag searches by name and description. Their
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

## Dark and LOTR examples

Each registered Universe manifest has `faction_tags.yml`, `factions.yml`, and
`faction_relationships.yml`. Tag definitions load before Factions, which load before Character
membership and faction relationships so symbolic references resolve in order. Dark demonstrates the
Sic Mundus–Erit Lux conflict and affiliated Characters on each details page; LOTR demonstrates the
Fellowship's alliance with the White Council. Every demo Faction has a summary and a description with
`##` sections.

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
