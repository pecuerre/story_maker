# Known Quirks & Tech Debt

Verified oddities in this codebase — things that look like bugs, are bugs, or will surprise you.
Each entry was checked against the code (paths given); update this file when one is fixed.
Index of all docs: [README.md](README.md).

## Correctness / security observations

1. **`visible?` always returns `true`.** `ApplicationHelper#visible?`
   (`app/helpers/application_helper.rb`) computes `controllers.include?(controller.controller_name)`
   on its own line and then returns literal `true`. Every sidebar "tag" shortcut is therefore
   always rendered (harmless today because it is only used to decide visibility, not access).

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

6. **`Relation`/`Ownership` composite-slug code looks unreachable.** Both define
   `before_validation :generate_slug, on: :create` (intended `character-tag-character` slugs when
   `name` is blank), but `HasSlug`'s `before_validation :set_slug` is registered first (at
   `include` time) and its `else` branch already assigns `SecureRandom.hex(4)`, so
   `generate_slug` always returns early. Net effect: unnamed relations/ownerships get a random
   hex slug.

7. **`Event#set_name` runs `on: :create` only.** Renaming an event's `title` later does **not**
   update `name` (only `title` is used by `display_string`, so the drift is mostly invisible —
   but `name` and `slug` stay at their create-time values).

8. **`SectionTagsController`-style default-tag assignment raises on tagless universes.**
   `SectionsController#create` / `CharactersController#create` do
   `...section_tags.order(:id).first.id if ids.empty?` — `NoMethodError` on `nil` if the universe
   has no tags yet (tag fixtures/seeds normally prevent this).

9. **CI runs a system-test job with no system tests.** `.github/workflows/ci.yml` has
   `system-test` (`test:system`) but there is no `test/system` directory yet (it will run zero
   tests; screenshots artifact is ignored).

## Dead / vestigial code

10. **`ApplicationController#default_url_options` is a no-op:**
    `return super unless Current.universe; super.merge()` merges nothing. `universe_slug` in URLs
    actually comes from request *recall* (see [architecture.md](architecture.md#routing--url-generation-the-sharp-edges)).

11. **`ApplicationHelper#visible?`** (see #1) — its comparison is discarded.

12. **`hello_controller.js`** — Rails scaffold leftover.

13. **`current_universe_sections_path`** in `SectionsController` (and similarly named private
    methods in other controllers) is defined but not referenced anywhere.

14. **Root `README.md`** is still the untouched Rails scaffold boilerplate — **this `docs/`
    directory is the source of truth** for project knowledge.

## Conventions that will bite you

15. **Positional path-helper trap.** `universe_story_sections_path(story)` binds the Story to
    `universe_slug` (first dynamic segment) and fails with
    `missing required keys: [:story_id]`. Always pass named keys:
    `universe_story_path(id: story)`, `universe_story_sections_path(story_id: story)`.

16. **Building on an association leaks into views.** `Current.universe.stories.new(...)` appends
    the unsaved record to the association target, so a sidebar rendering
    `Current.universe.stories.each` blows up on `id: nil`. Build with
    `Story.new(universe: Current.universe)` instead (`StoriesController` does).

17. **Fixture slugs use underscores** (`section_one`) while `HasSlug.slugify` converts `_` → `-`,
    so the class-level finder `Section.section_one` would look for `section-one`. Keep new slugs
    **dash-separated** (seed files already are).

18. **`404` vs `RecordNotFound` in tests.** Because `show_exceptions = :rescuable` in
    `config/environments/test.rb`, out-of-scope records render HTTP 404 — assert with
    `assert_response :not_found`; `assert_raises(ActiveRecord::RecordNotFound)` will not trigger.

19. **Old sections URL is gone.** `/u/<slug>/sections` now 404s; sections live under
    `/u/<slug>/stories/<story_id>/sections`.

20. **Sidebar issues many COUNT queries** (one per nav entry) on every page render; section
    counts are not memoized (`icon_text_count(Current.universe.X.count)`). The stories menu (and
    its count) moved to the top bar navbar, which renders no counts.

21. **Two lockfiles.** `bun.lock` (current — `bun install` runs during asset/test tasks) and a
    stale `yarn.lock` coexist; `Procfile.dev` still says `css: yarn watch:css`. Prefer bun
    (`bun run watch:css`).

22. **Migrations reference app models** (`Story`, `Section` in
    `db/migrate/20260923000000_move_sections_to_stories.rb`). Fine at this project stage, but
    editing those models later can break re-runs of old migrations (schema loads are safe).

23. **`Universe` has no validations** — a universe can be saved with a blank name (Story cannot).

24. **Section tags are universe-wide while sections are story-scoped — on purpose** (chapter /
    book / episode labels are reused across stories), but it means a tag can be deleted even if
    stories still reference it (`dependent: :destroy` on `universe.section_tags` only cleans join
    rows).

25. **`docs/todo.txt` markers:** "(A)" lines are the project owner's idea/backlog notes, not
    generated content — edit carefully. `docs/schema.txt` is a hand-maintained sketch (kept in
    sync manually; currently shows `story` and story-scoped `section`/`scene`).
