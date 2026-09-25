# Changelog

Universe Maker does not have release versions yet. This file is a date-based history of the
project instead. It records application code, site/UI behavior, schema and data, tests,
documentation, configuration, security, and tooling. Entries are grouped by calendar date in
reverse chronological order; related commits from the same day are consolidated into summaries.
The initial history was reconstructed from the repository's Git history through 2026-09-25. Dates
without recorded project changes are omitted.

Labels used below:

- `added` — a new capability, model, workflow, or interface
- `changed` — behavior, architecture, data shape, or visual design was reworked
- `fixed` — a correctness, persistence, routing, or usability problem was resolved
- `security` — authentication, authorization, privacy, or data-integrity hardening
- `docs` — project knowledge, decisions, or contributor guidance changed
- `chore` — tests, fixtures, seed data, dependency, CI, or maintenance work
- `planned` — a documented future direction; not implemented in that entry

## 2026-09-25

- **[added]** Created this date-based `CHANGELOG.md` and added a standing rule to record every
  future code, site, data, test, documentation, configuration, security, and tooling change.
- **[security]** Hardened the authentication and request lifecycle: stale authentication cookies
  are invalidated, remembered story context is cleared at account boundaries, and password resets
  safely invalidate the current browser session.
- **[security]** Made the universe visibility flag explicit and non-null, centralized
  public/private read-write-admin authorization, and enforced same-universe/same-story scope on
  tag associations and reads. Private-universe non-members now receive the same 404 response as
  an unknown universe.
- **[fixed]** Hardened event temporal references with same-universe validation, model and database
  self-reference checks, and safe cleanup when referenced events are deleted.
- **[planned]** Documented the Epic 11 Scenes domain model, UX contract, delivery slices, tests,
  and development-data requirements in the shared backlog; the feature is not implemented yet.

## 2026-09-24

- **[changed]** Refreshed the Bootstrap visual system and application shell with shared theme
  tokens, page headers, content surfaces, empty states, flash messages, row actions, taxonomy
  styling, and responsive layout improvements.
- **[changed]** Reorganized navigation into a clearer top bar, Universe Bible sidebar,
  Configuration/Tags area, Settings panel, and URL-backed workspace tabs for related records.
- **[added]** Added the initial browser system-test suite for sign-in/sign-out, universes and
  stories, story-scoped sections, character creation, and timeline navigation; CI now runs these
  tests and preserves failure screenshots.
- **[security]** Added universe memberships with read, write, and admin levels, public/private
  universe visibility, authorization for all universe- and story-scoped content, and an admin-only
  membership manager.
- **[fixed]** Made story URLs consistently use the short `/s/:id` shape and required explicit
  story scope for section and section-tag URLs; added a test guard against positional
  universe-scoped route-helper arguments.
- **[fixed]** Corrected event title/name/slug synchronization and restored predictable generated
  slugs for renamed records and relation/ownership composites.
- **[fixed]** Prevented story selections from surviving logout, account changes, password resets,
  or stale sessions; added universe-name validation and access-aware navigation/actions.
- **[chore]** Made migrations schema-only and consolidated the current schema history; expanded
  per-universe development data under `db/data/` and documented the disposable-data boundary.
- **[chore]** Repaired the GitHub Actions workflow, pinned reproducible Bun installs, and made
  Chrome/system-test setup and teardown more reliable.
- **[docs]** Added the agent guide, vision, ADRs, architecture/data-model/conventions/development
  references, known and resolved quirk records, and the shared backlog; removed vestigial code and
  refreshed the project README.
- **[fixed]** Normalized fixture slugs, corrected a visibility helper, and expanded regression
  coverage for routing, navigation, authentication, authorization, and workspace flows.

## 2026-09-23

- **[changed]** Completed the multi-story Universe model: Universe is the top-level container,
  world-building records are shared at universe scope, and stories are selected and remembered
  explicitly rather than falling back to the first story.
- **[changed]** Made sections and section tags story-scoped, added the nested story routes, and
  tightened cross-story hierarchy and tag validation.
- **[changed]** Added Universe and Story context/switchers to the top bar and improved navigation
  for both the universe overview and story workspaces.
- **[changed]** Made tags optional on every content model and removed default-tag creation and
  required-tag validation so untagged records remain valid.
- **[added]** Added the project vision document and expanded the architecture, data-model, and
  development documentation around the new universe/story boundaries.
- **[fixed]** Repaired section-tag associations and data loaders after moving them under stories.
- **[chore]** Consolidated migrations into schema-only create migrations, refreshed fixtures and
  tests, normalized the project to Bun, and made demo data available through universe directories.
- **[fixed]** Cached sidebar entity counts and invalidated them after relevant committed writes,
  eliminating repeated count queries on every page.
- **[fixed]** Repaired taxonomy and navigation tests after the scope and naming changes.

## 2026-09-22

- **[changed]** Replaced the early per-content “type” taxonomies with hierarchical tags and
  standardized content-to-taxonomy links as many-to-many associations, updating models,
  controllers, views, routes, fixtures, migrations, and demo data together.
- **[changed]** Refined the left navigation and sidebar presentation as the taxonomy workspaces
  expanded.

## 2026-09-21

- **[changed]** Improved the sidebar and universe/story menu structure, labels, and visual
  presentation in preparation for the larger workspace redesign.

## 2026-09-15

- **[fixed]** Adjusted the application route shape to keep the new universe scope consistent
  across navigation and resource URLs.

## 2026-09-14

- **[changed]** Replaced the original Story-centered root with a Universe-centered domain across
  controllers, models, routes, views, deployment metadata, demo data, tests, and documentation.
- **[changed]** Added more navigation options while the top-level universe model was introduced.

## 2026-09-12

- **[changed]** Expanded the Dark development dataset and moved its seed records toward YAML files
  with ordered loaders and symbolic references for sections, content, taxonomies, relations, and
  ownerships.
- **[added]** Added foreground-color support to taxonomy tags and the relevant editor/badge UI.
- **[chore]** Added and refreshed frontend dependency locks, fixtures, and tests during the data
  migration; the temporary Yarn setup was later replaced by the project-wide Bun standard.
- **[fixed]** Updated test fixtures and expectations to match the expanded YAML-backed data.

## 2026-09-11

- **[added]** Made the Timeline functional with event layout, edges, popovers, and an interactive
  timeline controller.
- **[changed]** Added taxonomy colors, many-to-many element/taxonomy support, Tom Select pillbox
  multi-selects, slugs across models, and a refactored per-universe seed-data layout.
- **[changed]** Improved the left menu and interactive editors as the world-building workspaces
  became more complete.
- **[docs]** Added the Mozilla Public License 2.0 to the project.

## 2026-09-10

- **[added]** Added the first Event and Timeline models, routes, views, layout algorithm, and
  timeline styling.
- **[added]** Added entity counts to the navigation menus.

## 2026-09-09

- **[fixed]** Repaired ownership persistence and taxonomy drag-and-drop behavior.
- **[changed]** Refactored routes and the character workspace, improved the complete character
  view, and refreshed visual navigation and menus.
- **[fixed]** Corrected data/controller integration issues found while expanding the content
  workspaces.

## 2026-09-07

- **[added]** Added Ownerships and Ownership Types, including their controllers, views, routes,
  schema, fixtures, navigation entries, and tests.

## 2026-09-05

- **[changed]** Added conventional list/modal views for Characters and Items and improved the
  surrounding menu.

## 2026-09-04

- **[added]** Added Locations, Items, Characters, and Relations, together with their first taxonomy
  models, schema, controllers, views, routes, fixtures, and navigation.
- **[changed]** Organized migrations and taxonomy nodes, and made taxonomy selection required in
  the early content workflow (this was later relaxed when tags became optional everywhere).
- **[changed]** Improved menus and visual consistency across the growing workspace.
- **[fixed]** Repaired item persistence, taxonomy drag-and-drop, and associated tests.

## 2026-09-03

- **[added]** Added Sections and made Sections work as a taxonomy, completing and hardening the
  tree-based taxonomy editor.
- **[changed]** Improved seed data, test coverage, and menu organization around the new section
  hierarchy.

## 2026-09-02

- **[added]** Added Section Types and the first interactive taxonomy-tree editor.
- **[fixed]** Corrected route generation and the right-sidebar presentation.

## 2026-09-01

- **[added]** Established the Rails 8 application foundation with SQLite, Solid Cache/Queue/Cable,
  Docker/Kamal deployment files, CI/security tooling, Bootstrap, Sass/PostCSS, and the initial
  development workflow.
- **[added]** Added Users, Sessions, Stories, password reset, sign-in/sign-out, and the first
  Story CRUD workspace.
- **[changed]** Added story slugs, initial Dark/LOTR seed data, and the initial navigation shell.
