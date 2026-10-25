# Characters

Characters are Universe-owned records shared by every Story in that Universe. Their workspace and
details page are at `/u/:universe_slug/characters` and `/u/:universe_slug/characters/:id`; the schema
and ownership graph are summarized in [data_model.md](../data_model.md).

## Profile

The Character modal records a name and optional plain-text profile fields:

| Field | What it records |
|---|---|
| `at_a_glance` | A short overview |
| `wants` | What the Character wants |
| `needs` | What the Character needs |
| `lies_to_self` | What the Character believes that is not true |
| `contradictions` | Conflicting traits, motives, or choices |
| `under_pressure_they` | How the Character responds under pressure |
| `never` | An action or boundary the Character will not cross |

Every profile field is optional. The old `description` column was renamed to `at_a_glance`, preserving
existing summaries. Character text search and the API use the structured profile fields; the API
returns `at_a_glance` and the other profile values instead of `description`.

## Faction membership

A Character may be assigned zero, one, or several same-Universe Factions. The multi-select in the
Character editor is optional; the Character details page links to assigned Factions. Membership is a
scoped HABTM join with database uniqueness and foreign-key constraints. Reads hide a corrupt
cross-Universe join, and model validation rejects a foreign membership on write. Deleting a Character
soft-deletes its own knowledge records but leaves its faction membership joins available for restore;
hard destruction removes the joins without deleting either endpoint.

Factions themselves and their taxonomy are documented in [factions.md](factions.md).

## Knowledge changes

The Character details page holds any number of knowledge records. Each captures a free-form **When**
label, **What they learn**, an optional source Character (**From whom**), and whether the information
changes their plan. The When field is intentionally prose rather than a date or Event reference, so a
writer can describe a Scene, revelation, or other in-world moment without inventing chronology.
Knowledge records belong to both their Universe and Character; the optional source must also belong
to that Universe. They are listed chronologically by creation order and can be edited or soft-deleted
from the details page. A Character's soft deletion cascades to its knowledge records.

The Character workspace follows the existing JSON modal mutation contract and Universe access policy.
Knowledge records use HTML forms embedded on the details page and the same draft-aware mutation path;
all reads and writes are scoped through the authorized Universe and nested Character URL.

## Character sample records

Character profile examples demonstrate populated and blank optional fields, multiple faction
memberships, and a Character with no Faction. In Dark, family and job tags describe Characters while
faction membership is the separate Faction association. Each Universe also includes a connected
knowledge record with a source Character. The manifests are `characters.yml` and
`character_knowledges.yml`; the latter loads after the Character and Faction definitions.

After changing either Universe's manifests, validate and reload both development datasets using the
workflow in [development.md](../development.md#required-workflow-after-editing-demo-yaml):

```sh
UNIVERSE=dark bin/rails db:demo:check
UNIVERSE=lotr bin/rails db:demo:check
script/demo reset dark lotr
```

For manual verification, sign in as `dark@dark` with the development password configured in
`UNIVERSE_MAKER_DEV_PASSWORD`, select Dark, and open `/u/dark/characters`. Open Jonas's Details page
to see the profile, faction membership, and sample knowledge entry; the Character list and details
page are also the browser entry points for editing those records.
