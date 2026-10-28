# SHARED BACKLOG

This is the one place for **pending** work, rough ideas, and things we may want
to do in the future. The owner can append ideas without worrying about format.

## How finished work leaves this file

This file follows the same discipline as [known_quirks.md](known_quirks.md), where a fixed
finding is no longer an open item. When work is finished it does not stay here as a
"completed" paragraph. In the same change that delivers it:

1. add or update the dated entry in [`../CHANGELOG.md`](../CHANGELOG.md), then
2. delete the item from this file.

The changelog is the durable record of delivered work, so nothing else has to track it
here. Do not archive finished items under a separate heading, and do not leave a
completion summary behind.

## How AI assistants should use this file

When you notice another worthwhile improvement while working on a task, ask
the owner whether to do it NOW, LATER, or NEVER.

- NOW: do the extra work as part of the current task, then update the changelog and
  remove the item.
- LATER: add it under FUTURE WORK below.
- NEVER: do not implement it and do not add it to this file.

Do not silently expand the current task. Keep this file focused on work that is
still pending.

## PENDING WORK

Items are numbered and the numbers are stable: a finished item is deleted without
renumbering, so the remaining numbers are left as they are and a number is never reused or
made to mean a different idea.

Because a number disappears from this file when its item is completed, **do not cite a backlog
number from another document**. Reference a pending idea by its heading text, and cite delivered
work through the matching document in `docs/` or its dated `CHANGELOG.md` entry.

These items are deliberately **LATER** by default. Use the owner's **NOW / LATER / NEVER** decision
before expanding a feature task; the DataFactor report is directional evidence, not an automatic
work order.

The highest number this file has used is 67. The list below keeps the numbers it already had and never
reuses one. It was triaged on 2026-10-25: two Scene ideas had already been delivered and left the
list, the rest became numbered items, and each item records what exists today and what its next step
depends on. The competitor survey on 2026-10-27 turned the four `check <site>` notes into items
49–60; that day's second triage turned the five loose notes into items 61–67 and folded prose
highlighting into the mention index. Loose notes still belong under FUTURE WORK until they are
triaged into this list.

38. **Universe URLs as subdomains instead of `/u/<universe_slug>`.**

   NOTE: Wait until deployment

   Serve a universe at `<universe_slug>.<host>` rather than under a path. **Needs an ADR before any
   code**, because the blast radius is the whole request boundary: `config.hosts` and `APP_HOST`
   name one host today, mailer `default_url_options` is static, the session cookie and the
   remembered destination are host-sensitive, CSRF and cross-subdomain navigation must keep working,
   and every route helper, test, and demo URL changes. Deployment also needs wildcard DNS and a
   wildcard TLS certificate. Keep `/u/...` redirecting to the new host so existing links and the
   smoke test survive, and keep the browser-owned start page working before a universe is chosen.

41. **Structured Scene roles from free-text annotations.**

   `SceneCharacter`, `SceneItem`, and `SceneLocation` carry a free-text `role` that is never checked
   against a vocabulary. **Blocked on evidence:** analyze existing annotations first, then promote
   only recurring values to controlled role types. That needs a scope (Universe or Story) and a
   migration decision; until then the free text is correct behavior, not debt.

42. **Scene character-knowledge analyzer.**

   NOTE: Wait until the story is more advanced

   Character knowledge records exist and are entered by hand; a Scene is not attributed as the place
   or occasion where something was learned. **Needs explicit attribution rules** — witnessed, told,
   or inferred — before storing anything. Presence must not imply knowledge, so this is a design
   decision before it is a query.

43. **Scene causality and temporal analyzer.**

   NOTE: Wait until the story is more advanced

   **Needs a design and a definition of evidence.** Compare Scene order, linked Events, independent
   Scene datetimes, and Element chronology to explain likely contradictions rather than resolve
   them. Related to the delivered
   [narrative/chronology comparison](features/scenes.md#narrative-order-beside-the-timeline), but it
   reports causes and uncertainty and is a separate analysis; nothing should be rewritten silently.

44. **Scene prose-contradiction analyzer.**

   NOTE: Wait until the story is more advanced

   Analyze Element prose for claims that conflict with recorded Universe facts. **Largest and least
   defined:** it needs a text-analysis layer (likely an external model), an evidence/citation
   surface, and a privacy decision about sending story prose out. Keep it separate from the
   structured checks above and do not start it before them.

45. **Timeline pan/zoom.**

   `timeline_controller.js` only draws edges between nodes; the pan/zoom the early docs described
   was never built, and the docs were corrected on 2026-09-29 to say so. **Needs UI design, not a
   defect fix:** a draggable/zoomable viewport changes how layer markers and node circles read,
   needs a keyboard and touch path, and the SVG edges must stay aligned under the transform. Worth
   doing only when a universe's event count makes the wrapped layout genuinely hard to read.

48. **The deployment-secret permissions test can pass with no assertions.**

   NOTE: Wait until deployment

   The 2026-10-25 suite reports "Test is missing assertions" for
   `test/deployment/deployment_secrets_test.rb:52`: it skips each key file that is absent, so a
   checkout with neither file runs no assertion at all. **Can be done now:** `skip` with a named
   reason when there is nothing to inspect, or assert the expected presence/absence explicitly. This
   was noticed during the triage, not carried from the old notes.

49. **Continuity findings inbox with cited evidence.**

   NOTE: Wait until the story is more advanced

   The analyzers in items 42–44 are specified as analyses but not as a place their results live: the
   only continuity report today is the read-only narrative comparison, whose one conflict type is
   drawn inline on its own tab. `PlotLens` and `Novilot` both show a finding as a questionable passage
   beside the exact line it conflicts with, with a status the author chooses — open, held for review,
   not an issue — and that shape is what makes a report trustworthy rather than a verdict. **Needs a
   design before any analyzer:** a Story- and Universe-scoped finding record carrying the quoted
   evidence and its source, a status lifecycle, and an inbox page, with a dismissal recorded rather
   than the finding deleted. It is the surface items 42–44 write into, so it should land before them,
   and it must never rewrite prose.

51. **Prose mention index and mention timeline.**

   Presence is an explicit link: a Character in a Scene appears only when somebody recorded it, and a
   name written inside an Element's body is invisible to every list, count, and the export's notes.
   Characters now carry aliases, but only list search reads them. `Novelcrafter`'s Mentions and mention
   timeline answer where a name appears, comes and goes, and is overused; its character detection is
   the same read. **Can be done without a model:** index Element bodies for registered names and
   aliases, present mentions as suggestions separate from presence so an unlinked name never becomes
   a fact, and show a record's mentions beside "appears in scenes". Highlighting a recognized name
   in prose is the first surface of that same index rather than a separate feature: Scene Details
   and the printable export mark the name and open the record, while an unlinked name stays a
   suggestion. It also supplies the mention layer the appearance heatmap needs.

52. **Scene planning board and matrix.**

   Scenes are ordered in a list inside a Section tree, and the Story page shows structure as text;
   there is no board or spreadsheet surface. `Novelcrafter`'s Grid drags Section columns and Scene
   cards, its Matrix is one row per Scene against attributes, and `Sudowrite`'s Canvas is a freeform
   board. **Needs UI design and a decision about writes:** a board that only reorders must reuse the
   existing sibling-position transaction, a card that edits a field must be a draft change like every
   other mutation, and the matrix must not become a second editor with its own validation. Worth
   doing when a long Story makes the list hard to scan; a structural gap is cheaper to see here than
   in prose.

53. **Story structure templates and beat sheets.**

   Sections and Scenes are created by hand, one at a time; nothing seeds a shape. `Novelcrafter` ships
   novel templates and a 12-act structure, `Novilot` offers beat-sheet templates, and `Sudowrite` walks
   from idea to outline to chapters. **Needs a decision on ownership:** whether a template is shipped
   data, a Universe record, or a user-saved Story skeleton, and whether a beat is a Section, a Scene,
   or a note on one. The safe first slice applies a template that creates empty Sections and Scenes
   through the ordinary mutation path, so a template can never import prose or facts.

54. **Scene status labels and archive.**

   A Scene has a soft delete and a word count but no state between "exists" and "removed": nothing
   says draft, revised, or final. `Novelcrafter` offers custom Scene labels and a Scene archive for
   scenes pulled from the manuscript without being deleted. **Needs a vocabulary and a filter:** a
   small fixed set of statuses, shown as a badge on the row and details page, offered by the Scene
   filter under the existing list-filter contract, and with the export deciding explicitly whether
   non-final scenes print. Custom labels per Story are a later decision, not the first move.

55. **Word-count goals and progress.**

   `WordCounts` already totals Element prose per Scene, Section, and Story, and the pages state it, but
   there is no target, deadline, or per-session progress. `Novilot` sells word goals and sprints, and
   `Novelcrafter` a marker timeline of scene lengths. **Needs a scope decision:** a goal per Story is
   the obvious start, while a per-user-per-universe goal crosses into preferences and needs the
   timezone-day boundary the app already has to define. The first slice is a target on the Story page
   with a progress bar that reads `WordCounts` rather than storing a count.

56. **Scene tension and pacing curve.**

   The narrative-order tab compares a Scene's own time with its Event and reports conflicts; nothing
   measures how a Story reads. `Novilot` visualizes tension and pacing with genre-aware feedback, and
   `Sudowrite` sells pacing through expansion. **Needs a rating before a chart:** a Scene-level tension
   value on a small worded scale rather than a free number, entered in the Scene form, then a curve on
   the Story page or the narrative tab whose points are Scenes in narrative order. Feedback text is a
   separate and much later decision, and the chart needs a table equivalent for keyboard and screen
   readers.

57. **Manuscript import into Scene Elements.**

   Export exists in one direction only: printable HTML assembled from stored Elements. `Novelcrafter`
   imports Word, Markdown, and HTML, and `Novilot` imports a whole manuscript; this app cannot take
   one. **Needs mapping rules and a preview:** which headings become Sections and Scenes, how
   paragraphs split into narration, and what happens to dialogue the importer cannot attribute. It
   also has to run as draft changes rather than direct writes, following the remember-then-apply path,
   and must never merge a second import into existing Scenes without an explicit author choice.

58. **Per-record change timeline.**

   Closed drafts already record every change and the universe history page groups them by day, but the
   only way to ask what happened to one Character or Scene is to read the whole history.
   `Novelcrafter` offers per-document revision history and restore. **Can be derived, not stored
   again:** the changes and their outcomes are in the draft tables, so a details-page tab can list the
   closed drafts naming this record. It needs an access decision first, because the universe history
   is admin-only while a record page is readable by guests and read-only members, and it names the
   authors of changes.

59. **Authored progressions beyond ownership and knowledge.**

   Time-varying facts exist in three places — `CharacterKnowledge` changes, item `Ownership` rows with
   dates, and Event-linked Scene presence — and the rest of a record's profile is one present-tense
   answer. `Novelcrafter` generalizes this as Codex progressions, so a title, allegiance, or
   appearance can differ by chapter. **Needs a model decision:** whether a progression is a new
   Event-linked fact row or a dated profile answer, and whether it is Universe- or Story-scoped; it
   must not duplicate ownership or knowledge. Start only after something can read the existing three,
   or the new rows become another source nobody checks.

60. **Universe backup archive.**

   The printable export covers a Story's prose and appendices, not the Universe's data: photos, tags,
   routes, plots, tropes, memberships, and change history have no download. `Novilot` pushes
   manuscripts, Story Bible, and outline packages to Dropbox or a private GitHub repository as a
   safety net. **Needs a format and a gate:** the loader already validates YAML manifests, so an
   admin-only archive in the story-structure layout is the obvious first slice, and restore is a
   separate, destructive, approval-required command that must not reuse the demo reset path. Backup
   first, restore in a second change.

61. **Story-structure interchange layout.**

   The tcs repository already holds a universe as directories of Markdown with YAML frontmatter —
   `story/characters/`, `story/factions/`, `story/locations/`, `story/tech/`, `story/plots/`, and
   `story/chapters/` — while this app has no format it can read or write. Define one layout and a
   validator: a manifest naming the universe and its stories, one directory per record type,
   frontmatter for every field that is not prose, a body whose sections map to the profile answers,
   `[[slug]]` and `[[rule:ID]]` references, and a `canon/` home for rules. It is the contract the
   importer reads and the universe backup writes, not a second storage format: the database stays the
   source of truth. **Needs decisions:** how closely the layout follows tcs's own directories, which
   frontmatter keys are required, how a `tech/` file becomes an Item, and how the single
   `docs/canon.md` becomes rule records. The validator runs without writing, and every test fixture
   is synthetic — the real novel is never committed.

62. **First story-structure import: reader, command, page, and canon.**

   Nothing imports a source directory today, and the importer is meant to grow one record type at a
   time. This slice delivers the reusable path every later slice plugs into: a reader for the layout,
   a registry where each record type is its own importer class behind one small shared interface, an
   entry point that imports everything currently registered, a Rails task taking the source path
   (proposed as `bin/rails story_structure:import`), and a platform-admin page that picks a folder
   under a configured import root, lists the registered slices, and previews counts before writing.
   Adding a type must not edit the command or the page. **Canon is the first slice**, and its record
   already exists in [features/canon.md](features/canon.md) and [ADR 0039](adr/0039-canon-rules-are-universe-owned-with-an-optional-story.md).

   A run **replaces** the universe named by the manifest: create it when absent, delete and recreate
   it when present, after an explicit destructive confirmation that says records created in the app
   for that universe are lost. No other universe is touched. The source directory lives outside the
   repository and is never copied into it; the page never accepts an arbitrary path from the browser,
   only a folder under the configured root; the page is platform-admin-only because it creates and
   destroys universes; and the task refuses a production run without the same confirmation. **Needs a
   safety rule** for a target universe with open drafts or members other than the importer, and a
   synthetic fixture universe that exercises the reader without any real prose.

63. **Import slice: Characters and Factions.**

   These are the first two record types after canon because they are the tcs directories that already
   hold real records. Map the template frontmatter and body sections onto the existing profile
   answers — `at_a_glance`, `wants`, `needs`, `lies_to_self`, `contradictions`,
   `under_pressure_they`, `never`, `pronouns`, and `aliases` for a Character; `mission`,
   `actual_aims`, `structure`, `internal_divisions`, `resources`, `would_never`, and
   `would_absolutely` for a Faction — and resolve each `[[slug]]` reference to the record created in
   the same run. **Needs a written field-by-field mapping** and a decision about `affiliation`, which
   may be a Character's faction membership rather than a profile answer. A reference whose target is
   missing is reported, never silently dropped, and a second import of an unchanged source must
   produce an identical universe.

64. **Import slice: Locations, Items, and Plots.**

   tcs `locations/` maps to the five sensory answers and the five layout answers, `tech/` maps to
   Items, and `plots/` maps to Story-owned Plots with their type, status, owner POV, and question.
   **Needs the same field mapping** plus a hierarchy decision: tcs files are flat, while Locations
   and Items carry `parent_id`. Scene assignments cannot arrive until the Scene slice exists, so a
   Plot lands with its description and no Scenes.

65. **Import slice: Sections, Scenes, and Elements.**

   tcs's `chapters/` is empty today, so this slice waits for prose in the source. It is not the
   arbitrary-manuscript importer: that one accepts Word, Markdown, or HTML and needs mapping and
   preview rules, while this one reads files already in the interchange layout. **Needs** the
   layout's Scene frontmatter — chapter, sequence, POV, location, timeline, branch, and status —
   mapped onto Section, Scene, point of view, datetime, and Tags, with dialogue attribution preserved
   only where the source records it. A chapter file that cannot be mapped is reported rather than
   guessed at.

66. **Appearance heatmap with a separate mention layer.**

   `SceneAppearances` answers which Scenes one record appears in, but nothing shows the whole Story
   at once. A Story-scoped grid has one row per Character and one column per Scene in narrative
   order. **Two layers, never merged:** recorded presence (an explicit link, Dialogue speech, or an
   Event reference) and names written in Element prose, drawn in a visually distinct way, with a
   legend that says a mention is not an appearance. **Needs** the prose mention index for the second
   layer, a visual design that holds in light and dark and print and does not rely on hue alone, and
   a table equivalent for keyboard and screen readers. The grid stays read-only.

67. **Scenes-per-Character chart.**

   A record page lists its own appearances and the Characters list is Universe-scoped, but no page
   answers how much of the current Story each Character carries. One bar per Character counts the
   Scenes in which they appear, over the current Story. The count is the existing union — explicit
   link, Dialogue speech, Event reference — with a Character who both participates and speaks
   counted once; prose mentions are excluded until the mention index exists, and then only as a
   second distinguished layer. **Needs a home** — the Story overview is the natural one because the
   measure is Story-scoped — plus a table equivalent and a chart pattern shared with the heatmap.
   There is no chart library; the Map's server-rendered SVG is the closest existing pattern.

## FUTURE WORK

Loose ideas that have not been triaged live here, in any format. When one is taken up, it is
analyzed like the list above, given the next number, and moved under PENDING WORK.
