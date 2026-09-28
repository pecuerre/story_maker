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

3. **Contextual inspector / right-side utility panel**

The right utility sidebar now reserves a stable home for future collaboration, analytics, and AI
tools. Replace its temporary `aria-disabled` links with a real contextual inspector as the
underlying product areas become concrete. The inspector should show information relevant to the
current page: selected entity details, related records, taxonomy usage, filters, or quick actions.
It remains a Bootstrap `offcanvas-end` below `xl` and can be hidden when there is nothing useful
to show. Candidate data includes selected-character relations/ownerships, relation-tag usage
counts, and story outline progress.

4. **Search, filtering, and sorting for large lists**

The top-bar search is now implemented and answers across every model; see
[ADR 0014](adr/0014-global-search-with-meilisearch.md) and the delivered work in
[`../CHANGELOG.md`](../CHANGELOG.md). What is still missing is the *in-list* half: a list a reader
has already landed on should be able to narrow, sort, and show its filters in the URL.

Add client- or server-backed search/filter/sort controls to Characters, Locations, Events, Items,
Relations, Ownerships, and taxonomy trees. Preserve universe/story scope, make filters removable
and visible in the URL where practical, and define behavior for empty results separately from an
empty database. Start with the fields already exposed by each model. The story-owned Scenes list
already has this shape (text, Section group, Scene Tag, inclusive in-world date range, canonical
query in the URL); reuse its `SceneFilter` conventions here instead of inventing a second filter
pattern, and reuse `Search::Scope` for the boundary rather than re-deciding what "this universe"
means.

5. **Richer relationship and entity rows**

Make list rows more useful for scanning large universes. Relations should render as a readable
sentence such as `Ariadne — is friend to → Lysander`, with direction and dates as metadata.
Characters could show relation/ownership counts, locations could show parent/child context, events
could show date range and related events, and items could show current/historical owners. Add
these as derived presentation data where possible; avoid duplicating source fields in the UI.

6. **Story overview dashboard**

Turn the current Story overview into a compact working dashboard: story description, section
count, section-tree preview, recently edited sections, quick “Add section” action, and links into
the relevant Universe Bible records. This should remain lightweight until the underlying section
and appearance/usage data are available.

7. **Universe summary cards**

Make the Universes index useful for choosing a workspace. Add story and entity counts, visibility,
recent activity, and a clear “Open universe” action. Consider eager-loading/caching the summary
counts so the index does not issue one count query per universe. Keep the existing authorization
and visibility rules in mind before exposing any summary data.

9. **Story-planning and world-building tools**

Story-owned scene planning is now implemented; see
[ADR 0007](adr/0007-story-owned-scenes-and-elements.md) and the delivered slices in
[`../CHANGELOG.md`](../CHANGELOG.md). Revisit the adjacent ideas this epic did not decide — Plot,
Tropes, Routes, Map, Distances, Meetings, POV structure, and turn-level dialogue — only with a
concrete domain decision: define what each record means, which scope owns it, how it appears in the
current page patterns, and whether it is worth adding to the data model. Replace a reserved link
only when the feature has a real destination and useful empty, loading, and error states. The MVP's
own limits stay visible rather than implied away: a Scene's `datetime` and its Event reference are
independent and may contradict each other, free-text roles are annotations the application does not
interpret, and one Dialogue block cannot say which line a speaker said. Continuity *checking* is
still the analyzer's job, and nothing here performs it.

10. **Collaboration and universe analysis**

Universe-level access management is implemented: public/private visibility and read/write/admin
memberships are available from the universe workspace. The right sidebar still reserves temporary
links for Tracking, Analyzer, richer Collaboration, Graphs, Analytics, and AI tools. Those remain
future product areas. Before replacing the placeholders with navigation, specify the underlying
records and permissions: inconsistency detection, incomplete/undefined records, submissions,
changes/forks, graphs, analytics, and drafts. A feature should appear as a live navigation item when
it has a useful destination and clear empty/loading/error states.

14. **Coverage measurement and CI gate (DataFactor follow-up)**

   Measure the current Minitest baseline with a real coverage tool (SimpleCov is a reasonable
   starting point), start collection before Rails loads, and decide whether the report's suggested
   80% threshold is appropriate for this codebase. Add the threshold only after measuring, upload
   the HTML report from CI, and add tests for meaningful uncovered behavior rather than padding
   assertions. Keep generated coverage out of Git and document the local command, exclusions, and
   the limits of the smoke system suite.

15. **One-command containerized onboarding (DataFactor follow-up)**

   Add and verify a development-safe `docker compose up` path using a development-specific service
   or command. It must prepare an isolated SQLite database, persist the correct local
   database/storage paths, expose the app, pass `/up`, build CSS assets, and work from a clean
   checkout. The existing Dockerfile is production-oriented and its server entrypoint calls
   `db:prepare`, which now loads production-safe seeds only; do not present that production
   entrypoint as a development data workflow. Document the verified development-specific command
   as an alternative to the `mise`/`bundle`/`bun` setup. Do not run development data in a
   production container, mount real data, or duplicate the existing entrypoint blindly. A
   devcontainer is optional and should follow the same boundary.

16. **Structured logging and runtime observability (DataFactor follow-up)**

   Preserve the existing `/up` health route and add a regression test. Evaluate structured request
   logging, request IDs, and optional error tracking with explicit redaction for password-reset
   tokens, cookies, credentials, DSNs, and personal data. Initialize an external tracker only when
   an environment variable is supplied. Define authentication, cardinality, retention, and privacy
   rules before adding metrics; do not add a public endpoint or dependency merely because a report
   names one. This work must coordinate with the logging, transport, and mailer findings in
   `known_quirks.md`.

17. **Development credential and environment hygiene (DataFactor follow-up)**

   Replace hardcoded local/demo passwords in the LOTR development users, Dark user data, and smoke script
   with an explicit environment variable or a generated local-only value. Make missing values fail
   clearly. Preserve or update the documented synthetic development login and exact load/verification
   instructions in the same change. Add a value-free `.env.example` only with an intentional
   `.gitignore` exception and document variable names/purposes without values. Never commit real
   `.env` files. This item is separate from the critical tracked `.kamal/secrets` rotation/removal
   work already recorded in `known_quirks.md`.

18. **Complete dependency, JavaScript, and container supply-chain checks (DataFactor follow-up)**

   Preserve the committed `bun.lock` and frozen installs. Add a supported Bun/npm audit path,
   verify the provenance and version consistency of locally vendored JavaScript, and add appropriate
   npm/Bun and Docker Dependabot ecosystems. Consider a clean production-image build/boot smoke
   check and Kamal configuration validation. Do not add a deploy job or typecheck job without an
   approved deployment contract or a real static-type toolchain; avoid unpinned or ceremonial CI
   steps. Coordinate with the existing known findings about vendored assets, image size, and
   reproducibility.

19. **Reduce shared editor/helper duplication (DataFactor follow-up)**

   Characterize the serialized field and JSON contracts used by `modal_fields.rb` and
   `tags_helper.rb` before changing them. Then extract declarative/shared helpers only where they
   remove real drift risk, with focused model/request/browser regressions. Preserve the existing
   three UI patterns, JSON-only mutation contracts, optional tags, authorization, and accessible
   error states. Do not refactor solely to improve a line-count metric.

20. **Include a soft delete. with a deleted_at column in tables**

   when users click delete, instead of actually deleting the records. we will just mark them as
   deleted, by setting the deleted_at column. add a default scope to models to only show "not deleted"
   records. add also a "recycle bin" where you can see those deleted elements. in the recycle bin
   you can actually delete for real. it is very important to track the relations that were deleted.
   for instance if i delete a story, the scenes and sections will be deleted. but later if i decide
   to recover the story, i shuold be ask "there are related elements associated with this, do you want
   to recover them too?"

23. **visual improvements**
  - move the seetings button on the top bar, under the account button
  - if no user is logged in, instead of a button [log in] show the same combo [account] and the login button inside
  - add a button "go back" in the settings, so when you finish changing settings you can continue where you left

These items are deliberately **LATER** by default. Use the owner’s **NOW / LATER / NEVER** decision
before expanding a feature task; the DataFactor report is directional evidence, not an automatic
work order.

## FUTURE WORK
- **change universes to subdomains**. replace the /u/universe_slug for universe_slug.<website>.com
- **Structured dialogue turns.** Replace or augment free-text Dialogue elements with ordered lines,
  speaker changes, parentheticals, and optional character attribution once the MVP reveals real usage.
- **Scene point-of-view/focus Character.** Record whose perspective presents a Scene separately from
  all Characters present, supporting same-Event/different-POV analysis without duplicating Event data.
- **Composite Scene-to-Event links.** If a Scene often contains several Events, introduce a scoped
  join model with roles/order rather than overloading the first version's optional single Event.
- **Narrative-order versus chronology comparison.** Visualize a Story's Scene sequence beside the
  Universe Timeline to expose flashbacks, parallel scenes, and unexplained order changes.
- **Structured Scene roles.** Analyze recurring free-text Character/Item/Location annotations before
  promoting useful values to controlled, analyzer-friendly role types.
- **Scene character-presence analyzer.** Use explicit participants and derived speakers to answer
  where a Character appears, with Story context and confidence/inference labels kept separate from
  author-entered facts.
- **Scene character-knowledge analyzer.** Track what a Character witnesses or is told in a Scene;
  this needs explicit attribution rules and should not be inferred from mere presence.
- **Scene causality and temporal analyzer.** Compare Scene order, linked Events, independent
  Scene datetimes, and Element chronology to explain likely contradictions rather than silently
  rewriting author data.
- **Scene prose-contradiction analyzer.** Analyze Element text for claims that conflict with Universe
  facts; this is a separate product from structured temporal/causal checks and should explain its
  evidence and uncertainty.
