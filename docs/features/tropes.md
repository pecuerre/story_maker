# Tropes

Tropes are a small, app-wide reference list for recognizing and discussing storytelling patterns.
They are not another Scene Tag taxonomy: the same reference is available to every Story and Scene,
and a saved assignment records a writer's detection or annotation rather than changing the shared
definition.

## The reference catalogue

`TropeCatalog` is a curated code-owned list of ten proof-of-concept entries. Each entry has a stable
slug, display name, original short description and craft note, and a source-page URL. The current
source references are TV Tropes. The app links to the source and its stated CC BY-NC-SA 3.0 terms;
the summaries and craft notes are original Universe Maker copy, not copied or scraped site text.
Adding or changing a reference is a code change; writers do not edit the shared catalogue in the
workspace. The ten entries are examples, not an exhaustive catalogue or a universal judgment that a
trope is good or bad.

The list intentionally includes both frequently criticized patterns and commonly useful devices.
Its craft notes describe risks or possible strengths without assigning an intrinsic quality score:
the same trope can work differently in different contexts.

## Story and Scene assignments

A writer may annotate a trope at either or both levels:

- `StoryTrope` records that a trope has been noticed or is relevant to the Story as a whole.
- `SceneTrope` records a detection in one Scene. It does not create a Story-level assignment, and a
  Story-level annotation does not imply that every Scene contains the trope.

Each assignment stores the stable catalogue slug and an optional, plain-text context note. The note
is where a writer can explain how the trope is used in this particular Story or Scene, including
whether the use is effective or a pattern to avoid. There is no global good/bad flag and no AI
detection or source import in this version; assignments are manual author decisions.

The Story editor and Scene editor each show the same ten references, their short descriptions, craft
notes, and source links. The Story Details page and Scene Details page show only their saved
assignments and context notes. These pages follow the existing HTML redirect/re-render contract and
the containing Story/Scene's Universe authorization. In a draft-based Universe, the containing
Story or Scene mutation is remembered and the annotation is not live until that draft is applied.
The draft page summarizes the selected catalogue entries and their context notes instead of exposing
the nested form payload. Guests and read-only members can read the references and assignments but do
not see editing controls.

Assignments are retained when a Story or Scene is soft-deleted, so restoring the parent restores its
annotations. Hard deletion removes the assignment rows with their owner. A duplicate catalogue slug
cannot be assigned twice at one level; the model and unique database index enforce that rule.

The tables and foreign keys are listed in [data_model.md](../data_model.md#stories--sections). The
per-universe example assignments are in `db/data/<universe_slug>/story_tropes.yml` and
`scene_tropes.yml`, loaded after their owning records by the development registry.
