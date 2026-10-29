# Canon rules

A Canon Rule records one rule the fiction must obey — what magic costs, how long a road takes, what
nobody can survive — together with an optional passage the rule comes from. The ownership decision and
its rejected alternatives are in [ADR 0039](../adr/0039-canon-rules-are-universe-owned-with-an-optional-story.md);
the rule's name, slug, category, and canon type are in
[ADR 0045](../adr/0045-a-canon-rule-has-a-name-and-a-stable-slug.md); the table is in
[data_model.md](../data_model.md#content-tables).

A rule is not a Scene Tag, a Trope, or a profile answer. A tag classifies a record, a trope names a
storytelling pattern, and a profile answer states a fact about one record. A rule is a constraint the
author wants to be able to cite while checking prose, so it has its own stable id.

## Ownership

A rule always belongs to a Universe. Its `story_id` is optional:

- **no story** — the rule holds across the whole Universe, and every Story in it follows it;
- **a Story** — only that Story owns the rule, for a retelling or a story-local constraint.

The Story must belong to the same Universe. That is an application-level validation, like the other
cross-scope references in the application, because the two foreign keys cannot prove it. A Story that
is soft-deleted takes its own rules with it; the Universe's rules are untouched, and a rule is
restored separately.

## The record

A rule has a required **name**, a required **slug**, an optional **category**, an optional **canon
type**, a required **statement**, and an optional **source**.

- **name** is the short title the list row, the search result, and the details page show.
- **slug** is the stable address. It is the story-interchange ledger id when the rule came from a
  source (`L2` becomes `l2`, because a slug is lowercase and hyphenated like every other slug in the
  application) and the name parameterized otherwise. It is assigned once and is not regenerated when
  the rule is renamed, so a citation that stored it keeps pointing at the rule. It is unique inside
  its Universe among live rules.
- **category** is the source area the rule belongs to — the area file's name without its extension
  in the interchange layout. It is free text, so a rule written in the application may name any area
  or none.
- **canon type** is one of `locked`, `rule`, `consequence`, or `open`, matching the ledger's `K`,
  `L`, `D`, and `O` prefixes. It is optional, because a rule can be written straight into the
  application without coming from a ledger. An open question imported from a ledger is stored as a
  rule of type `open`, beside the rules it questions; [ADR 0046](../adr/0046-an-open-canon-question-is-a-rule-of-type-open.md)
  owns that decision.
- **statement** is the rule itself: one short sentence the Story must obey.
- **source** is the passage the rule comes from — a quotation, a chapter reference, or a citation.

Name, statement, and source are author prose and are never translated. A rule is still reached at its
numeric URL: the slug is the rule's identity for citation, not its route.

Rules are flat and unordered. They are not hierarchical, positioned, tagged, or photographed, and a
Story does not get a second canon workspace beside its Sections, Plots, and Scenes.

## The Canon workspace

The workspace is `/u/:universe_slug/canon`, opened from **Canon** in the Universe Bible sidebar, with
a read-only details page at `/u/:universe_slug/canon/:id`. It is the flat list + modal pattern: every
rule in the Universe appears in one list, universe-wide rules first, each row naming its name, slug,
canon type, category, statement, owner, and linking to the Story when one owns it. The editor holds
the name, slug, category, canon type, statement, source passage, and an optional owner; choosing
**The whole universe** is how a rule is handed back to every Story. A blank slug is derived from the
name on create and then left alone.

Index and Details are guest-readable. Create, update, and delete are HTML-flow mutations, so a refused
submission re-renders the list with the shared error summary and reopens the editor on the rejected
values. In a draft-based Universe the change is remembered rather than written.

A rule is searchable by its name, statement, and source, and a result opens its details page. It also
carries the optional discussion thread every content record does. Neither the list nor the details
page checks prose against a rule: the continuity findings inbox and the contradiction analyzer are the
surfaces that will read these records, and their contract is elsewhere.

## Development-data manifests

Each registered Universe directory carries `canon_rules.yml`, loaded after its Stories. A manifest
always names `universe:`, `slug:`, and `name:`, names `story:` only when one Story owns the rule, and
may name `category:` and `canon_type:`. Verify the files with `script/demo check dark` and
`script/demo check lotr`; rebuild the local Universes with `script/demo reset dark lotr`, sign in as
`dark@dark` (or `lotr@lotr`) with the configured development password, and visit `/u/dark/canon` or
`/u/lotr/canon`.
