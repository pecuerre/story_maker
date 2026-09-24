# Known Quirks & Tech Debt

Verified **open** oddities in this codebase — things that look like bugs, are bugs, or will
surprise you. Each entry was checked against the code (paths given); when one gets fixed, move
it to [resolved_quirks.md](resolved_quirks.md) instead of deleting it, so the fix history
survives. Index of all docs: [README.md](README.md).

## Correctness / security observations

1. **cancancan is installed but never used.** `Ability` (`app/models/ability.rb`) includes
   `CanCan::Ability`, but there is no `authorize!`/`current_ability`/`load_and_authorize` anywhere
   in the app. Its rules are also wrong for this schema:
   `can :manage, Universe, user_id: user.id` — universes have `owner_id`, not `user_id`.
   Authorization today is effectively "any signed-in user may touch anything".

2. **No authorization on universe-scoped content.** Content controllers only scope by the
   `:universe_slug` param (`Current.universe.<assoc>.find(...)`). Any authenticated user (or, for
   universes, see next point) who knows a slug can read/modify/delete any universe's content.

3. **Universes are open even to guests, and private universes are readable by slug.**
   `UniversesController` declares
   `allow_unauthenticated_access only: %i[index show new create edit update destroy]` (i.e. all
   actions) and `set_universe` looks up `Universe.find_by(slug: …)` **without** applying
   `Universe.visible_to`. So `private: true` only hides a universe from the index/navbar —
   anyone with the slug can open and even edit/destroy it. `create` falls back to
   `Current.user || User.first`, so a logged-out creator's universe is owned by the first user.

## Development workflow observations

4. **Disposable universe data is still coupled to `db:seed`.** `db/data/` is intentionally
   development-only: one subdirectory per universe (`dark/`, `lotr/`, and future universe slugs)
   contains the records used to exercise that universe. The current `dark` and `lotr` loaders use
   `create`/`create!`, and `db/seeds.rb` still loads a hardcoded `["dark", "lotr"]` list, so the
   loaders are not safe to rerun. This is not a request to make temporary feature data production-
   idempotent; the intended fix is an explicit, environment-guarded development load/reset task
   that keeps `db/seeds.rb` production-safe. The current coupling is tracked as a transitional
   implementation gap in [ADR 0004](adr/0004-universe-data-and-demo-seeding.md).
