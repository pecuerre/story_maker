# ADR 0045: A canon rule has a name and a stable slug

- **Status:** Accepted
- **Date:** 2026-10-29
- **Related:** [ADR 0039](0039-canon-rules-are-universe-owned-with-an-optional-story.md), [Canon rules](../features/canon.md), [Data model](../data_model.md), [Story interchange](../features/story_interchange.md)

## Context

ADR 0039 gave a Canon Rule a required statement and an optional source passage, and addressed the
record by its numeric id. That was enough while a rule could only be written in the application:
the statement was its own label and nothing outside the database cited it.

The story-interchange ledger is a different source. It keys every canon item by a stable id — `K16`,
`L2`, `D8`, `O-I1` — titles the item with that id and a short name, and groups it under an area file
(`universe/canon/travel.md`). Re-importing the source has to find the same item again, and a reader
has to see the short title rather than a sentence with the id still attached. The record therefore
needs four facts it does not have: a slug, a name, a category, and a canon type.

The numeric id cannot be the stable address for that. It is assigned by the database, so a fresh
import cannot choose it, and a source that renumbers an item would silently move the citation. A
slug taken from the ledger id is the one value the source and the application can agree on.

## Decision

- A Canon Rule has a required **name**: the short title a list row, a search result, and a citation
  show. The required **statement** stays the sentence the prose must obey, and the optional **source**
  stays the passage the rule comes from.
- A Canon Rule has a required **slug**, unique inside its Universe among live rules. The slug is the
  story-interchange ledger id when the rule came from a source, and the name parameterized otherwise.
  It is assigned once and does not change when the rule is renamed, because its purpose is to keep a
  citation pointing at the same rule. The model therefore does **not** include `HasSlug`, whose
  behaviour regenerates the slug on a name change.
- The slug is lowercase and hyphenated like every other slug in the application, so a ledger id
  `L2` is stored as `l2`.
- An optional **category** names the source area the rule belongs to — the area file's name in the
  interchange layout.
- An optional **canon type** is one of `locked`, `rule`, `consequence`, or `open`, matching the
  ledger's `K`, `L`, `D`, and `O` prefixes. It is optional because a rule may be written directly in
  the application without coming from a ledger.
- The record is still reached at its numeric URL. This decision is about identity and citation, not
  about the route: changing the URL is a separate question and nothing needs it yet.
- Existing rows are not backfilled by a migration. The source is imported again, which supplies the
  ledger's own slug and name, so a migration inventing them from the statement would only be undone.

## Consequences

### Benefits

- The import can address a rule by the id the source already uses, and a re-import finds the same
  rule rather than creating a second copy.
- A rule can be renamed without breaking a citation that stored its slug.
- The list, search results, and details page can show a short title instead of a full sentence.
- The category and type make the ledger's own grouping and distinction available to the interface
  without deriving them from prose.

### Costs and constraints

- `slug` and `name` are required by the model but nullable in the table, because SQLite cannot add a
  `NOT NULL` column without a default and a blank default would collide under the unique index. A
  row written before this decision has no name; the application shows its statement until the
  source is imported again.
- Two rules in one Universe can no longer share a slug, so an import that maps two ledger items to
  the same id must fail rather than overwrite.
- ADR 0039's addressed-by-id rationale no longer describes the record. Its ownership and
  not-an-analyzer decisions still hold, so it is superseded in part rather than replaced.

## Alternatives considered

- **Keep the numeric id and add only a name:** rejected because the ledger id is the source's
  identity for the item, and a re-import could not match it to the existing row.
- **Use `HasSlug` like Character and Plot:** rejected because that concern regenerates the slug
  whenever the name changes, which is the one thing a citation cannot survive.
- **Store the slug exactly as the ledger writes it, including case:** rejected because a slug is
  lowercase everywhere else in the application, and a second casing rule for one model is how a
  lookup starts failing on one page and not another.
- **Derive the canon type from the slug prefix at read time:** rejected because a manually written
  rule has no prefix, and the stored value is what the editor and the import can disagree about
  visibly rather than in a helper.

## Related documentation

- [Canon rules](../features/canon.md) — the record, the workspace, and the import.
- [Data model](../data_model.md#content-tables) — the table, its index, and its validations.
- [Story interchange](../features/story_interchange.md) — the ledger ids and area files the slug,
  name, category, and type come from.
