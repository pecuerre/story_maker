# ADR 0031: Model story-owned Plot arcs across Scenes

- **Status:** Accepted
- **Date:** 2026-10-24
- **Related:** [ADR 0007](0007-story-owned-scenes-and-elements.md), [Scenes](../features/scenes.md), [Data model](../data_model.md)

## Context

Sections already organize a Story's script, and Scene Tags already classify its Scenes. A separate
Plot concept only earns a model if it means something neither can express. A story may have a named
through-line — such as a mystery or relationship arc — that connects Scenes across Sections, while a
Scene can participate in several through-lines.

## Decision

- A Plot is a named story-owned through-line with an optional description.
- Plot and Scene have a same-Story many-to-many relationship. A Plot is not a Section, a Scene Tag,
  or an ordered Scene group; assignments never change Section grouping or narrative order.
- Plots are flat, unordered records. Writers manage them in a story-scoped flat list with a modal,
  inspect linked Scenes on a Plot details page, and assign Plots in the existing Scene editor.
- Plot deletion is soft and retains its join rows for restoration. It never deletes or reorders Scenes.

## Consequences

This adds one story-owned table and one join table, plus a second grouping axis on Scene. Story scope
is enforced in both association writers and the development-data loader, because foreign keys alone
cannot prove it. Plot records participate in story authorization, the existing search index, and the
Story workspace navigation. There is no Plot hierarchy, manual order, tag assignment, or analyzer.

## Alternatives considered

- **Sections:** rejected because they are a hierarchy for organizing the script, and one Scene has at
  most one Section; a through-line can cross Sections and overlap another Plot.
- **Scene Tags:** rejected because they classify individual Scenes and do not provide a named record
  with its own description and linked-Scene details page.
- **`plot_id` on Scene:** rejected because it permits only one Plot per Scene and cannot represent
  overlapping arcs.

## Related documentation

- [Plot arcs](../features/plots.md) — current behavior and the workspace contract.
- [Scenes](../features/scenes.md) — Scene ownership and narrative order.
- [Data model](../data_model.md#stories--sections) — tables and scope constraints.
