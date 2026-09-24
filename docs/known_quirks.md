# Known Quirks & Tech Debt

Verified **open** oddities in this codebase — things that look like bugs, are bugs, or will
surprise you. Each entry was checked against the code (paths given); when one gets fixed, move
it to [resolved_quirks.md](resolved_quirks.md) instead of deleting it, so the fix history
survives. Index of all docs: [README.md](README.md).

## Correctness / security observations

1. **`visible?` always returns `true`.** `ApplicationHelper#visible?`
   (`app/helpers/application_helper.rb`) computes `controllers.include?(controller.controller_name)`
   on its own line and then returns literal `true` (the comparison is discarded). The redesigned
   sidebar no longer calls this helper, so the bug no longer affects the current navigation, but
   it must be fixed before reusing the helper for visibility decisions.

2. **cancancan is installed but never used.** `Ability` (`app/models/ability.rb`) includes
   `CanCan::Ability`, but there is no `authorize!`/`current_ability`/`load_and_authorize` anywhere
   in the app. Its rules are also wrong for this schema:
   `can :manage, Universe, user_id: user.id` — universes have `owner_id`, not `user_id`.
   Authorization today is effectively "any signed-in user may touch anything".

3. **No authorization on universe-scoped content.** Content controllers only scope by the
   `:universe_slug` param (`Current.universe.<assoc>.find(...)`). Any authenticated user (or, for
   universes, see next point) who knows a slug can read/modify/delete any universe's content.

4. **Universes are open even to guests, and private universes are readable by slug.**
   `UniversesController` declares
   `allow_unauthenticated_access only: %i[index show new create edit update destroy]` (i.e. all
   actions) and `set_universe` looks up `Universe.find_by(slug: …)` **without** applying
   `Universe.visible_to`. So `private: true` only hides a universe from the index/navbar —
   anyone with the slug can open and even edit/destroy it. `create` falls back to
   `Current.user || User.first`, so a logged-out creator's universe is owned by the first user.

5. **Seeds are not idempotent** despite the Rails boilerplate comment in `db/seeds.rb`
   ("should be idempotent"): the dark loader and `lotr.rb` use `create`/`create!` on every run,
   and the demo-universe list `["dark", "lotr"]` is hardcoded there.

6. **`Relation`/`Ownership` composite-slug code is a trap.** Both define
   `before_validation :generate_slug, on: :create` (intended `character-tag-character` slugs when
   `name` is blank), but `HasSlug`'s `before_validation :set_slug` is registered first (at
   `include` time). For the usual case — no `name` attribute at all — its `else` branch already
   assigns `SecureRandom.hex(4)`, so `generate_slug` returns early and unnamed
   relations/ownerships get a random hex slug. The composite branch only runs when `name` was
   assigned but is blank (`name: ""` → `slugify("")` → `nil`), where it builds
   `character-<tag>-character` — or just `character-character` when the record has no tags
   (tags are optional, see [data_model.md](data_model.md#slugs)).

7. **`Event#set_name` runs `on: :create` only.** Renaming an event's `title` later does **not**
   update `name` (only `title` is used by `display_string`, so the drift is mostly invisible —
   but `name` and `slug` stay at their create-time values).

8. **CI runs a system-test job with no system tests.** `.github/workflows/ci.yml` has
   `system-test` (`test:system`) but there is no `test/system` directory yet (it will run zero
   tests; screenshots artifact is ignored).
