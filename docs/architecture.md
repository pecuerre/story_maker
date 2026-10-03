# Architecture

How a request flows through Universe Maker: stack, lifecycle, authentication, routing/URL rules,
UI patterns and the Timeline algorithm. Conventions are in
[conventions.md](conventions.md), schema in
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
   When the resolved story is one a reader **explicitly selected**, it is also written to the
   browser's remembered destination (`RememberedDestination`), which is the cross-sign-in half of
   the same fact. The write is skipped when the destination has not changed, so ordinary browsing
   does not put a `Set-Cookie` on every response.

Per-request state lives in **`Current`** (`ActiveSupport::CurrentAttributes`):
`session`, `universe`, `story`, plus `delegate :user, to: :session`. It is reset between requests
by the Rails executor — never cache objects from it across requests.

The appearance preference is deliberately **not** part of `Current`: a theme belongs to the browser,
not to the session, universe, or story a request carries. `AppTheme` reads it from the signed cookie
`um_theme` and the layout renders it as `<html data-bs-theme>`; the `current_theme` helper memoizes it
for the render.

The language is a second browser-owned preference of exactly the same kind. `AppLocale` reads the
signed cookie `um_locale`, and `ApplicationController#switch_locale` is an `around_action` that sets
`I18n.locale` for the request **before any action runs**, so a redirect's flash is already
translated. The layout renders `<html lang="...">` from the same value, so the first paint is in the
right language. The start page (`AppStartPage`, signed cookie `um_start_page`) is a third, and it is
navigation state rather than display state: it decides where a sign-in with nothing to return to
lands, and it has its own section on `/settings`. All three, and why the layout owns them, are in
[features/settings.md](features/settings.md).

Because the session story map is cleared at every session boundary, the remembered **destination** is
separate state: a signed browser cookie (`um_last_scope`) holding the account id, universe slug, and
story id that were last worked in. `RememberedDestination.for` returns it only for the account that
wrote it, and only after re-resolving the records and re-checking `readable_by?` — a signed cookie
cannot be forged, but it can be stale. Every way it can be unusable (no cookie, another account's
cookie, a universe that is now private, a revoked membership, a deleted story) answers `nil`, which
is the universes list. The decision is in
[ADR 0017](adr/0017-browser-owned-start-page-and-remembered-destination.md).

A frozen constant holds an I18n **key**, never a translated string: a constant that called `t()` at
class-load time would resolve once, in whatever locale loaded the class first.
`TagsHelper::UNIVERSE_TAG_METADATA` stores `title_key:`/`description_key:`/… and
`tag_workspace_base` resolves them per request, so both locales come from one code path. The rule and
its other cases are in [features/i18n.md](features/i18n.md).

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
  `cookies.signed[:session_id]` with an expiry that matches the session's own absolute deadline, so
  the browser stops presenting a credential the server will not honour.
- **Session lifetime and source binding.** `Session` carries the policy
  ([ADR 0018](adr/0018-session-lifetime-and-user-agent-binding.md)): `expires_at` is an absolute
  deadline that use never extends, and `last_used_at` drives an idle timeout, refreshed at most once
  an hour so an active session is not written on every request. `find_session_by_cookie` refuses a
  session that is past either limit or that was created by a **different user agent** than the one
  presenting it, deletes its cookie, and destroys the row. The IP address is recorded and never
  enforced, because an address identifies a network rather than a person and mobile, VPN, and
  office/home switching all change it legitimately. A row with no recorded user agent, or no recorded
  lifetime, is left alone so a schema change cannot sign everybody out. `ApplicationCable::Connection`
  applies the same two checks, because a websocket does not run this concern and would otherwise
  accept a cookie the request path already refused. `PurgeExpiredSessionsJob` removes dead rows on a
  schedule; nothing depends on it, since an expired session is already refused without its row.
- Post-login destination (`sessions#new` remembers the page, `Authentication#after_authentication_url`
  resolves it):
  - a page remembered by `request_authentication`, or the same-host referer of the sign-in page, is
    returned to; otherwise, if the start-page preference is `remember`, the account's remembered
    destination is returned to; anything else lands on `root_url` (the universe list);
  - `Authentication#authentication_page?` rejects `/session`, `/session/new`, and `/passwords/*` as
    destinations, both when storing the referer and when resolving it. This is load-bearing: a wrong
    password reopens the form, and the browser sends that form (or the `POST /session` endpoint) as
    the referer of the reload, which used to become its own destination and loop a successful
    sign-in back to the form. A referer is parsed defensively because it is a client-supplied header;
  - the request following a successful sign-in is marked with `session[:post_sign_in_destination]`
    and consumed by an `ApplicationController` before-action. If that one request is refused (403 or
    404), `ApplicationController#refuse_request` redirects to the universe list with an alert instead
    of a bare status code, because a refusal there answers "nothing happened" to a sign-in that
    succeeded. Every other refusal keeps the bare 403/404.
- Sign-out destroys the `Current.session`, deletes the cookie, and clears remembered story
  selections. It deliberately does **not** clear the browser's remembered destination, which is what
  lets a reader resume after signing in again. Starting a new authenticated session performs the
  same session-scoped context cleanup, and a request with a stale/deleted authentication session
  clears its cookie and story context.
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

The route conventions — the universe scope, the nesting of stories and their sections, tags, and
scenes, which controllers answer which format, and the URL of every workspace — are in
[conventions.md](conventions.md#routes). What belongs to this document is the part that happens
*inside a request*, because it is a property of Rails' URL generation rather than of a route:

- `universe_slug` is usually **not** passed. Inside a universe-scoped request Rails fills missing
  segments from the current request (recall), which is why `universe_characters_path()` works in the
  sidebar with no arguments at all. Outside such a request — `bin/rails runner`, a job, a mailer — the
  same call raises `missing required keys: [:universe_slug]`. A **model** is always outside a request,
  so anything that builds a path from a model (`searchable`, `Search::Commands`) must pass
  `universe_slug` explicitly rather than rely on recall.
- `Universe#to_param` returns the slug and the route uses `param: :universe_slug`, so a universe is
  looked up by slug while every content model is addressed by numeric id.
- A `story_id` from another universe raises `RecordNotFound` → 404, which is how a cross-scope
  reference in a URL is caught before any query runs.

## Response formats per controller

| Flow | Controllers | Behavior |
|---|---|---|
| JSON-only mutations | all `*_tags` (including `scene_tags`), characters, locations, items, events, sections, **scene_elements**, **scene_characters**, **scene_items**, **scene_locations** | `index/new/show` render HTML; `create/update/destroy` answer `format.json` only, and a request that does not ask for JSON is refused with `406` **before** anything is written (`RequiresJsonMutationFormat`); errors → `unprocessable_content` + error hash |
| HTML flow | universes, **stories**, **scenes** (including Scene Tag assignment), relations, ownerships, universe memberships, **settings** | `show` renders the record's details page; `redirect_to` on success (`status: :see_other` for PATCH/DELETE), re-render with errors |

Every PATCH and DELETE in the HTML flow sends `status: :see_other`; a `create` is a POST, so its
default 302 is correct. A 302 after a non-GET verb asks the browser to repeat the mutation as a GET
against the redirect target, which Turbo then has to reinterpret.
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

## UI structure

The interface is a Bootstrap application shell with a fixed dark navbar, a responsive left and right
workspace navigation, and one flexible main content area. The breakpoints, the columns' widths, and
the color each scope block owns are in [visual_design.md](visual_design.md). What each column
**contains**, in what order, and the two-step universe-then-story selection that drives all of it are
in [features/navigation.md](features/navigation.md).

One thing belongs here, because it is about caching rather than layout: the universe page is the
landing page for a universe, so it lists the universe's own stories with an **Open** action each
instead of a summary card that links onward. It reuses the memoized story list, so the page adds no
query and no `COUNT` — the per-story section and scene counts stay in the cached sidebar metrics.

## Scene architecture

The Scene domain has its own home, in [features/scenes.md](features/scenes.md): the model and its
flat story-scoped ordering, `UniverseScopeResolver` as the single answer to which universe owns a
record, the four application-level scope validations, the route and response table, the
`SceneFilter` contract, the participation union, and the asymmetric deletion contract.

One thing belongs here rather than there, because it is about the request pipeline: a Scene is
resolved through `Current.universe.stories.find(...).scenes.find(...)`, and a record from another
Scene, Story, or Universe is a `404` rather than a cross-scope write.

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

## Runtime logging and observability

Production logs to tagged `STDOUT` (`config.log_tags = [:request_id]`) and answers `GET /up`.
On top of that the application emits two structured JSON events per line of interest, and
optionally forwards unhandled errors to an external collector. The three subjects are the log
format, the correlation key, and the collector.

### The log

`RequestLogMiddleware` (`lib/request_log_middleware.rb`) writes one `{"event":"request", …}`
object per completed request: `request_id`, `request_method`, `request_path`, `request_status`,
`request_format`, `request_controller`, `request_action`, `duration_ms`. It is inserted after
`Rails::Rack::Logger`, which is what makes the event carry the same `[request_id]` tag as
`Started`/`Completed` and makes `config.silence_healthcheck_path` silence it too. The fields are
an allowlist built from named values, never from the request object, so a cookie, session,
parameter, or account cannot ride along. `request_path` is the request's own `filtered_path`,
so the password-reset token filter covers this line exactly as it covers Rails'.

Rails' own lines are left in place: `Started GET "…" for <ip>` prints the client IP, so the
deployment's **log retention** is still the control that governs personal data in the log, and
no application-level filter can reach an upstream proxy's access log.

### The correlation key

The request id. `ActionDispatch::RequestId` puts it in `env`, `Rails::Rack::Logger` tags every
line of the request with it, `RequestLogMiddleware` repeats it as the `request_id` field, and the
same value is returned to the client as `X-Request-Id`. `RequestLogMiddleware` also publishes the
request's identity into `Rails.error`'s execution context, so an error raised anywhere inside a
request is reported with the request that raised it; the executor clears that context when the
request ends, so it cannot leak into the next one.

### The error collector

`ErrorTracking` (`lib/error_tracking.rb`) subscribes to `Rails.error`, which is where an unhandled
exception is reported by `ActionDispatch::Executor` and where a failed `Solid Queue` job is
reported. For every report it writes an `{"event":"error", …}` line carrying the exception class,
a redacted message, up to ten redacted backtrace frames, severity, `handled`, `source`, a
timestamp, and the correlation keys above.

Forwarding is **off unless `ERROR_TRACKING_DSN` is set**. With it set, unhandled errors are
POSTed as JSON to that https URL through `Net::HTTP` from the standard library — no gem is added,
which is why there is no vendor to audit and no client to initialize when the variable is
absent. Only `handled: false` reports are forwarded; a recovered error is logged and kept local.

The rules the collector is held to, stated before it exists as a feature:

- **Redaction.** Every emitted string is filtered through `config.filter_parameters` applied to
  `key=value` pairs (the same treatment the query string gets), then scrubbed of e-mail
  addresses and of URL credentials. The DSN is itself scrubbed out of everything logged, because
  it is a credential and a delivery failure quotes the address it failed to reach.
- **Authentication.** The DSN is the credential. It is supplied by the deployment, must be
  https, and is never written to the log. A malformed value fails the boot rather than being
  quietly ignored.
- **Cardinality and volume.** At most ten frames, a capped message, one attempt, two-second
  timeouts, no retry queue. Recovery is deliberately not automatic: a retry would be the
  application's own unbounded queue.
- **Failure behavior.** A collector that is down, slow, or broken costs one `warn` line. The
  report was already logged locally first, so a collector outage cannot lose it, and reporting
  never raises into the request that failed.
- **Retention and privacy.** The application stores neither the forwarded payload nor a copy of
  it; what the collector retains afterwards is the collector's policy, which is why unhandled
  errors are the only thing forwarded.

### What is deliberately absent

There is no metrics endpoint, no `Prometheus`/`StatsD` client, and no public `/metrics` route. A
public metrics route would be an unauthenticated window onto this application's traffic, and a
metrics client would be a dependency and a label-cardinality policy to maintain for numbers
nobody has asked to graph. `/up` answers liveness only; it deliberately reports nothing about
counts, latency, or errors. A future metrics surface would have to answer, in writing, who reads
it, how it authenticates, which labels it may carry (never a user, universe, story, or record id),
and how long anything is retained — before it is added.

## Timeline

The layering algorithm, the rule that keeps the drawn arrows from contradicting the rows they span,
and the fact that the Timeline is a tab of the Event workspace rather than a page of its own, are in
[features/events.md](features/events.md).

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
  [the resolved sidebar-count finding](delivery_history.md#sidebar-issued-count-queries-on-every-page-fixed).
- The navbar is three links, the search box, and the account menu, so it issues no query. The
  search box renders a form and a scope list from values it already has — `Current.universe`,
  `Current.story`, and `Search::Scope` — and asks the engine only for what a reader types. Only the
  universe page loads stories (`nav_stories`), and it reuses that memoized list instead of querying
  them again.
- `TaggedRecordCounts.for(tags)` answers "how many records carry each tag" with one grouped query
  over the HABTM table, because the scoped tag associations have an instance-dependent scope and
  cannot be eager loaded or grouped through Active Record. Every taxonomy index and the shared
  taxonomy workspace load it once, so a row's count pill is not an N+1. The Section tree's scene
  counts come from one `@story.scenes.group(:section_id).count` for the same reason.
- Row-level authorization costs a **fixed number of membership reads per render**, not one per
  record. `shared/_row_actions` asks `can_write_universe?` once per row, and each answer reaches
  `Universe#access_level_for`, which reads the membership table. `ApplicationHelper` remembers each
  answer per universe on the **view context**, which is built and discarded per request; the model
  remembers nothing, because a membership write followed by a second question must see the write.
- The taxonomy tree costs **one query for its own rows, whatever its depth**. Every tree page loads
  its whole hierarchy once and wraps it in a `HierarchyIndex` (`app/models/hierarchy_index.rb`),
  which answers roots and children in memory; the recursive partial descends through the index
  rather than through `node.children`, because Rails cannot preload an unknown depth and
  `children.any?` on an unloaded association counts separately from the `children.each` after it.
  The same load carries each node's tags and photo, so a row's badges and the editor's stored image
  do not query per row either.
- `TimelineLayout` still makes three pairwise passes over a universe's events, because the rules it
  implements are pairwise, but its cycle test no longer runs once per candidate edge. See
  [features/events.md](features/events.md) for the layering algorithm.
