# Development Universe Data

`db/data/` contains checked-in but disposable development data. It is not production seed data,
and it is not the source of truth for the Rails test fixtures. The files exist so a developer can
rebuild a local universe, exercise a feature in the browser, and test relationships between records.

## Directory convention

There is one subdirectory per universe, named with the universe slug:

```text
db/data/
  dark/
  lotr/
  star_wars/
  a_song_of_ice_and_fire/
```

A universe directory contains all data used to exercise that universe: its user/universe record,
memberships when explicit private or delegated-admin access is needed, stories, sections, section
tags, world-building records, taxonomies, and relationships. The current examples are:

- `dark/` — the more complete YAML-based Dark dataset;
- `lotr/` — the smaller Lord of the Rings dataset, currently written as Ruby.

The Dark directory includes a delegated-admin example: after the current transitional development
load (`bin/rails db:prepare`), sign in as the synthetic `collaborator@dark` / `collaborator` account
and open `/u/dark/members` to exercise membership management. Do not rerun the create-only demo
loader without deliberately rebuilding the disposable database.

A subdirectory represents a **universe**, not a feature. There should not be a separate
`db/data/dialog/` directory for a Dialog feature.

## Adding a universe

1. Create `db/data/<universe_slug>/`.
2. Add the universe record and all data needed to make that universe useful in the browser.
3. Use stable slugs and symbolic references rather than database numeric ids.
4. Register the universe with the development loader or its directory registry. Do not add the
   data to `db/seeds/` or a production data migration.

The current `db/seeds.rb` still loads the `dark` and `lotr` directories from a hardcoded list. That
wiring is transitional; the intended lifecycle is an explicit development-only load/reset task.

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
model load order/registry as well as the per-universe files.

`universe_memberships.yml` is used when
a sample universe should exercise private read/write/admin access; owner access is implicit and does
not need a membership row.

Dialog records must use the actual associations decided for the model. A story-scoped model uses
`story: Story.<slug>`; a universe-scoped model uses `universe: Universe.<slug>`. Include connected
characters, locations, items, events, sections, and tags where those relationships exist, so the
browser scenario exercises more than an isolated row.

## Lifecycle and safety

The preferred local workflow is to rebuild or reset the disposable database and then load one
universe directory. Temporary data may be create-only; it does not need production-style
idempotence when the database is deliberately rebuilt. Use synthetic local credentials only, and
never run a destructive reset without approval.

Automated tests use `test/fixtures/`, not these mutable development files. The local
`config/ci.rb` seed-replant check is a transitional exception and should be updated with the
explicit development-data task.
