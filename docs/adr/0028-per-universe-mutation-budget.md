# ADR 0028: The mutation budget belongs to the universe, and the framework macro cannot hold it

- **Status:** Accepted
- **Date:** 2026-10-12
- **Related:** [`0011`](0011-modal-json-mutation-contract.md), [`0012`](0012-client-side-verification-and-csrf.md), [`0005`](0005-universe-access-levels.md), [`../architecture.md`](../architecture.md), [`../data_model.md`](../data_model.md), [`../known_quirks.md`](../known_quirks.md)

## Context

Nothing throttled content mutations. The only two limits in the application were sign-in and
password reset, both fixed literals in source, and neither had a test — so as far as the suite was
concerned a limit and no limit were the same thing.

The product answer was that the budget belongs to the universe and is set by that universe's
admins, rather than being one rate for the whole application. That is the right owner for it: a
public universe deliberately lets every signed-in contributor write ([ADR
0005](0005-universe-access-levels.md)), so the exposure a universe has is a property of that
universe and of how its admins want it treated. It also means the budget has to be *editable*, which
is a schema column and a form, not a constant.

That decision runs straight into how `ActionController::RateLimiting` works. The `rate_limit` macro
evaluates `store: cache_store` and captures `to:` and `within:` when the controller's class body is
evaluated (`actionpack/lib/action_controller/metal/rate_limiting.rb`), so it can only express a limit
chosen in source. A limit read from a column per request cannot be declared with it.

The capture has a second consequence that only surfaced when the limits were finally tested: because
the store is fixed at class load, a test cannot install a different one afterwards. Under the test
environment's former `:null_store`, whose `increment` returns `nil`, both existing limits were inert
for the whole run — and swapping `Rails.cache` in a test could not reach them, because the object had
already been captured.

## Decision

### The budget is a column on `universes`, with a default that protects a new universe immediately

`universes.mutation_limit` is a nullable integer defaulting to **60 per minute**. Sixty is chosen
against what this application actually does: there is no bulk or batch path anywhere in it, so every
mutation is one deliberate act — a modal submit, one taxonomy edit, one scene drag — and a person
cannot reach it through ordinary work, while a script reaches it in about a second.

A column default rather than a form-time default matters: a universe is protected from the moment it
exists, not from the moment somebody visits a settings page. `NULL` is the stored form of "no limit at
all", which is why the column is nullable rather than using a sentinel; `0` is refused by validation,
because zero mutations and no limit are different settings and only one of them is what anybody means
by the field. A universe nobody may write to is private and read-only, which `private` and the
membership levels already say.

The window is a constant, not a column. A window is not the thing an admin has an opinion about; the
budget is. A per-universe rate reads as "N per minute" wherever N comes from.

### The counter is written out by hand, and counts what the macro's contract already means

`MutationThrottle` (`app/controllers/concerns/mutation_throttle.rb`) is a `before_action` that
increments a `Rails.cache` counter under a namespaced key and refuses past the universe's budget. It
reimplements the macro's contract — a cache counter, refused past a number — and nothing else. The two
existing limits keep using the macro, because theirs are per-IP, fixed in source, and never will be
per-universe.

The counter lives in `Rails.cache` rather than in a new service. This application has no Redis, and
Solid Cache implements `increment` under a row lock in production, so a multi-process deployment
counts into one place without new infrastructure.

### It runs after authorization, and only on universe-scoped writes

Three things have to be true where it sits: `Current.user` exists, `Current.universe` is resolved, and
the request is already known to be permitted. That is exactly between `authorize_universe_access` and
`set_current_story`, and the ordering is the design rather than an accident:

- **after** `authorize_universe_access`, so an anonymous visitor or a signed-in stranger to a private
  universe cannot spend an authorized account's budget with requests that were refused anyway. A limit
  is a brake on writes that were going to happen; it is not a way to lock somebody out.
- **only** for `POST`, `PATCH`, `PUT`, and `DELETE`, because a throttle that answered a burst of page
  loads would refuse a reader for reading.
- **only** when `Current.universe` is present, so platform-level writes — sign-in, password reset,
  settings, notifications, universe creation — are not counted against a universe's budget. They are
  not content mutations of a universe, and the first two carry their own limits.

A store that cannot count answers `nil`, and an uncounted request is allowed through. Refusing on that
basis would turn an inert cache into a locked-out application.

### A refusal answers in the shape the caller already understands

There is no third response contract. A JSON-only controller answers a bare `429` with no body, which is
what the shared modal reads; the HTML flow redirects back with a translated alert, exactly as
`refuse_request` already splits those two flows ([ADR
0011](0011-modal-json-mutation-contract.md)). The modal renders the `429` with its own sentence saying to
wait rather than to fix anything, because nothing about the record the author typed is wrong.

### The test environment's cache counts

`config.cache_store` in the test environment is a counting `:memory_store` rather than a
`:null_store`. This is what makes any of these limits observable in a request test at all, and it is
load-bearing for the two pre-existing limits too. The cost is that cached entries survive between
tests in one process, so tests that care about a counter clear it through
`test/test_helpers/throttle_test_helper.rb`.

## Consequences

### Benefits

- A public universe's write exposure is a setting its admins own rather than a constant nobody chose.
- A new universe is limited from creation, without anyone visiting a settings page.
- Every limit in the application is now exercised by a request test, including the two that were
  previously indistinguishable from no limit at all.
- A script hitting one universe spends that universe's budget, not a global one.

### Costs and constraints

- ~~One bucket covers every mutation, so a burst of photo uploads and a burst of scene edits share a
  budget. Per-endpoint groups are deliberately a later decision, taken once a single bucket has been
  observed being wrong.~~ **Resolved on 2026-10-13** by [ADR
  0029](0029-per-endpoint-throttle-groups.md), which splits the costly and the privileged mutations
  into their own ceilings inside this budget. The rest of this ADR is unchanged and still stands: it
  decided the budget, and those ceilings are sub-limits of it.
- `MutationThrottle` reimplements a framework contract and must keep up with it. The module says so at
  the point of implementation.
- Every new universe-scoped mutation controller inherits the guard automatically, and every test in
  this application now shares one cache whose entries outlive a single test.
- The budget is per account, so a shared account is one budget however many people are behind it.
- **The settings save spends the budget it sets.** `universes#update` is a universe-scoped write
  like any other, so an admin who configures a budget of 1 spends it on that save and waits out the
  window before raising it again. That is the same rule as every other mutation and it is not
  exempted deliberately: a guard that ignored the request controlling it could not be refused by
  the person it protects, and the wait is one window long rather than a lockout.

## Alternatives considered

### Declare the limit with `rate_limit` and configure it at boot

Rejected: the macro captures its arguments when the class body is evaluated, so the value cannot come
from a row. The only way to vary it would be to redefine the controller per universe, which trades a
rate limit for a class-reloading hazard.

### One application-wide limit in source, as sign-in and password reset have

Rejected because it was the status quo being complained about. It also makes the wrong owner for the
setting: the exposure is a property of one universe's openness, and universes differ in exactly that.

### Count every request rather than every mutation

Rejected. A reader refreshing a page, or a search dropdown typing, spends nothing on the universe, and
a limit that spends a writer's budget on their own page loads would be refused for reading.

### Refuse with a lockout, an exponential backoff, or a per-endpoint group

Rejected as premature. A refusal that says when to come back is the whole of this decision; what the
per-group numbers are, and which endpoints deserve their own budget, is a product decision to be taken
against observed behavior rather than against a guess made now.

**The per-endpoint group half was taken later**, on 2026-10-13, by [ADR
0029](0029-per-endpoint-throttle-groups.md). A lockout and a backoff are still rejected, and still
here: a refusal that says when to come back is the whole of the contract both decisions keep.

### Count before authorization, to refuse a flood earlier

Rejected deliberately: it would let anyone spend an authorized account's budget with requests that
were going to be refused anyway, which makes the limit a lockout rather than a brake.

## Related documentation

- [`../architecture.md`](../architecture.md) — the request lifecycle and where the guard sits in it
- [`../data_model.md`](../data_model.md) — the column, its default, and its validation
- [`../conventions.md`](../conventions.md)
- [`../features/i18n.md`](../features/i18n.md) — how the two refusal sentences are written and delivered
- [`0011-modal-json-mutation-contract.md`](0011-modal-json-mutation-contract.md) — the two response contracts a refusal follows
- [`0012-client-side-verification-and-csrf.md`](0012-client-side-verification-and-csrf.md)
