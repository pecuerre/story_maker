# ADR 0046: An open canon question is a canon rule of type open

- **Status:** Accepted
- **Date:** 2026-10-29
- **Related:** [ADR 0039](0039-canon-rules-are-universe-owned-with-an-optional-story.md), [ADR 0045](0045-a-canon-rule-has-a-name-and-a-stable-slug.md), [Canon rules](../features/canon.md), [Story interchange](../features/story_interchange.md)

## Context

The story-interchange ledger has four kinds of item, told apart by the id prefix: `K` locked facts,
`L` rules of the mechanism, `D` derived consequences, and `O` open questions. The Canon Rule record
already stores a canon type with exactly those four values, and the workspace shows it as a badge.

The import originally wrote only `K`/`L`/`D` and reported every `O` item by id, because ADR 0039
defines a rule as a constraint the prose must obey and an open question is not one. That left the
`open` type reachable only by hand, and it dropped 57 items from the real source — the questions the
author is still working through, which are the most useful thing to see beside the rules that touch
them.

## Decision

- An `O` item is written as a Canon Rule with `canon_type` `open`.
- It keeps everything the other items keep: its lowercased id as the slug, its statement as the name
  when it has no title, its area file as the category, and its whole cleaned text as the source.
- The validator still counts the `O` items separately as open canon questions for the preview and the
  validate task, but the Canon slice writes them instead of reporting them.
- The Canon workspace does not get a second list. A question sits with the universe's rules and is
  distinguished by its **Open question** badge, so the reader sees what is settled and what is not
  in one place.

## Consequences

### Benefits

- Nothing in the ledger is dropped from an import: the workspace holds the rules and the questions
  they leave open.
- The `open` type has a real source instead of being reachable only by hand.
- A question keeps its id, so it can still be cited while it is unanswered.

### Costs and constraints

- The Canon Rule record now includes a kind of record that is not a constraint. The statement of an
  open question is a question, and nothing may treat every rule as an enforceable fact. The
  continuity findings inbox and the contradiction analyzer must skip, or handle, `open` rules when
  they read this table.
- The record has no "answered" state. An answered question is reworded or retyped by the author; the
  ledger's `Answered (K1)` prose stays in its text.
- Importing a source no longer reports `O` ids, so the run page and preview count them as written
  records. The validate task still names them separately so an operator can see how many questions
  the source holds.

## Alternatives considered

- **Keep reporting `O` items and leave the type for hand entry:** rejected because the source's
  questions are part of its canon ledger, and dropping them from the import makes the workspace
  claim the universe is more settled than the author says it is.
- **A second table or a second list for questions:** rejected because both sides have the same
  identity, title, category, passage, ownership, and search document; a second table would duplicate
  all of it and the workspace would have to say which list a citation belongs to.
- **A boolean "question" flag beside the type:** rejected because the type already says it, and two
  representations of one fact can disagree.

## Related documentation

- [Canon rules](../features/canon.md) — the record, the type badge, and the workspace.
- [Story interchange](../features/story_interchange.md) — the ledger item and what the import writes.
