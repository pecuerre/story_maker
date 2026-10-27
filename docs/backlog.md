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

The highest number this file has used is 34. The list below continues at 35 and never reuses a
number. It was triaged on 2026-10-25: two Scene ideas had already been delivered and left the list,
the rest became numbered items, and each item records what exists today and what its next step
depends on. Loose notes still belong under FUTURE WORK until they are triaged into this list.

38. **Universe URLs as subdomains instead of `/u/<universe_slug>`.**

   Serve a universe at `<universe_slug>.<host>` rather than under a path. **Needs an ADR before any
   code**, because the blast radius is the whole request boundary: `config.hosts` and `APP_HOST`
   name one host today, mailer `default_url_options` is static, the session cookie and the
   remembered destination are host-sensitive, CSRF and cross-subdomain navigation must keep working,
   and every route helper, test, and demo URL changes. Deployment also needs wildcard DNS and a
   wildcard TLS certificate. Keep `/u/...` redirecting to the new host so existing links and the
   smoke test survive, and keep the browser-owned start page working before a universe is chosen.

39. **Composite Scene-to-Event links.**

   A Scene has one optional `event_id` today, independent of its `datetime`. **Needs a product
   decision** that a Scene commonly contains several Events before building the scoped join model
   the idea asks for: roles and order, migration, editors, API, sample data, tests, and docs. Do not
   overload the single `event_id` in the meantime.

41. **Structured Scene roles from free-text annotations.**

   `SceneCharacter`, `SceneItem`, and `SceneLocation` carry a free-text `role` that is never checked
   against a vocabulary. **Blocked on evidence:** analyze existing annotations first, then promote
   only recurring values to controlled role types. That needs a scope (Universe or Story) and a
   migration decision; until then the free text is correct behavior, not debt.

42. **Scene character-knowledge analyzer.**

   Character knowledge records exist and are entered by hand; a Scene is not attributed as the place
   or occasion where something was learned. **Needs explicit attribution rules** — witnessed, told,
   or inferred — before storing anything. Presence must not imply knowledge, so this is a design
   decision before it is a query.

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

45. **Timeline pan/zoom.**

   `timeline_controller.js` only draws edges between nodes; the pan/zoom the early docs described
   was never built, and the docs were corrected on 2026-09-29 to say so. **Needs UI design, not a
   defect fix:** a draggable/zoomable viewport changes how layer markers and node circles read,
   needs a keyboard and touch path, and the SVG edges must stay aligned under the transform. Worth
   doing only when a universe's event count makes the wrapped layout genuinely hard to read.

46. **Export a Story in book format.**

   Nothing exists. **Needs a format and scope decision:** manuscript output (Markdown, HTML, PDF, or
   EPUB), assembled from Sections and Scenes in narrative order, naming which fields and Elements
   are included, whether pending changes are excluded, and where the action lives. Build it on the
   story-scoped read path and keep access rules identical to reading the Story.

47. **Export a Story in script format.**

   Nothing exists. **Needs a format and scope decision:** screenplay/Fountain or plain text, with
   Scene headings from Sections and Scenes, Element roles, and Dialogue turns. It shares the
   assembly step with book export but not the output contract, so decide the two separately even if
   they ship together.

48. **The deployment-secret permissions test can pass with no assertions.**

   The 2026-10-25 suite reports "Test is missing assertions" for
   `test/deployment/deployment_secrets_test.rb:52`: it skips each key file that is absent, so a
   checkout with neither file runs no assertion at all. **Can be done now:** `skip` with a named
   reason when there is nothing to inspect, or assert the expected presence/absence explicitly. This
   was noticed during the triage, not carried from the old notes.

## FUTURE WORK

Loose ideas that have not been triaged live here, in any format. When one is taken up, it is
analyzed like the list above, given the next number, and moved under PENDING WORK.

- highlight things in text (locations, characters, items, etc.)
- appearance heatmap
- characters per scenes chart
- import characters, factions, scenes, from tcs.git
- define a new story structure zipfile with directories for scenes, plot, canon, characters, etc.
- check novelcrafter.com
- check plotlens.ai
- check novilot.com
- check sudowrite.com