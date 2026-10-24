# Plot arcs

A Plot is a named, story-owned narrative through-line: for example, a mystery arc or a relationship
arc that recurs across the story. It is not a Section (which organizes the script hierarchy), a Scene
Tag (which classifies a Scene), or a Scene (which occupies one place in narrative order). The domain
decision is recorded in [ADR 0031](../adr/0031-story-owned-plot-arcs.md); the schema is in
[data_model.md](../data_model.md#stories--sections).

## Scope and assignment

`Plot belongs_to :story` and has a required name, optional description, story-local slug, and soft
delete. A Story may own any number of plots, and each Plot may link to any number of Scenes from that
same Story. The many-to-many assignment is an independent grouping axis: a Scene may have multiple
Plots, a Plot may cross Sections, and neither association changes `Scene.position` or `section_id`.
Plots have no parent hierarchy or user-controlled ordering.

Both association writers validate unknown, duplicate, and cross-Story assignments before a join row
can be written. The development-data loader checks every referenced Plot as well. These are
application-level scope rules; the database join table has foreign keys and a unique pair index, but
cannot prove that two records share a Story.

## Workspace and editing

The Plot workspace is `/u/:universe_slug/s/:story_id/plots`, with a read-only details page at
`.../plots/:id`. It uses the flat list + modal pattern: a writer can create, edit, or soft-delete a
Plot from the list, and its Details page lists assigned Scenes in narrative order. The Scene's
existing full-page editor assigns zero or more Plots; it also links back to the Plot workspace when
none exist. The story sidebar and story workspace tabs expose Sections, Plots, and Scenes as separate
destinations.

Index and Details are guest-readable. Create, update, and delete are JSON-only mutations through the
shared modal contract; an existing draft-based universe remembers those writes in the usual way.
Deleting a Plot removes it from ordinary reads and the search index but retains its Scene join rows,
so restoring it restores the assignments. Scenes are never removed or reordered by Plot deletion.

Plot is searchable by its name and description, and search results open its story-scoped details page.
