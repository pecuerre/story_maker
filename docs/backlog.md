SHARED BACKLOG
==============

This is the one place for pending work, rough ideas, and things we may want
to do in the future. The owner can append ideas without worrying about format.

How AI assistants should use this file
--------------------------------------
When you notice another worthwhile improvement while working on a task, ask
the owner whether to do it NOW, LATER, or NEVER.

- NOW: do the extra work as part of the current task, then remove or mark the
  item as completed.
- LATER: add it under FUTURE WORK below.
- NEVER: do not implement it and do not add it to this file.

Do not silently expand the current task. Keep this file focused on work that is
still pending.

PENDING WORK
------------
(A) add "fixed" attribute to all _tags models (the fixed ones should not be
editable or deletable)

(A) marks a note written by the project owner. Later items may be rough notes
too; clarity is helpful, but formatting is not required.

FUTURE WORK
-----------

### Contextual inspector / right-side utility panel

The right utility sidebar now reserves a stable home for future collaboration, analytics, and AI
tools. Replace its temporary `aria-disabled` links with a real contextual inspector as the
underlying product areas become concrete. The inspector should show information relevant to the
current page: selected entity details, related records, taxonomy usage, filters, or quick actions.
It remains a Bootstrap `offcanvas-end` below `xl` and can be hidden when there is nothing useful
to show. Candidate data includes selected-character relations/ownerships, relation-tag usage
counts, and story outline progress.

### Search, filtering, and sorting for large lists

Add client- or server-backed search/filter/sort controls to Characters, Locations, Events, Items,
Relations, Ownerships, and taxonomy trees. Preserve universe/story scope, make filters removable
and visible in the URL where practical, and define behavior for empty results separately from an
empty database. Start with the fields already exposed by each model; do not add opaque global
search before the scoped lists are usable at scale.

### Richer relationship and entity rows

Make list rows more useful for scanning large universes. Relations should render as a readable
sentence such as `Ariadne — is friend to → Lysander`, with direction and dates as metadata.
Characters could show relation/ownership counts, locations could show parent/child context, events
could show date range and related events, and items could show current/historical owners. Add
these as derived presentation data where possible; avoid duplicating source fields in the UI.

### Story overview dashboard

Turn the current Story overview into a compact working dashboard: story description, section
count, section-tree preview, recently edited sections, quick “Add section” action, and links into
the relevant Universe Bible records. This should remain lightweight until the underlying section
and appearance/usage data are available.

### Universe summary cards

Make the Universes index useful for choosing a workspace. Add story and entity counts, visibility,
recent activity, and a clear “Open universe” action. Consider eager-loading/caching the summary
counts so the index does not issue one count query per universe. Keep the existing authorization
and visibility rules in mind before exposing any summary data.

### Global search / command palette

After scoped search is solid, add a global command palette for switching universes/stories and
jumping to Characters, Locations, Events, Sections, or the Timeline. It must respect the current
universe/story scope and should be keyboard accessible. This is a navigation enhancement, not a
replacement for scoped list filters.

### Story-planning and world-building tools

The sidebar now reserves a Scenes entry in the Story workspace. Revisit it and other ideas such
as Plot, Tropes, Routes, Map, Distances, Meetings, and Dialogs only with a concrete domain
decision: define what each record means, which scope owns it, how it appears in the current
page patterns, and whether it is worth adding to the data model. Replace the reserved link when
the feature has a real destination.

### Collaboration and universe analysis

The right sidebar now reserves temporary links for Tracking, Analyzer, Collaboration, Graphs,
Analytics, and AI tools. These remain future product areas. Before replacing the placeholders
with navigation, specify the underlying records and permissions: inconsistency detection,
incomplete/undefined records, collaborators, submissions, changes/forks, graphs, analytics, and
drafts. A feature should appear as a live navigation item when it has a useful destination and
clear empty/loading/error states.
