# Prose mentions

A **mention** is a Character's name or alias written inside a Scene Element's body. It is not an
appearance: presence is only ever an explicit `SceneCharacter` link or a Dialogue speaker, exactly as
[Scenes](scenes.md#elements) defines those two sources. The mention index reads prose and suggests a
Character; it never writes a presence link, never changes a Scene's Characters tab, and never adds a
row to `SceneAppearances` or `SceneParticipants`.

The index is **read-time and unstored**. A mention is a fact the prose already contains, so there is
no table to migrate, invalidate, or repair when an Element is edited. `MentionIndex`
(`app/models/mention_index.rb`) matches a body against registered names, and `StoryMentions`
(`app/models/story_mentions.rb`) is the Story-scoped read built on it. Both read live records through
the ordinary default scopes, so a soft-deleted Scene, Element, or Character contributes nothing.

## What counts as a name

`MentionIndex.for(story)` takes the Characters of that Story's own Universe. A Character contributes
its `name` and every alias in its `aliases` field, split on commas and newlines and trimmed. The
matching rules are part of the contract:

- **Case-insensitive, otherwise exact.** The author's accents and punctuation decide what is a name,
  so `Sméagol` does not match `Smeagol`.
- **Word boundaries only.** `Ann` does not match `Anna`, and `Jon` does not match `Jonas`.
- **The longest candidate wins.** An alias that starts with the bare name is still one mention, and
  `Jon Snow` is preferred over `Jon` at the same position.
- **A shared spelling is ambiguous.** A name or alias used by two Characters is left out entirely
  rather than attributed to whichever record the query returned first. Distinct names still work.
- **An empty body has no matches**, and an empty Universe produces an index that matches nothing.

`aliases` is free text. The parser is deliberately the same comma/newline convention the Character
form documents in [Characters](characters.md#profile); it does not interpret quotes, initials, or
punctuation as separate names.

## The two reads

`StoryMentions.for(story)` loads the Story's Scenes and Elements once and answers:

- `entries_for(character)` — the Scenes where the Character is named, in narrative order, each with
  the Elements that named them, the spellings used, and a count.
- `mentioned_in?(character, scene)` — the cheap set test a grid uses instead of building an entry per
  cell.
- `mentions_in(scene)` — every mention in one Scene, in Element order and then reading order, which is
  what in-place highlighting reads.

A Scene with several Elements is one entry, so a Character named twice in one Scene is one suggestion
with two mention rows, not two Scenes. The grouping is always by the Scene's `position`, never by an
in-world datetime or a Section.

## Surfaces

### Character details

The Character page shows **Mentioned in prose of &lt;Story&gt;** directly below **Appears in scenes of
&lt;Story&gt;**. It lists only the Scenes where the name is written and the Character is **not**
recorded as present; a mention in a Scene that already appears above is the same fact twice and is
left to the appearances section. Each row names the Scene, its narrative position, the Elements that
contain the name, the spelling used when it is an alias (**Written as The Fox**), and the badge
**Not recorded as present**. The section is read-only for every access level and, without a current
Story, asks the reader to select one rather than falling back to the Universe's first Story.

This is the **mention timeline**: the rows are the Character's mentions in telling order, which is
what answers where a name appears and where it drops out.

### Scene Details

Element bodies on Scene Details link every recognized name to its Character. A name the Scene records
as present is a solid hairline underline; a name it does not record is a **suggestion**, drawn with a
dashed underline and carrying a screen-reader-only note **not recorded as present**. The distinction
is a line pattern, not a hue, so it survives light, dark, and a monochrome print. The painted classes
are in [visual_design.md](../visual_design.md#scene-workspace).

The presence set is the same union the Characters tab shows — an explicit link or a Dialogue speaker
— and it only chooses the style. It never decides whether a name is a mention.

### Printable export

The manuscript marks the same names in an Element's printed prose, so a reader of the book sees the
Character link the workspace shows. The book's links inherit the prose colour rather than the page's
link blue, because the printed page is still the manuscript. Only `Element#body` is scanned; a
Dialogue's line-level turns are attributed speech and are not the prose body.

### The mention layer in the grid

The Story-wide grid draws a mention as a dashed mark in its own layer, beside recorded presence and
never merged with it. Its rows, columns, and read-only contract are in
[Appearances](appearances.md).

## Code and tests

- `app/models/mention_index.rb`, `app/models/story_mentions.rb`
- `app/helpers/mentions_helper.rb`, `app/views/characters/_mentions.html.erb`
- `app/views/scenes/_elements.html.erb`, `app/views/story_manuscripts/_scene.html.erb`
- `test/models/mention_index_test.rb`, `test/models/story_mentions_test.rb`
- `test/helpers/mentions_helper_test.rb`, `test/controllers/character_mentions_test.rb`,
  `test/controllers/scene_mentions_test.rb`
