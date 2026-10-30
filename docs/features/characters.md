# Characters

Characters are Universe-owned records shared by every Story in that Universe. Their workspace and
details page are at `/u/:universe_slug/characters` and `/u/:universe_slug/characters/:id`; the schema
and ownership graph are summarized in [data_model.md](../data_model.md).

## Profile

A Character has one short summary and one Markdown description beside the identity fields:

| Field | What it records |
|---|---|
| `name` | The Character's name |
| `character_tags` | Optional Universe-scoped Character Tags |
| `factions` | Zero or more same-Universe Factions |
| `pronouns` | The pronouns the Character uses |
| `aliases` | Other names the Character goes by, usually separated by commas |
| `summary` | One line shown in the list and at the top of the details page |
| `description` | The full profile, written in Markdown |

Every field except `name` is optional. There are deliberately no separate columns for wants, needs,
lies, contradictions, pressure, or knowledge: those are `##` sections inside `description`, which
keeps the form short and lets the author choose the shape of a Character's profile.

The description is stored as Markdown and rendered on the details page: `##` becomes a heading,
`**text**` becomes bold, and lists, tables, fenced code, and blockquotes keep their written form. Raw
HTML in the body is stripped, and an unknown reference stays visible as written. The renderer is
`CharacterDescription` in `app/services/character_description.rb`, reached through
`CharactersHelper#character_description_html` so every surface uses one dialect.

Aliases and pronouns are part of the searchable body, as are the summary and description, so a
reader can find a Character by a name it is known by or by what its profile says.

## Links inside a description

A description may link another record with a typed reference:

| Reference | Opens |
|---|---|
| `[[character:slug]]` | the Character |
| `[[faction:slug]]` | the Faction |
| `[[location:slug]]` | the Location |
| `[[item:slug]]` | the Item |

`[[plot:slug]]`, `[[scene:slug]]`, `[[rule:ID]]`, and `[[canon:ID]]` are also resolved when the
record exists. A bare
`[[slug]]` is the older form and still works; it is looked up across the Universe kinds in the order
Character, Faction, Location, Item, then Plot. A reference to a missing record, or to a record of a
different kind than its prefix declares, stays literal so the author sees it rather than losing it.
A reference inside a code span or fenced block is an example and is not linked.

The interchange's link rules are in
[story_interchange.md](story_interchange.md#references); this page owns how the application renders
them.

## Faction membership

A Character may be assigned zero, one, or several same-Universe Factions. The multi-select in the
Character editor is optional; the Character details page links to assigned Factions. Membership is a
scoped HABTM join with database uniqueness and foreign-key constraints. Reads hide a corrupt
cross-Universe join, and model validation rejects a foreign membership on write. Deleting a Character
leaves its faction membership joins available for restore; hard destruction removes the joins
without deleting either endpoint.

Factions themselves and their taxonomy are documented in [factions.md](factions.md).

The Character workspace follows the existing JSON modal mutation contract and Universe access policy.
All reads and writes are scoped through the authorized Universe URL.

The details page's prose mention suggestions are a separate read: a name written in a Scene never
becomes an appearance. Their matching rules and surfaces are in [mentions.md](mentions.md).

## Character sample records

Character profile examples demonstrate populated and blank fields, including pronouns and aliases,
multiple faction memberships, a Character with no Faction, and a Markdown description with `##`
sections and a typed link. In Dark, family and job tags describe Characters while faction membership
is the separate Faction association. The manifest is `characters.yml` in each Universe directory.

After changing either Universe's manifest, validate and reload both development datasets using the
workflow in [development.md](../development.md#required-workflow-after-editing-demo-yaml):

```sh
UNIVERSE=dark bin/rails db:demo:check
UNIVERSE=lotr bin/rails db:demo:check
script/demo reset dark lotr
```

For manual verification, sign in as `dark@dark` with the development password configured in
`UNIVERSE_MAKER_DEV_PASSWORD`, select Dark, and open `/u/dark/characters`. Open Jonas's Details page
to see the summary, faction membership, and Markdown description; the Character list and details
page are also the browser entry points for editing those records.
