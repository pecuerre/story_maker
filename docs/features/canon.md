# Canon rules

A Canon Rule records one rule the fiction must obey — what magic costs, how long a road takes, what
nobody can survive — together with an optional passage the rule comes from. The ownership decision and
its rejected alternatives are in [ADR 0039](../adr/0039-canon-rules-are-universe-owned-with-an-optional-story.md);
the table is in [data_model.md](../data_model.md#content-tables).

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

The required **statement** is the rule itself: one short sentence the Story must obey. The optional
**source** is the passage the rule comes from — a quotation, a chapter reference, or a citation. Both
are author prose and are never translated.

A rule is addressed by its numeric id, not a slug: its identity is the statement, so a slug would
change when the author reworded the rule and break any citation that stored it. The
[story interchange](story_interchange.md) can therefore point at a rule by id without the row moving.

Rules are flat and unordered. They are not hierarchical, positioned, tagged, or photographed, and a
Story does not get a second canon workspace beside its Sections, Plots, and Scenes.

## The Canon workspace

The workspace is `/u/:universe_slug/canon`, opened from **Canon** in the Universe Bible sidebar, with
a read-only details page at `/u/:universe_slug/canon/:id`. It is the flat list + modal pattern: every
rule in the Universe appears in one list, universe-wide rules first, each row naming its owner and
linking to the Story when one owns it. The editor holds the statement, the source passage, and an
optional owner; choosing **The whole universe** is how a rule is handed back to every Story.

Index and Details are guest-readable. Create, update, and delete are HTML-flow mutations, so a refused
submission re-renders the list with the shared error summary and reopens the editor on the rejected
values. In a draft-based Universe the change is remembered rather than written.

A rule is searchable by its statement and source, and a result opens its details page. It also carries
the optional discussion thread every content record does. Neither the list nor the details page checks
prose against a rule: the continuity findings inbox and the contradiction analyzer are the surfaces
that will read these records, and their contract is elsewhere.

## Development-data manifests

Each registered Universe directory carries `canon_rules.yml`, loaded after its Stories. A manifest
always names `universe:` and names `story:` only when one Story owns the rule. Verify the files with
`script/demo check dark` and `script/demo check lotr`; rebuild the local Universes with
`script/demo reset dark lotr`, sign in as `dark@dark` (or `lotr@lotr`) with the configured development
password, and visit `/u/dark/canon` or `/u/lotr/canon`.
