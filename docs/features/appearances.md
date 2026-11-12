# Appearance grid

The Appearance grid shows one whole Story at once: every Character with a row, every Scene with a
column in narrative order, and two layers that are never merged. It is **read-only** and has no stored
result. The page is at
`GET /u/:universe_slug/s/:story_id/appearances` (`AppearancesController#show`), reached from the
**Appearances** entry in the Story analytics block of the left sidebar and the **Open appearance
grid** button on the Story overview's scenes-per-character card.

The prose layer is produced by [Prose mentions](mentions.md) and the presence layer by the same union
[Scenes](scenes.md#participation-is-a-union-never-a-sum) uses everywhere else. This page combines
them for display; it does not create a third source.

The Story overview draws the same presence union the other way round, as a scenes-per-character
chart; it is described [below](#the-scenes-per-character-chart).

## The grid

- **Columns** are the Story's Scenes in `(position, id)` order. The column header shows the 1-based
  narrative position and links to Scene Details.
- **Rows** are the Characters this Story records as present somewhere or names in prose somewhere,
  ordered by name. A Character with neither is left out: a Universe holds records the Story never
  uses, and a grid of blank rows would bury the cast that matters.
- **Rows are read from the whole Story**, not from one Section or one filtered list. The grid has no
  filter, sort, or pagination; a narrowed grid would no longer be the Story at once.
- **Cells** carry two independent answers. A Character can be recorded present in a Scene, named in
  its prose, both, or neither. `AppearanceGrid#state_for` names the four states; the view draws two
  marks for `both` rather than one merged mark.

A row exists for a mention-only Character because the grid's second layer is a real suggestion even
when the first layer is empty. That is also why a mention can never make a cell count as an
appearance: `AppearanceGrid#appears?` reads only the presence union, and no code path writes a
`SceneCharacter` row.

## The two layers

**Recorded presence** is the union `SceneParticipants` owns: an explicit `SceneCharacter` link and a
Dialogue speaker (a line-level turn). It is the same union the Characters tab and
`SceneAppearances` already report. An Event reference is a source for an Event's appearances, not for
a Character row, so it does not appear in this grid.

**Prose mention** is `StoryMentions`: a registered Character name or alias written in an Element
body. Names, aliases, matching, ambiguity, and Story scope are all
[Prose mentions](mentions.md). The grid asks only `mentioned_in?(character, scene)`.

The legend states the distinction in the reader's language: a solid mark is a recorded appearance,
and a dashed outline is a prose mention, which **is not an appearance**.

## The scenes-per-character chart

The Story overview (`GET /u/:universe_slug/s/:story_id`, `StoriesController#show`) carries the other
Story-wide appearance read: one bar per Character recorded present in at least one of the Story's live
Scenes, scaled to the Story's whole Scene count. It is read-only and has no record, no route of its
own, and no stored result.

- **The count is the presence union, never a sum.** `CharacterSceneCounts` reads
  `SceneParticipants.character_ids_by_scene`, so an explicit `SceneCharacter` link and a Dialogue
  speaker are one appearance when both name the same Character in one Scene. A Character with no
  recorded presence in the Story is left out rather than printed as a zero, and only the Story's live
  Scenes count.
- **An Event reference and a prose mention do not add a Character.** An Event is a source for an
  Event's appearances, not a Character's, and a mention is a suggestion. The chart reads stored
  participation only and never scans prose, so the grid's mention layer has no counterpart here.
- **The denominator is the whole Story.** Bars are measured against every live Scene, including
  Scenes in which nobody appears, so a bar answers how much of this Story a Character carries rather
  than how the Characters compare with each other. The table states the same share as a percentage.
- **Order is appearances, then name.** The same name tie-break the grid uses orders the rows, so the
  same Story renders the same chart on every request.
- **The table is the equivalent.** The chart is a server-rendered SVG inside a focusable scroll
  region, and every bar links to its Character. A native disclosure beneath it holds a real table of
  the Character, the count, and the share, so a keyboard or screen-reader reader is not asked to
  decode the bars. The page has no JavaScript.
- **Two empty states are separate.** A Story with no Scenes says **No scenes yet**, and only a writer
  is offered the Scenes workspace; a Story whose Scenes record no Character says **No characters
  appear in &lt;Story&gt; yet**.

Access follows the Story page: [the grid's access rule](#access-and-response) applies unchanged,
because the chart is another read on the same Story.

## Access and response

The grid is a `show` on the Story, so it follows the Story page's rule: a guest may read a public
universe, a private universe needs its owner or a member, and another universe's Story is a `404`.
There is no sign-in requirement of its own, because a grid is a read. There is no mutation route, no
form, no CSRF surface, and no JavaScript.

Two empty states are separate: a Story with no Scenes says **No scenes yet**, and a Story whose
Scenes neither record nor name any Character says **No characters appear or are mentioned in
&lt;Story&gt; yet**. The second state names the Story because a Character is a Universe record and
the grid is only one Story's view of it.

## Accessibility and print

The table is the accessible equivalent, not an image or a CSS-only grid. It has a caption, `<th
scope="col">` Scene headers, `<th scope="row">` Character headers, and one visually hidden state
label per cell. The scroll container is a focusable `role="region"` with an accessible name, so a
keyboard user can scroll a wide Story without the page moving.

The marks do not rely on hue: recorded presence is a filled square, and a mention is a dashed outline.
Both survive light mode, dark mode, and a monochrome print, where the print stylesheet makes the
filled mark solid black and removes the sticky offsets. Column headers stay visible while the row
headers stick to the left edge during horizontal scrolling. The painted rules are in
[visual_design.md](../visual_design.md#appearance-grid).

## Code, styles, and tests

- `app/models/appearance_grid.rb`, `app/models/character_scene_counts.rb`,
  `app/helpers/story_workspace_helper.rb`
- `app/controllers/appearances_controller.rb`, `app/views/appearances/show.html.erb`
- `app/controllers/stories_controller.rb`, `app/views/stories/_character_scene_chart.html.erb`
- `app/assets/stylesheets/_appearance_grid.scss`, `app/assets/stylesheets/_character_scene_chart.scss`
- `test/models/appearance_grid_test.rb`, `test/models/character_scene_counts_test.rb`,
  `test/controllers/appearances_controller_test.rb`, `test/controllers/stories_controller_test.rb`
