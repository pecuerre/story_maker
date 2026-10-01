# ADR 0018: End sessions on a lifetime, and bind them to the user agent rather than the IP

- **Status:** Accepted
- **Date:** 2026-10-01
- **Related:** [`../architecture.md`](../architecture.md),
  [`../data_model.md`](../data_model.md),
  [`../known_quirks.md`](../known_quirks.md),
  [0005](0005-universe-access-levels.md)

## Context

A session row recorded who it belonged to and which client created it, and nothing about when it
would end. Three consequences followed, all of them verified against the tree before this decision:

- The cookie was **permanent**, while the row it named had no deadline, so a stolen session cookie
  stayed usable until its owner happened to sign out, reset their password, or be deleted. The
  cookie outliving the row was not an edge case: a permanent cookie lives about twenty years.
- There was **no cleanup path at all** for old rows, so the table grew without bound.
- Nothing checked whether the client presenting a cookie was the client that created it. The IP address
  and user agent were recorded and then never read.

The obvious fix is to expire sessions and bind them to their source. The second half is less obvious
than it looks, because "source" has two candidates and only one of them identifies a person.

An IP address identifies a **network**. Mobile connections change it routinely; a VPN changes it on
every reconnect; moving between an office and a home network changes it; a corporate proxy can put
several people behind one address. Binding a session to it would sign out legitimate readers at
exactly the moments they least expect it, and the failure looks like a broken application rather than
a security decision.

A user agent identifies a **client**, and it is what actually differs when a cookie is replayed from
somewhere else.

## Decision

- **Two columns on `sessions`**, both set by the application rather than by a column default:
  `expires_at` is the absolute end of the session's life and never moves; `last_used_at` is when it
  was last seen carrying a request and is what the idle timeout is measured from. The policy lives on
  the `Session` model (`IDLE_TIMEOUT`, `ABSOLUTE_TIMEOUT`, `LAST_USED_REFRESH_INTERVAL`), so the
  request path and the websocket connection ask the row rather than each re-implementing the rule.
- **Two limits, deliberately different kinds of rule.** The idle limit (two weeks) is refreshed by
  use, so an author returning to a project is not signed out. The absolute limit (one year) is not
  refreshed, so a session that is used continuously still ends. Neither can be pushed back by
  activity.
- **`last_used_at` is refreshed on a coarse interval, not on every request.** A timestamp written on
  every page view would make each request a write for no benefit, and would make the idle window only
  ever short by that interval.
- **The cookie expires with its session** instead of being permanent, so the browser stops presenting a
  credential the server will not honour rather than being told to sign in again for no stated reason.
- **The session is bound to the user agent that created it, and deliberately not to the IP address.**
  The address is still recorded, for diagnostics, and is never enforced. A mismatch on the user agent
  ends the session; a mismatch on the address does nothing.
- **A row with no recorded user agent is left alone.** It cannot be checked, and refusing to match a
  missing value against a present one would end sessions for a reason that has nothing to do with the
  client presenting them.
- **A row with no lifetime recorded is treated as still valid**, for the same reason: a schema change
  must not sign everybody out. Such a row is measured from when it was created.
- **A refused session is deleted, not merely ignored.** Once a session is past a limit or comes from
  another client it is over, and keeping the row would preserve a record of a credential that has
  already been refused.
- **`ApplicationCable::Connection` applies the same rules.** A websocket does not run the controller's
  authentication concern, so without this a connection opened with a cookie the request path would
  already have refused would still be accepted, and the request-time checks would mean nothing.
- **Cleanup is a scheduled job, not a dependency of correctness.** `PurgeExpiredSessionsJob` removes
  expired rows on a daily schedule in production. An expired session is already refused on its next
  request whether or not its row still exists, so the job only stops the table growing.

## Consequences

### Benefits

- A copied session cookie stops working on its own, without waiting for the owner to notice.
- The `sessions` table stops growing, and the absolute limit means a session cannot be kept alive
  forever by being used.
- The policy is stated once. The controller and the websocket connection cannot disagree about what
  makes a session valid, because neither of them decides.
- An IP change no longer signs anyone out, which was the failure mode most likely to have made this
  feature a source of support problems.

### Costs and constraints

- **A reader whose browser updates its user agent between visits is signed out.** This is rarer than
  an IP change but not impossible — a browser major-version update does it. It fails safe: the
  remedy is to sign in again.
- **The idle and absolute limits are policy values in a model, not configuration.** Changing either is
  a code change and a deploy. That is deliberate for this application, but it does mean the numbers
  cannot be tuned per environment.
- **`last_used_at` is written at most once an hour per session**, so a session that ends mid-interval
  can be idle for up to that much longer than the stated window.
- **Existing sessions get no lifetime.** Rows created before the migration are treated as valid and
  unbound, so they are governed by their own creation date through the idle rule alone.

## Alternatives considered

### Binding the session to the IP address as well

Rejected, and it was the owner's explicit choice between the two. An IP address is not a stable
identifier for a person: mobile networks, VPNs, and office/home switching all change it legitimately,
and signing a reader out at those moments produces a support problem that looks like a bug. The
user agent is the part of "source" that actually differs when a cookie is replayed somewhere else.

### Enforcing the absolute limit only

Rejected. It ends a long-abandoned session eventually but keeps a stolen cookie usable for that whole
year regardless of whether its owner is still using their own. Two limits cost two columns and answer
two different questions: "is this still in use?" and "is this still within its life?".

### A sliding absolute limit

Rejected. Extending the absolute deadline on each use makes the absolute limit decorative — a session
kept alive by an attacker is exactly the one that would never expire.

### Refreshing `last_used_at` on every request

Rejected. It would make every page view a database write for a value whose precision nobody can
observe, and it would convert a read-heavy request path into a write-heavy one.

### Cleaning up inside the request path

Rejected. Deleting other readers' expired sessions during an ordinary request makes a page load depend
on how many dead rows exist, and couples request latency to table size. A scheduled job with one
`DELETE` is the right shape for a table that only grows by appending.

## Related documentation

- [`../architecture.md`](../architecture.md)
- [`../data_model.md`](../data_model.md)
- [`../development.md`](../development.md)
- [0005](0005-universe-access-levels.md)