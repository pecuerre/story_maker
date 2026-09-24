# ADR 0005: Use universe-level public/private access with three membership levels

- **Status:** Accepted
- **Date:** 2026-09-24
- **Related:** [`../data_model.md`](../data_model.md), [`../architecture.md`](../architecture.md), [`../vision.md`](../vision.md)

## Context

Universe Maker is intended to support collaboration as well as solo writing. A public universe
should be useful to readers who have not signed in, while contributions should always be
attributable to a user. A private universe needs an explicit way to share it without making every
story or world-building record a separate authorization boundary.

The application already has universe and story ownership boundaries, but it had no membership
records or authorization rules. Treating a universe slug as sufficient for access would expose
private content; treating each story as the permission boundary would make shared world-building
records inconsistent.

## Decision

Authorization is defined at the universe level and has three levels: **read**, **write**, and
**admin**.

- Public universes are readable by guests. Every signed-in user can contribute. The owner and
  explicitly granted admin members can manage settings and memberships.
- Private universes are readable only by their owner and members. Read members can view, write
  members can view and contribute, and admin members can additionally manage settings and
  memberships.
- The owner is always an admin. The owner does not need a duplicate membership row.
- A user's effective access applies to every story and every universe- or story-scoped component
  in that universe. Sections and section tags continue to resolve their universe through their
  story.
- `Ability` is the single policy definition used by the request authorization concern. Universe
  membership management is an admin-only HTML flow at `/u/:universe_slug/members`.

## Consequences

### Benefits

- Public reading works without accounts, while anonymous writes are impossible.
- Private collaboration has a small, understandable role model.
- Shared world-building records cannot accidentally have different permissions from their stories.
- Authorization is explicit and testable instead of relying on controller scoping alone.

### Costs and constraints

- Every universe-scoped controller must allow public read requests to reach the shared policy
  callback, then require authentication for writes.
- A private non-member receives 404 to avoid disclosing the universe; this includes anonymous
  visitors. A member with an insufficient level receives 403.
- Membership changes affect access immediately and must be covered by request/model tests.

## Alternatives considered

### One global application-admin role

Rejected because access is scoped to a universe; an application administrator should not automatically
receive collaborator access to every private world.

### Separate permissions for every story and content model

Rejected because it duplicates policy and makes shared universe records ambiguous.

### Store an owner membership row

Rejected because the owner is already represented by `universes.owner_id`; a second row could drift
from ownership and would complicate owner transfers.

## Related documentation

- [`../data_model.md`](../data_model.md)
- [`../architecture.md`](../architecture.md)
- [`../universe_maker_conventions.md`](../universe_maker_conventions.md)
- [`../known_quirks.md`](../known_quirks.md)
