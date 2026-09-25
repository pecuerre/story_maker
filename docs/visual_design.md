# Visual Design and UI Conventions

This document is the source of truth for Universe Maker's Bootstrap-based visual system and
information architecture. It describes decisions that affect shared views and CSS; it is not a
replacement for the domain rules in [`data_model.md`](data_model.md) or the request/routing rules
in [`architecture.md`](architecture.md).

## Design decision

Universe Maker stays on **Bootstrap 5.3**, Bootstrap Icons, Sass, PostCSS/autoprefixer, Hotwire,
and Stimulus. Do not introduce a second component framework or a utility-only CSS system.

The interface should feel like a calm writing workspace:

- content is the largest and most prominent area;
- navigation is quiet and scoped;
- one primary action is visually dominant per page;
- color is reserved for meaning, not decoration;
- destructive actions are visually distinct from navigation categories;
- the universe/story model is always explicit.

The workspace keeps a quiet, permanent right utility sidebar at wide breakpoints. Its **Settings**
section contains the real Members access manager, while the remaining Collaboration, Analytics,
and AI entries are deliberate `aria-disabled` placeholders that should become real destinations
as the underlying product areas are defined. Below the `xl` breakpoint the panel becomes a
Bootstrap `offcanvas-end`, so the main writing surface keeps priority on smaller screens.

## Theme tokens

Bootstrap variables live in
[`app/assets/stylesheets/_theme.scss`](../app/assets/stylesheets/_theme.scss), which is imported
**before** `bootstrap/scss/bootstrap` in `application.bootstrap.scss`. Change the palette,
typography scale, radii, or component defaults there rather than adding one-off overrides in
views.

Current starting palette:

| Token role | Value | Use |
|---|---:|---|
| Primary | `#3454d1` | primary buttons, selected navigation, focus/accent |
| Body background | `#f5f7fb` | page canvas |
| Body text | `#1f2937` | headings and primary copy |
| Secondary text | `#667085` | descriptions and metadata |
| Border | `#dfe3e8` | surfaces, list rows, separators |
| Success | `#2f855a` | successful status only |
| Warning | `#9a6700` | warning/attention status only |
| Danger | `#c92a2a` | destructive actions and errors |

Rules:

- Do not use danger red as a general category color for Characters, Locations, Events, or Items.
- User-defined tag colors are data, not theme colors. They may be rendered as colored badges, but
  they must not be used for active navigation or buttons.
- Check text/background contrast when adding a tag color. The badge shape and text must remain
  legible even when the chosen colors are poor.
- Prefer Bootstrap semantic variables (`$primary`, `$body-color`, `$border-color`, etc.) over
  hard-coded colors in feature partials.
- Keep the custom `--um-*` variables for shell/layout values that are not Bootstrap component
  defaults.

## Typography

The default system sans-serif stack is intentional; no web-font dependency is required for the
normal UI. The current scale starts at:

- `$h1-font-size: 2rem` for page titles;
- `$h2-font-size: 1.5rem` for major page sections;
- body text at Bootstrap's `1rem` base with a `1.5` line height;
- compact metadata at `.8125rem`–`.875rem`.

Use sentence case for page headings and normal sentence case for descriptions. Uppercase is
reserved for small navigation/section labels such as `STORY WORKSPACE`. Do not make every card
heading uppercase.

## Spacing and shape

- Use the Bootstrap spacing scale (`8px`, `12px`, `16px`, `24px`, `32px`) through utilities or the
  shared component classes.
- Interactive rows should generally be at least `40px` high; primary controls should retain a
  comfortable touch target.
- Shared page surfaces use a subtle border, `.5rem`–`.75rem` radius, and a very light shadow.
- Avoid global rules that shrink every `.nav-link` or `.list-group-item`. Component-specific
  classes such as `.sidebar-link`, `.entity-row`, and `.taxonomy-row` own their spacing.
- Do not use inline `style` attributes for layout or state. Existing tag color values are the
  intentional exception because they come from user data.

## Application shell

`app/views/layouts/application.html.erb` is the shell:

1. a fixed dark Bootstrap navbar;
2. a responsive left workspace navigation;
3. one flexible main content region with a `page-shell` wrapper;
4. a responsive right utility navigation;
5. a skip link and one shared flash region.

The navbar is intentionally explicit about context:

- `Universes` is the global picker;
- `Universe: <name>` is the current universe switcher;
- `Story: <name or Select>` is the current story switcher;
- `Account` contains the signed-in email and logout action.

The navbar does not render placeholder links. The right utility sidebar is the one intentional
exception: its `aria-disabled` entries reserve space for future Collaboration, Analytics, and AI
features without presenting them as implemented routes.

### Responsive behavior

- At `lg` and above, the left workspace navigation is a 16rem sticky column.
- Below `lg`, it becomes a Bootstrap `offcanvas-start`; the main area shows a compact `Menu`
  button and the current universe/story context.
- At `xl` and above, the right utility navigation is a 14rem sticky column.
- Below `xl`, it becomes a Bootstrap `offcanvas-end`; the workspace bar exposes it through a
  `Tools` button. The `Menu` button is only shown below `lg`, when the left panel also needs an
  offcanvas trigger.
- The main column must have `min-width: 0` so long descriptions and tables do not break the grid.
- Keep `scroll-padding-top`/sticky offsets aligned with the fixed navbar height.

The old `.container-xl` 2/8/2 shell is not the content-arrangement model anymore. Use the shared
shell classes and let the main region grow.

## Navigation and information architecture

The left navigation is task-oriented and scope-aware:

### Story workspace

When a story is selected:

- Story overview;
- Sections;
- Scenes (a reserved placeholder for future story structure).

When no story is selected:

- All stories;
- a prompt explaining that a story must be selected for story-specific structure;
- Scenes (a reserved placeholder).

New story remains in the navbar's Story dropdown; it is not repeated as a sidebar button.

### Universe Bible

The Bible is a direct record list without People/Places/Time/Objects group labels:

- Characters;
- Locations;
- Events;
- Timeline;
- Items.

Characters open a two-tab **Characters / Relations** workspace, and Items open a two-tab **Items /
Ownerships** workspace. Locations, Events, and Sections each have a single record tab. These tabs
are URL-backed navigation, not in-document tab panes, so each page keeps its canonical URL and
mutation flow.

### Configuration

Configuration is a separate sidebar section. **Tags** opens the shared taxonomy workspace:
**Universe Tags** is selected by default and contains Character, Relation, Location, Event, Item,
and Ownership tag tabs; **Story Tags** contains the story-scoped Section tags tab. The right-side
**Settings** section contains **Members** for universe admins, where the read/write/admin access
list is managed. New configuration tools should be added as top-level entries here, grouped by
scope when needed.

Counts use aligned `.sidebar-count` pills. Current links use a soft primary background and
`aria-current="page"`; color is not the only state signal. The reserved Scenes and right-sidebar
entries are the intentional placeholders for future functionality.

### Right utility sidebar

The right sidebar contains a real **Settings** section with the universe **Members** access manager
for admins. Its other space is reserved for future **Analytics** and **AI** tools. Keeping the
access manager here leaves Configuration focused on shared taxonomy management while preserving a
stable home for richer collaboration and analysis features without adding fake routes.

## Shared view patterns

### Page header

Use `app/views/shared/_page_header.html.erb` for work pages. It accepts:

- `title` (required);
- `eyebrow` (scope label such as `Universe Bible` or `Story: ...`);
- `description`;
- `count` and `count_label`;
- a block for page actions.

The primary action belongs in the header's action area. On narrow screens actions wrap below the
copy. Avoid placing a title and its primary button in unrelated vertical sections.

### Empty states

Use `shared/_empty_state` for no records. It must explain what the record belongs to and why it is
useful. Tags remain optional in every empty-state message. Do not imply that a default tag is
required.

### Flat entity lists

Characters, items, events, relations, and ownerships use:

- `shared/_row_actions` for a neutral overflow menu;
- a visible name/title and tag badges;
- a short description clamped to a readable number of lines;
- a `content-surface`/`list-group` wrapper;
- a modal for quick create/edit, preserving the existing JSON-only mutation flow;
- mutation controls hidden for guests and read-only members, while the record content remains visible.

Relations should read naturally (`Character A → Character B`) rather than as an unlabeled database
row. Ownerships use the same readable relationship treatment.

### Related content navigation

Use `shared/_content_tabs` for related record workspaces. The Character workspace has Characters
and Relations; the Item workspace has Items and Ownerships. Locations, Events, and Sections each
have one record tab. Use `shared/_tag_workspace_navigation` for Configuration → Tags: the outer
Universe/Story selector is followed by the six universe taxonomy tabs or the single story Section
tags tab. All tabs are URL-backed Bootstrap `nav-tabs`: use the active class and
`aria-current="page"`, but do not add `data-bs-toggle="tab"` because each destination is a separate
request.

### Taxonomy trees and other hierarchy pages

Use `shared/_taxonomy_tree` and `shared/_taxonomy_node` for tag indexes, Sections, and Locations.
The shared tree provides:

- a page header with explicit `title`, count, description, and human-readable add label;
- optional URL-backed workspace tabs via `tabs` and `tabs_aria_label` locals;
- a consistent empty state;
- a native rename button with inline rename for users with write access;
- visible Move up/Move down controls, Insert before/Insert after actions, and add-child controls;
  drag handles remain an optional enhancement;
- a neutral overflow menu for edit/delete. Read-only viewers see the hierarchy without mutation
  controls.
- successful mutations refresh the same URL so counts and serialized parent/tag options are never
  stale; dynamic names and option labels are rendered as text, not HTML.

The add action must be human-readable (`Add relation tag`), never generated directly from a
model parameter (`Add Relation_tag`). The tree Stimulus controller owns the inline add form and
must keep the empty-state removal, hierarchy indentation, and keyboard/focus behavior in sync with
the rendered node partial.

### Full-page forms

Universes, Stories, and universe membership management use the existing form patterns with:

- Bootstrap labels and controls;
- an alert-based error summary;
- a clear primary submit action;
- a cancel link back to the relevant scope.

Do not replace these with a modal: full-page forms remain appropriate for objects with a stable
URL and meaningful navigation.

### Planned Scene workspace (slice 11.0 contract; not implemented)

The accepted [ADR 0007](adr/0007-story-owned-scenes-and-elements.md) defines a calm, explicit
Scene workspace. The existing **Scenes** sidebar entry remains an `aria-disabled` placeholder
until the slice 11.1 vertical slice exists.

The global Scenes page is a flat list in narrative order, not a Section-grouped tree. It uses the
shared page header, content surface, row actions, and empty state. Rows show:

- required Title and a clamped description preview;
- **Ungrouped** or the full Section ancestor path;
- Scene Tag badges;
- Element and participant counts;
- edit/delete controls only for writers;
- visible Move up/Move down controls with a clear disabled state at sequence boundaries.

The page's primary **Add scene** action opens the stable new Scene form. The list must state that
order is the order the story is told, not in-world chronology. At narrow widths, order controls and
actions wrap without hiding the title or relying on hover.

Scene Details uses URL-backed tabs for **Details**, **Characters**, **Items**, and **Locations**.
Details contains the HTML form and the ordered Element list. Characters/Items/Locations show the
linked record, its optional free-text role, and writer-only add/remove/edit controls. Empty states
link to the relevant Universe Bible workspace; read-only users see the same information without
mutation instructions.

The Section selector includes **Ungrouped** and indented Section paths. A Section-grouped outline
may be added in the Sections workspace later, but it is a second organization view: it must never
replace or visually imply that the global Scene list is ordered by Section position.

Narration and Dialogue Elements use one Bootstrap modal. The form has a kind selector, required
**Title**, optional plain-text **Content**, and a multi-speaker picker visible and required only
for Dialogue. Narration has no speaker control. Error summaries stay in the modal with the entered
values; a failed request does not close it. Element rows show kind, Title, a body preview,
speakers for Dialogue, and accessible Move up/Move down controls.

The Scene/Story/Section/Event/shared-record destructive copy from ADR 0007 is mandatory. Do not
replace the consequences with only “Delete {record}?” merely to save space.

## Accessibility and interaction

- Every icon-only control has an accessible label or visually hidden text.
- Current navigation uses `aria-current="page"` and a non-color indicator.
- Dropdown menus have unique IDs and `aria-labelledby` targets.
- Delete actions are labeled as destructive and retain confirmation.
- Keep focus states visible; do not use hover as the only way to discover an action.
- Taxonomy actions become visible on keyboard focus and on touch devices; insertion targets are at
  least 44×44 CSS pixels and reordering never depends on hover or drag/drop.
- Preserve `prefers-reduced-motion` handling for transitions and drag feedback.
- Tag color is supplementary information, never the only way to identify a record.

## Change checklist for a new page

1. Choose the existing functional pattern (tree, flat modal list, or full-page form).
2. Start with `shared/_page_header` and `shared/_empty_state` where applicable.
3. Use the correct universe/story scope in every path.
4. Use `shared/_row_actions` for modal-list rows rather than inventing another action layout.
5. Add the record link to the Bible or Story workspace; use `shared/_content_tabs` for related
   records and `shared/_tag_workspace_navigation` for taxonomy management. Put the Members access
   manager in the right-side Settings section.
6. Check keyboard focus, mobile width, empty state, and long text.
7. Update the relevant docs and tests in the same change.
