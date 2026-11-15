# ADR 0048: Give the Narrative order comparison a visual chart view

- **Status:** Accepted
- **Date:** 2026-11-15
- **Related:** [`../features/scenes.md`](../features/scenes.md),
  [`../visual_design.md`](../visual_design.md),
  [0037](0037-compare-narrative-order-with-the-timeline-read-only.md),
  [0012](0012-client-side-verification-and-csrf.md)

## Context

[ADR 0037](0037-compare-narrative-order-with-the-timeline-read-only.md) put the Story's telling order
and the Universe Timeline side by side as two lists, and deliberately drew no connectors: the two
lists do not align row for row, so a line between them would claim an alignment they do not have.

A reader can still hold only one reading at a time. A run of flashbacks is a scatter of rows in the
left list and its mirror in the right one; the shape of the reversal is exactly what two lists are
worst at showing. The owner asked for a second, visual view of the same comparison: two columns, one
line per Scene, the lines dim at rest and one line standing out when its Scene is pointed at or
focused — "something similar to a Sankey diagram".

The constraints are the ones the comparison already has. `Scene.position` is the telling order and
`TimelineLayout` is the only authority for when Events happen. The page reads saved records and
never rewrites them. Nothing new is stored, so the visual view may not add a column, a verdict, or a
flag. The page stays signed-in and keeps the universe's read authorization.

## Decision

### The comparison gains a second view, not a second page subject

The Narrative order page keeps one route and one `NarrativeComparison`. It gains a URL-backed
**List** / **Chart** strip, so `?view=chart` is the chart's canonical link and the bare URL stays the
list:

```text
GET /u/:universe_slug/s/:story_id/narrative_order          # List (default)
GET /u/:universe_slug/s/:story_id/narrative_order?view=chart # Chart
```

An unknown `view` value is the list. The strip is the shared `content_tabs` component with `active`
passed explicitly, like the Scene editor's tabs, so it is never an in-document Bootstrap pane and
the page gets no new route, action, or permission.

### Both columns hold every Scene, ordered by the two questions

The chart draws the Story's Scenes, not the Timeline's Event list:

- **Left — the narrative order.** `position` order, the same sequence the list's left column uses.
- **Right — the chronological order.** The same Scenes sorted by the Timeline row of the Event that
  places them, then by `position`. A Scene the Timeline cannot place has no chronological row, so it
  keeps narrative order in a band below a dashed rule.

Every Scene appears in both columns, so both column counts are the Story's Scene count. This is what
makes one line per Scene possible, and it is why a crossing line means exactly one thing: the Story
tells two Scenes in an order the Timeline reverses. The chart still calls that a flashback, a cold
open, or a parallel thread, never an error, and it never claims to know which one.

The right column is therefore a different question from the list view's right column. The list keeps
the whole Timeline, including Events no Scene depicts; the chart has no place to put an Event that is
not a Scene, and inventing one would break the one-line-per-Scene reading. The List view remains the
complete Timeline reading and the text alternative.

### The chart is a read, drawn by the server

`NarrativeChartLayout` reads the comparison and computes the column order, each bar's y in both
columns, the bar height, the dashed separator, and every connector path. The view renders those
values and sorts nothing; the domain order stays in one place, as ADR 0037 requires.

The SVG is server-rendered and complete before JavaScript runs. A bar is a link to the Scene with an
accessible name (`Narrative position N of M · Scene name · Step`), so every row is reachable and
named without the script, and the browser's own tooltip shows that name. The right column's bar is
the same link with `tabindex="-1"`: it is clickable, but a Scene is one tab stop, not two.

### The lines are dim until a Scene is chosen

At rest every connector is a light border-color line at reduced opacity, so the field reads as a
quiet texture and the two columns stay the subject. Pointing at or focusing a bar gives that Scene's
two bars the primary color and its line full weight, and recedes the others. Leaving the chart returns
the lines to rest. The highlighted Scene's facts — position, title link, Section, Events, own time,
step, and conflict — appear in the panel below the chart, with the same markup the list row uses.

The panel sits below the chart on purpose: a taller card (a conflict adds a line) must not move the
bars out from under the pointer.

### A density tradeoff, chosen deliberately

A Story's bars are compressed towards one screen: the row pitch shrinks from 12 to 4 SVG units, and
only below that minimum does the region scroll. At these heights a visible label per bar is
impossible, so the chart relies on the accessible name, the browser tooltip, and the detail panel.
That is accepted because the List view is the labeled reading; the chart exists for shape, not for
reading titles one by one.

The script is one small Stimulus controller that only toggles classes and a `hidden` attribute. It
builds no text, moves no bar, and reads no translation. Its Bun and browser coverage follows
[ADR 0012](0012-client-side-verification-and-csrf.md).

### What this does not change

- No new storage, route, permission, filter, or sort control.
- No flashback, parallel-thread, or out-of-order marker is stored or inferred.
- No Scene, Event, `position`, or `datetime` is rewritten, and no conflict is resolved.
- The list view's two columns keep ADR 0037's rule and still draw no connectors between themselves;
  the chart's lines join a Scene to itself, which is the one alignment the two columns do have.
- No draft change is projected; the chart reads saved records like the Timeline.

## Consequences

### Benefits

- The shape of the telling — a run of flashbacks, a crossing, a parallel stretch — is visible at once,
  which is the question two lists answer worst.
- Both views read the same comparison and cannot disagree about which Scene is placed where.
- The chart adds no data and no server-side surface: the layout is derived per request from records
  the page already loads.

### Costs and constraints

- A second view of one page to keep documented and tested, and one more client-side behaviour.
- The chart cannot show an Event no Scene depicts, so it is not a Timeline view; a reader who wants
  the Universe's whole chronology reads the List view.
- With no visible labels, a reader who cannot see the chart gets the accessible names and the list.
  A very long Story compresses to the minimum pitch and scrolls.

## Alternatives considered

### In-page Bootstrap tabs with no URL

Both views would be in one response and switch instantly, but neither would have a link, and the
application has no in-document tab pattern. The URL-backed strip matches the Scene editor and keeps a
chart link shareable.

### Visible labels on every bar

At several pixels per Scene a label does not fit, and scaling the chart up to fit labels gives up the
one-screen overview that motivated the view. The known cost is hover or focus.

### A tooltip that follows the pointer

It would put the facts next to the cursor, but it is another positioned surface to keep inside the
viewport, it cannot be read with the keyboard, and its text would have to be built on the client. The
fixed panel below the chart uses the server-rendered rows instead.

### Keep the Timeline's Event rows on the right

That keeps the chart's right column identical to the list view's, but several Scenes converge on one
Event row and Events with no Scene have no line. A reader could no longer see which two Scenes
reversed, which is the reason the chart exists.

### Draw connectors in the list view

The lists do not align row for row, and ADR 0037's reason for refusing connectors there is still
true. Only the chart, where both columns are the same Scenes and align by identity, gets lines.

## Related documentation

- [`../features/scenes.md`](../features/scenes.md#narrative-order-beside-the-timeline) — the page's
  current rules, both views, and the conflict definition.
- [`../visual_design.md`](../visual_design.md#narrative-order-chart) — the chart's painted shape.
- [ADR 0037](0037-compare-narrative-order-with-the-timeline-read-only.md) — why the comparison exists
  and what it refuses to claim.
- [ADR 0012](0012-client-side-verification-and-csrf.md) — how the chart's script is verified.
