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

- **[added]** Completed Epic 11 slice 11.1, the core Scene vertical slice: a schema-only `scenes`
  migration (real `story_id` foreign key, indexed `position`, `slug`) and `Scene` model with a
  required Title, optional short description, and no `parent_id`. A Story now owns its contiguous
  narrative-order Scenes, maintained transactionally in flat mode by `PositionedResourceOrder`
  with the Story as scope owner.
- **[added]** Added story-scoped Scene routes and `ScenesController` on the HTML redirect/re-render
  flow: the canonical `/u/:universe_slug/s/:story_id/scenes` list with narrative-position badges,
  short-description previews, a full add/edit/delete journey, the stable Scene editor shell
  (Scene Details is the canonical inspectable page and one shared `_form` is the only editor), and
  a member `move` action driven by keyboard- and touch-operable Move up/Move down controls that
  are disabled at the sequence boundaries. Section/Event/datetime, tags, Elements, and world links
  are intentionally not routed yet.
- **[changed]** The left-sidebar **Scenes** entry is now a real story-scoped link with its own
  cached count while a Story is selected, and stays an `aria-disabled` placeholder with the
  existing "select a story" prompt when no Story is current — it never falls back to the first
  Story. The story overview links to both Sections and Scenes.
- **[fixed]** `MaintainsSiblingPositions` no longer assumes a `parent_id`: flat sequences omit the
  ordering parent entirely, so a parentless flat record works through the shared service.
- **[fixed]** Gave `Story` two separate sidebar count cache entries. `menu_scene_count` uses its own
  `cache_scope`, so adding a second scalar metric can no longer overwrite the section count;
  `InvalidatesMenuCounts` takes an optional `cache_scope:` for exactly this case.
- **[security]** Registered `Scene` in the `Ability` content registry; Scenes resolve their Universe
  through `scene.story.universe`, so public read stays open to guests while every mutation still
  requires the shared universe read/write/admin policy. Cross-scope story/scene lookups return 404.
- **[chore]** Added `scenes.yml` development data for the Dark (8 scenes) and LOTR (5 scenes)
  universes, including a title-only scene and explicit narrative positions, registered `Scene` as
  a flat story-scoped position group in the development-data registry, and added scene fixtures.
- **[chore]** Added model, request, routing, ability, menu-count, ordering-service, and browser
  coverage for the slice, and updated the architecture, data model, conventions, visual design,
  development, backlog, and known-quirks documentation.
- **[added]** Populated the disposable LOTR development universe with world-building sample data so
  every content model is exercised: 7 characters and 8 character tags, 12 hierarchically nested
  locations and 6 location tags, 5 items and 5 item tags, 5 relations with symmetric/asymmetric
  relation tags, 5 ownerships with date ranges, and 6 events forming a chained timeline with event
  tags. Added loader coverage asserting the counts, tag and location parentage, ownership links,
  and the event chain.
- **[security]** Removed `.kamal/secrets` from Git tracking, added an ignore rule and CI guard,
  restricted the preserved local file to mode `0600`, and documented that master-key rotation and
  history cleanup remain owner actions. The secret value was not read or changed.
- **[security]** Redacted password-reset tokens from Rails request paths, added no-store/no-referrer
  reset headers, strong-parameter validation, and regression coverage for blank resets and rendered
  multipart mail.
- **[security]** Made production mail/URL/SMTP settings explicit and fail-closed, enabled HTTPS
  redirects/HSTS behavior, restricted the production host allowlist, and marked the session cookie
  `Secure`; added mailer, cookie, and production-configuration coverage.
- **[fixed]** Added ADR 0009 and `PositionedResourceOrder`: positioned controller mutations now
  maintain hierarchical and explicitly flat sequences transactionally across create, move,
  reparent, and destroy, with focused service/controller tests and flat development-data metadata.
- **[security]** Rebuilt taxonomy dynamic fields and nodes with DOM APIs instead of `innerHTML`,
  added hostile-name browser coverage, and refreshed server-rendered taxonomy state after every
  successful mutation.
- **[fixed]** Completed backlog items 12 and 13: taxonomy parent/tag options and counts no longer
  remain stale, boundary insertion uses the actual list, native rename supports Enter/Space, and
  Move/Insert controls plus touch-visible targets provide non-drag editing. Added ADRs 0010 and
  focused keyboard/touch/system regressions.

- **[security]** Added machine-readable Tom Select version metadata to the local importmap pin and a
  regression test, so `bin/importmap audit` includes Tom Select 2.6.2 instead of skipping it.
  Complete Bun/npm graph, vendored-file provenance, and Dependabot coverage remain separate follow-up
  work.
- **[docs]** Distilled the 2026-09-25 DataFactor report into the agent guide, a durable quality
  guidance document, ADR 0006, focused backlog items, and verified follow-up quirks. The guidance
  keeps the report directional, reconciles stale health/lockfile signals, prioritizes real tested
  work over score gaming, makes security, privacy, and development-data boundaries explicit, and
  clarifies the destructive `db:restart` warning in the root README.
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
- **[docs]** Completed Epic 11 slice 11.0 as a documentation-only decision: ADR 0007 fixes
  story-owned narrative ordering, the Scene/Scene Element field contract, independent Event/time
  references, URL-backed workspace and JSON/HTML response boundaries, Section grouping, and the
  detailed deletion confirmations. No Scene schema, routes, controllers, views, fixtures, or demo
  data were added.
- **[planned]** Kept the newly recorded soft-delete/recycle-bin idea as later work; it is not part
  of slice 11.0 and requires a separate persistence, restore, authorization, and relation-tracking
  decision before implementation.
- **[docs]** Clarified the slice 11.0 review findings: Scene uses one Event-compatible datetime
  point, shared-record deletion copy now discloses existing dependent destroys, Scene destroy is
  explicitly HTML, and flat ordering must extend the existing positioned-controller concern rather
  than bypass it.
- **[added]** Implemented ADR 0008's registry-driven development universe loader: shared model
  order, strict YAML/file/reference/scope validation, normalized sibling positions, explicit
  `db:demo:check/load/reset` tasks, and common YAML data for Dark and LOTR.
- **[security]** Removed development data from `db:seed`/`db:prepare` and added environment and
  confirmation guards to destructive development database tasks; CI now validates checked-in data
  manifests instead of replanting demo records.
- **[fixed]** Hardened the development loader after review: reset tasks guard before any drop,
  environment overrides are test-only, association types/targets are validated, file/position
  contracts are strict, and incomplete schemas can be repaired by the reset path.

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
