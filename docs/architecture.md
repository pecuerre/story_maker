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
| Assets | Propshaft; `stylesheet_link_tag :app` + `javascript_importmap_tags`; `stale_when_importmap_changes` on `ApplicationController` |
| Auth | `bcrypt` (`has_secure_password`), signed permanent cookie session |
| JSON views | Jbuilder (only for `universes/*.json`) |
| Jobs/cache/cable | `solid_queue`, `solid_cache`, `solid_cable` (DB-backed) |
| Mail | `PasswordsMailer` (`deliver_later`) |
| Deploy | **Kamal** (`config/deploy.yml`, service `universe_maker`) + Dockerfile |
| Extras | `cancancan` (**unused** — see [known_quirks.md](known_quirks.md)), `colorize` (seed output), `image_processing` |
| Tooling | RuboCop (`rubocop-rails-omakase` style), Brakeman, bundler-audit, importmap audit |

## Request lifecycle

`ApplicationController` before_action chain (order matters):

1. **`require_authentication`** (from the `Authentication` concern, registered first) — reads the
   signed cookie `session_id` → `Current.session`; redirects to `/session/new` unless the action
   is listed in `allow_unauthenticated_access` (universes: everything except nothing —
   it allows all its actions; sessions/passwords: `new/create/…`; timeline & content controllers
   require sign-in).
2. **`resume_session`** — loads the session again for public pages so `Current.user` is available
   in views (navbar).
3. **`set_current_universe`** — if `params[:universe_slug]` is present:
   `Current.universe = Universe.find_by!(slug: …)` (404 via `RecordNotFound` when unknown).
   Skipped by `SessionsController` and by `UniversesController#index`.
4. **`set_current_story`** — when a universe is present, resolves `Current.story`:
   - explicit `params[:story_id]` (sections) or `params[:id]` on the `stories` controller wins and
     is remembered in the session (`session[:current_story_ids]` keyed by universe id);
   - otherwise the remembered story, if it still exists;
   - `nil` otherwise. There is deliberately **no fallback to the universe's first story**: a story
     only becomes current when the user picks it, which is what reveals the WHAT/HOW sidebar
     cards and the current-story item in the top bar.
   A `story_id` from another universe raises `RecordNotFound` → 404 (cross-scope protection).

Per-request state lives in **`Current`** (`ActiveSupport::CurrentAttributes`):
`session`, `universe`, `story`, plus `delegate :user, to: :session`. It is reset between requests
by the Rails executor — never cache objects from it across requests.

Other global behavior: `allow_browser versions: :modern`,
`stale_when_importmap_changes`, `rate_limit to: 10, within: 3.minutes` on
`sessions#create` and `passwords#create`.

### Test-env behavior (matters when writing tests)
- `config.action_dispatch.show_exceptions = :rescuable` → `ActiveRecord::RecordNotFound`
  renders **404** instead of raising: assert with `assert_response :not_found`
  (`assert_raises` will **not** fire).
- `config.action_controller.raise_on_missing_callback_actions = true` → every
  `before_action`/`skip_before_action` must reference a method that exists.

## Authentication & sessions

- Sign-in form posts **flat** params `email_address` / `password`
  (`form_with url: session_path` → `params.permit(:email_address, :password)`), **not**
  `session[…]`. Wrong nesting fails with `ArgumentError: One or more password arguments are
  required` (500).
- `start_new_session_for(user)` creates a `Session` row (user agent, IP) and sets
  `cookies.signed.permanent[:session_id]`.
- Sign-out destroys the `Current.session` and deletes the cookie.
- Password reset: `passwords#create` mails a token link, `passwords#edit/update` change the
  password and destroy all of that user's sessions.
- Visibility: `Universe.visible_to(user)` (public or owned) is applied to the universes index and
  the navbar dropdown. **It is not applied on `universes#show` or on any content controller** —
  see [known_quirks.md](known_quirks.md).
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
- `universe_slug` itself is usually **not** passed: inside a universe-scoped request Rails fills
  missing segments from the current request (recall), which is why
  `universe_characters_path()` works in the sidebar. Outside such a request (e.g. `bin/rails
  runner`) the same call raises `missing required keys: [:universe_slug]`.
- `Universe#to_param` → slug (the route uses `param: :universe_slug` and looks up by slug).
  Content models are addressed by numeric id.
- Story URLs use the short `/s` resource path: `/u/:slug/s`, `/u/:slug/s/:story_id`, and the
  story-scoped content paths `/u/:slug/s/:story_id/sections` and
  `/u/:slug/s/:story_id/section_tags`. The universe-level `/u/:slug/sections` path is intentionally
  not routed; every section URL must include its story id.

## Response formats per controller

| Flow | Controllers | Behavior |
|---|---|---|
| JSON-only mutations | all `*_tags`, characters, locations, items, events, sections | `index/new` render HTML; `create/update/destroy` answer `format.json` only (an HTML POST would 406); errors → `unprocessable_content` + error hash |
| HTML flow | universes, **stories**, relations, ownerships | `redirect_to` on success (`status: :see_other` for PATCH/DELETE), re-render with errors |
| Both | universes (also has `*.json.jbuilder`) | |
| No mutation | timeline, sessions, passwords | |

## UI structure

Layout (`app/views/layouts/application.html.erb`): fixed top **navbar**, **left sidebar** (theme
cards), **main** content (`yield` + `content_for :title`), **right sidebar** (placeholder
panels). Everything follows a two-step selection:

1. **No universe selected yet** (fresh login → the Universes index): both sidebars are dropped
   and the main column takes the full width — the only thing to do is pick (or create) a
   universe from the *Universes* dropdown.
2. **Universe selected** (`Current.universe`): the sidebars appear with the universe-scoped
   cards; the navbar grows a dropdown named after the universe.
3. **Story selected** (`Current.story`): the story-scoped WHAT/HOW cards and the current-story
   navbar item appear.

Navbar items, left to right: **Dashboard** (placeholder), **Universes** (dropdown via
`nav_universes` → list / all / new), **[current universe]** (dropdown via `nav_stories` → the
universe's stories, *All stories*, *New story* — only once a universe is selected),
**[current story]** (link to `universe_story_path` — only once a story is selected).

Three page patterns + their Stimulus controllers are described in
[universe_maker_conventions.md](universe_maker_conventions.md#views---three-patterns):
taxonomy tree (`taxonomy_tree`), flat list + modal (`modal_form` + `tom_select`), plain forms.

Data flow for the tree/modal editors: `modal_fields.rb` serializes field descriptors into
`data-*-value` attributes → Stimulus builds the form → `fetch`/form submit to the JSON endpoints
→ response JSON `{ id, name, …, url }` updates the DOM. Drag & drop sends `{ position: n }`
patches handled by `MaintainsSiblingPositions`.

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
- Sidebar count data is stored in `Rails.cache`: one grouped entry for the current universe and one
  for the current story. `InvalidatesMenuCounts` expires the relevant entry after committed creates,
  destroys, and scope moves. Open transactions calculate without filling the cache, and entries have
  a one-hour safety expiry. See [former quirk #18](resolved_quirks.md#former-18--sidebar-issued-count-queries-on-every-page-fixed).
- The navbar adds one `stories` query per render (`nav_stories`).
