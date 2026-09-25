# Architecture

How a request flows through Universe Maker: stack, lifecycle, authentication, routing/URL rules,
UI patterns and the Timeline algorithm. Conventions are in
[universe_maker_conventions.md](universe_maker_conventions.md), schema in
[data_model.md](data_model.md).

## Stack

| Layer | Choice |
|---|---|
| Framework | Ruby on Rails **8.1.3** (`load_defaults 8.1`), app module `UniverseMaker` |
| Ruby | **3.4.10** (pinned in `mise.toml`) |
| Database | **SQLite 3** (`sqlite3 >= 2.1`); separate `cache/cable/queue` schemas for solid_* |
| Server | Puma + **Thruster** (in the Docker image) |
| Front-end | Hotwire (**Turbo + Stimulus**), **importmap** (no bundler for JS), Bootstrap 5 + bootstrap-icons + tom-select via npm, CSS built with **sass → postcss/autoprefixer** (`cssbundling-rails`) |
| Assets | Propshaft; `stylesheet_link_tag :app` + `javascript_importmap_tags`; development uses a dynamic `tmp/assets` manifest so the CSS watcher is not shadowed by a stale public manifest; `stale_when_importmap_changes` on `ApplicationController` |
| Auth | `bcrypt` (`has_secure_password`), signed permanent cookie session |
| JSON views | Jbuilder (only for `universes/*.json`) |
| Jobs/cache/cable | `solid_queue`, `solid_cache`, `solid_cable` (DB-backed) |
| Mail | `PasswordsMailer` (`deliver_later`) |
| Deploy | **Kamal** (`config/deploy.yml`, service `universe_maker`) + Dockerfile |
| Extras | `cancancan` (universe authorization), `colorize` (seed output), `image_processing` |
| Tooling | RuboCop (`rubocop-rails-omakase` style), Brakeman, bundler-audit, importmap audit |

## Request lifecycle

`ApplicationController` before_action chain (order matters):

1. **`require_authentication`** (from the `Authentication` concern, registered first) — reads the
   signed cookie `session_id` → `Current.session`; redirects to `/session/new` unless the action
   is listed in `allow_unauthenticated_access`. Universe content controllers explicitly allow only
   their read actions so public pages can render; every write still requires a session before the
   authorization callback runs.
2. **`resume_session`** — loads the session again for public pages so `Current.user` is available
   in views (navbar).
3. **`set_current_universe`** — if `params[:universe_slug]` is present:
   `Current.universe = Universe.find_by!(slug: …)` (404 via `RecordNotFound` when unknown).
   Skipped by `SessionsController`, `PasswordsController`, and by `UniversesController#index`;
   those non-universe controllers also skip the authorization callback.
4. **`authorize_universe_access`** (from `UniverseAuthorization`) — checks the resolved universe
   through `Ability`/`current_ability`: public universes grant read access to guests and write
   access to signed-in users; private universes require an owner or membership. A private
   universe is hidden from every non-member, including guests, with the same 404 used for an
   unknown slug. Guests attempting a public-universe write are sent to sign in, while
   authenticated collaborators without the required level receive 403.
5. **`set_current_story`** — when a universe is present, resolves `Current.story`:
   - explicit `params[:story_id]` (sections) or `params[:id]` on the `stories` controller wins and
     is remembered in the session (`session[:current_story_ids]` keyed by universe id);
   - otherwise the remembered story, if it still exists;
   - `nil` otherwise. There is deliberately **no fallback to the universe's first story**: a story
     only becomes current when the user picks it, which is what reveals the WHAT/HOW sidebar
     cards and the current-story item in the top bar. The remembered map is cleared whenever an
     authenticated session starts or ends, when password reset invalidates the current browser
     session, and when a stale authentication cookie is encountered, so it cannot cross accounts.
   A `story_id` from another universe raises `RecordNotFound` → 404 (cross-scope protection).

Per-request state lives in **`Current`** (`ActiveSupport::CurrentAttributes`):
`session`, `universe`, `story`, plus `delegate :user, to: :session`. It is reset between requests
by the Rails executor — never cache objects from it across requests.

Other global behavior: `allow_browser versions: :modern`,
`stale_when_importmap_changes`, `rate_limit to: 10, within: 3.minutes` on
`sessions#create` and `passwords#create`.

### Test-env behavior (matters when writing tests)
- `config.action_dispatch.show_exceptions = :rescuable` and the application-level
  `ActiveRecord::RecordNotFound` handler render **404** instead of raising: assert with
  `assert_response :not_found` (`assert_raises` will **not** fire).
- `config.action_controller.raise_on_missing_callback_actions = true` → every
  `before_action`/`skip_before_action` must reference a method that exists.

## Authentication & sessions

- Sign-in form posts **flat** params `email_address` / `password`
  (`form_with url: session_path` → `params.permit(:email_address, :password)`), **not**
  `session[…]`. Wrong nesting fails with `ArgumentError: One or more password arguments are
  required` (500).
- `start_new_session_for(user)` creates a `Session` row (user agent, IP) and sets
  `cookies.signed.permanent[:session_id]`.
- Sign-out destroys the `Current.session`, deletes the cookie, and clears remembered story
  selections. Starting a new authenticated session performs the same context cleanup, and a
  request with a stale/deleted authentication session clears its cookie and story context.
- Password reset: `passwords#create` mails a token link, `passwords#edit/update` change the
  password and destroy all of that user's sessions. Password-reset responses set `Cache-Control:
  no-store` and `Referrer-Policy: no-referrer`. The custom `PasswordResetPathFilter` redacts the
  token path segment in Rails request logs; production proxy/access-log configuration must also
  avoid retaining reset URLs. If the reset is completed in that user's current browser, its
  authentication cookie and remembered story selections are cleared too.
- Visibility and authorization are centralized in `Ability` plus `UniverseAuthorization`:
  - public universe: guests may read; every signed-in user may write; only the owner or an admin
    member may change universe settings or memberships;
  - private universe: only the owner and members may enter; read members cannot mutate, write
    members can contribute, and admin members can also manage access;
  - access is inherited by every story and component in the universe; story-scoped records are
    authorized through their story's universe.
- `Universe.visible_to(user)` applies the same policy to the universes index and navbar dropdown.
  Universe show and all universe-scoped content callbacks apply the policy before loading records.
- Guests attempting a public-universe write are redirected to sign in. Every non-member,
  including a guest, receives 404 for a private universe; a member with insufficient
  write/admin access receives 403. This keeps private-universe existence indistinguishable from
  an unknown slug while making permission failures explicit for known collaborators.
- The membership admin screen lives at `/u/:universe_slug/members` and is linked for universe
  admins from the universe view/navigation.
- In tests use `sign_in_as(users(:user_one))` / `sign_out`
  (`test/test_helpers/session_test_helper.rb`, mixed into integration tests).

## Routing & URL generation (the sharp edges)

- Universe content is mounted with `scope "u/:universe_slug", as: :universe`
  → named helpers `universe_*`, URLs `/u/<slug>/...`.
- Stories are a full resource inside that scope with sections and section tags nested:
  `resources :stories, path: "s" do resources :sections; resources :section_tags end`.
- **Always pass route keys by name**: `universe_story_path(id: story)`,
  `universe_story_sections_path(story_id: story)`, `universe_story_section_path(story_id: story,
  id: section)`.
  A positional record (`universe_story_sections_path(story)`) is assigned to the *first* dynamic
  segment — `universe_slug` — and yields `missing required keys: [:story_id]` or a broken URL.
  The test suite scans Ruby and ERB call sites and rejects positional arguments to universe-scoped
  route helpers.
- `universe_slug` itself is usually **not** passed: inside a universe-scoped request Rails fills
  missing segments from the current request (recall), which is why
  `universe_characters_path()` works in the sidebar. Outside such a request (e.g. `bin/rails
  runner`) the same call raises `missing required keys: [:universe_slug]`.
- `Universe#to_param` → slug (the route uses `param: :universe_slug` and looks up by slug).
  Content models are addressed by numeric id.
- Story URLs use the short `/s` resource path: `/u/:slug/s`, `/u/:slug/s/:story_id`, and the
  story-scoped content paths `/u/:slug/s/:story_id/sections`, `/u/:slug/s/:story_id/section_tags`,
  `/u/:slug/s/:story_id/scene_tags`, and `/u/:slug/s/:story_id/scenes`. The universe-level
  `/u/:slug/sections`, `/u/:slug/scene_tags`, and `/u/:slug/scenes` paths are intentionally not
  routed; every section, tag, and scene URL must include its story id.
- Universe memberships live at `/u/:universe_slug/members`; only universe admins can reach the
  membership index and mutations. The taxonomy workspace lives at `/u/:universe_slug/tags`; its
  `scope` and `taxonomy` query parameters select the Universe/Story scope and taxonomy editor.

## Response formats per controller

| Flow | Controllers | Behavior |
|---|---|---|
| JSON-only mutations | all `*_tags` (including `scene_tags`), characters, locations, items, events, sections | `index/new` render HTML; `create/update/destroy` answer `format.json` only (an HTML POST would 406); errors → `unprocessable_content` + error hash |
| HTML flow | universes, **stories**, **scenes** (including Scene Tag assignment), relations, ownerships, universe memberships | `redirect_to` on success (`status: :see_other` for PATCH/DELETE), re-render with errors |
| Both | universes (also has `*.json.jbuilder`) | |
| No mutation | tags, timeline, sessions, passwords | |

## UI structure

The UI is a Bootstrap 5.3 application shell with a fixed dark **navbar**, responsive left and
right workspace navigation columns, and one flexible **main content** area. The left column is
the working navigation; the right column contains **Settings** plus reserved space for future
universe tools such as richer collaboration, analytics, and AI. The right column becomes a
Bootstrap `offcanvas-end` below `xl`, and the left column becomes an `offcanvas-start` below `lg`.
On narrower screens, the mobile workspace bar exposes **Tools** below `xl` and **Menu** below `lg`.

Everything follows a two-step scope selection:

1. **No universe selected yet** (fresh login → the Universes index): workspace navigation is not
   rendered and the main column takes the full width. The only initial task is selecting or
   creating a universe from the **Universes** dropdown.
2. **Universe selected** (`Current.universe`): a 16rem workspace sidebar appears on large screens
   and as a left offcanvas below the `lg` breakpoint. At `xl` and above, a 14rem right utility
   sidebar is also visible. The left sidebar contains **Story workspace**, **Universe Bible**, and
   a separate **Configuration** section containing **Tags**. The right utility sidebar has a
   **Settings** section containing **Members** for universe admins. The navbar adds explicit
   **Universe: …** and **Story: …** context/switchers.
3. **Story selected** (`Current.story`): Story workspace gains the story overview plus **Sections**
   and **Scenes** workspace tabs. The story is still remembered per universe; no first-story
   fallback exists. The **Scenes** sidebar entry is a real story-scoped link only while a story is
   selected; with no current story it stays an `aria-disabled` placeholder beside the explicit
   "select a story" prompt.

The navbar contains **Universes**, the current **Universe** switcher, the current **Story**
switcher, and an **Account** menu. It keeps **New story** in the Story dropdown rather than in the
left sidebar, and only shows contribution/admin actions when the current user has the required
level. Universe-scoped content is shared by every story; Sections and Section tags remain
story-scoped. Related record workspaces now keep only the records together in URL-backed tabs:
Characters / Relations, Locations, Events, Items / Ownerships, and Sections. Taxonomy management
lives under **Configuration → Tags**, with **Universe Tags** (Character, Relation, Location, Event,
Item, and Ownership tags) and **Story Tags** (Section and Scene tags) selectors.

All work pages use the shared `page_header`, `content_surface`/`entity-list`, `row_actions`, and
`empty_state` patterns. Visual tokens and responsive/component conventions live in
[`visual_design.md`](visual_design.md). Three functional page patterns + their Stimulus
controllers are described in
[universe_maker_conventions.md](universe_maker_conventions.md#views---three-patterns):
taxonomy tree (`taxonomy_tree`), flat list + modal (`modal_form` + `tom_select`), plain forms.

Data flow for the tree/modal editors: `modal_fields.rb` serializes field descriptors into
`data-*-value` attributes → Stimulus builds every dynamic field and node by DOM APIs (user names,
descriptions, option labels, and ARIA values are assigned as text/attributes, never interpolated
into `innerHTML`) → `fetch` submits to the JSON endpoints → a successful mutation uses a
same-URL Turbo visit so serialized parent/tag descriptors and all counts are refreshed from the
server. Taxonomy insertion, move, and edit controls are available by pointer, touch, and keyboard;
HTML5 drag/drop is an optional enhancement. Position changes use the transactional ordering
service described in ADR 0009. The Story Tags scope now presents **Section tags** and **Scene
tags** as separate story-scoped taxonomy tabs; both use the same DOM-safe tree and JSON mutation
contract, while Scene assignment stays in the HTML Scene form.

## Scene architecture (slices 11.1–11.4 implemented)

[ADR 0007](adr/0007-story-owned-scenes-and-elements.md) accepts the first-version Scene domain and
UX contract. Slices 11.1–11.4 implement its core, references, Section grouping, and Scene Tag
taxonomy: the `scenes` and `scene_tags` tables, the `Scene` and `SceneTag` models, story-scoped
routes, the canonical Scenes list, the Scene Details editor with its URL-backed tab shell,
narrative-order moves, both Section-grouping paths, and optional tag assignment. Elements and
world-presence links remain in slices 11.5–11.10 and are **not** routed yet.

### Ownership and resolution

- A required `Story` owns the contiguous, narrative-order `Scene.position`. A Scene never causes a
  Story to be selected implicitly. `ScenesController` uses the flat mode of `PositionedResourceOrder`
  through `maintains_flat_positions_for :scene`; it does not inherit `Hierarchical` and does not
  use `section_id` as an ordering parent.
- `Scene belongs_to :story` and resolves its Universe through `scene.story.universe`
  (`Scene#universe`) for authorization and shared helper decisions. Controllers load Scenes
  through `Current.universe.stories.find(...).scenes.find(...)`; unscoped record lookup is not
  permitted.
- A Scene persists a required title (`name`, labelled **Title**), an optional short description, a
  `slug`, its narrative `position`, an optional same-Story `section_id`, an optional same-Universe
  `event_id`, one optional in-world `datetime`, and zero or many optional same-Story `SceneTag`
  assignments.
- A `SceneTag belongs_to Story` and follows the same hierarchical/colored taxonomy conventions as
  `SectionTag`; it resolves its Universe through that Story and is managed only through the
  story-scoped taxonomy workspace.
- `UniverseScopeResolver` is the single answer to "which universe owns this record?". `Ability` and
  `ApplicationHelper#universe_for_record` both call it, so record-level authorization and the
  mutation controls a view renders cannot disagree. It resolves a record directly through
  `#universe`, or through a declared owner association (`story`, `scene`, `section`). A model
  nested deeper than one of those — a speaker link under a Scene Element, for example — defines its
  own `universe` method that delegates through its owner, and the first step of the walk finds it.
- `SectionPaths` (a value object, not a record) turns one ordered Section list into every
  root-first ancestor path and the depth-indented selector options. Preloading an arbitrary tree
  depth with `includes` is not possible, and `Section#ancestor_chain` would query per level per
  Scene, so both the Scenes list and the Sections workspace build the index from a single query.
  `SceneTagPaths` does the same for the story-scoped Scene Tag hierarchy used by the assignment form.
- The global Scene list is ordered by `(position, id)` and is never grouped by Section.

### Implemented routes and response split

| Purpose | Canonical URL | Mutation response |
|---|---|---|
| Global Scene list | `/u/:universe_slug/s/:story_id/scenes` | HTML |
| Scene Details | `/u/:universe_slug/s/:story_id/scenes/:scene_id` | HTML |
| Narrative-order move | `PATCH /u/:universe_slug/s/:story_id/scenes/:id/move` | HTML |
| Section grouping | `PATCH /u/:universe_slug/s/:story_id/scenes/group` | HTML |
| Scene Tag taxonomy | `/u/:universe_slug/s/:story_id/scene_tags` | JSON mutations, HTML index |
| New / Edit Scene | `.../scenes/new`, `.../scenes/:id/edit` | HTML |
| Characters / Items / Locations tabs, Elements (later slices) | not routed yet | JSON when added |

Scenes have no Universe-level route. Every Scene and Scene Tag route includes its Story, and all
route-helper keys are passed by name. `ScenesController` answers HTML only and follows the
redirect/re-render flow: successful create/update redirect to Scene Details, a move redirects back
to the list with a `303`, and grouping redirects back to the Sections workspace with a `303`.
`SceneTagsController` follows the established taxonomy JSON mutation contract while its index uses
the shared tree; it rejects a non-JSON mutation before the positioned service can commit anything.
Because the Scene flow never uses the shared JSON modal path, it does not inherit
the current modal submission, error-display, or stale-DOM behavior in
[`known_quirks.md`](known_quirks.md); slice 11.5 must still fix that path before Elements depend on
it.

A move is a single transactional service call. The controller converts `direction=up|down` into
the neighboring target position and lets `PositionedResourceOrder` clamp and normalize the group,
so a move at a sequence boundary is a no-op with explicit flash copy rather than a partial write.
An unknown `direction` is a `400` (`ActionController::ParameterMissing`), never a silent success.

Grouping is a different kind of change, so it is a different action with its own documented failure
modes. `ScenesController#group` posts the chosen `scene_id` and `section_id` to `/scenes/group` (a
collection route, so the workspace form needs no client-side scripting) and resolves the Section
through `@story.sections.find`. A Section from another story or universe is therefore a `404` and
the model's own scope validation cannot fail here. Both `scene_id` and `section_id` keys are
required, and a blank `section_id` is the explicit **Ungrouped** choice — `params.expect` rejects a
blank scalar, so that one key is checked for presence directly. The flash copy always states that
the narrative position did not change.

### Validation, not exceptions

Same-Story and same-Universe scope is an application rule: a real foreign key cannot prove it. The
`Scene` model adds `section_belongs_to_story`, `event_belongs_to_story_universe`,
`optional_references_exist`, and `datetime_is_a_valid_point`. A malformed `section_id`/`event_id`
therefore renders a `422` field error through the ordinary HTML re-render flow instead of raising a
foreign-key exception, and an unparseable `datetime` is reported instead of being silently cast to
`nil` and discarded. The editor re-renders the submitted raw value, so a rejected entry is never
cleared from the field. The form's selectors, the delete confirmations, and the development-data
loader enforce the same rules. `SceneTag` uses the shared hierarchical Story scope validation, and
`Scene`/`SceneTag` use the shared `has_many_tags` DSL so a foreign-story assignment is a normal
model error rather than a cross-scope disclosure. The Story-scoped `scenes_scene_tags` table also
has real foreign keys and a unique `[scene_id, scene_tag_id]` index.

### UX

The Story workspace gained a flat **Scenes** list with Title/short-description previews, a 1-based
narrative-position badge, a Section-group or **Ungrouped** badge, optional Scene Tag badges, and
add/edit/delete actions. Visible Move up/Move down buttons are real `button_to` forms (keyboard
operable, no drag required) and are disabled at the sequence boundaries. The page states that the
order is the order the story is told, not in-world chronography, and that a section group only
organizes a scene. Read-only users and public guests see the same list with no mutation controls and
a non-instructional empty state.

Scene Details (`/scenes/:id`) is the canonical, inspectable destination: it renders the Title,
narrative position, short description, Section group, Scene Tags, linked Event, formatted in-world
time, and story context for writers, read-only members, and guests, and gives only writers an **Edit
scene** action. The Title/Description/Section/Event/time/Scene Tag form lives once, at
`/scenes/:id/edit` (`scenes/_form`, reused by `new`), so there is no second edit surface. Scene
Tag definitions are edited separately in the story-scoped taxonomy workspace; assignment remains
optional and never receives a default.

The editor shell is URL-backed through `shared/_content_tabs`: **Scene Details** is a live link and
**Characters**, **Items**, and **Locations** are `aria-disabled` placeholders with an explanatory
title until their slices add a real destination. A tab is never rendered as a link to a route that
does not exist, and it is never an in-document Bootstrap pane.

The Sections workspace keeps its taxonomy tree and adds a **Grouped scenes** outline below it:
ungrouped scenes first, then each Section's nested path, with the narrative position and Title of
every scene in canonical order inside its group. For writers it adds one selector-driven move form
(Scene → group) offering **Ungrouped** plus every Section path; drag-and-drop is not offered, so the
move is always available by keyboard and on touch. Read-only members and guests see the same outline
with no controls. The tree's read-only empty state now has its own copy, so a read-only member is
not told to add or drag sections.


## Production boundary

Production fails closed when `APP_HOST`, `MAILER_FROM`, or `SMTP_ADDRESS` is missing. It uses
`APP_HOST` with HTTPS for generated mailer URLs, configures SMTP from the documented environment
variables, enables `assume_ssl` and `force_ssl`, keeps `/up` available to the health check, and
sets the production session cookie `Secure` explicitly. The Kamal/deployment host must provide a
TLS-terminating proxy and the required environment variables; the application does not provide a
development or placeholder mail host fallback.

The Rails request logger redacts password-reset path tokens through
`lib/password_reset_path_filter.rb`. This protects application logs, not an upstream proxy's
access log or a browser's external history; production logging and retention must be configured
accordingly.

## Timeline

Route `get "timeline", to: "timeline#index"` → `TimelineController` → **`TimelineLayout`**
(`app/models/timeline_layout.rb`) + **`UnionFind`** (`app/models/union_find.rb`):

1. Events marked as simultaneous (`simultaneous_event`) are grouped with union-find.
2. Between groups a directed "happens no later than" DAG is built, trying in order of confidence:
   full non-overlapping start/end ranges → start dates alone → end dates alone → explicit
   `before_event`/`after_event`. Edges that would create a cycle are skipped (`reachable?`).
3. Longest-path layering assigns rows: no known predecessor → top row; otherwise at least one row
   below all predecessors.
4. The view renders `@layers`/`@edges`; `timeline_controller.js` handles pan/zoom and popovers
   whose content comes from `TimelineHelper#event_popover_content` (dates, tags, relations,
   description).

## Caching / performance notes

- `stale_when_importmap_changes` (HTTP caching keyed on the importmap).
- `solid_cache` store in production; `nav_universes` and `nav_stories` are memoized per request.
- Sidebar count data is stored in `Rails.cache`: one grouped entry for the current universe, and
  one entry per scalar story metric. A story caches its section count and its scene count under
  two distinct keys (`Story::SECTION_MENU_COUNT_SCOPE` and `Story::SCENE_MENU_COUNT_SCOPE`) so a
  second scalar metric on the same owner can never overwrite the first; `InvalidatesMenuCounts`
  takes an optional `cache_scope:` for exactly that reason and expires the correct entry.
  Expiration happens from model `after_commit` callbacks when a counted record is created or
  destroyed (and when a record moves to another scope). Open transactions calculate without
  filling the cache, and entries have a one-hour safety expiry. See
  [former quirk #18](resolved_quirks.md#former-18--sidebar-issued-count-queries-on-every-page-fixed).
- The navbar adds one `stories` query per render (`nav_stories`).
