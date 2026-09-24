# Universe Maker

Universe Maker is a Rails application for building and maintaining consistent story universes. It
keeps characters, locations, events, items, relationships, sections, and their tags in a searchable
structure so writers can track continuity and spot contradictions as a story grows.

The project uses Rails 8, Hotwire, SQLite, import maps, and Bun for the CSS build. See the
[development guide](docs/development.md) for the full setup, test, seeding, CI, and deployment
workflows.

## Quick start

Install the pinned tools with [mise](https://mise.jdx.dev), then install the Ruby and JavaScript
dependencies:

```bash
mise install
bundle install
bun install
bin/rails db:prepare
```

Start Rails and the CSS watcher together:

```bash
bin/dev
```

The application is then available at <http://localhost:3000>. Run `bin/rails server` by itself when
you do not need the CSS watcher.

## Tests and quality checks

```bash
bin/rails test       # Minitest models, controllers, and integration tests
bin/rails test:system # browser-based smoke tests (requires Chrome)
bin/rubocop          # Ruby style checks
bin/brakeman --no-pager
bin/bundler-audit
bin/importmap audit
```

`bin/rails db:restart` recreates the disposable database, migrates it, and reloads the demo data.
The database is rebuilt from `db/data/`; application-data migrations are intentionally not used.

## Documentation

[`docs/`](docs/README.md) is the source of truth for this project. In particular:

- [Vision](docs/vision.md) — the product goals and continuity promise
- [Development](docs/development.md) — setup, tests, seeds, CI, and deployment
- [Architecture](docs/architecture.md) — request lifecycle, routing, and feature design
- [Data model](docs/data_model.md) — schema, associations, validations, and slugs
- [Conventions](docs/universe_maker_conventions.md) — patterns for adding and changing features
- [Known quirks](docs/known_quirks.md) and [resolved quirks](docs/resolved_quirks.md) — verified
  caveats and fix history

When behavior changes, update the relevant document in the same change.
