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

The highest number this file has used is 60. The list below keeps the numbers it already had and never
reuses one. It was triaged on 2026-10-25: two Scene ideas had already been delivered and left the
list, the rest became numbered items, and each item records what exists today and what its next step
depends on. The competitor survey on 2026-10-27 turned the four `check <site>` notes into items
49–60. Loose notes still belong under FUTURE WORK until they are triaged into this list.

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

50. **Universe canon rules.**

   The app holds facts as records — profiles, knowledge changes, ownerships, relationships, Events —
   but no record states a rule the story must obey, such as what magic costs or how long a road takes.
   `PlotLens` sells exactly this as "world rules" and links each violation back to the rule's source,
   and `Novilot` checks a draft against its Story Bible for the same purpose. **Needs a scope and a
   shape:** a rule belongs to the Universe unless the Story owns it, needs a short statement plus an
   optional source passage, and only earns its keep when something checks prose against it, so it
   pairs with item 49 and the contradiction analyzer rather than standing alone. Tropes are a genre
   catalogue, not this.

51. **Prose mention index and mention timeline.**

   Presence is an explicit link: a Character in a Scene appears only when somebody recorded it, and a
   name written inside an Element's body is invisible to every list, count, and the export's notes.
   Characters now carry aliases, but only list search reads them. `Novelcrafter`'s Mentions and mention
   timeline answer where a name appears, comes and goes, and is overused; its character detection is
   the same read. **Can be done without a model:** index Element bodies for registered names and
   aliases, present mentions as suggestions separate from presence so an unlinked name never becomes
   a fact, and show a record's mentions beside "appears in scenes". It also supplies the data the
   appearance heatmap idea in FUTURE WORK needs.

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
   admin-only archive in that shape is the obvious first slice, and restore is a separate, destructive,
   approval-required command that must not reuse the demo reset path. Backup first, restore in a
   second change.

## FUTURE WORK

Loose ideas that have not been triaged live here, in any format. When one is taken up, it is
analyzed like the list above, given the next number, and moved under PENDING WORK.

- highlight things in text (locations, characters, items, etc.)
- appearance heatmap
- characters per scenes chart
- import characters, factions, scenes, from tcs.git
- define a new story structure zipfile with directories for scenes, plot, canon, characters, etc.