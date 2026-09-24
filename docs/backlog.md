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

The sidebar now reserves a Scenes entry in the Story workspace. Revisit it and other ideas such
as Plot, Tropes, Routes, Map, Distances, Meetings, and Dialogs only with a concrete domain
decision: define what each record means, which scope owns it, how it appears in the current
page patterns, and whether it is worth adding to the data model. Replace the reserved link when
the feature has a real destination.

10. **Collaboration and universe analysis**

Universe-level access management is implemented: public/private visibility and read/write/admin
memberships are available from the universe workspace. The right sidebar still reserves temporary
links for Tracking, Analyzer, richer Collaboration, Graphs, Analytics, and AI tools. Those remain
future product areas. Before replacing the placeholders with navigation, specify the underlying
records and permissions: inconsistency detection, incomplete/undefined records, submissions,
changes/forks, graphs, analytics, and drafts. A feature should appear as a live navigation item when
it has a useful destination and clear empty/loading/error states.

11. **Adding Scenes to a Story**

- a story is a sequence of scene. one after the other
- events are chronological, but scenes don't have to be. the scenes define in which order the story will be told, not the orden things happen
- let's add a new model call SceneTag. similar to SectionTag.
- include the SceneTag editor inside Configuration > Tags > Story Tags
- one scene happens in a location, at some moment (event), involve some characters and/or some items.
- a scene have a name(or title) and a description
- a scene is a sequence (of at least one) dialog, description or narration
- visually, when i am editing a scene i see multiple tabs
  - tab 1 (Scene details)
    - the title
    - the short description
    - when it happened (for now just a datetime that can be null, we will expand on that later)
    - and then a list like
        - dialog
        - narration
        - dialog
        - description
        - another dialog
        - another narration
      - i should be able to change the order of those (let's call scene elements)
      - i should be able to add new scene elemnts
      - for now each scene element would only contain
        - a title
        - a type (narration, description, dialog)
        - a description
      - those scene element details should be edited in a bootstrap modal dialog like we do in other parts of the project
  - tab 2 (Characters)
    - empty for now
  - tab 3 (Items)
    - empty for now
  - tab 4 (Location)
    - empty for now