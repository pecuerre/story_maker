# SHARED BACKLOG

This is the one place for **pending** work, rough ideas, and things we may want
to do in the future. The owner can append ideas without worrying about format.

## Instructions for Agents

### How finished work leaves this file

This file follows the same discipline as [known_quirks.md](known_quirks.md), where a fixed
finding is no longer an open item. When work is finished it does not stay here as a
"completed" paragraph. In the same change that delivers it:

1. add or update the dated entry in [`../CHANGELOG.md`](../CHANGELOG.md), then
2. delete the item from this file.

The changelog is the durable record of delivered work, so nothing else has to track it
here. Do not archive finished items under a separate heading, and do not leave a
completion summary behind.

### How AI assistants should use this file

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

The highest number this file has used is 96. The list below keeps the numbers it already had and never
reuses one. It was triaged on 2026-10-25: two Scene ideas had already been delivered and left the
list, the rest became numbered items, and each item records what exists today and what its next step
depends on. The competitor survey on 2026-10-27 turned the four `check <site>` notes into items
49–60; that day's second triage turned the five loose notes into items 61–67 and folded prose
highlighting into the mention index. Loose notes still belong under FUTURE WORK until they are
triaged into this list.

### Wait for Deployment

38. **Universe URLs as subdomains instead of `/u/<universe_slug>`.**

   Serve a universe at `<universe_slug>.<host>` rather than under a path. **Needs an ADR before any
   code**, because the blast radius is the whole request boundary: `config.hosts` and `APP_HOST`
   name one host today, mailer `default_url_options` is static, the session cookie and the
   remembered destination are host-sensitive, CSRF and cross-subdomain navigation must keep working,
   and every route helper, test, and demo URL changes. Deployment also needs wildcard DNS and a
   wildcard TLS certificate. Keep `/u/...` redirecting to the new host so existing links and the
   smoke test survive, and keep the browser-owned start page working before a universe is chosen.

48. **The deployment-secret permissions test can pass with no assertions.**

   The 2026-10-25 suite reports "Test is missing assertions" for
   `test/deployment/deployment_secrets_test.rb:52`: it skips each key file that is absent, so a
   checkout with neither file runs no assertion at all. **Can be done now:** `skip` with a named
   reason when there is nothing to inspect, or assert the expected presence/absence explicitly. This
   was noticed during the triage, not carried from the old notes.


### Wait until the tcs story is more mature

42. **Scene character-knowledge analyzer.**

   A Character's knowledge is prose in the description's `## Knowledge` section and is entered by
   hand; a Scene is not attributed as the place or occasion where something was learned. **Needs
   explicit attribution rules** — witnessed, told, or inferred — before storing anything. Presence
   must not imply knowledge, so this is a design decision before it is a query.

43. **Scene causality and temporal analyzer.**

   **Needs a design and a definition of evidence.** Compare Scene order, linked Events, independent
   Scene datetimes, and Element chronology to explain likely contradictions rather than resolve
   them. Related to the delivered
   [narrative/chronology comparison](features/scenes.md#narrative-order-beside-the-timeline), but it
   reports causes and uncertainty and is a separate analysis; nothing should be rewritten silently.

44. **Scene prose-contradiction analyzer.**

   Analyze Element prose for claims that conflict with recorded Universe facts. **Largest and least
   defined:** it needs a text-analysis layer (likely an external model), an evidence/citation
   surface, and a privacy decision about sending story prose out. Keep it separate from the
   structured checks above and do not start it before them.

49. **Continuity findings inbox with cited evidence.**

   The analyzers in items 42–44 are specified as analyses but not as a place their results live: the
   only continuity report today is the read-only narrative comparison, whose one conflict type is
   drawn inline on its own tab. `PlotLens` and `Novilot` both show a finding as a questionable passage
   beside the exact line it conflicts with, with a status the author chooses — open, held for review,
   not an issue — and that shape is what makes a report trustworthy rather than a verdict. **Needs a
   design before any analyzer:** a Story- and Universe-scoped finding record carrying the quoted
   evidence and its source, a status lifecycle, and an inbox page, with a dismissal recorded rather
   than the finding deleted. It is the surface items 42–44 write into, so it should land before them,
   and it must never rewrite prose.

56. **Scene tension and pacing curve.**

   The narrative-order tab compares a Scene's own time with its Event and reports conflicts; nothing
   measures how a Story reads. `Novilot` visualizes tension and pacing with genre-aware feedback, and
   `Sudowrite` sells pacing through expansion. **Needs a rating before a chart:** a Scene-level tension
   value on a small worded scale rather than a free number, entered in the Scene form, then a curve on
   the Story page or the narrative tab whose points are Scenes in narrative order. Feedback text is a
   separate and much later decision, and the chart needs a table equivalent for keyboard and screen
   readers.

### Next Items

41. **Structured Scene roles from free-text annotations.**

   `SceneCharacter`, `SceneItem`, and `SceneLocation` carry a free-text `role` that is never checked
   against a vocabulary. **Blocked on evidence:** analyze existing annotations first, then promote
   only recurring values to controlled role types. That needs a scope (Universe or Story) and a
   migration decision; until then the free text is correct behavior, not debt.

45. **Timeline pan/zoom.**

   `timeline_controller.js` only draws edges between nodes; the pan/zoom the early docs described
   was never built, and the docs were corrected on 2026-09-29 to say so. **Needs UI design, not a
   defect fix:** a draggable/zoomable viewport changes how layer markers and node circles read,
   needs a keyboard and touch path, and the SVG edges must stay aligned under the transform. Worth
   doing only when a universe's event count makes the wrapped layout genuinely hard to read.

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

96. **Complete participant and accessibility validation.**

   Follow up the initial browser walkthrough with real participants and record where they hesitate.
   Cover a writer-only account, actual screen-reader use, browser zoom, and the remaining role, theme,
   language, viewport, focus, contrast, and reduced-motion combinations. Prioritize desktop while
   retaining tablet and phone; use the findings to revisit the existing UI/UX and visual-design
   hypotheses. An automated walkthrough or accessibility-tree inspection is not user testing.

### UI and UX review — 2026-11-12

This is a **source-based design review**, not a browser, accessibility, or user-testing audit.
It examined the shell, navigation, Story overview, lists, Scene editor and board, analytics,
drafts, and export views, alongside the design and navigation documents. The recommendations below
are hypotheses to validate, except where the [browser baseline](delivery_history.md#2026-11-12)
records a specific observation; they are not claims about user struggles.
No UI changes are approved by recording them here. Each item is a separate decision for later.

The existing direction is worth keeping: a calm, scope-aware Bootstrap workspace, theme tokens,
visible keyboard/touch controls, meaningful empty states, and accessible alternatives for diagrams.
The main opportunity is to make the next task easier to find and reduce competing controls without
losing the information writers need. Priorities are suggested, not commitments; evaluate each item on
its own alongside the browser baseline follow-ups.

76. **Improve the prose-writing loop.**

   Scene Details places Elements after identity facts, and each Element's edit action is inside a row
   menu; narration uses a five-row textarea in a modal ([`scenes/_elements`](../app/views/scenes/_elements.html.erb)).
   Prototype a more prominent writing entry point and more comfortable long-form editing without
   assuming a new editor is needed. Compare narration and dialogue, preserve ordering and mention cues,
   and explicitly test unsaved text, errors, focus, mobile keyboards, and draft-mode feedback.
   **Question:** do writers primarily compose here or import prose from elsewhere?

77. **Streamline the Scene editing form.**

   [`scenes/_form`](../app/views/scenes/_form.html.erb) exposes photo, description, drafting contract,
   status, tags, plots, grouping, time, events, and point of view in one long form; tags and plots use
   native multiple selects while Events uses a searchable picker. Test grouped progressive disclosure
   and a consistent, accessible selection experience for long lists. Preserve all existing selections,
   error recovery, no-JavaScript behavior where applicable, and the preference that hides the drafting
   contract. **Question:** which fields must be immediately visible during initial creation?

78. **Make list navigation more discoverable.**

   On the [Characters list](../app/views/characters/index.html.erb) and other shared lists, record names
   are plain text and a separate **Details** link opens the record; the
   [Scene board](../app/views/scene_boards/show.html.erb) instead links the title. Test whether readers
   try the names first, and compare linked titles with the existing explicit Details action. Any change
   must be consistent across relevant list/tree patterns, retain distinct accessible link names and
   visible actions, and not interfere with the tree's inline rename control.

79. **Clarify what moving a Scene on the board does.**

   [`scene_boards/show`](../app/views/scene_boards/show.html.erb) groups cards into Section columns,
   but its arrows change the Story-wide narrative sequence while **Move to section** changes grouping.
   Test concise visible guidance and labels that distinguish those operations, especially when adjacent
   narrative Scenes are in different columns. Keep keyboard/touch alternatives and do not imply that
   changing a Section automatically changes narrative order.

80. **Give filters less visual weight without hiding their state.**

   The [Scene filter](../app/views/scenes/_filter.html.erb) displays search, Section, tag, status, and
   two dates before the list, even when none is active. Compare an always-visible search plus an
   **Advanced filters** disclosure against the current layout, particularly on phones. Active criteria,
   result counts, a clear path, shareable URLs, and the difference between no records and no matches must
   remain visible; preserve filtering and narrative-order semantics.

81. **Keep a reader oriented between Scenes.**

   Scene Details shows its narrative position and an **All scenes** link, but
   [`scenes/show`](../app/views/scenes/show.html.erb) has no previous/next navigation. Explore labelled
   neighboring-Scene links to support sequential reading and editing. Define whether a filtered-list
   visit should carry its filter or navigate the whole narrative order; keep boundary states,
   permissions, and direct links understandable.

82. **Rebalance the workspace at constrained widths.**

   The [application shell](../app/views/layouts/application.html.erb) has left and right navigation
   panels, a collapsed navbar, and a separate mobile Menu/Tools bar; at wide sizes the panels reserve
   30rem together. Test usable content width, panel scrolling, long scope names, and the discoverability
   of search and Tools around the `lg`/`xl` breakpoints and at 200% zoom. Consider a compact or
   collapsible tools panel only if the comparison shows a benefit; retain scope, keyboard access, and
   pending-work visibility.

83. **Reduce friction switching scope.**

   The [navbar](../app/views/layouts/_navbar.html.erb) links to the current Universe and Story, while
   changing them means returning to the Universe chooser or Universe page. Test whether frequent
   switching warrants a clearly labelled, keyboard-accessible shortcut or whether the existing two-step
   route is sufficient. Keep explicit Universe/Story context, access boundaries, and the rule that no
   Story is selected implicitly; compare mobile and desktop.

84. **Distinguish export scopes before download.**

   The Story's [Export page](../app/views/story_exports/show.html.erb) offers a scoped printable Story
   and a Universe-wide interchange download. Prototype stronger scope labels and concise inclusion/
   exclusion summaries next to each action, so the two similarly prominent buttons cannot be mistaken
   for the same output. Confirm the wording against the export and interchange contracts; preserve their
   access rules and avoid promising a complete backup.

85. **Help readers navigate large analytics views.**

   The [Appearance grid](../app/views/appearances/show.html.erb) and
   [Scene matrix](../app/views/scene_matrices/show.html.erb) already have accessible tables and
   scrollable regions, but wide Stories can require substantial horizontal exploration. Test visible
   scroll cues and a way to narrow or jump to a Character, Scene, or Section. Decide whether a narrowed
   view should share the list's filters; keep the full-table equivalent, explicit layer meanings, and
   print behavior. Assess with realistic data before choosing a control.

86. **Audit the visual system's hierarchy and feedback.**

   Review real rendered screens for repeated bordered pills, equal-weight outline buttons, narrow
   metadata, touch targets, theme contrast, and toast persistence. Prototype changes using existing
   Bootstrap and theme tokens rather than a new framework; make status and actions distinguishable
   without color alone. Verify success, failure, loading, long text, focus, reduced motion, and both
   themes rather than assuming these are broken.

- **The import confirmation outgrows the flash cookie.** A run lists every reported item in its
  post-import flash. The real `tcs` source is now about 3.9 kB of ids (canon, characters, factions),
  and Rails stores flash in the cookie session, so the confirmation can raise `CookieOverflow` after
  the import has committed. The preview and the rake task need no change; the page flash should
  summarize counts per slice instead of every id, or move the detail to a redirect target.

### Visual design initiative — 2026-11-12

The earlier UI/UX review is primarily about workflows; this initiative develops a coherent, more
modern visual direction. The stages are in suggested order, with owner decisions before a direction
is prototyped and before it is rolled out. These are pending ideas, not approval for a redesign.
Coordinate with the existing visual/task baseline and visual hierarchy audit rather than repeating
the same observations; use their findings to inform the other UI/UX items.

87. **Define the visual design brief.**

   Agree with the owner on the desired character of the workspace, its intended users and priorities,
   and what "modern" should mean for this product. Gather a few reference products or screenshots
   and identify the specific qualities worth borrowing, such as density, typography, navigation, or
   color. Record constraints and representative screens before exploring directions; a calm writing
   studio is one possible direction, not a predetermined choice.

88. **Audit the rendered interface for visual design.**

   Inspect the running app in a browser and capture the shell, empty and populated Story overviews,
   a list, and Scene details and editor. Compare desktop and mobile, light and dark themes, and long
   English and Spanish labels. Assess color, typography, spacing, hierarchy, component consistency,
   content width, navigation placement, responsive behavior, contrast, keyboard focus, and zoom.
   Document concrete observations and screenshots, building on the existing baseline and hierarchy
   audit rather than presenting source-based hypotheses as verified problems.

89. **Explore and recommend visual directions.**

   Present two or three distinct directions using representative screens, screenshots or prototypes,
   with an explanation of tradeoffs and a recommended choice. For each, propose light/dark neutral,
   accent, and semantic colors; font candidates, sizes, weights, line heights, and prose readability;
   navigation and menu placement, page headers, content widths, and mobile layout; component treatments;
   and a spacing and density scale. Check contrast and font licensing, loading, and fallbacks rather
   than assuming they are suitable. Ask the owner to choose a direction before implementation.

90. **Prototype the chosen design on representative screens.**

   Apply the selected direction to the workspace shell and a small set of representative screens,
   not the entire application. Review actual screenshots at useful desktop and mobile sizes, in both
   themes, with zoom and keyboard focus; check translations and preserve existing workflows. Refine
   the direction with the owner and obtain approval before a site-wide rollout.

91. **Roll out the approved visual system in slices.**

   Translate the approved prototype into the existing Bootstrap and theme-token system, then update
   related screens in manageable groups. Validate accessibility, responsive behavior, translations,
   and existing workflows as each slice lands. Keep changes reversible, avoid a new framework or
   other dependencies unless justified, and update the owning design documentation as behavior changes.

## FUTURE WORK

Loose ideas that have not been triaged live here, in any format. When one is taken up, it is
analyzed like the list above, given the next number, and moved under PENDING WORK.

- **Read-only Story overview empty copy.** An empty Story's cast card still says "Add the first
  scene to begin" and its Section-tree card says "Add the first one to begin" to a guest or read-only
  member, who can add neither. Give those cards a read-only description, the way the Sections
  workspace already has `read_only_empty_description`, and add the Spanish copy.
