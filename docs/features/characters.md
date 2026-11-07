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
| `summary` | One line shown in the list and at the top of the details page; plain text that may carry a reference |
| `description` | The full profile, written in Markdown |

Every field except `name` is optional. There are deliberately no separate columns for wants, needs,
lies, contradictions, pressure, or knowledge: those are `##` sections inside `description`, which
keeps the form short and lets the author choose the shape of a Character's profile.

The editor presents them in that reading order after the name — aliases, pronouns, tags, factions,
photo, short summary, description — in the same wide, scrollable modal the other flat-list
workspaces use.

The description is stored as Markdown and rendered on the details page: `##` becomes a heading,
`**text**` becomes bold, and lists, tables, fenced code, and blockquotes keep their written form. Raw
HTML in the body is stripped, and an unknown reference stays visible as written. The renderer is
`MarkdownDescription` in `app/services/markdown_description.rb`, reached through
`ApplicationHelper#markdown_description_html` so every surface uses one dialect. Characters and
[Factions](factions.md#scope-and-profile) both store their description this way.

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
record exists. A `rule` or `canon` reference keeps its own ledger id as the label — `[[canon:K47]]`
reads as `K47`, not as the rule's full name — because a citation names the rule by id and the name
would repeat the rule inside the sentence citing it; every other kind is labeled with the record's
name. A bare
`[[slug]]` is the older form and still works; it is looked up across the Universe kinds in the order
Character, Faction, Location, Item, then Plot. A reference to a missing record, or to a record of a
different kind than its prefix declares, stays literal so the author sees it rather than losing it.
A reference inside a code span or fenced block is an example and is not linked.

On screen a description is rendered with its references as links. The printable manuscript's appendix
is the one surface that renders a description without them: there a reference is the name of the
record it names, because paper has nothing to click. [exports.md](exports.md#universe-appendices)
owns that document and its heading levels.

The interchange's link rules are in
[story_interchange.md](story_interchange.md#references); this page owns how the application renders
them.

### References in a summary

The summary is one line of plain text and is never rendered as Markdown: `##` and `**` stay as the
author typed them, and no block element is produced. It accepts the same `[[kind:slug]]` references
as the description, rendered one of two ways by `MarkdownDescription`:

- at the top of the details page, a reference becomes the link; an unresolved reference stays
  written, exactly as in the description.
- in a list row (the Character, Faction, and Item lists, a Faction's affiliated Characters, the
  Locations tree row, and a remembered create's pending row) and in the printable manuscript's
  appendix, a reference becomes the name of the record it names and is never a link: the row already
  carries its own Details link, and a second one inside a two-line preview competes with it, while
  paper has nothing to click at all ([exports.md](exports.md#universe-appendices)).
  A `rule` or `canon` reference keeps its ledger id here too, for the same reason it does in the
  description. An unresolved reference stays written there too, so a typo stays visible.

The views reach both renderings through `ApplicationHelper#summary_html` and
`ApplicationHelper#summary_text`; the appendix reaches the plain-text one through
`StoryExportsHelper#manuscript_appendix_text`. Nothing escapes or resolves a reference on its own.

## Faction membership

A Character may be assigned zero, one, or several same-Universe Factions. The multi-select in the
Character editor is optional; the Character details page links to assigned Factions. Membership is a
scoped HABTM join with database uniqueness and foreign-key constraints. Reads hide a corrupt
cross-Universe join, and model validation rejects a foreign membership on write. Deleting a Character
leaves its faction membership joins available for restore; hard destruction removes the joins
without deleting either endpoint.

Factions themselves and their taxonomy are documented in [factions.md](factions.md).

The Character workspace follows the existing JSON modal mutation contract and Universe access policy.
All reads and writes are scoped through the authorized Universe URL. A writer's details page carries
an **Edit character** control that opens the same modal, so a Character can be edited without
returning to the list.

The details page's prose mention suggestions are a separate read: a name written in a Scene never
becomes an appearance. Their matching rules and surfaces are in [mentions.md](mentions.md).

## Interaction network

The **Network** tab beside Characters and Relations at `/u/:universe_slug/network`
(`CharacterNetworksController#show`) draws how often each pair of Characters shares the page. It is
read-only, has no stored result, and is derived from the Universe's live records on every request.

**Scope.** Every live Scene of every live Story in the Universe, regardless of which Story is
currently selected. The Characters workspace is Universe-scoped, so its network is too.

### Score

A pair's interaction score is:

| Signal | Points |
|---|---|
| a Scene where both are participants | 1 |
| a Dialogue Element where both speak | 2 |
| two adjacent Dialogue turns by different speakers (an exchange) | 1 |

Participation is the union [Scenes](scenes.md#participation-is-a-union-never-a-sum) and
[Appearances](appearances.md) already use: an explicit `SceneCharacter` link or a Dialogue speaker,
never their sum. A pair appears only when its score is positive.

Two things deliberately do **not** count. A prose mention is a suggestion, not an appearance
([mentions.md](mentions.md)), so naming two Characters in one paragraph is not interaction. A
Relation is a stated link rather than a counted event, so it neither creates an edge nor thickens
one; it can color an edge that interaction already created, as described below.

Faction membership is a third layer and is not interaction either. **Show faction membership as
relation** is on by default and joins every pair of Characters in the same live Faction with a dotted
line. It adds no score, changes no table row, and does not bring a Character into the graph on its
own: only pairs whose two Characters are already nodes are drawn. Because **Show characters with no
connections** is also on by default, every live Character is a node, so faction members with no
recorded interaction are included and the layout places them as a group. A pair in several Factions
gets one line, colored by the first Faction in that pair's list. At most 160 faction pairs are drawn,
in Faction name then member name order, and the summary says when the cap truncated them. Turning the
option off is `faction_links=0` in the URL; both view options preserve each other. The server always
renders the whole graph, so a toggle only hides a layer and never moves a node.

A Faction's `bgcolor` is the dotted line's color. `fgcolor` is stored for a future use and is not
painted. A pair in several Factions uses the first Faction by name then id, matching the order the
links are built in.

### Derivation, not counters

The network is calculated on the fly; there are no counter columns, no read model, and no
background job. Presence links, Dialogue turns, Elements, Scenes, and Characters are all
soft-deletable through several write paths, so a stored counter would have to be repaired on every
delete and restore. Reading the live rows means a soft-deleted record leaves the network on the
next request by construction. If a Universe ever grows enough for the request to cost too much, a
cached read model is the place to add one; a second stored truth is not.

The diagram keeps at most 120 Characters, the table keeps at most the 240 strongest connections, and
the faction layer keeps at most 160 pairs; the page says when any of them is showing a subset.

### Diagram and text alternative

`CharacterNetworkLayout` derives coordinates at render time from a deterministic force-directed
simulation, following the [Map](map.md#page)'s derived-SVG pattern. The seed is fixed and the input
order is stable, so the same records always produce the same picture. Interaction edges and faction
links are both springs, so faction members settle together even when they share no Scene; stronger
interactions pull harder. Line thickness follows the interaction score and dot size follows the
Character's total interaction.

Every live Character is a node by default. One with no positive interaction is drawn as a smaller
dashed ring and still takes part in the force layout, rather than being parked in a separate band,
because the default faction links need it in the graph to group its Faction. A Universe with no
interaction edge still draws its cast; the connections table is omitted and a note says there are no
interaction connections yet. The summary above the diagram states how many of the Universe's
Characters have a recorded connection.

The two view controls are real links, so without JavaScript they navigate to the server-rendered
alternative and preserve the other option. With JavaScript, `character_network_controller.js` hides
and shows the layers in place instead: the server has already laid out every node, so a toggle never
moves a node and leaves a gap where a hidden Character or faction line was. The URL is rewritten in
place (`show_unconnected=0`, `faction_links=0`), so a reload or a shared link restores the same view.

An edge is neutral unless the pair has a Relation carrying a Relation tag. It then takes that tag's
`bgcolor`, and the table repeats the tag badge, so the color is never the only signal. The graph is
undirected, so a Relation in either direction colors the pair. When a pair has several Relations the
first Relation by id that has a tag supplies it, and inside that Relation the first tag by
`(position, id)` is chosen because a HABTM has no order of its own. A Relation with no interaction
still draws no line.

The ordered table below the diagram is the accessible and printable equivalent: it names the pair,
the Relation tag that colors the line, the shared Scene count, the shared Dialogue count, the
exchange count, and the score. The diagram is a labelled `role="group"` inside a focusable scroll
region and every node links to its Character. The only empty state is a Universe with no Characters:
a Universe with Characters but no interaction edge still draws the cast and says the interaction
connections are not recorded yet.

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
