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

The appearance preference is deliberately **not** part of `Current`: a theme belongs to the browser,
not to the session, universe, or story a request carries. `AppTheme` reads it from the signed cookie
`um_theme` and the layout renders it as `<html data-bs-theme>`; the `current_theme` helper memoizes it
for the render. See [ADR 0013](adr/0013-platform-settings-and-browser-theme.md).

Other global behavior: `allow_browser versions: :modern`,
`stale_when_importmap_changes`, `rate_limit to: 10, within: 3.minutes` on
`sessions#create` and `passwords#create`.

### Test-env behavior (matters when writing tests)
- `config.action_dispatch.show_exceptions = :rescuable` and the application-level
  `ActiveRecord::RecordNotFound` handler render **404** instead of raising: assert with
  `assert_response :not_found` (`assert_raises` will **not** fire).
- `config.action_controller.raise_on_missing_callback_actions = true` → every
  `before_action`/`skip_before_action` must reference a method that exists.
- `allow_forgery_protection` is **off** for the fast request suite. The two files that must prove a
  real token is sent and accepted wrap their own window in `with_forgery_protection`:
  `test/controllers/csrf_mutation_test.rb` (server side) and
  `test/system/csrf_token_test.rb` (a real browser, for both `fetch` implementations). A passing
  request test therefore does **not** mean a token was verified. A JSON mutation whose token is
  rejected answers **403**, so the shared editor can say "reload the page and sign in again" instead
  of reporting a validation error the server never produced.

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
- `Universe.visible_to(user)` applies the same policy to the universes index (the landing page).
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
- **Platform settings are not universe-scoped**: `GET /settings` shows the page and
  `PATCH /settings` stores a preference. It is the only page outside `/u/:universe_slug` that is not
  authentication, so it skips `set_current_universe` and `authorize_universe_access` and allows
  unauthenticated access. See [ADR 0013](adr/0013-platform-settings-and-browser-theme.md).
- **Search is both**: `GET /search` searches the platform, and
  `GET /u/:universe_slug/search` keeps a universe-scoped search inside that universe's URL so the
  shared callbacks authorize it. A helper that builds both, for a form that must work on either,
  is `search_path_for(universe, query)`; a search result's own link is the path stored in the
  document, not a route rebuilt at render time. See **Global search** below.
- Every `universe_*` route helper takes named keys, **including from a model**. Search builds paths
  from `app/models/concerns/searchable.rb` and `app/models/search/commands.rb`, which are outside any
  request, so `universe_slug` is passed explicitly there rather than relied on from recall.

## Record details pages

Every standard element and every element tag has exactly one details page, and it is the
destination of the **Details** link that every list row and taxonomy node renders. The URLs are the
ordinary nested resource show routes:

| Record | Details URL |
|---|---|
| Character, Location, Item, Event | `/u/:universe_slug/characters\|locations\|items\|events/:id` |
| Relation, Ownership | `/u/:universe_slug/relations\|ownerships/:id` |
| Character/Relation/Location/Event/Item/Ownership tag | `/u/:universe_slug/<element>_tags/:id` |
| Section, Section Tag, Scene Tag | `/u/:universe_slug/s/:story_id/sections\|section_tags\|scene_tags/:id` |
| Universe, Story, Scene | `/u/:universe_slug`, `/u/:universe_slug/s/:story_id`, `.../scenes/:id` |

A details page is HTML-only, guest-readable on a public universe, and read-only: it renders no
mutation control at all, so authorization only decides whether the page is reachable. The record is
always loaded through the authorized scope (`Current.universe.<plural>.find` or
`@story.<plural>.find`), so another universe's or story's id is a `404`.

The page is composed from four shared partials, so each record type can keep adding information
without inventing a new page pattern:

- `shared/_record_details` — page header (eyebrow, title, back link) plus the identity card;
- `shared/_detail_facts` — the `[ label, value ]` grid, fed by the `detail_fact` helper so a
  missing value renders explicit copy instead of a blank row;
- `shared/_detail_section` — one related-records section, with a `count` badge, and its empty state
  whenever the count is zero or no block was given;
- `shared/_tagged_record_list` — the records carrying a tag, each linking to its own page and showing
  every tag it carries (not just the one filtering the list), batch-loaded through `RecordTags` so the
  badge row costs one grouped query rather than one per record.

A content page currently identifies the record and then states honestly that the related information
will appear later. A Section additionally lists the scenes grouped under it, each still showing its
narrative position, because grouping never sets order. A tag page lists the
records that carry it through `HasManyTags#tagged_records`, the scoped inverse association, so it
cannot disclose another universe's or story's records. `TaggedRecordCounts` answers the same
question for a whole taxonomy in one grouped query, which is what the row's `.record-count` pill
uses.

## Response formats per controller

| Flow | Controllers | Behavior |
|---|---|---|
| JSON-only mutations | all `*_tags` (including `scene_tags`), characters, locations, items, events, sections, **scene_elements**, **scene_characters**, **scene_items**, **scene_locations** | `index/new/show` render HTML; `create/update/destroy` answer `format.json` only, and a request that does not ask for JSON is refused with `406` **before** anything is written (`RequiresJsonMutationFormat`); errors → `unprocessable_content` + error hash |
| HTML flow | universes, **stories**, **scenes** (including Scene Tag assignment), relations, ownerships, universe memberships, **settings** | `show` renders the record's details page; `redirect_to` on success (`status: :see_other` for PATCH/DELETE), re-render with errors |
| Both | universes (also has `*.json.jbuilder`), **searches** | |
| No mutation | tags, timeline, sessions, passwords | |

`searches` is the one read-only flow that deliberately serves both formats from one action:
HTML is the shareable results page and JSON is the autocomplete dropdown. It never mutates, so
there is no ambiguous HTML-and-JSON *mutation* to forbid, and
`RequiresJsonMutationFormat` does not apply to it.

`scene_elements` has no read action at all, because Elements are read on Scene Details; every one of
its actions is a mutation and therefore authenticated. `scene_characters`, `scene_items`, and
`scene_locations` mix the two: each `index` is a real HTML read page and each one's mutations are
JSON-only, the same hybrid the Scene record flow is. No action accepts an ambiguous
HTML-and-JSON mutation merely to make a form work.

### Soft delete

A delete is a soft delete: the controller calls `soft_delete` instead of `destroy!`, the record's
`deleted_at` is set, and the row is kept. The `SoftDeletable` default scope hides soft-deleted
records from every ordinary query, so a deleted record is invisible to lists, details pages,
associations, and search exactly as if it were gone — but it can be restored. The positioned
controllers (`destroy_with_sibling_position`) soft-delete through `PositionedResourceOrder`, which
normalizes the remaining siblings' positions in the same transaction, so a soft-deleted record
leaves the same contiguous gap a hard delete would. A soft delete cascades to the model's declared
associations (`soft_deletes`), so deleting a Universe soft-deletes its whole subtree; see
[data_model.md](data_model.md#soft-delete) for the full cascade and nullify rules.

## UI structure

The UI is a Bootstrap 5.3 application shell with a fixed dark **navbar**, responsive left and
right workspace navigation columns, and one flexible **main content** area. The left column is
the working navigation; the right column contains **Configuration** (Tags plus the Members access
manager) plus reserved space for future universe tools such as richer collaboration, analytics, and
AI. The right column becomes a
Bootstrap `offcanvas-end` below `xl`, and the left column becomes an `offcanvas-start` below `lg`.
On narrower screens, the mobile workspace bar exposes **Tools** below `xl` and **Menu** below `lg`.

Everything follows a two-step scope selection:

1. **No universe selected yet** (fresh login → the Universes index): workspace navigation is not
   rendered and the main column takes the full width. The only initial task is selecting or
   creating a universe from the **Universes** dropdown.
2. **Universe selected** (`Current.universe`): a 16rem workspace sidebar appears on large screens
   and as a left offcanvas below the `lg` breakpoint. At `xl` and above, a 14rem right utility
   sidebar is also visible. The left sidebar is one continuous navigation surface read as two
   scoped blocks, each with its own hue:

   1. **Current universe** context (universe name);
   2. **Universe Bible** (Characters, Locations, Events, Timeline, Items);
   3. **Current story** context (story name) or an explicit
      "None selected" state;
   4. **Story workspace** (Story overview, Sections, Scenes) or All stories plus a prompt.

   The right utility sidebar is the tools scope and the third hue: a green **Universe tools**
   context block followed by a **Configuration** section with **Tags** for everyone and
   **Members** for universe admins, then the future **Collaboration**, **Analytics**, and **AI**
   placeholder groups.
3. **Story selected** (`Current.story`): Story workspace gains the story overview plus **Sections**
   and **Scenes** workspace tabs. The story is still remembered per universe; no first-story
   fallback exists. The **Scenes** sidebar entry is a real story-scoped link only while a story is
   selected; with no current story it stays an `aria-disabled` placeholder beside the explicit
   "select a story" prompt.

The universe page is the landing page for a universe, so it lists the universe's own stories with an
**Open** action each instead of a summary card that links onward; the header keeps **All stories**
for the full page and carries **New story** for writers. It reuses the memoized story list, so the
page adds no query and no `COUNT` — the per-story section and scene counts stay in the cached
sidebar metrics.

The navbar is deliberately three links and no scope switchers: the **Universe Maker** brand links to the
landing page (`/`, the universes index, which is also where a universe is created), and
**Universe: …** / **Story: …** are plain links to the current universe page and the current story
page. There is no universe or story dropdown, so changing universes happens on the landing page and
changing stories happens on the universe page, which lists them. A scope link carries `.active` and
`aria-current="page"` only on the page it points at, and the account menu is the navbar's only
Bootstrap dropdown and its only action. The **Settings** entry lives inside that account menu in
`navbar-actions` and is the one platform-level navigation item: it is rendered for every visitor,
including a guest, and it is deliberately absent from the right utility sidebar's **Configuration**
section, which configures a universe ([ADR 0013](adr/0013-platform-settings-and-browser-theme.md)).
The settings page remembers where it was opened from and offers a **Go back** action that returns
there, and signing in from any page returns the reader to that page. Related record workspaces keep
only the records together in URL-backed tabs:
Characters / Relations, Locations, Events, Items / Ownerships, and Sections. Taxonomy management
lives under the right sidebar's **Configuration → Tags**, with **Universe Tags** (Character,
Relation, Location, Event, Item, and Ownership tags) and **Story Tags** (Section and Scene tags)
selectors.

The one thing the top bar does add is the **search box** (`shared/_search_bar`), between the scope
links and the actions. It is not a switcher and it issues no query of its own: it renders the scope
list and the form, and a scope option the page cannot honour — "this story" with no story selected —
is `disabled` rather than hidden, so the shape of the dropdown is the same on every page. The box is
a plain GET form first; submitting it opens the results page. See **Global search** below and
[ADR 0014](adr/0014-global-search-with-meilisearch.md).

## List rows

Every list row — flat entity lists, taxonomy nodes, and the Scenes list — has the same shape, so a
row means the same thing in every workspace:

- **left**: the record's name (plain text, not a link) followed by its tag badges and, for a
  taxonomy node or a section, a `.record-count` pill holding the number of related records its own
  page will list together with what it counts — "(4 characters)", "(3 scenes)". A bare figure next to
  a name is ambiguous in a list of many rows, so the label is part of the visible text and therefore
  the pill's own accessible name. `record_count_text(count, label)` formats it and
  `record_count_badge(count, label)` wraps it in the pill, which is styled like the sidebar's
  `.sidebar-count` pills;
- **right**: `record_details_link` — real navigation to that record's own page, rendered for
  read-only members and public guests too, labelled **Details** only, with the record name in its
  accessible name — followed by the action menu (`shared/_row_actions` for flat lists, the taxonomy
  row's own menu for trees, and the Scenes row's Edit/Delete menu).

Both halves of the right-hand group are always visible: nothing on a row depends on hover, so the
list works with a keyboard, on touch, and at a narrow width. A count is never part of the Details
label, which keeps the link short in a long list and keeps the count where it can be scanned next to
the name it belongs to. The taxonomy tree serializes the formatted count onto the node
(`data-record-count-label`) because the tree controller rebuilds the rename button when an inline
rename is cancelled; the text is formatted by the server, so nothing is pluralized in JavaScript.


All work pages use the shared `page_header`, `content_surface`/`entity-list`, `row_actions`,
`empty_state`, and `record_details`/`detail_section` patterns. Visual tokens and
responsive/component conventions live in
[`visual_design.md`](visual_design.md). Three functional page patterns + their Stimulus
controllers are described in
[universe_maker_conventions.md](universe_maker_conventions.md#views---three-patterns):
taxonomy tree (`taxonomy_tree`), flat list + modal (`modal_form` + `tom_select`), plain forms.

Data flow for the tree/modal editors: `modal_fields.rb` serializes field descriptors into
`data-*-value` attributes → Stimulus builds every dynamic field and node by DOM APIs (user names,
descriptions, option labels, and ARIA values are assigned as text/attributes, never interpolated
into `innerHTML`) → `fetch` submits to the JSON endpoints, with the page's `csrf-token` meta tag
sent as `X-CSRF-Token` → a successful mutation uses a
same-URL Turbo visit so serialized parent/tag descriptors and all counts are refreshed from the
server. The client side of that contract is verified by `bun run test:js` and
`bun run lint:js` (see [development.md](development.md#client-side-tests-and-lint-bun--biome)),
including a gate that fails if a new HTML-parsing sink appears in `app/javascript`. A taxonomy row now carries only the name, the tags, the count, the **Details** link, and one
overflow menu (Add child, Insert before/after, Move up/Move down, Edit, Delete); the row itself no
longer holds add/move buttons, and the name is sized to its own text so only hovering the name
starts an inline rename. Insertion, move, and edit controls are available by pointer, touch, and
keyboard; HTML5 drag/drop is an optional enhancement. Position changes use the transactional
ordering service described in ADR 0009. The Story Tags scope now presents **Section tags** and
**Scene tags** as separate story-scoped taxonomy tabs; both use the same DOM-safe tree and JSON
mutation contract, while Scene assignment stays in the HTML Scene form.

The shared flat-list modal has its own reliability contract, decided in
[ADR 0011](adr/0011-modal-json-mutation-contract.md): a modal page declares
`data-modal-form-response-value="json"|"html"`, and in `json` mode `modal_form_controller.js`
submits the form itself (`Accept: application/json`, the CSRF token, the form's own field names),
marks the submit button pending, renders a `422` error hash both in a focused summary and next to
the control that caused it, reports a request that never reached the server or a non-validation
failure, and performs the same-URL Turbo visit after a successful create, update, or delete. A
JSON-only row's delete is issued by the same controller, because a `204` destroy gives Turbo no
replacement to apply. An ordered JSON-only row's **Move up/Move down** is issued there too, for the
same reason: a `PATCH` move with no form to follow. Every part of that path is asserted per page in
`test/controllers/modal_json_contract_test.rb` and in the browser suite, because a request test
cannot see the error UI, the pending state, or the refresh.

## Scene architecture (slices 11.1–11.10 implemented)

[ADR 0007](adr/0007-story-owned-scenes-and-elements.md) accepts the first-version Scene domain and
UX contract. Slices 11.1–11.4 implement its core, references, Section grouping, and Scene Tag
taxonomy: the `scenes` and `scene_tags` tables, the `Scene` and `SceneTag` models, story-scoped
routes, the canonical Scenes list, the Scene Details editor with its URL-backed tab shell,
narrative-order moves, both Section-grouping paths, and optional tag assignment. Slice 11.5 then
made the shared modal JSON path reliable for the Element and presence-link modals that come next.
Slices 11.6 and 11.7 add the `scene_elements` and `scene_characters` tables, the `SceneElement` and
`SceneCharacter` models, the Dialogue speaker link, the ordered Element list on Scene Details, and
the Characters tab. Slices 11.8 and 11.9 add `scene_items` and `scene_locations` with the Items and
plural Locations tabs, completing the four workspace tabs. Slice 11.10 adds `SceneAppearances` and
the "Appears in scenes" section on the Character, Item, Location, and Event details pages, so a
shared universe record can be traced forward into the Story's narrative sequence. Every Scene-owned
route in [ADR 0007](adr/0007-story-owned-scenes-and-elements.md) is now live.

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
- A `SceneElement belongs_to Scene` and forms its own flat, contiguous sequence inside that Scene.
  It stores a `kind` restricted to `narration` or `dialogue` — never a column named `type`, which
  Active Record reserves for single-table inheritance — a required `name` labelled **Title**, and an
  optional plain-text `body` labelled **Content`. It does not inherit `Hierarchical` and has no
  `parent_id`; `SceneElementsController` uses the flat mode of `PositionedResourceOrder` with the
  Scene as the scope owner, and `position` is not a permitted form field so only the Move controls can
  change it.
- A Dialogue's speakers are a plain many-to-many link (`scene_element_speakers`) because the link
  carries no data of its own and records no turn order. A Dialogue must name at least one
  same-Universe Character, Narration may name none, and a Dialogue cannot become Narration while
  speakers remain unless the request carries the modal's explicit `remove_speakers` confirmation —
  which clears them in the same atomic update. `Character` declares the same link from its side, so
  deleting a Character removes its speaker links and its presence links and never a Scene or an
  Element.
- A `SceneCharacter belongs_to Scene` and `belongs_to Character`, and carries a nullable free-text
  `role`. It is a join model rather than a HABTM association precisely because the role is part of the
  decision; a blank role means no role and is never checked against a vocabulary.
- `SceneItem belongs_to Scene` and `belongs_to Item`, and `SceneLocation belongs_to Scene` and
  `belongs_to Location`, with the same nullable free-text `role` and the same same-Universe rule.
  They are join models for the same reason as `SceneCharacter`. Unlike a Character, neither an Item
  nor a Location has a second derived source, so their tabs have no union to reconcile.
- Participation has **two independent sources**, and nothing merges them into one stored row: an
  explicit `SceneCharacter` link, and a Character who speaks in one of the Scene's Dialogue
  Elements. `SceneParticipants` reads both, labels which is which, and reports the **union** — a
  Character who both participates and speaks is one participant, never two.
- `UniverseScopeResolver` is the single answer to "which universe owns this record?". `Ability` and
  `ApplicationHelper#universe_for_record` both call it, so record-level authorization and the
  mutation controls a view renders cannot disagree. It resolves a record directly through
  `#universe`, or through a declared owner association (`story`, `scene`, `section`). `SceneElement`,
  `SceneCharacter`, `SceneItem`, and `SceneLocation` all reach their Universe through `scene`, so
  none needs a new entry; a model nested deeper than one of those defines its own `universe` method
  that delegates through its owner, and the first step of the walk finds it.
- `SectionPaths` (a value object, not a record) turns one ordered Section list into every
  root-first ancestor path and the depth-indented selector options. Preloading an arbitrary tree
  depth with `includes` is not possible, and `Section#ancestor_chain` would query per level per
  Scene, so both the Scenes list and the Sections workspace build the index from a single query.
  `SceneTagPaths` does the same for the story-scoped Scene Tag hierarchy used by the assignment form,
  and `LocationPaths` for the universe-scoped Location hierarchy the Locations tab shows and offers.
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
| Scene Elements | `.../scenes/:scene_id/elements`, `.../elements/:id`, `.../elements/:id/move` | JSON only |
| Scene Characters tab | `.../scenes/:scene_id/characters`, `.../characters/:id` | HTML index, JSON mutations |
| Scene Items tab | `.../scenes/:scene_id/items`, `.../items/:id` | HTML index, JSON mutations |
| Scene Locations tab | `.../scenes/:scene_id/locations`, `.../locations/:id` | HTML index, JSON mutations |

Scenes have no Universe-level route. Every Scene and Scene Tag route includes its Story, and all
route-helper keys are passed by name. `ScenesController` answers HTML only and follows the
redirect/re-render flow: successful create/update redirect to Scene Details, a move redirects back
to the list with a `303`, and grouping redirects back to the Sections workspace with a `303`.
`SceneTagsController` follows the established taxonomy JSON mutation contract while its index uses
the shared tree; it rejects a non-JSON mutation before the positioned service can commit anything.
The Scene record flow itself never uses the shared modal path, so it inherits nothing from it. The
Element and presence-link mutations added in slices 11.6–11.9 do: they reuse
`modal_form_controller.js` under [ADR 0011](adr/0011-modal-json-mutation-contract.md) instead of a
second editor, so their JSON submission, `422` rendering, pending state, and post-mutation refresh
are the same contract that is already covered for Characters, Items, and Events.

`SceneElementsController` has no read action at all: Elements are read on Scene Details, so every one
of its actions is a mutation, every one requires a session and the shared Universe write policy, and
`RequiresJsonMutationFormat` refuses an HTML request before the positioned service can commit
anything. `SceneCharactersController#index` is a real read page (guests and read-only members see it),
while its mutations are JSON-only like the other presence flows. Both load their records through
`Current.universe.stories.find(...).scenes.find(...)` and the Scene's own association, so a record
from another Scene, Story, or Universe is a `404` rather than a cross-scope write.

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

The Scene-owned records prove their shared Universe the same way, because no foreign key can:
`SceneElement#speakers_belong_to_the_scene_universe`,
`SceneCharacter#character_belongs_to_the_scene_universe`,
`SceneItem#item_belongs_to_the_scene_universe`, and
`SceneLocation#location_belongs_to_the_scene_universe` compare against `scene.story.universe_id`.
A `character_ids` writer on `SceneElement` turns an unknown, duplicated, or cross-Universe id into an
ordinary field error instead of a driver exception, exactly as `Scene#scene_tag_ids=` does, and a
direct association assignment is checked by the same validation. The same-Universe rule is also in
each controller, where a foreign `character_id`, `item_id`, or `location_id` is a `404` because the
record is resolved through `Current.universe`. The development-data loader proves it a third time: a
Scene-owned record's Universe is resolved through its Scene, and a manifest may only reference
records from its own universe directory. `scene_elements` additionally carries a database
`check_constraint` on `kind`, and `scene_element_speakers`, `scene_characters`, `scene_items`, and
`scene_locations` all carry real foreign keys and a unique pair index, so every uniqueness rule is
proved in the model *and* the database.

### UX

The Story workspace gained a flat **Scenes** list with Title/short-description previews, a 1-based
narrative-position badge, a Section-group or **Ungrouped** badge, optional Scene Tag badges, and
add/edit/delete actions. The Title is plain text, exactly like every other list, and the row's
right-hand group holds the **Details** link into Scene Details followed by Move up/Move down and the
action menu; all of it is rendered for every access level except the mutation controls. Visible Move
up/Move down buttons are real `button_to` forms (keyboard
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

The editor shell is URL-backed through `shared/_content_tabs`: **Scene Details** and **Characters**
are live links, while **Items** and **Locations** stay `aria-disabled` placeholders with an
explanatory title until their slices add a real destination. A tab is never rendered as a link to a
route that does not exist, and it is never an in-document Bootstrap pane.

### Scene Elements live under Scene Details

The ordered Element list renders on Scene Details rather than on a page of its own: the Scene above
it already carries the identity, the references, and the tags, so the prose blocks belong to the same
page. A Scene may hold any number of Elements, including none, so the empty state says so instead of
implying that a Scene is unfinished. Each row shows its 1-based position in **this Scene's**
sequence, its kind, its content (or an explicit "no content yet"), the speakers of a Dialogue, and
— for writers only — Move up/Move down, **Edit**, and **Delete**.

The Move controls are the same visible, boundary-aware buttons the Scenes list uses, but they cannot
be Turbo forms: the Element endpoint is JSON-only, so `modal_form_controller.js#move` issues the
`PATCH` itself and then performs the same-URL refresh a save performs. A move past either end is a
deliberate no-op — the view disables the control and the service clamps the position — and a rejected
move announces the server's own message in the page-level live region, because a row with no form has
no error summary to render into.

**Narration and Dialogue are the same editor with two different sets of rules**, so the modal offers
an **Element type** selector, a required **Title**, an optional **Content** textarea, and a
many-speaker **Speakers** picker. `scene_element_form_controller.js` owns one small piece of that
form: it shows the picker only for Dialogue and offers the "remove the speakers" confirmation only
when a Dialogue that has speakers is switched to Narration. The server is what enforces the rule. A
hidden picker is deliberately *not* disabled, so a hidden selection is still submitted and the server
can see there is something to confirm; the confirmation then sends an empty speaker list in the same
request, which is the only way a Dialogue becomes Narration. A dialogue's own copy states the
limitation out loud: the link records who is in the conversation, not which line belongs to whom.

### The Characters tab shows two kinds of participation

`/characters` is a real read page, so a guest and a read-only member see exactly what a writer sees
minus the controls. Its rows are the **union** of the two participation sources, one per Character:

- a stored `SceneCharacter` link, labelled **Participant**, showing its role or **No role recorded**;
- a Character who only speaks, labelled **Speaks in N element(s)** and naming the Elements, with no
  add/edit/remove menu at all, because there is no stored row to act on.

A Character who is both carries both labels on a single row, which is why the count on the page and
the count in the Scenes list are the union and never the sum. Writers add a link, edit the Character
and its role, and remove the link. The Character and the role are both editable, because the editor
offers both controls and a control that looks editable but is ignored would be worse than none; a
duplicate is the model's uniqueness error rendered in the modal rather than a hidden option, since a
stale page or a second window can submit one anyway. The picker offers every Universe Character
because Characters are shared by every Story in the Universe. Removing a link never removes a
Character, and never changes who speaks in an Element: those are separate links with separate
consequences.

The Scenes list gained two per-row counts from these two sources: an Element count and a participant
count. Both are read in one grouped query each for the whole page, never per row, and the
participant count is the same union the tab shows.

### The Items and Locations tabs have one source each

`/items` and `/locations` follow the Characters tab's page shape — a read page whose mutations are
JSON-only — with one difference that follows from the domain: neither an Item nor a Location has a
derived second source, so there is no union to reconcile and no row without a link. Every row is a
stored `SceneItem` or `SceneLocation` link showing its role or **No role recorded**, and the row list,
the page count, and the count a mutation changes are the same rows.

The Locations tab is plural because a Scene may use any number of places, and it is the only Scene
workspace whose rows are hierarchical. Each row is named with its full ancestor path
(`Winden / Jonas House / Jonas Room`), and the picker is depth-indented in root-first order, so a
nested place is never ambiguous. The row *list* is a flat name order rather than tree order: a flat
list is easier to scan, and the path in each row is what disambiguates two places with the same
name. The picker still walks the tree so a child is never offered before its parent.

Both tabs offer every Universe Item/Location, because those records are shared by every Story in
the Universe. A duplicate is the model's uniqueness error rendered in the modal rather than a hidden
option, for the same reason as the Characters tab. Removing a link never removes the Item or the
Location, and never removes a Location's nested places: each is a shared record, and a link only
withdraws one Scene's claim on it.

### "Appears in scenes" traces a record forward

The Character, Item, Location, and Event details pages each end with an **Appears in scenes of
<Story>** section, the reverse of the three tabs. It is the one place where a shared universe
record is read through the Story's narrative sequence, and it is deliberately not a new workspace:
the same links would be broken if it were.

`SceneAppearances` is the single query object behind it. It reports the **union** of a stored
presence link, a derived Dialogue speaker, and an Event reference — one row per Scene, never a sum
— ordered by Scene `position`, which is the order the Story is told and not the order the Event
happened. A row is labelled with the reason(s) it appears, so **Linked**, **Speaks in N element(s)**,
and **Depicted** are never collapsed into a single word, and a role is only ever shown for a stored
link. The whole section is read-only navigation, so it renders for every access level: the Scenes it
points at are readable by exactly the people who can read the record it is attached to, and every
link carries an explicit `story_id` because a Scene has no Universe-level URL.

The section is scoped to `Current.story`. With no Story selected there is nothing to list, so the
section says so and offers the story list — the same explicit selection the sidebar asks for, never
a fallback to the Universe's first Story.

The Sections workspace keeps its taxonomy tree and adds an **Ungrouped scenes** list below it:
only the scenes that belong to no Section, in canonical narrative order, headed by a badge that says
how many that is ("3 ungrouped scenes") and carrying the pointer to each Section's own page. A Section
is a group rather than a record with a list of its own, so a grouped scene is read on that Section's
details page and is not repeated here. For writers the list keeps one selector-driven move form
(**Ungrouped scene** → group) offering **Ungrouped** plus every Section path. That form offers only
the ungrouped scenes it lists, because the surface is the Ungrouped end of the workspace: offering a
grouped scene here would contradict the block the reader is in. A grouped scene is regrouped from its
own Section's page, where its editor carries the Section selector with **Ungrouped**, so nothing
became unreachable. Drag-and-drop is not offered, so the move is always available by keyboard and on
touch. Read-only members and guests see the same list with no controls, and when every scene is
grouped the form disappears with the list rather than offering an empty selector. The tree's read-only
empty state now has its own copy, so a read-only member is not told to add or drag sections.

### The story's Scene list is filtered, never re-ordered

A Story can hold hundreds of scenes, so the canonical list carries a search area instead of growing
without limit. `SceneFilter` (`app/models/scene_filter.rb`) is the value object behind it, and the
list stays the Story's canonical narrative order under every view:

- Query keys on `GET /u/:universe_slug/s/:story_id/scenes`: `q` (free text over the title and short
  description), `section_id` (a Section of this Story or the literal `ungrouped`), `scene_tag_id` (a
  Scene Tag of this Story, the author's label for a scene), and `from`/`to` (inclusive in-world
  **days**, applied to the scene's own `datetime`). Filters combine with `AND`.
- A filter is validated against the lists the index already loaded (`SectionPaths#ids` and the
  story-scoped Scene Tags), so a foreign or unknown id is dropped instead of reaching the query, and
  a value that cannot be used is reported on the page (`flash.now[:alert]`) rather than silently
  emptying the list. An unreadable date is the same case. A scene without an in-world time is
  outside any date range: a null is never inside a range.
- The tag filter narrows through the scoped inverse association
  (`SceneTag#tagged_records.select(:id)`), so it cannot disclose another Story's scenes, and the
  section filter uses an in-memory membership check rather than a second query.
- A plain GET form submission arrives with blank values for the untouched fields, so the index
  redirects once (`302`) to the canonical query built from `SceneFilter#query_params`. The address
  bar, a bookmark, and a shared link therefore carry only the filters really in effect, and the
  recognized keys of a `move` or `destroy` request are carried back to the same list, so a reordered
  or deleted scene does not dump the author on the full story.
- Position, totals, and boundaries never come from the filtered rows: one aggregate query
  (`COUNT(*)`, `MIN(position)`, `MAX(position)`) answers the Story total shown by the position
  badges and the real first/last position that disables Move up/Move down. A narrowed list therefore
  cannot mistake its first visible row for the first scene of the Story.
- Two empty states are kept apart: a Story without scenes says **No scenes yet** (and only a writer
  is told to add one), while a filter that matches nothing says **No scenes match these filters**,
  repeats the active filters, and offers **Clear filters**.
- The list itself costs one filtered query plus one aggregate, and the preloaded tag associations
  and Section paths keep it free of N+1 work.

## Global search

The top bar carries one search box, and it is a plain GET form before it is anything
else. `GET /search` searches the whole platform; `GET /u/:universe_slug/search` keeps a
universe-scoped search inside that universe's URL, so the shared universe callbacks
resolve and authorize the scope exactly as they do for every other page of that
universe. Both are a single `get` rather than a `resources` collection, so the route
advertises no action that does not exist. `SearchesController#show` is the one read that
answers in two formats:

- **HTML** is the results page: shareable, keyboard-reachable, usable with scripting off,
  and the only place a result set can be explained (the count, the scope, a dropped value,
  an engine that is not answering).
- **JSON** is the dropdown, asked for by `search_controller.js` as the reader types. It
  carries `available`, `reason`, `query`, `scope`, `scope_label`, `total`, `discarded`,
  `commands`, and `results`.

The read never writes, so it has no mutation path, no mass assignment, and nothing for a
CSRF token to protect.

**The parts, and where each decision lives:**

| Concern | Where |
|---|---|
| The request: text, scope, story boundary, and every value that could not be used | `Search::Query` (`PARAMS`, `discarded`, `query_params`) |
| The scope dropdown: a boundary (platform / universe / story) or a kind ("only characters"), resolved rather than trusted | `Search::Scope` |
| Authorization and display: the filter sent to the engine, and the context names of each hit | `Search::Catalog` |
| Navigation destinations | `Search::Commands` |
| The engine, and the one place that speaks to it | `Search::Client` / `Search::UnavailableBackend` |
| Which models are indexed | `Search::Registry` |
| What one record contributes | the model's own `searchable` declaration (`Searchable`) |
| Rebuilding the index | `Search::Reindexer`, `bin/rails search:reindex` |
| When a save or destroy reaches the index | `Search::IndexRecordJob`, `Search::RemoveRecordJob` |

Four rules are worth knowing before changing any of it:

1. **A platform search is filtered, not post-filtered.** The engine is asked only for
   documents whose universe the reader may read (`Universe.visible_to`, the same rule
   `Ability` enforces), and a reader with no readable universe is not asked at all.
2. **A document stores ids, not names.** `Search::Catalog` resolves the displayed universe
   and story names in two queries at read time, so a rename never leaves a stale name in
   the index and never needs a reindex of the records that mention it.
3. **A search never changes the current story.** `SearchesController` skips the shared
   `set_current_story` callback — which would remember `params[:story_id]` in the session —
   and resolves the story itself. The top-bar form still carries the current story so the
   reader can pick "this story" without a page load, and a story id on its own does not
   narrow the search: the scope decides whether it is a boundary.
4. **A value that cannot be used is dropped and reported**, in the `discarded` list and as a
   `flash.now[:alert]`, in the same spirit as `SceneFilter`. A missing scope is not an
   error; an unrecognized one is.

An engine that is not configured, not reachable, or refusing is a stated state
(`Search::Unavailable` → "Search is not available"), never a failed request, because the box
renders on every page. [ADR 0014](adr/0014-global-search-with-meilisearch.md) records why there
is no SQL fallback behind it.

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
- `solid_cache` store in production; `nav_stories` is memoized per request.
- Sidebar count data is stored in `Rails.cache`: one grouped entry for the current universe, and
  one entry per scalar story metric. A story caches its section count and its scene count under
  two distinct keys (`Story::SECTION_MENU_COUNT_SCOPE` and `Story::SCENE_MENU_COUNT_SCOPE`) so a
  second scalar metric on the same owner can never overwrite the first; `InvalidatesMenuCounts`
  takes an optional `cache_scope:` for exactly that reason and expires the correct entry.
  Expiration happens from model `after_commit` callbacks when a counted record is created or
  destroyed (and when a record moves to another scope). Open transactions calculate without
  filling the cache, and entries have a one-hour safety expiry. See
  [former quirk #18](resolved_quirks.md#former-18--sidebar-issued-count-queries-on-every-page-fixed).
- The navbar is three links, the search box, and the account menu, so it issues no query. The
  search box renders a form and a scope list from values it already has — `Current.universe`,
  `Current.story`, and `Search::Scope` — and asks the engine only for what a reader types. Only the
  universe page loads stories (`nav_stories`), and it reuses that memoized list instead of querying
  them again.
- `TaggedRecordCounts.for(tags)` answers "how many records carry each tag" with one grouped query
  over the HABTM table, because the scoped tag associations have an instance-dependent scope and
  cannot be eager loaded or grouped through Active Record. Every taxonomy index and the shared
  taxonomy workspace load it once, so a row's count pill is not an N+1. The Section tree's scene
  counts come from one `@story.scenes.group(:section_id).count` for the same reason. Row-level
  authorization in `shared/_row_actions` and the recursive taxonomy partial remain N+1 and are still
  tracked in [`known_quirks.md`](known_quirks.md).
