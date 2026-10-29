# ADR 0043: A story-interchange import replaces one universe, with its registry and slice boundaries

- **Status:** Accepted
- **Date:** 2026-10-29
- **Related:** [The story interchange is a directory contract](0041-the-story-interchange-is-a-directory-contract.md), [Canon rules](0039-canon-rules-are-universe-owned-with-an-optional-story.md), [Universe access levels](0005-universe-access-levels.md), [Story interchange](../features/story_interchange.md)

## Context

ADR 0041 settled the directory contract and the validator that reads it. Nothing wrote a source
into the database, and the author's real repository is the source that matters. The import could not
arrive all at once: Characters, Factions, Locations, Items, Plots, and Scenes each need their own
field mapping, and several of those mappings need decisions the database does not answer today. The
first slice therefore had to deliver the reusable path — registry, entry point, command, page — and
exactly one record type, so later slices add a mapping rather than a second import system.

Three questions had to be settled before any record was written. What owns a run's target when the
source carries no manifest? What happens to the Universe already at that address? And who may start
one, given that it creates and destroys Universes rather than editing a page inside one?

## Decision

- **The source names the target, and a run replaces it.** The source directory's basename is the
  Universe slug, so an import cannot be pointed at an unrelated Universe. One run replaces the one
  live Universe at that slug, or creates it when absent. No other universe is touched.
- **Replacing is a soft delete, not a hard delete.** The application's own delete is
  `SoftDeletable#soft_delete`; a hard delete would leave soft-deleted child rows whose foreign keys
  still name the old Universe. The old rows stay hidden, the new Universe takes the same slug, and
  the app records for the old one are unreachable. There is no Universe restore path, so the
  confirmation still says they are lost.
- **A replaced Universe keeps its privacy and collaboration mode; a new one takes the defaults.**
  The source carries neither setting, and silently publishing a private Universe or turning a
  draft-based one into a direct one is not an import.
- **The entry point is one transaction.** Validate, soft-delete, create, and every slice's write
  happen together, so a refused or failed slice leaves the database as it was.
- **Each record type is one `StoryInterchange::Importer` subclass in `Importers::ALL`.** A slice
  declares an I18n key for its name and the validator count it writes, and returns how many records
  it wrote plus the source ids it reported instead. The command, the page, and the preview read the
  registry, so adding a type never edits them. Canon is the first slice.
- **The validator owns reading canon.** It already registers every `K`/`L`/`D`/`O` id, so it also
  carries each item's statement, source, path, and line on the report. The canon slice does not parse
  the area files a second time, and cannot disagree with the preview about what an item says.
- **A target with open drafts or members other than the importer is refused.** Replacing it would
  destroy somebody else's unfinished work or access. Both the page and the task name what they found
  and write nothing; the operator resolves it in the app first. An existing Universe owned by
  somebody else is refused by the same rule, because the owner is one of its members.
- **The page is platform administration, not universe administration.** It asks for `:manage` on
  `StoryInterchange::Import`, the same `:platform` level the universe creation limit uses. A guest
  signs in; a signed-in account without `users.platform_admin` receives `403`.
- **The page accepts a folder name, never a path.** It lists only the folders directly under
  `STORY_INTERCHANGE_IMPORT_ROOT`, and refuses a separator, `..`, a dot-file, or a symlink that
  resolves outside the root. The source is read in place and never copied into the repository.
- **The destructive confirmation belongs to the caller, the safety check does not.** The page
  requires its checkbox and the task requires `CONFIRM_STORY_INTERCHANGE_IMPORT=1` in every
  environment; the service refuses an unsafe plan either way, so a caller cannot skip the safety
  rule. The task takes the owner's email because a Universe must have an owner.

## Consequences

### Benefits

- Later record types add one importer class and one registry entry; the task, page, and preview are
  already finished.
- The source cannot be aimed at an unrelated Universe, and a wrong import loses nothing outside the
  one Universe the directory names.
- Canon rules are written from the same parse the operator previewed, including the area citation a
  rule can carry today.
- The old Universe's rows survive a replacement in the same soft-deleted state as every other
  deleted record, so a future restore path has data to work with.

### Costs and constraints

- A run cannot import into a Universe whose slug differs from its directory name. Renaming the source
  root is how the target changes, and the page shows the derived slug before writing.
- Only one Universe per slug can be live, so two sources cannot be imported side by side under
  names that parameterize alike.
- A source is never updated in place: every run replaces the Universe, so records created in the app
  for it are lost even when the source only gained one file. That is the destructive confirmation's
  subject.
- Characters, Factions, Locations, Items, Plots, and Scenes are still validator-only; importing a
  real source replaces the Universe with one that has canon rules and no stories yet.

## Alternatives considered

- **Update the existing Universe in place:** rejected because the source has no identity per record
  beyond a slug, and a merge would have to decide how a record the source dropped is treated, how
  app-created records survive, and which side wins a conflict. Replacing is the one rule that can be
  stated and tested now.
- **Hard-delete the old Universe:** rejected because soft-deleted child rows keep foreign keys to it,
  and because the application already treats delete as a reversible mark. A hard delete would need a
  separate purge path before it were safe.
- **Let the page choose a target Universe:** rejected because the source names its own identity and a
  free choice would let a source be written into a Universe whose slug no reference can predict.
- **Accept any path from the browser, or an upload:** rejected because the page creates and destroys
  Universes. A filename under one configured root bounds what a browser can ask the server to read.
- **Build every record type before shipping the path:** rejected because several mappings are still
  undecided, and one uncertain mapping would delay the reusable registry, command, and page.
- **Enforce the destructive confirmation inside the service:** rejected because the service is also
  the test and library entry point, where a confirmation flag would be ceremony rather than a human
  decision. The safety check is inside, so the refusal that protects other people's work cannot be
  skipped.

## Related documentation

- [Story interchange](../features/story_interchange.md) — the layout, the validator, and the current
  import behavior.
- [Canon rules](../features/canon.md) — the record the first slice writes.
- [Universe backup](../features/universe_backup.md) — the reverse direction, still a projection.
