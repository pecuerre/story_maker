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
  password and destroy all of that user's sessions. If the reset is completed in that user's
  current browser, its authentication cookie and remembered story selections are cleared too.
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
  story-scoped content paths `/u/:slug/s/:story_id/sections` and
  `/u/:slug/s/:story_id/section_tags`. The universe-level `/u/:slug/sections` path is intentionally
  not routed; every section URL must include its story id.
- Universe memberships live at `/u/:universe_slug/members`; only universe admins can reach the
  membership index and mutations. The taxonomy workspace lives at `/u/:universe_slug/tags`; its
  `scope` and `taxonomy` query parameters select the Universe/Story scope and taxonomy editor.

## Response formats per controller

| Flow | Controllers | Behavior |
|---|---|---|
| JSON-only mutations | all `*_tags`, characters, locations, items, events, sections | `index/new` render HTML; `create/update/destroy` answer `format.json` only (an HTML POST would 406); errors → `unprocessable_content` + error hash |
| HTML flow | universes, **stories**, relations, ownerships, universe memberships | `redirect_to` on success (`status: :see_other` for PATCH/DELETE), re-render with errors |
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
3. **Story selected** (`Current.story`): Story workspace gains the story overview plus a
   **Sections** workspace tab. The story is still remembered per universe; no first-story fallback
   exists.

The navbar contains **Universes**, the current **Universe** switcher, the current **Story**
switcher, and an **Account** menu. It keeps **New story** in the Story dropdown rather than in the
left sidebar, and only shows contribution/admin actions when the current user has the required
level. Universe-scoped content is shared by every story; Sections and Section tags remain
story-scoped. Related record workspaces now keep only the records together in URL-backed tabs:
Characters / Relations, Locations, Events, Items / Ownerships, and Sections. Taxonomy management
lives under **Configuration → Tags**, with **Universe Tags** (Character, Relation, Location, Event,
Item, and Ownership tags) and **Story Tags** (Section tags) selectors.

All work pages use the shared `page_header`, `content_surface`/`entity-list`, `row_actions`, and
`empty_state` patterns. Visual tokens and responsive/component conventions live in
[`visual_design.md`](visual_design.md). Three functional page patterns + their Stimulus
controllers are described in
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
