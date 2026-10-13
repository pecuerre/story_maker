# ADR 0029: The costly and the privileged mutations get their own ceilings, and the one that has no universe belongs to the platform

- **Status:** Accepted
- **Date:** 2026-10-13
- **Related:** [`0028`](0028-per-universe-mutation-budget.md), [`0005`](0005-universe-access-levels.md), [`0015`](0015-record-photos.md), [`../architecture.md`](../architecture.md), [`../data_model.md`](../data_model.md), [`../features/settings.md`](../features/settings.md)

## Context

[ADR 0028](0028-per-universe-mutation-budget.md) gave a universe one mutation budget, counted
per account per minute, and recorded as a deliberate cost: *"One bucket covers every mutation, so a
burst of photo uploads and a burst of scene edits share a budget. Per-endpoint groups are
deliberately a later decision, taken once a single bucket has been observed being wrong."* This is
that later decision.

The bluntness is not hypothetical and it is not one problem. A single bucket conflates four things
that are different in kind:

- **Cost.** A photo is the only mutation that runs an image through `PhotoProcessing`. Every other
  write in this application is a row or two.
- **Privilege.** Granting, changing, or removing someone's access hands out reach. It is the only
  write a universe's `admin` level performs, and doing it a thousand times a minute is a different
  act from doing it three times.
- **Fan-out.** A discussion reply also writes the notification its conversation receives
  (`DiscussionMessage#post!`), so it is not the one row it looks like.
- **Scope.** `POST /u` creates a universe. There is no universe yet, so there is no universe whose
  admins own a budget for it, and no universe to read one from.

ADR 0028 also fixed the numbers on a principle worth keeping: a window is not the thing an admin
has an opinion about, the budget is. So the windows stay constants, and the counts follow the
budget's owner — which means the three universe-scoped counts are columns on `universes` beside
`mutation_limit`, and the fourth cannot be.

## Decision

### A group is a ceiling inside the universe's budget, not a share of it

A mutation that belongs to a group spends **both**: one from `universes.mutation_limit` and one from
its group's counter. A request is refused when either is over. The group's number therefore binds
*first*, inside the budget, rather than replacing it.

The alternative — a grouped mutation spends only its group, and never touches the overall budget —
was rejected because it quietly redefines what the admin's setting means. "Changes per minute: 60"
has to stay a bound on this universe's total writes, or it becomes a description of ordinary edits
that a flood of uploads or grants can pass through without counting, which is the one reading an
admin would not expect from the field they were given.

### The three groups that have a universe

| group | what it matches | window | default |
|---|---|---|---|
| `:photo` | a mutating request whose payload carries a **present** `photo_data` | 1 minute | 10 |
| `:membership` | every write in `MembershipsController` | 1 minute | 10 |
| `:discussion` | a write in `MessagesController` | 1 minute | 30 |

Each is a column on `universes` — `photo_mutation_limit`, `membership_mutation_limit`,
`discussion_mutation_limit` — with the same three rules `mutation_limit` has: a column default so a
universe is protected from creation, `NULL` for "no limit on this group", and a refused `0`. `NULL`
is per group rather than per universe, so an admin can leave the content budget open and still cap
uploads. `Universe::MUTATION_GROUP_COLUMNS` is the one list: the columns, the defaults, the
validation, and the form fields are all answered from it, so a fourth group is one entry plus one
column.

Two details of the matching are load-bearing:

- **A blank photo field is not an upload.** The cropper's field is rendered on every editor and
  submits empty when the author changed no picture, so charging the photo ceiling for those would
  make it mean "edits" — which the universe budget already counts. The detection walks the payload
  for a *present* `photo_data` rather than reading one known key, because the parameter is nested
  under whichever model the request carries. `remove_photo` is deliberately not in this group:
  dropping a picture writes no image and costs no processing.
- **A level change is a grant.** `MembershipsController` is `admin`-gated in its entirety, and
  changing an existing member's level hands out exactly as much reach as creating the row did. All
  three of its writes are one group.

### The one group with no universe is the platform's

`universes#create` is a platform-level write: `Current.universe` is nil on `POST /u`, because there is
no universe to resolve. It spends no universe budget, and its number comes from
`platform_settings.universe_creation_limit` — a single-row table with a column default of 5 per
**hour**.

The hour is the one window that is not the universe's minute, and it is deliberate: creating a
universe is an act an author performs once or twice, not once a minute, so a per-minute window
would describe an activity that does not exist.

### A platform setting needs a platform owner, and there was no such account

Every privilege in this application is a level *inside* a universe ([ADR
0005](0005-universe-access-levels.md)), and nobody administers the platform itself. Three answers
were possible and two of them are traps:

- *Any signed-in account may change it.* `can :create, Universe` is already open to every signed-in
  account, so this "only bounds a capability contributors have" — and it would also let any
  contributor raise the ceiling for everybody, including for their own flood.
- *An account that owns a universe.* Trivial: anybody may create a universe, so anybody may own one.
- *`users.platform_admin`.* **Chosen.** It is the first privilege in this application that is not a
  membership level, it defaults to `false`, and nothing in the interface sets it — which is exactly
  why it needs to exist: there is no screen on which an ordinary person could be given the power to
  change it. `Ability` answers it with a `:platform` level, declared as a class rule for the same
  reason every other rule is (a CanCan block matched against a class returns `true` without running).

The setting is edited from the **Limits** section of the platform Settings page. That page is
otherwise entirely about what one browser remembers, which is why the section is hidden from everyone
else rather than shown read-only, and why `settings_sections` — not a `hidden` attribute — decides
which sections exist: a section a reader may not open must also be a section a guessed
`?section=limits` cannot reach.

### One request, at most one group

Groups are matched in a fixed order and the first match wins, so a universe created *with* a photo
spends the creation group and not the photo group. The privileged action is matched first on
purpose: its ceiling is an order of magnitude tighter, and an account cannot create universes in a
flood anyway, so the precedence cannot be used to escape a limit that mattered.

## Consequences

### Benefits

- A photo flood, a mass grant, and a burst of scene edits stop consuming each other's budget.
- The ceilings an admin cares about are settings, in the same place and the same shape as the
  overall budget, with per-group `NULL`.
- Universe creation is counted at all, which it was not: ADR 0028 could not count a mutation that has
  no universe to count it against.
- The one non-universe setting in the application has an owner and an authorization rather than a
  constant.

### Costs and constraints

- Five more columns and one more table, one more form panel, and one more authorization concept. The
  last of those is the only genuinely new thing in the application's model: `Ability` now has a level
  that is not about a universe, and it governs exactly one setting.
- **The three universe group ceilings are per universe, so an operator cannot change them centrally.**
  They are admin settings because the budget they sit inside is one, and moving them to the platform
  would put a universe's photo ceiling in the hands of somebody who administers no universe.
- A grouped mutation still spends the universe budget, so a flood spends both and is refused by
  whichever ceiling arrives first. The group's counter is not a refund mechanism.
- `PlatformSetting.current` reads the first row and falls back to an unsaved default rather than
  writing on read, so a missing row is not an error — and a second row would be a data error nothing
  in the interface can create.
- The detection for `:photo` is a payload walk on every mutating request. It is one `each_pair` per
  level over a payload the application already parsed, and it is skipped entirely for a request that
  carries no parameters at all.

## Alternatives considered

### Each group as a rate on its own, sharing nothing with the universe budget

Rejected: it leaves "Changes per minute" describing something other than the universe's total
writes, which is the one thing an admin reads that field to mean.

### The groups as constants in `MutationThrottle`

Rejected in favour of settings, deliberately against ADR 0028's own reasoning that the budget belongs
to the universe: the owner decided per-group numbers are an admin's to set, so they are stored where
an admin sets them. The *windows* stayed constants for the same reason ADR 0028 kept its window
constant — a window is not a thing anybody has an opinion about, and a per-group window column would
put a number nobody understands (a one-second window is a limit no human can work within) one form
field away from a human.

### Grouping by route or by controller alone

Rejected for photos: there is no photo endpoint. A photo is a `photo_data` value inside an ordinary
mutation, which is why the only way to see one is to look at what the payload carries.

### A platform role broader than one setting

Rejected: the flag exists to change one number. Anything wider — managing accounts, reading every
universe — would be a second access model beside [ADR 0005](0005-universe-access-levels.md) with no
feature to justify it, and a much larger piece of work to get right.

### Leaving universe creation uncounted

Rejected: it is the cheapest write in the application to flood and the one whose flood costs the
deployment the most, because every universe is a search index, a set of menu counts, and a slug that
has to stay unique.

## Related documentation

- [`../architecture.md`](../architecture.md) — where the guard sits and what it now counts
- [`../data_model.md`](../data_model.md) — the four new columns and the singleton table
- [`../conventions.md`](../conventions.md) — the universe form's fields
- [`../features/settings.md`](../features/settings.md) — the one section that is not a browser
  preference
- [`../features/photos.md`](../features/photos.md) — what a photo upload actually costs
- [`0028-per-universe-mutation-budget.md`](0028-per-universe-mutation-budget.md) — the budget these
  are sub-limits inside
- [`0005-universe-access-levels.md`](0005-universe-access-levels.md) — the access model this adds one
  non-universe level to