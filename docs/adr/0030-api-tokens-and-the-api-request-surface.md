# ADR 0030: Bearer-token credentials and the JSON-only API request surface

- **Status:** Accepted
- **Date:** 2026-10-19
- **Related:** [`0005`](0005-universe-access-levels.md), [`0011`](0011-modal-json-mutation-contract.md), [`0028`](0028-per-universe-mutation-budget.md), [`0029`](0029-per-endpoint-throttle-groups.md), [`../architecture.md`](../architecture.md), [`../conventions.md`](../conventions.md)

## Context

The backlog's API deliverable (item 30) lets external tools, apps, and agents read and write universes and stories. The write half is largely delivered already: characters, locations, items, events, sections, every `*_tags` controller, `scene_elements`, and the scene-presence links all answer `format.json` for create, update, and destroy, and authorization (`Ability` + `UniverseAuthorization`) and the per-universe mutation budget already exist. What is missing is the credential itself and the request surface it authenticates.

A new credential type and a new request surface are foundational decisions, not extensions of an existing one, so slice 1 needs its own ADR.

## Decision

### The credential

`api_tokens` (`user_id`, `name`, `token_digest`, `last_used_at`, `revoked_at`) and `api_token_universes` (`api_token_id`, `universe_id`). A token belongs to a `User` and to an explicit set of universes, so notifications, drafts, and any collaborator history keep an author. The bearer value is shown once at creation and never stored: only `token_digest` is kept, the same discipline as `password_digest`. A short leading prefix (`token_prefix`) is stored only so a presented token can be located before its digest is verified; the prefix alone is not a credential.

### Authentication

`TokenAuthentication` sits beside `Authentication` and resolves `Authorization: Bearer …` into `Current.user` and `Current.api_token`. `Current.user` now reads `session.user || api_token.user`. `Current.api_token.universes` narrows the reachable universes to the join table.

### The API surface

`Api::BaseController < ApplicationController` keeps `Ability` and `MutationThrottle` untouched, and drops `allow_browser versions: :modern`, the session-loading and sign-in callbacks, and forgery protection — for that surface only. It is reached through `namespace :api` with parallel `Api::*` controllers rather than token auth through the existing HTML controllers, because the existing controllers carry browser-only setup (`set_section_paths`, `set_event_options`, remembered-story session state) an API has no use for.

Slice 1 proves the surface with `Api::CharactersController`: index, show, and create/update/destroy, all JSON. A mutation in a draft-based universe answers `202` with the remembered change instead of writing; both demo universes are `direct`, so that is invisible locally.

## Consequences

### Benefits

- One credential type inherits the existing authorization, mutation budget, and draft-remembering behavior instead of duplicating them.
- A token bound to a user and explicit universes cannot reach universes it was not issued for: `set_current_universe` scopes the lookup to `Current.api_token.universes`, so anything else is `404`.
- The API surface is browser-agnostic: no session, no CSRF, no modern-browser guard.

### Costs and constraints

- A new request surface to keep secure and documented as more slices are added.
- The bearer value cannot be re-issued: it is shown once, and revoking is the only way to retire a token (slice 4).
- The prefix lookup couples generation and authentication to a fixed prefix length.

## Alternatives considered

### Token auth allowed through to the existing controllers

Rejected: those controllers run HTML-only setup on every call, or the callback chain has to branch for it, with the `allow_browser` and CSRF bypass living inside the browser controllers. Separate `Api::*` controllers cost about the same and keep policy, validation, and position services single-sourced.

### A token bound to universes with no user behind it

Rejected: decided with slice 1's contract that the credential is bound to a `User`, so every change keeps an author.

## Related documentation

- [`../architecture.md`](../architecture.md)
- [`../conventions.md`](../conventions.md)
- [`../data_model.md`](../data_model.md)
- [`0005`](0005-universe-access-levels.md)
- [`0011`](0011-modal-json-mutation-contract.md)
