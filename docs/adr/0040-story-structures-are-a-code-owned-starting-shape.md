# ADR 0040: Story structures are a code-owned starting shape

- **Status:** Accepted
- **Date:** 2026-10-28
- **Related:** [Universe and Story scope](0001-universe-and-story-scope.md), [Disposable schema](0003-disposable-schema-and-seed-data.md), [Transactional position maintenance](0009-transactional-position-maintenance.md), [Curated trope references](0032-curated-tropes-are-contextual-annotations.md), [Story structures](../features/story_structures.md), [Data model](../data_model.md)

## Context

Sections and Scenes were created only by hand, so a new Story offered no starting shape. The domain
questions had to be answered before a record existed: whether a template belongs to the code, a
Universe, or an author's saved Story skeleton, and whether a beat is a Section, a Scene, or a note on
one. The feature must also stay clear of manuscript prose and Universe facts, and it must respect the
existing draft contract and the transactional position service.

## Decision

- Keep the structures in a small, code-owned `StoryStructureCatalog`, in the same spirit as
  `TropeCatalog`. Adding or changing an entry is a code and translation change; no template table,
  editor, or Universe setting is introduced.
- Each entry is a list of acts, and each act is a list of beats. An **act becomes a Section** and a
  **beat becomes a Scene** in that Section. The beat's guidance becomes the Scene's starting
  description. There is no note record and no beat as a Section.
- Apply an entry only to a Story with no live Sections or Scenes. The apply locks the Story,
  re-checks the emptiness, and creates every record through `PositionedResourceOrder` inside one
  transaction, so validation, positions, and rollback are the ordinary mutation path's answers.
- Store no template slug or foreign key on the created records. The result is ordinary author-owned
  content that can be renamed, regrouped, or deleted without leaving a template relationship behind.
- Refuse the apply in a draft-based Universe. A template is many creates whose Scenes name Sections
  that do not yet exist; a remembered change names one record, so the batch has no honest draft
  representation in this slice.
- Render the control on Story Details only for an empty Story in a direct Universe, with the
  catalogue's acts and beats available as a preview.

## Consequences

- The catalogue needs no migration, policy, search kind, or workspace. A new entry costs catalogue
  data and two locale entries per label and description.
- The applied shape is a one-time starting point. Changing a catalogue entry never rewrites a Story
  that used it, and there is no merge or re-apply operation.
- A draft-based Universe cannot use the feature until a later decision gives a batch of linked creates
  a draft representation; the page states that restriction rather than hiding the feature silently.
- Universe-owned templates and a user-saved Story skeleton remain separate future decisions. If one
  is accepted, this ADR is not edited; a new ADR supersedes the ownership choice.

## Alternatives considered

- **Universe-owned template records.** A new model, table, controller, views, authorization, and
  tests would be needed before any template could be applied, and each Universe would maintain its
  own list. Rejected for the first slice.
- **User-saved Story skeletons.** Saving an existing Story's Section/Scene shape needs a template
  record and a copying policy for names, descriptions, tags, and records that are not part of the
  shape. Rejected for the first slice.
- **Beats as Sections or as notes.** Sections already organize a hierarchy, and Scenes already carry
  narrative order, which is the sequence a beat sheet is for. A note record would add a new surface
  that does not participate in the Scene sequence.
- **Remember the apply in a draft.** A remembered change names one record, and each Scene's Section
  does not exist until the draft is applied. Rejected as unrepresentable rather than silently writing
  through the draft contract.
