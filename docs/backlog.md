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

The highest number this file has used is 70. The list below keeps the numbers it already had and never
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

   NOTE: Leave for later

   `SceneCharacter`, `SceneItem`, and `SceneLocation` carry a free-text `role` that is never checked
   against a vocabulary. **Blocked on evidence:** analyze existing annotations first, then promote
   only recurring values to controlled role types. That needs a scope (Universe or Story) and a
   migration decision; until then the free text is correct behavior, not debt.

42. **Scene character-knowledge analyzer.**

   NOTE: Wait until the story is more advanced

   A Character's knowledge is prose in the description's `## Knowledge` section and is entered by
   hand; a Scene is not attributed as the place or occasion where something was learned. **Needs
   explicit attribution rules** — witnessed, told, or inferred — before storing anything. Presence
   must not imply knowledge, so this is a design decision before it is a query.

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

   NOTE: Leave for later

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

54. **Scene archive and custom status labels.**

   Scenes now carry a fixed draft/revised/final status, shown on the list and details page, filterable,
   and available to the export's final-only choice. The competitor **Scene archive** pulls scenes from
   the manuscript without deleting them, and custom per-Story labels are still undecided. **Needs a
   model decision:** whether the archive is a separate flag from the writing status or a fourth
   status, and whether a custom label replaces the fixed vocabulary or sits beside it. Keep the
   archive distinct from soft delete, which already owns removal and restoration.

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

   Time-varying facts exist in two places — item `Ownership` rows with dates, and Event-linked Scene
   presence — and the rest of a record's profile, including a Character's description, is one
   present-tense answer. `Novelcrafter` generalizes this as Codex progressions, so a title,
   allegiance, or appearance can differ by chapter. **Needs a model decision:** whether a progression
   is a new Event-linked fact row or a dated profile answer, and whether it is Universe- or
   Story-scoped; it must not duplicate ownership. Start only after something can read the existing
   two, or the new rows become another source nobody checks.

60. **Universe backup archive: identity, access, and restore.**

   The core archive exists: an admin downloads a `.tar.gz` of the Universe's content, photos, and a
   readable projection, and [the backup document](features/universe_backup.md) owns what it carries.
   Users, memberships, drafts and their change history, review requests, notifications, and API
   tokens are deliberately deferred. **Needs a privacy decision** on whether those rows join the same
   archive, get a separate owner-only archive, or stay out: they carry identity, access, or somebody
   else's unfinished work. Restore is the other half, and it is still separate, destructive, and
   approval-required: it must remap ids, decide how an older archive's missing tables are treated,
   and must not reuse the development-data reset path.

67. **Scenes-per-Character chart.**

   A record page lists its own appearances and the Characters list is Universe-scoped, but no page
   answers how much of the current Story each Character carries. One bar per Character counts the
   Scenes in which they appear, over the current Story. The count is the existing union — explicit
   link, Dialogue speech, Event reference — with a Character who both participates and speaks
   counted once; prose mentions never add to it and may appear only as a second distinguished layer.
   **Needs a home** — the Story overview is the natural one because the measure is Story-scoped —
   plus a table equivalent and a chart pattern shared with the
   [Appearance grid](features/appearances.md). There is no chart library; the Map's server-rendered
   SVG is the closest existing pattern.

68. is there any statistic about contributions per universe? something like
  - john doe: 40%
  - jane doe: 33%
  - mark markson: 20%
  - jack jackson: 7%

## FUTURE WORK

Loose ideas that have not been triaged live here, in any format. When one is taken up, it is
analyzed like the list above, given the next number, and moved under PENDING WORK.

- **The import confirmation outgrows the flash cookie.** A run lists every reported item in its
  post-import flash. The real `tcs` source is now about 3.9 kB of ids (canon, characters, factions),
  and Rails stores flash in the cookie session, so the confirmation can raise `CookieOverflow` after
  the import has committed. The preview and the rake task need no change; the page flash should
  summarize counts per slice instead of every id, or move the detail to a redirect target.
