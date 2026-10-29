# Story structures

A Story begins as an empty shell: its Sections and Scenes are created by hand, one at a time. This
feature offers a small set of **starting shapes** instead, so a writer can seed a Story's structure
and then rename, regroup, delete, or fill the records like any others. The shape is a template, not a
second kind of Story content.

The [story interchange](story_interchange.md) is a different subject: it defines the import and
backup directory layout, not a starting shape for one Story.

The templates are code-owned rather than stored records. `StoryStructureCatalog` is the single
catalogue, in the same spirit as [`TropeCatalog`](tropes.md#the-reference-catalogue): adding a
structure is a code change, no Universe owns a template, and no writer edits the shared list.
[ADR 0040](../adr/0040-story-structures-are-a-code-owned-starting-shape.md) owns the ownership
decision and the alternatives it rejected. The Story, Section, and Scene tables are unchanged; see
[the schema](../data_model.md#stories--sections).

## The catalogue

An entry has a stable slug, a name, a short description, and a list of acts. Each act has a name and
a list of beats. The catalogue ships two entries:

- **Three-Act Structure** — three acts and eight beats, from opening image through climax and
  resolution.
- **Hero's Journey** — departure, initiation, and return, with twelve beats.

Names and descriptions are I18n keys, not translated strings in the catalogue, because the picker
and the records it creates render in the request's language. Applying an entry stores the names and
beat guidance in the language active **at apply time**; after that they are ordinary author data and
do not change when the reader switches language.

## Applying a structure

An act becomes a `Section`; a beat becomes a `Scene` in that Section. The beat's description becomes
the Scene's starting `description`, so the applied record explains its purpose. That description is
guidance, not imported manuscript prose, and the writer may replace or clear it.

`StoryStructureApplier` performs the whole apply in one transaction:

- It locks the Story and re-checks that the Story has no live Sections or Scenes. A Story with only
  removed Sections and Scenes still counts as empty.
- It creates each Section and Scene through the ordinary model path and
  `PositionedResourceOrder`, so their validations and contiguous `(position, id)` sequences are the
  same ones a hand-created record gets. Sections receive positions `0..n`; Scenes receive the same
  in narrative order across the whole Story.
- A failure rolls the entire apply back, so a template can never leave half a structure behind.

The result is ordinary records with no special marker: the catalogue is not referenced by an applied
Section or Scene, so later edits cannot make the Story disagree with a template it carries.

### Why the Story must be empty

A template is a starting shape, not a shape merged into an existing one. Appending it to a Story that
already has structure would interleave two outlines with no stated order, so the Story page offers
the control only while `sections` and `scenes` are both empty, and the service checks again after
locking the Story.

### Why draft-based universes are excluded

A draft-based universe remembers a mutation as one `DraftChange` naming one record. A structure is
many creates, and each Scene names a Section whose id does not exist until the draft is applied, so
the batch cannot be represented as independent remembered changes. The first slice therefore refuses
the mutation in a draft-based universe instead of writing through the draft contract. The Story page
states the reason where the control would otherwise be; a direct universe is the only place a
structure can be applied.

## The apply route and its responses

| Purpose | Canonical URL | Response |
|---|---|---|
| Apply a structure | `POST /u/:universe_slug/s/:story_id/apply_structure` | HTML redirect |

The route is a member action on the Story, not a record route: there is no template row to create,
read, or delete. The form on Story Details posts `structure_slug` and follows the HTML
redirect/re-render contract: success redirects to the Story with a notice, and a refused apply
redirects to the same page with an alert.

Documented failures: an unknown slug is a `404`; a missing `structure_slug` is a `400`; a Story that
already has Sections or Scenes and a draft-based universe are both redirected with an alert and no
write; a guest is sent to sign in; a read-only member receives `403`. The mutation carries the
ordinary CSRF token, and the mutation budget counts the request once.

## What a structure never does

Applying a structure creates no Elements, dialogue, prose, tags, plots, photos, point of view,
in-world time, Events, Characters, Items, Locations, or Universe records. It cannot import manuscript
text or world facts. Every Section and Scene it creates is empty apart from its name and the beat's
guidance description.

Universe-owned templates and user-saved Story skeletons are deliberately deferred; the catalogue
decision above is the first slice. A beat is a Scene in this slice, not a note record or a Section.
