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

The sidebar is the one place where color carries structure: the universe, the current story, and the
configuration/tools area each own one hue, so a reader can tell at a glance which scope a section
belongs to. Everything else stays in the neutral palette.

The workspace keeps a quiet, permanent right utility sidebar at wide breakpoints. Its
**Configuration** section contains the real Tags entry and the Members access manager, while the
remaining Collaboration, Analytics,
and AI entries are deliberate `aria-disabled` placeholders rendered in the flat disabled gray.
They should become real destinations as the underlying product areas are defined. Below the `xl`
breakpoint the panel becomes a Bootstrap `offcanvas-end`, so the main writing surface keeps priority
on smaller screens.

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

The sidebar also has three **scope** hues, declared as `--um-scope-*` custom properties so a block's
color is set in one place:

| Scope | Strong | Soft | Used by |
|---|---:|---:|---|
| Universe | `#263da8` | `#edf0ff` | the universe context block and the Universe Bible header |
| Story | `#8c2f39` | `#fbeaec` | the story context block and the Story workspace header |
| Tools | `#1f6f4a` | `#e6f4ec` | the right-sidebar context block and every right-sidebar header |
| Disabled | `#98a2b3` | — | placeholder navigation and disabled menu items |

The story hue is a muted crimson, deliberately **not** the danger red: scope must never be confused
with "this will delete something". Placeholder navigation uses the disabled gray with no hover
emphasis, because those entries are not implemented.

Rules:

- Do not use danger red as a general category color for Characters, Locations, Events, or Items, and
  do not use a scope hue for anything other than its sidebar block.
- User-defined tag colors are data, not theme colors. They may be rendered as colored badges, but
  they must not be used for active navigation or buttons.
- Check text/background contrast when adding a tag color. The badge shape and text must remain
  legible even when the chosen colors are poor.
- Prefer Bootstrap semantic variables (`$primary`, `$body-color`, `$border-color`, etc.) over
  hard-coded colors in feature partials.
- Keep the custom `--um-*` variables for shell/layout values that are not Bootstrap component
  defaults.

### Light and dark

The page is rendered in one of two themes, **Light** (the default) and **Dark**, chosen per browser on
the **Settings** page and applied by Bootstrap's own `data-bs-theme` attribute on the root element
([ADR 0013](adr/0013-platform-settings-and-browser-theme.md)). The layout writes the attribute, so the
first paint is already correct and no script is involved.

The **Language** choice sits beside it on the same settings page and is the same kind of preference: a
per-browser cookie, chosen on `/settings?section=language`, applied by the layout writing `<html lang>`.
The two preferences are independent, and a change to either loads the whole document rather than
navigating with Turbo, so the root attributes and the rendered copy change together. The cookies, the
`around_action`, the page, and why the navigation is a full load are in
[features/settings.md](features/settings.md).

Bootstrap flips its own variables; the `--um-*` tokens above are ours, so each one that carries a
light-only value is re-tinted in the `[data-bs-theme="dark"]` block of
[`app/assets/stylesheets/_application_custom.scss`](../app/assets/stylesheets/_application_custom.scss):

| Token | Light | Dark | Used by |
|---|---:|---:|---|
| `--um-primary-soft` | `#edf0ff` | `rgba(52, 84, 209, .24)` | selected navigation, current-page fills |
| `--um-primary-strong` | `#263da8` | `#aebcff` | selected navigation text |
| `--um-sidebar-bg` | `#ffffff` | `--bs-tertiary-bg` | both sidebars |
| `--um-hover-bg` | `#f3f5f9` | `rgba(255, 255, 255, .06)` | row and link hover |
| `--um-surface-raised` | `#fbfcfe` | `rgba(255, 255, 255, .025)` | the last sidebar section |
| `--um-row-hover` | `#fafbfe` | `rgba(255, 255, 255, .04)` | entity and taxonomy row hover |
| `--um-surface-veil` | `rgba(255, 255, 255, .72)` | `rgba(255, 255, 255, .03)` | empty states, tag scope tabs |
| `--um-tag-badge-border` | `rgba(31, 41, 55, .12)` | `rgba(255, 255, 255, .22)` | the tag badge's hairline |
| `--um-scope-universe` | `#263da8` | `#9db1ff` | universe scope text |
| `--um-scope-universe-soft` | `#edf0ff` | `rgba(52, 84, 209, .22)` | universe scope background |
| `--um-scope-story` | `#8c2f39` | `#eda3ab` | story scope text |
| `--um-scope-story-soft` | `#fbeaec` | `rgba(140, 47, 57, .28)` | story scope background |
| `--um-scope-tools` | `#1f6f4a` | `#84d3a8` | tools scope text |
| `--um-scope-tools-soft` | `#e6f4ec` | `rgba(31, 111, 74, .26)` | tools scope background |
| `--um-disabled-text` | `#98a2b3` | `#8a93a3` | placeholder navigation |

Rules for the dark theme:

- **A light-only literal color is a bug.** Anything that needs a surface tint gets a `--um-*` token
  with a dark value, not a literal `rgba(255, 255, 255, …)` or near-white hex.
- A scope keeps its hue across themes. Only the value and the background change, so the universe is
  still blue, the story still red, and the tools scope still green at a glance.
- The navbar stays dark in both themes: it is the one dark surface that is part of the design, not a
  theme choice.
- Author-chosen data colors are left alone: tag badges and timeline nodes keep the colors stored on
  the record, with the dark-text `rgba(0, 0, 0, .75)` node label that those backgrounds need.
- A new component must be checked in both themes before it is finished; the browser suite is the
  place to see it (`test/system/settings_theme_test.rb` proves the switch itself).

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
5. a skip link and one shared floating toast region for flash messages.

The navbar is intentionally small: three links, one search box, and the account menu. **What each
entry contains and links to is in [features/navigation.md](features/navigation.md)** — read that for
the entries; this is only the shell.

A scope link is marked current with `.active` **and** `aria-current="page"` only on the page it points
at, so the bar never claims a scope that is not the page being viewed. The account menu is the
navbar's only Bootstrap dropdown, and the top bar issues no query of its own — the search box renders
from what the page already knows and asks the engine only for what a reader types.

### Search

The painted treatment only. The behaviour, the rules, and the reasons behind each decision are in
[features/search.md](features/search.md) — read that for *why*; this section is what it looks like.

The box reads as one control: a rounded field with a search icon, the text input, and the scope
dropdown as a compact select divided off by a hairline at the field's trailing edge. The dropdown
wears **no surface of its own** — its background is the field's own color, so the two are one
surface with no seam, and no border except that hairline; the field's trailing curve carries the
hover, instead of a square panel inside the pill. Its chevron is the bar's, not Bootstrap's, because
Bootstrap's is a per-theme literal and the bar is always dark. It sits between the scope links and
the actions and grows into the space they leave, up to 30rem; the actions keep their own row and
never wrap under it.

The field's and the scope's colors are **opaque**, and the field declares `color-scheme: dark`,
because the browser — not this stylesheet — paints the scope's open option list and the input's
clear button, and takes the list's panel color from the element's own background. The opaque values
are the white overlay composited onto the bar's color in Sass, because CSS cannot resolve an overlay
onto the surface beneath it. What the browser still owns is left to the browser: a dropdown styled in
every detail would be a custom listbox, which would cost the plain GET form that works without
scripting.

The navbar is dark in both themes, so the box's colors are declared once and are **not** re-tinted by
`data-bs-theme` — a widget that changed palette with the page theme inside an always-dark bar would
look borrowed from the page it sits above. The results panel is a raised dark surface with a shadow,
scrolled to 24rem, and painted above the actions to its right.

The panel is one listbox holding two labelled groups — **Go to** for navigation destinations and
**Results** for records — separated by a hairline, with an uppercase group heading and a kind badge
(`Character`, `Scene element`, `Character tag`) on every row, the record's context underneath, and a
one-line excerpt. **Both kinds of row wear the same row treatment**, because the panel, not the page,
paints them: the bar's near-white text, the same padding, the same radius, the same hover and
keyboard-cursor tint. The matched run in a title is `<mark>`ed wherever the title is, in the
full-strength amber with the app's own dark on top of it. A panel with nothing to show says so in
muted text: "No matches for …" or "Search is not available."

**See all results** appears only when there is an answer to open, and is the panel's **footer**:
the dropdown and the link are one box with one surface, the list scrolls inside a 24rem cap, and
the link sits in flow beneath the results, divided from them by a hairline.

The same dropdown is rendered on the search results page, and that copy is the **ordinary**
theme-aware form control: the caller states which surface it sits on, so the bar's dark treatment
never reaches a page that follows the theme. On the results page the content uses the ordinary
theme-aware surfaces: a `content-surface` form block, an uppercase group heading in the secondary
color, kind badges and titles in a row, and `Previous` / `Next` with a `Page N` position. A
truncated list always says "Showing 12 of 40 matches" — a short list that looks complete is how a
reader concludes a universe is smaller than it is.

The navbar does not render placeholder links. The right utility sidebar is the one intentional
exception: its `aria-disabled` entries reserve space for future Collaboration, Analytics, and AI
features without presenting them as implemented routes.

### Responsive behavior

- At `lg` and above, the left workspace navigation is a 16rem sticky column.
- Below `lg`, it becomes a Bootstrap `offcanvas-start`; the main area shows a compact `Menu`
  button and the current universe/story context.
- Below `lg` the navbar collapses into the toggler menu, and the search box is inside it with the
  account menu — it is one collapsed navigation surface, not a bar that stays partly usable.
- At `xl` and above, the right utility navigation is a 14rem sticky column.
- Below `xl`, it becomes a Bootstrap `offcanvas-end`; the workspace bar exposes it through a
  `Tools` button. The `Menu` button is only shown below `lg`, when the left panel also needs an
  offcanvas trigger.
- The main column must have `min-width: 0` so long descriptions and tables do not break the grid.
- Keep `scroll-padding-top`/sticky offsets aligned with the fixed navbar height.

The old `.container-xl` 2/8/2 shell is not the content-arrangement model anymore. Use the shared
shell classes and let the main region grow.

## Navigation and information architecture

The painted system for navigation is here; **what the navigation contains** is in
[features/navigation.md](features/navigation.md), which owns the entry lists, the two-step
universe-then-story selection, the Configuration placement rule, and the honest-placeholder rules.
Do not restate an entry list here — add the row to the feature document instead.

- The left navigation is task-oriented and scope-aware, and is one continuous surface read as two
  scoped blocks. Each block is a **context header** followed by the section it introduces, so the
  reader can always tell which scope a link belongs to.
- Configuration is not in the left column; it belongs to the right utility sidebar, so the left
  column carries universe and story content only.
- At `lg` and above the left column is a 16rem sticky column; below `lg` it becomes a Bootstrap
  `offcanvas-start` with a compact **Menu** button. At `xl` and above the right column is a 14rem
  sticky column; below `xl` it becomes an `offcanvas-end` opened by a **Tools** button. The
  **Menu** button appears only below `lg`, when the left panel also needs a trigger. The main column
  must have `min-width: 0`, and sticky offsets stay aligned with the fixed navbar height.
- Real entries show `icon_text_count` as aligned `.sidebar-count` pills, and a list row's own count
  uses the identical `.record-count` pill. Current links use a soft primary background and
  `aria-current="page"`, so color is never the only state signal. Placeholder navigation is rendered
  in the flat disabled gray with no hover emphasis.
- The **Settings** page is a platform page, not universe content, so it is reached from the top bar's
  account menu, is rendered for every visitor including a guest, and has no workspace shell. Its
  content and its vertical tab strip are in [features/settings.md](features/settings.md).

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

### Row and count treatment

The row shape — plain-text name on the left with its badges and count pill, the Details link and the
overflow menu on the right, and the rule that nothing on a row depends on hover — is defined once, in
[conventions.md](conventions.md#list-rows). Read that for the contract. This section is the painted
treatment: the `.record-count` pill is styled like the sidebar's `.sidebar-count` pills so a row's
count and a sidebar's count read as the same quiet object, and a destructive action in a row's overflow
menu is marked by text or icon rather than by a permanently red button.

### Flat entity lists

Characters, items, events, relations, and ownerships use:

- `shared/_row_actions` for a neutral overflow menu;
- a visible name/title and tag badges;
- a short description clamped to a readable number of lines;
- a `content-surface`/`list-group` wrapper;
- a modal for quick create/edit, preserving the existing JSON-only mutation flow;
- mutation controls hidden for guests and read-only members, while the record content and the Details
  link remain visible.

A modal has three states, and none of them is a dead end
([ADR 0011](adr/0011-modal-json-mutation-contract.md)):

- **Open** — the first field is focused, and an existing record's text is selected so a rename can be
  typed over it. Nothing depends on hover or a wide viewport.
- **Saving** — the submit button is disabled, carries a spinner, and the form is `aria-busy`. The
  entered values stay visible.
- **Rejected** — the modal stays open. A `danger` alert at the top of the body lists the reasons and
  takes focus, and each message also appears next to the control that caused it with `aria-invalid`
  and `aria-describedby`. A record-level message, or a rejection with no field of its own, appears
  only in the summary. A request that never reached the server, a `403`, and a `5xx` each get their
  own wording, and none of them closes the modal or discards the input.

A failed delete has no modal to stay open, so it reports itself in the page-level live region beside
the flash messages as a visible `danger` alert, and the row is left alone. A short confirmation
("Saved. Refreshing the list…") is visually hidden and only announced, because the refreshed render
that follows is the real confirmation.

Relations and ownerships keep the HTML re-render flow, so their rejected submission lands on a
re-rendered page instead of an open modal. They follow the same rules: the reason is stated with
`shared/_error_summary` under the page header, the same summary is rendered inside the editor, and
the entry is preserved in the editor that reopens, so the author never retypes a rejected form. The
taxonomy tree's editor uses the identical summary-and-field-message contract.

Relations should read naturally (`Character A → Character B`) rather than as an unlabeled database
row. Ownerships use the same readable relationship treatment.

### Related content navigation

Use `shared/_content_tabs` for related record workspaces. The Character workspace has Characters
and Relations; the Item workspace has Items and Ownerships. Locations, Events, and Sections each
have one record tab. Use `shared/_tag_workspace_navigation` for Configuration → Tags: the outer
Universe/Story selector is followed by the six universe taxonomy tabs or the two story taxonomy
(Section/Scene) tabs. Use `shared/_settings_navigation` for the platform Settings page, whose tab
strip is the same pattern turned vertical (`nav nav-tabs flex-column`). All tabs are URL-backed
Bootstrap `nav-tabs`: use the active class and `aria-current="page"`, but do not add
`data-bs-toggle="tab"` because each destination is a separate request.

### Details-page treatment

The details page's contract — four shared partials, read-only, guest-readable, one per record — is in
[conventions.md](conventions.md#record-details-pages). The painted treatment: the identity card with
the record type, then a `.detail-facts` grid of labelled values where an unset value renders explicit
copy instead of an empty cell, then one or more related-records sections, each with a count badge and
its own empty state. The empty copy states what will appear later and must not tell a guest or a
read-only member to add records. The identity card's two-column layout when a record has a photo is
in [conventions.md](conventions.md#record-details-pages).

### Taxonomy trees and other hierarchy pages

The taxonomy system's rules — the DSL, the mandatory scope, the tree's row and menu contract, the
`taggable` and `show_in_menu` flags, and the DOM-built editor — are in
[features/tags.md](features/tags.md). The painted shape of the tree:

- `shared/_taxonomy_tree` and `shared/_taxonomy_node` render tag indexes, Sections, and Locations
  with a page header carrying an explicit `title`, count, description, and a human-readable add
  label, optional URL-backed workspace tabs, and a consistent empty state.
- The name carries a native rename button for users with write access, sized to its own text so only
  hovering or focusing the name starts a rename; clicking the rest of the row does nothing.
- A `.record-count` pill sits next to the name and its tags, naming the number of records that page
  will list (`(4 characters)`, `(3 scenes)`), with a **Details** link on the right that is visible at
  every access level. The row carries the single neutral overflow menu, whose items and boundary
  behavior are in [features/tags.md](features/tags.md); the row itself has no add or arrow buttons,
  and drag handles remain an optional enhancement.
- The row's right-hand group (Details + menu) is never a hover affordance: a hover-revealed control is
  not usable on touch and is invisible to a keyboard user scanning a long list, so the row is the same
  shape as a flat list row.
- The first insert target of the tree needs room for its 44px button, so the root list keeps top
  padding; otherwise the button would hang over the hint paragraph above it.

### Full-page forms

Universes, Stories, and universe membership management use the existing form patterns with:

- Bootstrap labels and controls;
- an alert-based error summary;
- a clear primary submit action;
- a cancel link back to the relevant scope.

Do not replace these with a modal: full-page forms remain appropriate for objects with a stable
URL and meaningful navigation.

### Scene workspace

The Scene pages' content, behaviour, and rules are in [features/scenes.md](features/scenes.md).
The painted shape:

- The global Scenes page is a flat list in narrative order, not a Section-grouped tree, using the
  shared page header, content surface, entity rows, and empty state. The 1-based narrative position
  is a bordered pill with an `aria-label="Narrative position N of M"`, where both numbers come from
  the whole sequence; the grouping badge shows the Scene's full nested Section path, or **Ungrouped**
  with an open-folder icon and a `title` stating that grouping does not change the narrative order;
  optional Scene Tag badges use the taxonomy colors, and untagged Scenes remain valid.
- Rows show two small bordered count pills — the Scene's **Element** count and how many **Characters
  take part** — then a right-hand group with the **Details** link for every access level, the
  writer-only Move up/Move down controls, and the Edit/Delete menu with a clear disabled state at
  the sequence boundaries.
- The three Scene workspace tabs share one row shape: the linked record's name as plain text, a
  bordered **Linked** badge, and `Role: …` with **No role recorded**. The Characters tab is the
  exception, because it has a second source: a Character who only speaks carries **Speaks in N
  element(s)** instead of **Linked** and has no dropdown.
- The Locations tab is the only one whose rows are hierarchical, so its title is the full ancestor
  path (`Winden / Nielsen House / Martha Room`) and its picker is depth-indented in root-first order.
- **Appears in scenes of &lt;Story&gt;** reuses the same entity rows, prefixed with the same 1-based
  narrative-position pill, with its reason badges (**Linked**, **Speaks in N element(s)**,
  **Depicted**) listed and never collapsed.
- The **Find scenes** filter surface (`scenes/_filter`) is a full-width `search` field, a **Section**
  select, a **Scene Tag** select, two `date` fields labelled **In-world from** and **In-world to**, a
  **Filter scenes** submit, and a **Clear filters** link that appears only while a filter is in
  effect. The fields fold into one column below `sm` with the two date fields side by side. One
  sentence states the two rules an author needs: filtering does not change the narrative order, and a
  Scene without an in-world time is not in a date range. Every access level sees it, because
  filtering is reading. While a filter is active the surface adds `Showing N scenes of M scenes.`
  followed by the active filters as neutral badges.
- Narration and Dialogue Elements use one Bootstrap modal and the shared modal contract, not a second
  editor. A one-line hint under the type selector states what each kind is, and the same line changes
  with the selection. An empty Element list gets its own empty state, because a Scene may hold any
  number of Elements, including none.
- A long Section name wraps instead of pushing the layout, and the action group wraps below the title
  at narrow widths instead of hiding it or relying on hover.

## Accessibility and interaction

- Every icon-only control has an accessible label or visually hidden text.
- Current navigation uses `aria-current="page"` and a non-color indicator, including the top bar's
  scope links, which are current only on the page they point at.
- Dropdown menus have unique IDs and `aria-labelledby` targets.
- Delete actions are labeled as destructive and retain confirmation.
- The Details link repeats the record name in its accessible name, so many identical looking links
  stay distinguishable in a long list. A count is a separate pill whose visible text names what it
  counts, so it is announced as a fact about the record rather than as part of the link.
- Placeholder navigation keeps `aria-disabled` and is additionally styled as unavailable, so the
  visual state and the semantics agree.
- Keep focus states visible; do not use hover as the only way to discover an action. A row's Details
  link and overflow menu are always rendered, so no list control depends on hover, on a pointer
  device, or on a wide viewport.
- Taxonomy insertion targets are at least 44×44 CSS pixels and reordering never depends on
  hover/drag or a drag-only path.
- Preserve `prefers-reduced-motion` handling for transitions and drag feedback.
- Tag color is supplementary information, never the only way to identify a record.

## Change checklist for a new page

1. Choose the existing functional pattern (tree, flat modal list, or full-page form). A read-only
   details page is composed from `shared/_record_details` and `shared/_detail_section`, never from
   a modal and never with its own editor.
2. Start with `shared/_page_header` and `shared/_empty_state` where applicable.
3. Use the correct universe/story scope in every path.
4. Use `shared/_row_actions` for modal-list rows rather than inventing another action layout, and
   render `record_details_link` on every row so the record's own page stays one click away. Keep the
   [list row shape](#list-rows): plain-text name on the left, Details then actions on the right.
5. Add the record link to the Bible or Story workspace; use `shared/_content_tabs` for related
   records and `shared/_tag_workspace_navigation` for taxonomy management. Put universe
   configuration tools and the Members access manager in the right sidebar's **Configuration**
   section, and a preference that belongs to the person rather than the universe in the top bar's
   **Settings** page, behind `shared/_settings_navigation`.
6. Check keyboard focus, mobile width, empty state, long text, and the page in **both** themes.
7. Update the relevant docs and tests in the same change.
