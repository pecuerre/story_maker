# SHARED BACKLOG

This is the one place for pending work, rough ideas, and things we may want
to do in the future. The owner can append ideas without worrying about format.

## How AI assistants should use this file

When you notice another worthwhile improvement while working on a task, ask
the owner whether to do it NOW, LATER, or NEVER.

- NOW: do the extra work as part of the current task, then remove or mark the
  item as completed.
- LATER: add it under FUTURE WORK below.
- NEVER: do not implement it and do not add it to this file.

Do not silently expand the current task. Keep this file focused on work that is
still pending.

## PENDING WORK

1. **Explicit development universe-data loader**

Replace the transitional `db:seed`/`db:restart` coupling with an environment-guarded development
loader. Discover or register one `db/data/<universe_slug>/` directory per universe, support loading
one named universe after a deliberate reset, validate model order and symbolic references, and
keep temporary data out of production seed/deploy paths. Preserve the convention that a new model
gets files such as `db/data/dark/dialogs.yml` in each relevant universe directory rather than a
feature-level `db/data/dialog/` directory.

2. **add "fixed" attribute to all _tags models**

the fixed ones should not be editable or deletable and should be shown as submenus of the respective objects.

3. **Contextual inspector / right-side utility panel**

The right utility sidebar now reserves a stable home for future collaboration, analytics, and AI
tools. Replace its temporary `aria-disabled` links with a real contextual inspector as the
underlying product areas become concrete. The inspector should show information relevant to the
current page: selected entity details, related records, taxonomy usage, filters, or quick actions.
It remains a Bootstrap `offcanvas-end` below `xl` and can be hidden when there is nothing useful
to show. Candidate data includes selected-character relations/ownerships, relation-tag usage
counts, and story outline progress.

4. **Search, filtering, and sorting for large lists**

Add client- or server-backed search/filter/sort controls to Characters, Locations, Events, Items,
Relations, Ownerships, and taxonomy trees. Preserve universe/story scope, make filters removable
and visible in the URL where practical, and define behavior for empty results separately from an
empty database. Start with the fields already exposed by each model; do not add opaque global
search before the scoped lists are usable at scale.

5. **Richer relationship and entity rows**

Make list rows more useful for scanning large universes. Relations should render as a readable
sentence such as `Ariadne — is friend to → Lysander`, with direction and dates as metadata.
Characters could show relation/ownership counts, locations could show parent/child context, events
could show date range and related events, and items could show current/historical owners. Add
these as derived presentation data where possible; avoid duplicating source fields in the UI.

6. **Story overview dashboard**

Turn the current Story overview into a compact working dashboard: story description, section
count, section-tree preview, recently edited sections, quick “Add section” action, and links into
the relevant Universe Bible records. This should remain lightweight until the underlying section
and appearance/usage data are available.

7. **Universe summary cards**

Make the Universes index useful for choosing a workspace. Add story and entity counts, visibility,
recent activity, and a clear “Open universe” action. Consider eager-loading/caching the summary
counts so the index does not issue one count query per universe. Keep the existing authorization
and visibility rules in mind before exposing any summary data.

8. **Global search / command palette**

After scoped search is solid, add a global command palette for switching universes/stories and
jumping to Characters, Locations, Events, Sections, or the Timeline. It must respect the current
universe/story scope and should be keyboard accessible. This is a navigation enhancement, not a
replacement for scoped list filters.

9. **Story-planning and world-building tools**

Scene planning is now specified in Epic 11 below. Revisit adjacent ideas such as Plot, Tropes,
Routes, Map, Distances, Meetings, POV structure, and richer dialogue only with a concrete domain
decision: define what each record means, which scope owns it, how it appears in the current page
patterns, and whether it is worth adding to the data model. Replace a reserved link only when the
feature has a real destination and useful empty, loading, and error states.

10. **Collaboration and universe analysis**

Universe-level access management is implemented: public/private visibility and read/write/admin
memberships are available from the universe workspace. The right sidebar still reserves temporary
links for Tracking, Analyzer, richer Collaboration, Graphs, Analytics, and AI tools. Those remain
future product areas. Before replacing the placeholders with navigation, specify the underlying
records and permissions: inconsistency detection, incomplete/undefined records, submissions,
changes/forks, graphs, analytics, and drafts. A feature should appear as a live navigation item when
it has a useful destination and clear empty/loading/error states.

11. **Epic 11 — Add Scenes to a Story**

Treat this as an epic rather than one implementation task. It crosses the story/script data model,
ordered writing, taxonomy, world-building links, editing UX, continuity analysis, and several
existing UI infrastructure gaps. Ship it as the ordered slices below so each slice remains
reviewable and testable.

#### Outcome and settled product decisions

- A **Story owns its Scenes**. Universe-level Characters, Locations, Items, and Events remain
  shared by every Story in the Universe.
- A Story is a canonically ordered sequence of Scenes. Scene `position` expresses **narrative
  order**—the order in which the Story is told—not in-world chronology.
- **Sections are optional organizational groupings**, not an alternative source of order. Authors
  may write and order Scenes first, then assign each Scene to zero or one Section such as a book,
  chapter, season, or episode. A nested Section also places a Scene within that Section's ancestor
  path; it does not copy the Scene into several stored memberships.
- A Scene and an Event are different concepts. Several Scenes can reference the same Event. For
  example, the same Event can appear once from one character's point of view in Season 1 and
  again from another character's point of view in Season 3. Do not deduplicate or merge those
  Scenes merely because their Event is the same.
- A Scene has one optional link to a Universe Event and one optional in-world datetime. These two
  fields are intentionally independent for this version: selecting or changing one must not
  overwrite or validate against the other.
- A Scene can involve zero or many Characters, Items, and Locations. Each presence link can carry
  an optional, free-text role such as “setting,” “enters,” “carries,” or “objective.” Roles are
  author annotations, not a controlled vocabulary in this version.
- A Scene Tag is a story-scoped, hierarchical taxonomy similar to Section Tag. Scene tags are
  optional, editable through **Configuration → Tags → Story Tags**, and never receive an
  automatically assigned default.
- The Scene Element sequence is ordered independently. The first version has two element kinds:
  **Narration** and **Dialogue**. A Scene can contain any number of elements, including none; an
  unfinished Scene is valid.
- A Dialogue element can name many speaking Characters. This identifies who speaks in the block,
  but does **not** capture turn-by-turn attribution inside its free text.
- Within its required Story, a Scene requires only a title. Description, Section, Event, datetime,
  tags, elements, and all world-building links may be added later. Element rules apply only after an
  Element is created; they do not prevent a title-only Scene from being saved.
- A speaker is also a participant in the Scene. The Characters tab should make that relationship
  obvious and should not require the author to maintain the same person twice.

#### Recommended target domain model

Finalize exact column and association names in slice 11.0, but the intended ownership graph is:

- `Scene belongs_to Story`; `Scene belongs_to Section, optional: true`; `Scene belongs_to Event,
  optional: true`; and Story owns the ordered `has_many :scenes` collection. Scene includes
  `HasSlug`, has a contiguous `position`, and stores a short optional description plus the
  independent optional datetime.
- `SceneTag belongs_to Story` and follows the existing hierarchical, colored, story-scoped tag
  conventions. **Configuration → Tags → Story Tags** manages tag definitions; assigning tags to an
  individual Scene belongs on Scene Details. `Scene`/`SceneTag` use optional story-scoped tag
  associations and the `scenes_scene_tags` join table.
- `SceneElement belongs_to Scene`; ordered by `position`; stores an element kind, optional title,
  and text content. Prefer persisted `name` labelled **Title** and a required `body` labelled
  **Content**; confirm those defaults in slice 11.0. Never name the kind column `type`, because
  Active Record reserves that name for single-table inheritance. Prefer `kind` or `element_type`,
  constrain it to `narration` or `dialogue` in model/database checks, and forbid speakers on
  Narration. Changing Dialogue to Narration with speakers must fail clearly or remove them only
  after explicit confirmation in an atomic update.
- `SceneCharacter`, `SceneItem`, and `SceneLocation` are join records that preserve a nullable
  free-text `role` and enforce that every linked Universe record belongs to the Scene's Universe.
  Blank role input means no role; do not validate it against a controlled vocabulary. Join models
  are preferable to unannotated HABTM here because the role is part of the decision.
- `SceneElementSpeaker` is a many-to-many link to Universe Characters, with the same-Universe check
  as other Scene links. It should not imply speaker-turn order; a later structured-dialogue model
  can own that concern. The Characters tab should derive participation from explicit presence links
  plus Element speakers and label the difference, rather than create a duplicate `SceneCharacter`
  row solely because someone speaks.
- Use real foreign keys and appropriate indexes in schema-only migrations: Story/Scene ownership,
  optional Section/Event references, `[story_id, position]`, `[scene_id, position]`, Section-grouped
  lookup, and unique indexes for each presence/speaker pair. Do not rely on SQLite foreign keys to
  prove same-Universe or same-Story application scope.
- Recommended deletion contract: deleting a Scene removes its Elements, tag joins, speaker links,
  and presence links; deleting a Story cascades its story-owned Scenes; deleting a Section or Event
  nullifies Scene references; deleting a Character, Item, or Location removes its Scene/speaker join
  records but never the Scene. Shared world records always survive Scene deletion. Add confirmation
  copy and model/request tests for each path rather than relying on an unannounced database error.

#### Frontend and interaction contract

- Replace the reserved Scenes entry with a real Story-scoped link only when a Story is selected.
  With no current Story, keep the existing explicit “select a Story” flow; never fall back to the
  first Story.
- The Scenes index is a flat list in canonical Scene order, with an explicit **Ungrouped** indicator
  where appropriate, clear title and short-description previews, Section and tag badges,
  element/participant counts, and add/edit/delete actions. Its main list is ordered only by Scene
  `position`.
- The main Scene editor uses the project's URL-backed workspace tabs: **Scene Details**,
  **Characters**, **Items**, and **Locations**. The tab is “Locations” because the model supports
  many. Use canonical URLs and `aria-current`, not in-document Bootstrap tab panes.
- The canonical collection is `/u/:universe_slug/s/:story_id/scenes`. The Scene Details destination is
  `/u/:universe_slug/s/:story_id/scenes/:scene_id`; related tabs use readable nested index routes
  such as `/characters`, `/items`, and `/locations`, and Elements use a nested `scene_elements`
  collection. Scene Tag definitions use the existing Story Tags workspace. Do not add a
  Universe-level Scene route.
- Scene Details contains title, short description, optional Section, optional Event, optional
  datetime, Scene Tags, and the ordered Scene Element list. Keep Elements under Details for the
  first version; split them into another tab only if real use shows that Details is too dense.
- Deliberately use the HTML redirect/re-render flow for the stable Scene Details form and JSON plus
  Stimulus for Element and role-bearing presence-link modal CRUD. This is a new, documented hybrid
  response architecture, not a change to the current response matrix; add it to the architecture and
  conventions docs. Define and test those formats per controller rather than making one action accept
  HTML and JSON ambiguously.
- Scene Elements use Bootstrap modal editors as requested. Narration and Dialogue have distinct
  labels; Dialogue presents a many-speaker picker and keeps prose in the element body.
- Character, Item, and Location tabs list linked records with their role annotation and provide
  add/remove flows. They are empty states with real links, not fake tabs.
- Reordering must have visible Move up/Move down controls and keyboard support. Drag-and-drop may
  be an enhancement, but it must not be the only way to reorder on touch devices or with a
  keyboard.
- Grouping Scenes into Sections changes organization only, never narrative order. Keep the global
  ordered Scenes view and provide a separate Section-grouped outline so Section position is never
  mistaken for Story position.
- Read-only users can inspect every Scene detail and link but see no mutation controls. Mark every
  intended public read action (index/show and each related tab read action) as unauthenticated-readable
  while keeping every mutation behind authentication and the shared Universe policy. Preserve
  public/private Universe behavior through the shared authorization path; do not add a separate
  visibility check in the controller.
- Test the editor at desktop and mobile widths, with long titles/descriptions, empty Scene and
  Element states, keyboard-only navigation, screen-reader labels, reduced motion, and all Universe
  access levels. Avoid UI that depends on hover or a wide viewport.

#### Delivery slices

- **11.0 — Domain contract and UX skeleton.** Add an ADR that extends the accepted
  Universe/Story scope decision without rewriting its history. Confirm the remaining defaults:
  Scene title storage/label, whether Element body is required, whether Dialogue requires at least
  one speaker, datetime timezone/precision, and the exact confirmation copy for the recommended
  deletion contract. Sketch the global Scene list, URL-backed tabs, Element modal, and Section
  grouping flow. Recommended defaults are: persist Scene title as `name`; require Element body but
  not Element title; require one or more speakers for Dialogue; keep role nullable; follow the
  existing Event datetime precision for now. Backlog item 1 is a prerequisite for the final
  development-data/manual-verification slice, not a reason to delay the domain design.
- **11.1 — Core Scene vertical slice.** Add a schema-only Scene migration and model, Story
  association, stable `name`/slug, and a transactionally maintained contiguous position with
  deterministic `position, id` ordering. Add Story-scoped routes/controllers, the canonical Scenes
  index, accessible move controls, a title/description create-edit-delete journey, the stable Scene
  editor shell, the real sidebar link and scene count/cache invalidation, and basic empty and
  read-only states. Keep Section/Event/datetime, tags, Elements, and world links out of this slice.
  Include model/request/route tests, connected development data, and matching docs.
- **11.2 — Scene Details, references, and time.** Extend the stable editor with the optional
  same-story Section link, optional same-Universe Event link, and independent optional datetime.
  Add the URL-backed tab shell and explicit “narrative order” versus “in-world time” copy. Reject
  malformed optional IDs as 422 validation errors rather than allowing a database exception. Add
  the authorization/helper adapter for Scene-owned records so nested models resolve their Universe
  through Scene.
- **11.3 — Section grouping workspace.** Let authors group already-written Scenes under optional
  Sections and move a Scene between “Ungrouped,” a Section, or another Section. Show nested Section
  paths and preserve the canonical Scene order. Update the Sections workspace to show grouped Scenes
  while retaining the existing tree. Use selectors/move controls first; drag-and-drop is optional.
- **11.4 — Scene Tag taxonomy and assignment.** Add Scene Tag schema/model, story-scoped optional
  tag association, hierarchical editor under **Configuration → Tags → Story Tags**, and per-Scene
  tag assignment on Details. Depend on taxonomy hardening tasks 12 and 13 below; do not copy the
  current stored-DOM, stale-option/count, insertion, touch, or keyboard behavior into a new tree.
- **11.5 — Modal JSON reliability for Element editing.** Make the shared modal flow submit JSON
  correctly, show 422 errors, handle loading/network failures, and remove rows and update counts
  reliably. This is a shared infrastructure slice with browser regressions for existing modal
  consumers; it must be complete before Scene Elements depend on it.
- **11.6 — Scene Elements and Dialogue speakers.** Add Scene Elements with the same transactional
  ordering guarantees as Scenes and the many-to-many speaker join. Implement Narration and Dialogue
  creation, editing, deletion, and accessible reordering in Bootstrap modals. A Dialogue may have
  many speakers but no turn structure; apply the minimum-speaker rule confirmed in 11.0, and Narration
  cannot retain speakers. Do not copy the taxonomy tree controller or assume
  `MaintainsSiblingPositions` supports a flat parentless sequence.
- **11.7 — Character presence and speaker coherence.** Add `SceneCharacter` with nullable free-text
  role, the Characters tab, scoped same-Universe validation, and a derived view of explicit
  participants plus Element speakers without duplicate rows. Keep speaker links and participant
  roles distinguishable.
- **11.8 — Item presence.** Add `SceneItem` with nullable free-text role, the Items tab, scoped
  same-Universe validation, and add/remove/role-edit behavior. Include duplicate-link and deletion
  tests.
- **11.9 — Location presence.** Add `SceneLocation` with nullable free-text role, the plural
  Locations tab, scoped same-Universe validation, and add/remove/role-edit behavior. Include
  duplicate-link and deletion tests.
- **11.10 — Continuity integration and reverse links.** Add “Appears in Scenes” links to relevant
  Character, Item, Location, and Event workspaces, always with Story context and authorization. Add
  analyzer-oriented query tests proving that multiple Scenes can reference one Event while Scene
  `position` remains narrative order. Coordinate any Story dashboard preview with backlog item 6
  rather than implementing that dashboard twice; this slice should not defer performance or privacy
  work on the links it adds.

#### Definition of done for every slice

- Include the full stack for the models introduced by that slice: scoped routes/controllers,
  views/helpers, navigation, authorization, empty/loading/error states, fixtures, model and request
  tests, and focused system tests for interaction behavior. Request tests cover the full
  public/private read-write-admin matrix; system tests cover representative UI and read-only paths
  rather than every viewport/access-level permutation.
- Keep routes nested under both Universe and Story, use `params.expect(...)`, pass all route keys
  by name, and load every record through the authorized Universe/Story/Scene associations. Register
  every new model in the policy registry and add/test Universe delegation or resolver support for
  records that reach their Universe through Scene.
- Validate same-story relationships in application code and same-Universe world references in
  application code; ordinary foreign keys cannot enforce those shared scopes. Unknown optional IDs
  must become documented 422/404 responses, not 500s.
- Add connected data for the models introduced by that slice to the relevant
  `db/data/<universe_slug>/` files, and update the shared loader order. At Epic completion, exercise
  a title-only empty Scene, ungrouped and Section-assigned Scenes, Event-only and datetime-only
  Scenes, deliberately independent Event/datetime values, multiple Scenes sharing one Event, a
  Narration without speakers, a Dialogue with many speakers, multiple Locations, and both blank and
  populated roles. Do not add isolated placeholder rows.
- Treat backlog item 1 as a hard prerequisite before final development-data/manual verification.
  Keep temporary Scene data out of production seed/deploy paths, and never run a destructive reset
  without approval.
- Update the matching architecture, data model, conventions, visual design, development, and ADR
  documentation in the same change. Replace the old copy that describes Scenes merely as an
  example of a Section, and move fixed shared-editor quirks from `known_quirks.md` to
  `resolved_quirks.md` rather than deleting their history.
- Preload Sections/tags and calculate Element/participant counts without N+1 queries and without
  double-counting derived speakers in every list-bearing slice. Keep the existing Story count-cache
  key collision from being copied into a second scalar metric.
- Run the smallest relevant tests while iterating, then the full relevant Rails/system/RuboCop
  checks for shared infrastructure; run `bin/brakeman --no-pager` at Epic completion and
  `bun run build:css` whenever SCSS changes. Report every check not run and provide the exact
  development login, scoped URL, load/rebuild command, and manual checks when handing off.

#### Explicit warnings and scope boundaries

- Do not collapse Event and Scene into one model or one-to-one relationship. Multiple Scenes can
  depict the same Event, including separately written viewpoint variants. The MVP stores no POV
  field, so do not claim that it can identify who perceived an Event; that is Future Work.
- The independent Event/datetime decision permits contradictory values. This version must not
  claim to detect or synchronize that contradiction; show both values with precise labels and add a
  consistency policy only as a later product decision.
- Free-text roles are useful annotations but weak analyzer input. Do not infer controlled semantics,
  causality, or knowledge from them until recurring values and rules are explicitly modeled.
- Many speakers attached to one free-text Dialogue block cannot answer “which exact line did this
  Character say?” Keep that limitation visible and do not market the MVP as structured dialogue.
- A Scene and its Elements are flat ordered sequences. Reusing a hierarchy concern that assumes
  `parent_id` can corrupt positions; maintain destroy, transaction, and concurrency behavior too.
- Do not copy the current modal submission, error, or delete weaknesses documented in
  `known_quirks.md`; new code would inherit known 406s, silent validation failures, and stale DOM.
  Complete the modal reliability slice before Elements depend on it.
- Do not use a `type` discriminator, default Scene Tags, or default/required generic presence links.
  Tags and world-presence links remain optional; the proposed one-or-more-speaker rule applies only
  after an author creates a Dialogue Element and must be confirmed in slice 11.0.
- Do not add a nested authorization adapter only in a view. SceneElement, speaker, and presence
  records must resolve their Universe through Scene in both Ability and shared helper paths, or
  writers may see missing controls and record-level checks may deny valid mutations.
- The recommended deletion contract is intentionally asymmetric: Scene/Story-owned records cascade,
  optional Section/Event references nullify, and shared Character/Item/Location deletion removes only
  join records. Never destroy a shared world record because a Scene referenced it.
- This epic creates machine-readable structure, not automatic continuity correctness. A Scene
  containing prose can still contradict other Scenes; the actual checker/analyzer is later work.

#### Out of scope for the first epic

Do not add a full manuscript/rich-text editor, turn-level dialogue, multiple Events per Scene,
overlapping Section memberships, a controlled role ontology, real-time collaboration, new Story
permissions, automatic chronology reconciliation, or AI analysis. Those require separate domain
decisions and should not delay the basic ordered Scene workflow.

12. **Eliminate taxonomy modal XSS and stale editor state**

    The current taxonomy editor has a documented stored-DOM XSS path and returns stale serialized
    parent/tag options and counts after CRUD. Escape text by construction (do not interpolate user
    names into `innerHTML`), refresh dependent descriptors and counts after every mutation, and add
    hostile-name and reopen-after-CRUD browser regressions. Move the resolved findings from
    `known_quirks.md` to `resolved_quirks.md`. This is a prerequisite for adding Scene Tags, not a
    Scene-specific cleanup.

13. **Make taxonomy tree insertion and reordering correct and accessible**

    Fix root insertion after a subtree, restore inline rename and keyboard semantics on newly
    created nodes, and provide touch and keyboard alternatives to hidden insertion/reorder controls.
    Cover boundary insertion, focus retention, Enter/Space behavior, and drag-free reordering with
    focused browser tests. Complete this before the Scene Tag editor reuses the taxonomy controller;
    an existing green desktop drag/drop test is not evidence that the interaction is usable.

## FUTURE WORK

- **Structured dialogue turns.** Replace or augment free-text Dialogue elements with ordered lines,
  speaker changes, parentheticals, and optional character attribution once the MVP reveals real usage.
- **Scene point-of-view/focus Character.** Record whose perspective presents a Scene separately from
  all Characters present, supporting same-Event/different-POV analysis without duplicating Event data.
- **Composite Scene-to-Event links.** If a Scene often contains several Events, introduce a scoped
  join model with roles/order rather than overloading the first version's optional single Event.
- **Narrative-order versus chronology comparison.** Visualize a Story's Scene sequence beside the
  Universe Timeline to expose flashbacks, parallel scenes, and unexplained order changes.
- **Structured Scene roles.** Analyze recurring free-text Character/Item/Location annotations before
  promoting useful values to controlled, analyzer-friendly role types.
- **Scene character-presence analyzer.** Use explicit participants and derived speakers to answer
  where a Character appears, with Story context and confidence/inference labels kept separate from
  author-entered facts.
- **Scene character-knowledge analyzer.** Track what a Character witnesses or is told in a Scene;
  this needs explicit attribution rules and should not be inferred from mere presence.
- **Scene causality and temporal analyzer.** Compare Scene order, linked Events, independent
  Scene datetimes, and Element chronology to explain likely contradictions rather than silently
  rewriting author data.
- **Scene prose-contradiction analyzer.** Analyze Element text for claims that conflict with Universe
  facts; this is a separate product from structured temporal/causal checks and should explain its
  evidence and uncertainty.
