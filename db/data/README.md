# Development Universe Data

`db/data/` contains checked-in but disposable development data. It is not production seed data,
and it is not the source of truth for the Rails test fixtures. The files exist so a developer can
load one universe, exercise a feature in the browser, and test relationships between records.

> **After any YAML change, rebuild the development database.** Rails does not watch or synchronize
> these files. Validate the changed universe, then run the destructive reset below before opening
> the app. The YAML files are the source of truth; records created only in the UI are not exported,
> merged, or preserved and will be lost by that reset.

## Directory convention

There is one subdirectory per universe, named with the universe slug:

```text
db/data/
  dark/
  lotr/
  star_wars/  # after it is registered in the development registry
  a_song_of_ice_and_fire/
```

A universe directory contains all data used to exercise that universe: its user/universe record,
memberships when explicit private or delegated-admin access is needed, stories, sections, section
tags, scenes, world-building records, taxonomies, and relationships. Every registered universe
directory
must contain one YAML file for every model in the shared registry; use `[]` for a model that the
universe intentionally does not exercise.

The current examples are:

- `dark/` — the more complete YAML-based Dark dataset;
- `lotr/` — the smaller Lord of the Rings dataset, now expressed in the same YAML format.

The Dark directory includes a delegated-admin example: after loading it with the explicit
development task, sign in as the synthetic `collaborator@dark` / `collaborator` account and open
`/u/dark/members` to exercise membership management. These credentials are disposable development
values, not production secrets.

A subdirectory represents a **universe**, not a feature. There should not be a separate
`db/data/dialog/` directory for a Dialog feature.

## Adding a universe

1. Create `db/data/<universe_slug>/`.
2. Add every registered model file to that directory, using `[]` for intentionally unused models.
3. Use stable slugs and symbolic `Model.slug` references rather than database numeric ids.
4. Register the universe in `app/services/development/universe_data_registry.rb`.
5. Validate it before loading it:

   ```bash
   UNIVERSE=<universe_slug> bin/rails db:demo:check
   ```

Do not add the data to `db/seeds/`, a migration, a deploy command, or the hard-coded production
seed path.

## Adding or changing a model

A new persisted model gets a data file in every universe directory where it should be exercised.
The file name follows the model/table name, for example if we have a new model called Dialog then:

```text
db/data/dark/dialogs.yml
```

If the Dialog model is added and should be testable in the LOTR universe too, add:

```text
db/data/lotr/dialogs.yml
```

Do not create `db/data/dialog/` merely because the model is named `Dialog`. Update the shared
`Development::UniverseDataRegistry` model order/registry as well as the per-universe files. The
loader rejects missing files, unknown files, duplicate identifiers, forward references, malformed
references, cross-scope associations, raw foreign-key IDs, and unknown attributes before it writes
records. Hierarchical positions use file order unless every sibling supplies a unique non-negative
integer position. Flat position groups — currently the story-owned `scenes` sequence — are declared
in the registry with `position_mode: :flat` and are grouped per story, never per parent; supply
explicit `position` values when the file should state the order directly.

`universe_memberships.yml` is used when a sample universe should exercise private read/write/admin
access; owner access is implicit and does not need a membership row.

Dialog records must use the actual associations decided for the model. A story-scoped model uses
`story: Story.<slug>`; a universe-scoped model uses `universe: Universe.<slug>`. Include connected
characters, locations, items, events, sections, and tags where those relationships exist, so the
browser scenario exercises more than an isolated row.

## Lifecycle and safety

YAML edits are not hot-reloaded or synchronized to an existing database. **After adding, deleting,
or updating any file under `db/data/**/*.yml`, validate every changed universe and rebuild the local
development database before testing the change in the app:**

```bash
UNIVERSE=dark bin/rails db:demo:check
UNIVERSE=lotr bin/rails db:demo:check

# Drops the entire development database, migrates it, and loads Dark.
CONFIRM_DB_RESET=1 UNIVERSE=dark bin/rails db:demo:reset

# Optional: add LOTR back when both sample universes should be available locally.
UNIVERSE=lotr bin/rails db:demo:load
```

The reset target can be either registered universe. It drops all records and loads only the named
universe, so load each additional universe once after the reset if it should remain available. The
loader is create-only: `db:demo:load` refuses an existing universe, and there is no update, merge,
or UI-export mode. A record created only through the UI is therefore intentionally lost on reset.
The owner accepts that loss for this disposable local database; this workflow must never target a
production or other real database.

The development loader remains explicit and environment-guarded. `check` is read-only and may run in
development or test; `load` and `reset` may write only in development. `db:demo:reset` requires the
explicit confirmation value above and does not invoke `db:seed`.

`db:prepare` and `db:seed` load only production-safe files under `db/seeds/`. They never load
`db/data/`. The guarded `db:restart` task resets the schema without demo data; use
`db:demo:reset` when a disposable universe should be loaded.

Temporary data may be create-only because the supported operation is an explicit reset followed by
a load. The loader normalizes hierarchical sibling positions from YAML/file order. Automated tests
use `test/fixtures/`, not these mutable development files.
