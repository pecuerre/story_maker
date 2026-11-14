# Visual Directions — 2026-11-14

This document presents three visual directions and records the owner's choice. The three proposals
began as a static comparison: no application token, stylesheet, view, or behaviour changed while the
direction was being chosen. The chosen **Index** direction has since been applied to the workspace
shell, the representative screens, and the remaining workspaces through the rollout slices; the
built values are in [visual_design.md](visual_design.md). The aim, users, constraints, and
representative screens remain owned by [visual_design_brief.md](visual_design_brief.md); the built
system remains owned by [visual_design.md](visual_design.md). This document owns the proposed
directions, their tradeoffs, the contrast and font checks, and the recommendation.

The three directions are **Index** (a reference atlas), **Ledger** (a dense data index), and
**Folio** (an editorial workspace). Each is applied to the same screens with the same content, so
the comparison is like-for-like. The review prototype is
[visual_directions_prototype.html](visual_directions_prototype.html). On 2026-11-14 the owner chose
**Index**; [ADR 0047](adr/0047-adopt-index-as-the-visual-direction.md) records the decision, and the
three proposals remain in this document as the comparison record.

## How to review the prototype

Open the prototype in a browser. The review bar switches **Direction**, **Light/Dark**, **Language**,
and **Screen** without reloading. The **Español (labels)** mode is a stress test, not a full
translation: it replaces interface labels and counts with longer Spanish strings while record prose
and page descriptions stay in English, so the rails, filters, and row groups are tested at their
longest. The screens are:

- **Story overview** — the shell, a populated Story, structure and planning panels, and the
  scenes-per-character chart.
- **Empty overview** — the same shell and header with a Story that has no Sections or Scenes, and
  the two starting points.
- **Characters** — the flat list with its filter, counts, row menu, and Details link.
- **Tags tree** — the taxonomy tree with a scope switch, indentation, count pills, and row actions.
- **Character details** — a record page with identity facts, serif profile prose, related scenes,
  and relations.
- **Scene details** — the read-only Scene page, opening with prose Elements before the identity
  facts.
- **Scene editor** — the editable Scene form, with the Element list and optional disclosures.

A screen can also be opened directly, for example
`visual_directions_prototype.html?dir=ledger&theme=dark&screen=characters`. Adding `&chrome=0`
hides the review bar for a clean screenshot.

The prototype is a hand-built static mock of the real markup, not a running Rails page. Its colours,
type sizes, spacing, and component shapes are exact to the proposals; its content is representative,
not live data. Screenshots captured during the review are in
`/tmp/opencode/visual-directions-2026-11-14/shots/` (temporary, not committed): 1440-pixel desktop
and 768-pixel tablet captures for every screen in both themes, 390-pixel phone spot checks for the
overview, Characters list, Character details, and Scene editor, and the Spanish label stress test at
1440, 768, and 390 on the overview and Characters list.

## The shared test set and baseline

The 2026-11-13 rendered audit measured the baseline this exploration has to improve:

- **Density.** At 1440, the two sidebars take 480 pixels and leave 940 for content. A Character row
  is 98 pixels tall, a Scene row 65, so peer lists disagree.
- **Hierarchy.** Several pages show two solid primary buttons — the header action and the filter
  submit. The Story structure card offers three equal outline buttons. Scene headers put their
  primary action after secondary destinations.
- **Chrome.** The photo file input keeps light browser chrome in dark mode, the Details link uses a
  new-tab icon for same-tab navigation, and Scene tags stacks two identical tab bars.

These directions do not decide the three local defects that do not depend on a direction; those
are backlog items 97–99. They do answer the questions that do: how dense the workspace should be,
where hierarchy comes from, how much of the shell is permanent, and what the palette and type feel
like.

Every direction keeps the brief's constraints: Bootstrap 5.3 and the existing page patterns, tokens
in `_theme.scss` and `--um-*`, both themes designed together, 4.5:1 text and 3:1 control boundaries,
visible focus, 40-pixel-tall rows at minimum on phones, no second framework, and no web-font
dependency. Colour still carries meaning: danger red is action-only, scope hues stay in their
sidebar blocks, and tag colours remain author data.

## Direction A — Index: the reference atlas

Index is the brief's **reference atlas** taken literally. The page reads like a well-made reference
volume: a warm paper canvas, dark ink, serif titles and prose, hairline rules between facts, and
chrome that recedes. It changes the visual language more than it changes the information
architecture.

**Palette.** Light is warm paper rather than cool app gray, which separates the workspace from a
generic admin console without adding decoration. Dark is a warm near-black, not a blue-gray
inversion. The primary is an ink blue, deep enough to carry white button labels and quiet enough to
sit beside the three scope hues.

| Role | Light | Dark |
|---|---:|---:|
| Canvas | `#F6F4EE` | `#171613` |
| Surface | `#FFFDF8` | `#1E1C18` |
| Sunken surface | `#ECE8DD` | `#28241E` |
| Text | `#1E1D1A` | `#ECE7DC` |
| Secondary text | `#5F5A50` | `#B3AB9B` |
| Hairline | `#D3CCBC` | `#3D382E` |
| Control border | `#8C8371` | `#8B8272` |
| Primary | `#1D4F7A` | `#9CC0E0` |
| On primary | `#FFFFFF` | `#0D2237` |
| Primary soft | `#E4EDF5` | `#22384B` |
| Success | `#2C6B45` | `#84C59E` |
| Warning | `#835600` | `#DDB05C` |
| Danger | `#A32626` | `#F09999` |
| Universe scope | `#244A7C` on `#E7EDF6` | `#9DB7DD` on `#223449` |
| Story scope | `#8A2F3A` on `#F6E6E8` | `#EDA3AB` on `#3A2427` |
| Tools scope | `#2A6A4B` on `#E5F0E9` | `#8CCBAA` on `#1E352B` |

**Type and prose.** The UI stays on the system sans stack. Titles and prose use a system serif
stack: `"Iowan Old Style", "Palatino Linotype", Palatino, "Book Antiqua", Georgia, "Times New
Roman", serif`. Base text is 15px/1.5; H1 is 30px/1.18 at weight 600; H2 19px/1.3; H3 15px/1.4.
Metadata is 12.5px, and section kickers are 10.5px uppercase with 0.11em tracking. Record prose is
17px/1.68 with a 68-character measure. Fact labels are uppercase 11px; values are sentence case.
The serif is the hierarchy device, so headings do not need boxes.

**Shell, density, and components.** The left rail narrows from 256 to 232 pixels and the right tools
rail from 224 to 204, and the content cap rises to 1,040 pixels. At 1440 the rendered page still
fills about 940 pixels after its own padding, so Index's density gain comes from the 46-pixel row and
the type scale rather than from a materially wider column; the real width gain needs Folio's removed
rail. List rows settle at 46 pixels, between the old 98-pixel Character row and 65-pixel Scene row,
with one clamped summary line. A card is used only for a genuine group; facts are a labelled
definition grid separated by hairlines, not a stack of tiles. Buttons are flat with 3–4px corners;
there is no shadow. Charts have squared bars. Tag chips are hairline rectangles. The primary action
remains a single solid ink-blue control per page, with filters and secondary actions outlined or
quiet.

**Tradeoffs.** Index gains the strongest match to the brief, a real density increase without a new
page pattern, and a clear type-led hierarchy that removes several nested borders. It also has the
lowest rollout risk: most of it is palette, type, spacing, and component tokens, not a new shell.

It costs some cross-platform fidelity: Iowan Old Style exists on Apple platforms, so Windows and
Linux fall through Palatino, Book Antiqua, Georgia, or Times New Roman. Georgia's larger x-height
makes a 17px serif look bigger than Palatino's, and headings will not be pixel-identical across
operating systems. That is acceptable for a system stack but must be checked on the actual
machines. A 46-pixel row is denser than today's 98-pixel Character row yet taller than today's
65-pixel Scene row, so a Scene list grows slightly. The warm neutrals need re-checking against
author-chosen tag colours, especially pale tags that were chosen against a cool white.

## Direction B — Ledger: the dense index

Ledger treats the workspace as a **data surface** first. It is monochrome, compact, and tabular:
narrow rails, 40-pixel rows, leading row numbers, right-aligned figures, square corners, and a
single deep-green accent. It is the direction most comfortable with a large universe and the least
interested in looking like a book.

**Palette.** Light is a cool near-white with graphite text; dark is a blue-black with mint used
sparingly. The primary is deep green rather than the current blue, so it is unmistakably a different
direction. Scope hues keep their families but are desaturated to match the denser surface.

| Role | Light | Dark |
|---|---:|---:|
| Canvas | `#F8F9FA` | `#101416` |
| Surface | `#FFFFFF` | `#171C1F` |
| Sunken surface | `#EEF1F3` | `#20262A` |
| Text | `#15181B` | `#E4E9EC` |
| Secondary text | `#566069` | `#A2B1BA` |
| Hairline | `#CDD5DB` | `#313B42` |
| Control border | `#818D95` | `#7E8D96` |
| Primary | `#0C6B5D` | `#6AD8C3` |
| On primary | `#FFFFFF` | `#05201B` |
| Primary soft | `#E2F1EE` | `#1D3A35` |
| Success | `#1D7A4B` | `#7ACB9C` |
| Warning | `#7D5600` | `#E3B45C` |
| Danger | `#B42318` | `#FFA09A` |
| Universe scope | `#1E4F86` on `#E8EEF6` | `#8FB8E8` on `#1D2F40` |
| Story scope | `#8A2533` on `#F9E7E9` | `#F09AA4` on `#3A2024` |
| Tools scope | `#176B4D` on `#E2F2EB` | `#7AD3AB` on `#173127` |

**Type and prose.** Everything is the system sans stack; there is no serif anywhere. Base text is
13.5px/1.45; H1 is 24px/1.18 at weight 680 with −0.02em tracking; H2 15.5px/1.3; H3 13.5px/1.35.
Metadata is 11.5px, and kickers are 10px uppercase with 0.12em tracking. Record prose is 15.5px/1.6
with a 64-character measure. Figures are tabular by default, and labels are uppercase 10.5px.
Prose remains readable, but it is a data view's prose, not a book's.

**Shell, density, and components.** Rails are 216 and 184 pixels, and content can grow to 1,180
pixels; the main padding drops to 22–24 pixels. Rows are 40 pixels on desktop and rise to 44 below
the tablet breakpoint so the phone keeps its touch target. Fact rows are a compact two-column table
with the label at the left and the figure right-aligned; list rows carry a leading two-digit index.
Tag chips are square and transparent, cards have a 2px corner and no shadow, chart bars are square,
and the page header can sit on a faint band. The filter is a single inline row rather than a block
of labelled fields.

**Tradeoffs.** Ledger puts the most records and facts on one screen, which is exactly what a large
universe or a comparison-heavy analytics session wants. It is the most consistent with the
"reference work" half of the brief and the least likely to waste width.

Its risk is the other half of the brief. At 13.5px with 40px rows, a phone-width exception, and
uppercase labels throughout, it can read as an administration console rather than a calm writing
workspace. Prose is sans and smaller, so a Scene editor feels like a form instead of a page. Spanish
labels are the longest strings in the application; the compact header, filter row, and row side
group are where they will wrap or truncate first. Its density is tuned for 1440 pixels, so an
1100-pixel laptop sees much less of it.

## Direction C — Folio: the editorial workspace

Folio is the **editorial** reading of the brief. It keeps the atlas's facts and links but gives the
page more air, one permanent rail instead of two, rounded surfaces with a soft shadow, and the most
generous prose setting. It is the direction a writer would choose to read in; it is also the one a
reader scanning a forty-row table would notice first.

**Palette.** Light is a warm blush-neutral with a plum primary; dark is a warm charcoal with a
lilac primary. The plum is deliberately far from danger red and from the story scope's crimson. The
scope hues stay recognisable but are warmed slightly to sit on the blush canvas.

| Role | Light | Dark |
|---|---:|---:|
| Canvas | `#F7F3EF` | `#1A1718` |
| Surface | `#FFFDFB` | `#221E20` |
| Sunken surface | `#EFE8E2` | `#2C2529` |
| Text | `#211E1B` | `#EFE8E4` |
| Secondary text | `#685F57` | `#B9ACA3` |
| Hairline | `#DCCFC4` | `#443B3F` |
| Control border | `#958273` | `#8E7D84` |
| Primary | `#6B3F5E` | `#D6A7C7` |
| On primary | `#FFFFFF` | `#2C1225` |
| Primary soft | `#F2E7EF` | `#3B2A35` |
| Success | `#356A4C` | `#86C7A4` |
| Warning | `#835600` | `#E0B25B` |
| Danger | `#A52F2F` | `#F39B98` |
| Universe scope | `#2C4A7A` on `#E9EEF7` | `#A3B9DF` on `#25313F` |
| Story scope | `#8A3040` on `#F8E8EA` | `#F0A4AE` on `#3B2428` |
| Tools scope | `#2F6A4F` on `#E8F1EC` | `#8BC9A8` on `#20352B` |

**Type and prose.** UI is the system sans stack; titles and prose use the same system serif stack as
Index. Base text is 15.5px/1.55; H1 is 34px/1.12 at weight 500; H2 21px/1.3; H3 16.5px/1.4.
Metadata is 12.5px. Record prose is 18px/1.72 with a 64-character measure, the most comfortable
reading setting of the three. The lighter heading weight and the extra leading are what make the
page feel authored rather than administrative.

**Shell, density, and components.** The left rail is 248 pixels, and the right tools column is
removed from the permanent shell. Configuration, collaboration, and the inspector open in a drawer
from a **Tools** button in the top bar at every width, including desktop. Content caps at 1,060
pixels with 34–40-pixel padding. Rows are 54 pixels; chart rows are 32. Cards have a 10px corner and
a very soft shadow; tag chips are pills; the record portrait is a rounded medallion; buttons use a
7px corner. The page header loses its rule and gains a small leading accent beside the kicker. Prose
keeps a 64-character measure even when the surrounding card is wider.

**Tradeoffs.** Folio gives prose the best home and the shell the most room. One rail plus a tools
drawer returns width and reduces the number of permanent scopes competing for attention. It is the
most distinctive of the three and the least like the current application.

It is also the lowest-density direction: 54-pixel rows and 30-pixel section gaps mean more
scrolling on the lists and analytics pages the brief says are the common visit. Moving Configuration
behind a drawer costs a click for frequent Settings and Members work. The rounded cards and shadow
edge toward the card gallery the brief explicitly rejects; the mock keeps cards only for real
groups, but the treatment is the hardest to keep disciplined during a rollout. It is also the
largest structural change — shell and navigation, not just tokens — so it carries the most
translation, responsive, and implementation risk.

## Contrast and font verification

The palettes were checked with the WCAG 2.x relative-luminance formula. Text targets 4.5:1 against
its background; control boundaries target 3:1 against the surface. The lowest sampled value in each
category is shown.

| Direction / theme | Text | Secondary | Link | Button label | Control border | Success | Warning | Danger | Scope hues (min) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Index light | 15.33 | 6.74 | 8.43 | 8.57 | 3.69 | 6.27 | 6.27 | 7.22 | 5.51 |
| Index dark | 14.67 | 7.46 | 8.93 | 8.48 | 4.48 | 8.47 | 8.46 | 7.87 | 6.19 |
| Ledger light | 16.91 | 6.42 | 6.41 | 6.41 | 3.40 | 5.33 | 6.56 | 6.57 | 5.59 |
| Ledger dark | 15.14 | 7.80 | 10.00 | 9.95 | 5.02 | 8.88 | 8.96 | 8.79 | 6.65 |
| Folio light | 15.02 | 6.15 | 8.29 | 8.41 | 3.62 | 6.24 | 6.28 | 6.79 | 5.53 |
| Folio dark | 14.69 | 7.45 | 8.01 | 8.37 | 4.25 | 8.41 | 8.39 | 7.81 | 6.64 |

All sampled text pairs pass 4.5:1 and every control boundary passes 3:1. Hairline dividers are
deliberately quieter than control borders; they separate content rather than identify a control,
and the current application's `#DFE3E8` hairline is below 3:1 for the same reason. The focus ring
uses the primary colour, which is at least 6.4:1 against its surface in every theme.

The 390-pixel Spanish stress pass found the chart's `4 de 24` count wrapping, so its count column
was widened; the tools rail's `Solicitudes de revisión` wraps to two lines rather than truncating.
No horizontal overflow appeared at 1440, 768, or 390 in either language.

Fonts were checked for licensing and loading before being proposed. All three directions use
operating-system fonts only. There is no `@font-face`, no network request, no font cache, and no
layout shift. The serif stacks are composed of fonts the operating system supplies under its own
licence; none is redistributed with the application. The stack ends in generic `serif`, so an
unknown platform degrades to its own serif rather than to a missing glyph. Iowan Old Style is
Apple-only and Palatino, Book Antiqua, Georgia, and Times New Roman cover the other platforms; the
difference in x-height and width is the main fallback risk, which is why headings and prose use a
`ch`-based measure.

Web fonts were considered and rejected. Inter, Source Serif 4, and IBM Plex Sans are all
open-licensed and technically suitable, but each adds roughly 100–300 kB, needs a `font-display`
decision and a metrics-matched fallback, and contradicts the brief's explicit exclusion of a
web-font dependency. If a later prototype finds the system serif unacceptable, the next step is a
self-hosted OFL face with a measured fallback, not a hosted font service.

Not verified: contrast in the running Rails application after Bootstrap's own variables are
applied; the exact fallback font chosen by each operating system; Windows, Android, or iOS
rendering; print; forced-colors/high-contrast mode; colour-blind simulation; and real screen-reader
use. The prototype's flat colours and shadows are representative, not a rendering guarantee.

## Recommendation

**Chosen: Index.** On 2026-11-14 the owner accepted the recommendation;
[ADR 0047](adr/0047-adopt-index-as-the-visual-direction.md) records the decision. Index is the
closest to the agreed reference atlas, it improves the measured density and hierarchy problems
without inventing a new page pattern, and it can be rolled out with the least risk. It also leaves
room to borrow the other directions' strengths later:

- from **Ledger**, the tabular treatment for the appearance grid, scene matrix, and inspector
  figures, where right-aligned numerals and a compact header genuinely help comparison;
- from **Folio**, the 64-character prose measure and generous Element editing surface, without its
  one-rail shell or card treatment.

The choice is not a hybrid. Mixing the three at the token level is how the current system
accumulated competing blues, shadows, and equal-weight buttons. Index is chosen first; its own
components can absorb a specific pattern from another direction later, when that pattern has a job
to do.

The prototype stage applied Index's palette, type, 46-pixel row, narrower rails, and fact/rules
treatment to the workspace shell and the representative screens on 2026-11-14, then reviewed real
screenshots in both themes, at 1440, 768, and 390, in English and Spanish. The applied values and
component treatments now live in [visual_design.md](visual_design.md); the review captures are in
`/tmp/opencode/visual-index-prototype-2026-11-14/shots/` (temporary, not committed). The likely
pressure points found in the review were the long Spanish labels in the narrowed rails, the
system-serif fallback on Linux, and tag colours chosen against the old cool white.

Ledger and Folio remain the alternatives considered. Had Ledger been chosen, its first question
would have been whether 13.5px/40px is comfortable for prose editing and for Spanish; had Folio been
chosen, its first question would have been whether moving tools into a drawer harms frequent
Configuration and Inspector use.

## What this does not decide

- It does not fix the final token values; the applied prototype may refine the selected palette and
  type before the rollout.
- It does not settle the local defects in backlog items 97–99, the export-scope wording, the
  analytics navigation, or the two-tab-bar scope switch. The Tags screen shows only the scope
  switch so the second bar does not become a direction decision; backlog item 99 owns that
  treatment.
- It does not roll Index out to every screen. The applied prototype changes the shell, the shared
  tokens, and the representative screens; the remaining workspaces are validated in the slices
  owned by backlog item 91, and a screen found wanting is refined there rather than by mixing in
  Ledger or Folio.
