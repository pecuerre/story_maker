# Visual Design and UI Conventions

This document is the source of truth for Universe Maker's Bootstrap-based visual system and
information architecture. It describes decisions that affect shared views and CSS; it is not a
replacement for the domain rules in [`data_model.md`](data_model.md) or the request/routing rules
in [`architecture.md`](architecture.md).

## Design decision

Universe Maker stays on **Bootstrap 5.3**, Bootstrap Icons, Sass, PostCSS/autoprefixer, Hotwire,
and Stimulus. Do not introduce a second component framework or a utility-only CSS system.

The interface should feel like a calm writing workspace. Its aim is the denser **reference atlas**
recorded in [visual_design_brief.md](visual_design_brief.md): facts and cross-links lead, type and
alignment carry hierarchy, and chrome recedes. The conventions below implement the accepted
**Index** direction in [visual_directions.md](visual_directions.md) and
[ADR 0047](adr/0047-adopt-index-as-the-visual-direction.md) across the workspace shell and every
workspace.

- content is the largest and most prominent area;
- navigation is quiet and scoped;
- one primary action is visually dominant per page, and it leads the header's action group;
- color is reserved for meaning, not decoration;
- destructive actions are visually distinct from navigation categories;
- the universe/story model is always explicit.

The sidebar is the one place where color carries structure: the universe, the current story, and the
configuration/tools area each own one hue, so a reader can tell at a glance which scope a section
belongs to. Everything else stays in the neutral palette.

The **public front door** at `/` is the one guest-facing introductory surface. It uses a neutral hero
band with a soft primary tint, a small fact card, and a grid of bordered cards. It introduces no
palette and borrows no sidebar scope hue; every other page stays a workspace surface.

The workspace keeps a quiet, permanent right utility sidebar at wide breakpoints. It is one
continuous tools scope, opening with the green **Universe tools** context block and then the
**Configuration** and **Collaboration** sections, with the **Inspector** closing the column when the
current page has rows to show. Every entry there is a real destination: this is not where future
product areas are reserved as disabled rows. Which entry belongs to which section, and the gates that
decide whether it appears, are owned by [features/navigation.md](features/navigation.md). Below the
`xl` breakpoint the panel becomes a Bootstrap `offcanvas-end`, so the main writing surface keeps
priority on smaller screens.

## Theme tokens

Bootstrap variables live in
[`app/assets/stylesheets/_theme.scss`](../app/assets/stylesheets/_theme.scss), which is imported
**before** `bootstrap/scss/bootstrap` in `application.bootstrap.scss`. Change the palette,
typography scale, radii, or component defaults there rather than adding one-off overrides in
views.

Current palette:

| Token role | Value | Use |
|---|---|---|
| Primary | `#1d4f7a` | primary buttons, selected navigation, focus/accent |
| Body background | `#f6f4ee` | page canvas |
| Body text | `#1e1d1a` | headings and primary copy |
| Secondary text | `#5f5a50` | descriptions and metadata |
| Border | `#d3ccbc` | surfaces, list rows, separators |
| Surface | `#fffdf8` | cards and content surfaces |
| Control border | `#8c8371` | form controls and row actions (3:1) |
| Success | `#2c6b45` | successful status only |
| Warning | `#835600` | warning/attention status only |
| Danger | `#a32626` | destructive actions and errors |

The sidebar also has three **scope** hues, declared as `--um-scope-*` custom properties so a block's
color is set in one place:

| Scope | Strong | Soft | Used by |
|---|---|---:|---|
| Universe | `#244a7c` | `#e7edf6` | the universe context label, Universe Bible headings, and its active rows |
| Story | `#8a2f3a` | `#f6e6e8` | the story context label, Story workspace headings, and the Story workspace header |
| Tools | `#2a6a4b` | `#e5f0e9` | the right-sidebar context label and every right-sidebar heading |
| Disabled | `#9a9283` | — | placeholder navigation and disabled menu items |

The story hue is a muted crimson, deliberately **not** the danger red: scope must never be confused
with "this will delete something". Placeholder navigation uses the disabled gray with no hover
emphasis, because those entries are not implemented.

Rules:

- Do not use danger red as a general category color for Characters, Locations, Events, or Items, and
  do not use a scope hue for anything other than its sidebar block.
- User-defined tag colors are data, not theme colors. They may be rendered as colored badges, but
  they must not be used for active navigation or buttons.
- Check text/background contrast when adding a tag color. The badge shape and text must remain
  legible even when the chosen colors are poor; the tag editor says so when a pair cannot be read,
  and lets the author save it anyway ([features/tags.md](features/tags.md#the-editor)).
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
| `--um-primary-soft` | `#e4edf5` | `#22384b` | selected navigation, current-page fills |
| `--um-primary-strong` | `#173f61` | `#c7ddf0` | selected navigation text |
| `--um-on-primary` | `#ffffff` | `#0d2237` | text on a filled primary control |
| `--um-sidebar-bg` | `#fbf9f3` | `#1b1915` | the left rail |
| `--um-tools-bg` | `#f8f5ed` | `#1a1814` | the right tools rail |
| `--um-topbar-bg` | `#20242a` | `#101216` | the fixed dark navbar |
| `--um-hover-bg` | `#efebe2` | `#26221c` | row and link hover |
| `--um-surface-raised` | `#f8f5ed` | `#1b1915` | the last sidebar section |
| `--um-row-hover` | `#faf7f0` | `#242019` | entity and taxonomy row hover |
| `--um-surface-veil` | `rgba(255, 253, 248, .62)` | `rgba(30, 28, 24, .62)` | empty states, tag scope switch |
| `--um-tag-badge-border` | `rgba(30, 29, 26, .16)` | `rgba(236, 231, 220, .18)` | the tag badge's hairline |
| `--um-control-border` | `#8c8371` | `#8b8272` | form controls and row actions |
| `--um-scope-universe` | `#244a7c` | `#9db7dd` | universe scope text |
| `--um-scope-universe-soft` | `#e7edf6` | `#223449` | universe scope background |
| `--um-scope-story` | `#8a2f3a` | `#eda3ab` | story scope text |
| `--um-scope-story-soft` | `#f6e6e8` | `#3a2427` | story scope background |
| `--um-scope-tools` | `#2a6a4b` | `#8ccbaa` | tools scope text |
| `--um-scope-tools-soft` | `#e5f0e9` | `#1e352b` | tools scope background |
| `--um-disabled-text` | `#9a9283` | `#777061` | placeholder navigation |

Bootstrap's own dark variables are re-pointed in the same block: the warm near-black canvas
(`#171613`), text (`#ece7dc`), secondary text (`#b3ab9b`), surfaces (`#28241e`), hairlines
(`#3d382e`), and the pale ink-blue primary (`#9cc0e0`) with dark text on it.

Rules for the dark theme:

- **A light-only literal color is a bug.** Anything that needs a surface tint gets a `--um-*` token
  with a dark value, not a literal `rgba(255, 255, 255, …)` or near-white hex.
- A scope keeps its hue across themes. Only the value and the background change, so the universe is
  still blue, the story still red, and the tools scope still green at a glance.
- **Outline buttons need their own dark-theme rule.** Bootstrap's outline mixin bakes the light
  theme's color into every button variable and never re-tints it, so `_application_custom.scss`
  re-points the text, boundary, hover, and pressed variables of every `.btn-outline-*` at the dark
  text-emphasis palette. Keep that loop rather than patching one variant, and check a changed theme
  color in both themes against the 4.5:1 text and 3:1 boundary targets.
- **Semantic text utilities need the same re-tint.** Bootstrap's `.text-danger` keeps the light
  theme's deep red in dark mode, where it is about `2.5:1` on the near-black canvas; the dark
  danger text-emphasis is the legible counterpart. `_application_custom.scss` points `.text-danger`
  at it, so a destructive menu item is readable before it is hovered as well as after.
- The navbar stays dark in both themes: it is the one dark surface that is part of the design, not a
  theme choice.
- Author-chosen data colors are left alone: tag badges and timeline nodes keep the colors stored on
  the record, with the dark-text `rgba(0, 0, 0, .75)` node label that those backgrounds need.
- A new component must be checked in both themes before it is finished; the browser suite is the
  place to see it (`test/system/settings_theme_test.rb` proves the switch itself).

## Typography

The UI is the operating-system sans stack; titles and record prose are the operating-system serif
stack. No web-font dependency is required, and nothing is loaded over the network.

- `$font-family-sans-serif` is `system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif`;
- `$um-font-serif` is `"Iowan Old Style", "Palatino Linotype", Palatino, "Book Antiqua", Georgia,
  "Times New Roman", serif`. The stack ends in generic `serif`, so an unknown platform falls back to
  its own serif rather than a missing glyph;
- body text is `.9375rem` at a `1.5` line height;
- page titles are `1.875rem` at weight 600 and `1.18` line height; card and section titles are
  `1.1875rem` and `.9375rem`;
- page descriptions are serif `.9375rem`; record prose is serif `1.0625rem` at `1.68` with a
  `68ch` measure;
- metadata and labels are `.75rem`–`.8125rem`; fact labels are `.6875rem` uppercase with `.03em`
  tracking; page and section kickers are `.65625rem` uppercase with `.11em` tracking.

Use sentence case for page headings and normal sentence case for descriptions. Uppercase is
reserved for small navigation/section labels and fact labels. Do not make every card heading
uppercase. The serif is the hierarchy device, so a heading does not need a box around it.

## Spacing and shape

- Use the Bootstrap spacing scale (`8px`, `12px`, `16px`, `24px`, `32px`) through utilities or the
  shared component classes.
- Index is flat: surfaces are a 1px hairline with a 4px radius and **no shadow**; buttons and
  controls use a 3px radius. Resolve hierarchy with type, alignment, and rules, not nested boxes.
  A form that sits inside a page panel is not a second card: the panel already supplies the surface,
  so the form drops `.form-surface` and takes the panel's padding. A form that stands alone is the
  page's one card.
- List rows settle at `46px` on desktop with one clamped summary line; keep at least a `40px`
  touch target on phones, where a row may grow as its tags or labels wrap. A row's menu button keeps
  its painted `30px` box; below `sm` its hit area grows into the row's own padding to the row's
  `40px` target, so touch can reach it without growing the row or moving the painted label. The name
  is a text link and its own target.
- The content column caps at `1040px`; the workspace rails are `14.5rem` and `12.75rem`.
- Avoid global rules that shrink every `.nav-link` or `.list-group-item`. Component-specific
  classes such as `.sidebar-link`, `.entity-row`, and `.taxonomy-row` own their spacing.
- Do not use inline `style` attributes for layout or state. Existing tag color values are the
  intentional exception because they come from user data.
- Every in-list filter is a quiet block rather than a second card: `.list-filter` names the block,
  its title is a small uppercase kicker, its explanatory sentence is hidden below `md`, and its
  submit stays an outline button. The search and any order control stay in the first row; the
  narrowing controls sit behind the shared **Advanced filters** disclosure. The Characters filter
  established the treatment on the prototype and the rollout gave the same classes to the Universe
  record lists, the Scenes list, and the shared taxonomy tree. The disclosure's markup, its state
  badge, and the rule that a closed group still submits are in
  [`list_filters.md`](features/list_filters.md#the-search-areas-shape).

## Application shell

`app/views/layouts/application.html.erb` is the shell:

1. a fixed dark Bootstrap navbar, 50px tall;
2. a responsive left workspace navigation, `14.5rem` wide;
3. one flexible main content region with a `page-shell` wrapper, capped at `1040px`;
4. a responsive right utility navigation, `12.75rem` wide;
5. a skip link, one shared floating toast region for flash messages, and one floating notice for a
   held live update.

The shell itself caps at `1440px` and centers on wider displays; the navbar stays full width. The
navbar is intentionally small: three links, one search box, and up to three actions. **What each
entry contains and links to is in [features/navigation.md](features/navigation.md)** — read that for
the entries; this is only the shell.

The sidebar rows are 30px on desktop and 40px below `lg`, with a 3px inline-start edge on the
active row and a soft primary fill.
The scope hue belongs to the context label and section heading; Index lets the rail's own warm
surface show through instead of filling each block with a tint. Labels wrap rather than truncate when
a translated entry is longer than the rail, which is why the Spanish **Solicitudes de revisión** takes
two lines in the narrow tools column.

Below `xl` a mobile workspace bar carries the **Menu** and **Tools** drawer buttons and, at its
trailing edge, the current scope: the universe name and then the story name. The two names are
separate flex items, so a translated button pair that leaves too little room drops the whole story to
a second line — prefixed by its separator — instead of clipping the only place a phone states which
story is current.

A scope link is marked current with `.active` **and** `aria-current="page"` only on the page it points
at, so the bar never claims a scope that is not the page being viewed. The search box issues no query of
its own — it renders from what the page already knows and asks the engine only for what a reader types.

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

### The draft indicator

The painted treatment only. What it states, where it sits, and why it is not in a page header are in
[features/navigation.md](features/navigation.md) — read that for *why*; this is what it looks like.

The indicator wears the bell's own shape: a `btn-outline-light` at the same small size, in the same
actions row. The journal icon is followed by the word **Draft** and, when something is waiting, its
count as a `badge` **inside the button's flex row** rather than pinned to a corner, for the bell's
reason: the navbar is too small for a corner badge and a count the reader can read beats a dot. The
number uses tabular numerals so 9 → 10 does not shift the bell beside it. It is `text-bg-light` rather
than the bell's danger red, because pending work is the reader's own, waiting to be applied, and not
an alert about something that happened. At zero the badge is absent and the word stays, so the button
neither changes size nor disappears with its count. It is a plain link, not a dropdown: there is
nothing to choose between, and the drafts page is the list.

### The notifications bell

The painted treatment only. What a notification is, who is told what, and why the figure is uncached are
in [conventions.md](conventions.md#notifications) — read that for *why*; this is what it looks like.

The bell is a `btn-outline-light` sized like the account menu beside it, with the icon followed by its
unread count as a `badge` **inside the button's flex row** rather than pinned to a corner: a corner
badge has nowhere to sit at the navbar's small size, and a count the reader can read beats a dot, whose
whole answer is "something". The count uses tabular numerals so a bell going 9 → 10 does not shift the
button. The menu is `dropdown-menu-dark`, aligned to the bar's trailing edge like the account menu, and
the widest of the two — a notification is a sentence and an account line is a word.

An **unread** entry is bolder rather than tinted. The menu is dark and every other tint on it is already
a hover or active state, so weight is the one difference left that survives both themes. On the page,
the same row is marked by a three-pixel `--um-primary-strong` edge on its inline start and the same
bold sentence, because the list is where a reader reads the entries in order rather than scanning them.
A row's moment is secondary text at a smaller size, and a reviewer's note is a further line in secondary
text: three levels of loudness for three kinds of thing, and the middle one is the news.

The menu's item wraps rather than truncating — `.dropdown-item` is single-line by default, which would
cut a sentence off mid-word — and it carries no icon, because the action of a row is opening the thing
it names rather than acting on it.

### The held-update notice

The painted treatment only. What a live update is, which three streams carry them, and why a refresh is
applied only when the page holds nothing unsent are in
[conventions.md](conventions.md#real-time-updates) — read that for *why*; this is what it looks like.

The notice is a **floating card where the flash toasts are** — the same offset below the navbar, the
same trailing edge, the same width cap, the same z-index — because it answers the same moment: something
happened that this page does not show yet. It wears the page's own surface and border rather than a
status color, since nothing has gone wrong; what distinguishes it is the pair of controls. The sentence
sits on its own and the **Reload** button beside it is the primary outline, with the close button last.

It is hidden with a modifier class rather than the `hidden` attribute, because the element's own
`display: flex` would win against the attribute's `display: none` and the notice would be permanently
visible on every page.

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

The navbar renders no placeholder links, and neither does the right utility sidebar: every entry
there is a real destination. A destination that does not exist yet is an `aria-disabled` span painted
in the flat disabled gray, never a link to a missing route; which entries are currently waiting, and
the rules that keep navigation honest, are in
[features/navigation.md](features/navigation.md#navigation-entries-are-honest-about-what-exists).

### Responsive behavior

- At `lg` and above, the left workspace navigation is a `14.5rem` sticky column.
- Below `lg`, it becomes a Bootstrap `offcanvas-start`; the main area shows a compact `Menu`
  button and the current universe/story context.
- Below `lg` the navbar collapses into the toggler menu, and the search box is inside it with the
  account menu — it is one collapsed navigation surface, not a bar that stays partly usable.
- At `xl` and above, the right utility navigation is a `12.75rem` sticky column.
- Below `xl`, it becomes a Bootstrap `offcanvas-end`; the workspace bar exposes it through a
  `Tools` button. The `Menu` button is only shown below `lg`, when the left panel also needs an
  offcanvas trigger.
- The main column must have `min-width: 0` so long descriptions and tables do not break the grid.
- Keep `scroll-padding-top`/sticky offsets aligned with the 50px fixed navbar.

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
- At `lg` and above the left column is a `14.5rem` sticky column; below `lg` it becomes a Bootstrap
  `offcanvas-start` with a compact **Menu** button. At `xl` and above the right column is a
  `12.75rem` sticky column; below `xl` it becomes an `offcanvas-end` opened by a **Tools** button.
  The **Menu** button appears only below `lg`, when the left panel also needs a trigger. The main
  column must have `min-width: 0`, and sticky offsets stay aligned with the 50px navbar.
- Real entries show `icon_text_count` as aligned `.sidebar-count` pills, and a list row's own count
  uses the identical `.record-count` pill. Current links use a 3px primary edge and a soft primary
  background with `aria-current="page"`, so color is never the only state signal. Placeholder
  navigation is rendered in the flat disabled gray with no hover emphasis.
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

The primary action belongs in the header's action area, and it leads that group: the controls after it
are navigation, conversation, or a page-state control, never another destination for the same task.
On narrow screens actions wrap below the copy. From `md` up, the copy keeps a readable basis and the
action area takes at most half the row, folding its own controls onto more lines when they do not
fit; a long title, a long description, or a translated action label never widens the document or
reaches the right sidebar. Avoid placing a title and its primary button in unrelated vertical
sections.

A list's filter is a supporting control, not a second page primary: its submit is an outline button
so the single solid primary stays in the header. The same rule holds on a taxonomy tree, where the
filter and the add control share the header. A form that changes the page's own content rather than
being its primary action — the Sections workspace's **Move scene**, for example — submits with that
same outline weight.

The **Story overview** chooses its one primary action from the Story's state rather than its record
type: an empty Story with a starting structure available leads to the structure card below, so the
header and the body recommend the same first step; an empty Story without one leads to **Open
sections**, and a Story with a Section or Scene leads to **Open scenes**. Sections, Plots, and Scenes
stay in the structure card below as one destination row each — never as a cluster of equal buttons
with the same counts repeated beneath them — and the appearance grid opens from the
scenes-per-character card, so the header does not repeat the body's destinations or offer a second
creation label beside the list it opens.

The header's `description` is for a page that **is** the thing it describes. A workspace that has a
**tab strip** states what it holds in `shared/_content_intro` instead, rendered *below* the strip and
above the list — `.content-intro`, the same `.page-description` treatment pulled back up against the
tabs. The header then states only what identifies the page: eyebrow, title, count. `shared/_content_tabs`
renders the intro itself when given one, and `shared/_taxonomy_tree` renders it after whichever
navigation it used. Characters, Relations, Locations, Events, Items, Ownerships, the Timeline, and
every taxonomy tree are on this treatment; a page with no strip (a universe, a story, a settings
section) keeps its sentence in the header.

### Empty states

Use `shared/_empty_state` for no records. It must explain what the record belongs to and why it is
useful. Tags remain optional in every empty-state message. Do not imply that a default tag is
required.

### Row and count treatment

The row shape — the linked name on the left with its badges and count pill, the action menu on the
right, and the rule that nothing on a row depends on hover — is defined once, in
[conventions.md](conventions.md#list-rows). Read that for the contract. This section is the painted
treatment: a linked name keeps the title's size and weight, takes the link color, and underlines on
hover or focus, the same link color the menu's **Details** item uses, so it reads as a destination
without gaining an icon or a second weight. The `.record-count` pill is styled like the sidebar's
`.sidebar-count` pills so a row's count and a sidebar's count read as the same quiet object, and a
destructive action in a row's overflow menu is marked by text or icon rather than by a permanently red
button. The Members workspace's person list uses the same `.entity-row` wrapper instead of a table,
with its access select, Save, and Remove controls in the row's action group, so a phone wraps them
under the name rather than clipping the select.

### Flat entity lists

Characters, items, events, relations, and ownerships use:

- `shared/_row_actions` for a neutral overflow menu;
- a visible name/title and tag badges;
- one clamped line of summary or description: a flat list row is a glance, and the record's own page
  carries the full text, so Character and Scene rows share one density instead of growing with
  whichever summary they happen to carry;
- a `content-surface`/`list-group` wrapper;
- a modal for quick create/edit, preserving the existing JSON-only mutation flow;
- mutation controls hidden for guests and read-only members, while the record content and the name
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
and Relations; the Item workspace has Items and Ownerships; the Event workspace has Events and the
**Timeline**. Locations and Sections each have one record tab. The Timeline is a tab rather than a
sidebar entry of its own: the sidebar keeps one Event link, current across both tabs, and the two are
reached through `content_workspace_tabs(:event)`. Use `shared/_tag_workspace_navigation` for
Configuration → Tags: the Universe/Story scope switch is a URL-backed segmented control, followed by
the seven universe taxonomy tabs or the two story taxonomy (Section/Scene) tabs. Use
`shared/_settings_navigation` for the platform Settings page, whose tab strip is the same pattern
turned vertical (`nav nav-tabs flex-column`). Every tab strip is a URL-backed Bootstrap `nav-tabs`:
use the active class and `aria-current="page"`, but do not add `data-bs-toggle="tab"` because each
destination is a separate request. The scope switch's links are not tab-shaped; its active option
carries `aria-current="page"` like every other current destination.

### Details-page treatment

The details page's contract — four shared partials, read-only, guest-readable, one per record — is in
[conventions.md](conventions.md#record-details-pages). The painted treatment: the identity card with
the record type, then a `.detail-facts` list of labelled values separated by hairlines, where an
unset value renders explicit copy instead of an empty cell, then one or more related-records
sections, each with a count badge and its own empty state. The label is a small uppercase kicker at
the left of the row and the value is sentence case at the right; below `sm` the label sits above the
value so neither is squeezed. The empty copy states what will appear later and must not tell a guest
or a read-only member to add records. The identity card's two-column layout when a record has a photo
is in [conventions.md](conventions.md#record-details-pages). Scene Details uses the same hairline
list for its identity facts, after the Element prose.

Two variants exist for facts that do not want to be a labelled row, and a details page picks per
fact rather than per record:

- **`.detail-facts-wide`** — the facts span the card's whole measure instead of the column a photo
  leaves, because they are prose. A tag's description is the case that uses it; its value is set at
  the serif prose measure (`68ch`, `1.0625rem`, `1.68`).
- **`.detail-footer`** — the record's own *settings* as compact `label: value` pairs on one quiet
  line below a rule, set in the secondary colour. They are configuration rather than something a
  reader scans for. A tag's `scope: universe` and `color: #d3d3d3` are the case that uses it; the
  scope's explanation lives in a popover behind an info button, not on the card, and the button keeps
  a visible focus ring because it is a control wearing plain text.

Neither is a second partial: both are the same `shared/_detail_facts` and a new `shared/_detail_footer`,
so a fact's label/value contract stays one thing. The painted shapes are here; the rules are in
[features/tags.md](features/tags.md#the-tag-details-card).

### Taxonomy trees and other hierarchy pages

The taxonomy system's rules — the DSL, the mandatory scope, the tree's row and menu contract, the
`taggable` and `show_in_menu` flags, and the DOM-built editor — are in
[features/tags.md](features/tags.md). The painted shape of the tree:

- `shared/_taxonomy_tree` and `shared/_taxonomy_node` render tag indexes, Sections, and Locations
  with a page header carrying an explicit `title`, count, and a human-readable add label, optional
  URL-backed workspace tabs, the taxonomy's own sentence below that navigation as `.content-intro`,
  and a consistent empty state.
- The name is a link to the record's own page, for every access level; there is no rename button and
  no inline creation. The page's Add button and the row menu's Add child open the editor modal.
- A `.record-count` pill sits next to the name and its tags, naming the number of records that page
  will list (`(4 characters)`, `(3 scenes)`). The row carries the single neutral overflow menu, whose
  items and boundary behavior are in [features/tags.md](features/tags.md); for a writer it opens with
  **Details** and then holds the mutations, and the row itself has no add or arrow buttons. Drag
  handles remain an optional enhancement.
- The name link and the menu toggle are never a hover affordance: a hover-revealed control is not
  usable on touch and is invisible to a keyboard user scanning a long list, so the row is the same
  shape as a flat list row.

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
  take part** — with the name as the route and, for writers, Move up/Move down controls and the menu
  whose first item is **Details**.
- The three Scene workspace tabs share one row shape: the linked record's name, a bordered
  **Linked** badge, and `Role: …` with **No role recorded**. The Characters tab is the
  exception, because it has a second source: a Character who only speaks carries **Speaks in N
  element(s)** instead of **Linked** and has no dropdown.
- The Locations tab is the only one whose rows are hierarchical, so its title is the full ancestor
  path (`Winden / Nielsen House / Martha Room`) and its picker is depth-indented in root-first order.
- **Appears in scenes of &lt;Story&gt;** reuses the same entity rows, prefixed with the same 1-based
  narrative-position pill, with its reason badges (**Linked**, **Speaks in N element(s)**,
  **Depicted**) listed and never collapsed.
- The **Find scenes** filter surface (`scenes/_filter`) is a full-width `search` field, a **Section**
  select, a **Scene Tag** select, a **Status** select, two `date` fields labelled **In-world from**
  and **In-world to**, a **Filter scenes** submit, and a **Clear filters** link that appears only
  while a filter is in effect. The fields fold into one column below `sm` with the two date fields
  side by side. One
  sentence states the two rules an author needs: filtering does not change the narrative order, and a
  Scene without an in-world time is not in a date range. Every access level sees it, because
  filtering is reading. While a filter is active the surface adds `Showing N scenes of M scenes.`
  followed by the active filters as neutral badges.
- The Scene editor keeps the title, short description, status, and Section in view and folds every
  other optional field into a `.form-disclosure` native `<details>`: a hairline, a bold summary, and
  a group that expands in place rather than navigating. Tags, plots, and Events share one searchable
  picker rather than mixing a native multiple list with a richer control.
- A recognized Character name in Element prose is a `.mention` link with a solid hairline underline.
  A name the Scene does not record as present adds `.mention--suggested` and a dashed underline; the
  difference is a line pattern rather than a hue, so it survives light, dark, and print. The matching
  and suggestion rules are in [features/mentions.md](features/mentions.md).
- Narration and Dialogue Elements use one Bootstrap modal and the shared modal contract, not a second
  editor. A one-line hint under the type selector states what each kind is, and the same line changes
  with the selection. An empty Element list gets its own empty state, because a Scene may hold any
  number of Elements, including none.
- **Scene Details opens with that Element list**, above the identity card: a writer's next block is
  the first thing the page shows rather than the last thing it scrolls to. Each row carries a visible
  **Edit** button beside its Move controls and keeps Delete in the menu. The editor's Content field is
  a tall, growing textarea (`.scene-element-body`) rather than a five-row box, and the dialog is
  full-screen below `sm`, so a phone's keyboard has room above the paragraph it is writing into.
- A Scene's drafting contract, when the browser preference shows it, is a `.drafting-contract-body`
  surface closing the page: a tertiary-background card with a leading accent rule, rendered
  Markdown, and tighter list spacing than body prose, so an imported contract reads as an outline
  rather than its source block. The whole section is absent when the preference is **Hide**.
- A long Section name wraps instead of pushing the layout, and the action group wraps below the title
  at narrow widths instead of hiding it or relying on hover.

### Narrative order chart

The two views, the column order, and the read-only contract are in
[features/scenes.md](features/scenes.md#narrative-order-beside-the-timeline); the painted shape:

- The page's own **List** / **Chart** strip is a URL-backed `content_tabs` strip with `active` set
  explicitly, so each view is a canonical request rather than an in-document pane. The Story
  workspace's tabs never appear here.
- Two column headings name the orders and carry the same Scene count, because both columns hold the
  same Scenes. The chart itself is a server-rendered SVG inside a `.narrative-chart-scroll` region
  with `tabindex="0"` and an accessible name; it has a floor width and scrolls rather than shrinking
  a column into a thumbnail.
- A bar is one Scene and carries no label: at a Story's density a label would not fit, so the bar's
  link has an accessible name (its narrative or chronological position, the Scene, and its step) and
  the facts live in the detail panel below the chart. The panel sits below so a taller card never
  moves the bars out from under the pointer.
- At rest every connector is a light border-color line and every bar is secondary ink at half
  opacity. The Scene under the pointer or the keyboard takes the primary color on both bars and its
  line, and the other lines recede. Focus is shown on the bar itself, not only in the panel.
- The band of Scenes with no place on the timeline is separated by a dashed rule and drawn lighter.
  The legend below the chart names the bar, the line, and the dashed rule, so the meaning is not
  carried by color alone, and every painted value comes from Bootstrap theme tokens so Light and Dark
  both stay legible.

### Scene board

The board's columns, ordering, and read-only contract are in
[features/scenes.md](features/scenes.md#the-story-wide-scene-planning-board); the painted shape:

- A `.scene-board-scroll` region with `tabindex="0"` and an accessible name holds a row of fixed-width
  columns. It scrolls horizontally rather than shrinking a column below a readable width, and a tall
  board scrolls vertically inside the same bounded region, so each column heading stays at the top of
  its column.
- A column is a bordered surface carrying its Section name (linked to the Section page) and a count
  pill that names what it counts. An empty column says **No scenes here** instead of disappearing.
- A card uses the tertiary background inside its column and carries the 1-based position pill and the
  Scene title link. The title uses the same link color at rest and underline on hover/focus as a list
  row's name. Nothing on the card depends on hover.
- A writer's card adds the list's Move up/Move down buttons under a visible **Narrative order**
  label, with the same disabled boundary state, and a **Change section only** disclosure holding a
  compact Section selector and its **Save section** submit. The labels keep the two operations apart
  because an arrow inside a column otherwise reads as moving the card within that column. The
  disclosure is a native `<details>`, so regrouping needs no JavaScript and a keyboard or touch reader
  uses the same control as a mouse. Read-only members and guests get the card without those controls,
  and there is no drag handle.
- Print lets the columns wrap, removes the sticky heading offset, and keeps a column from breaking
  across pages.

### Scene matrix

The matrix's rows, columns, and read-only contract are in
[features/scenes.md](features/scenes.md#the-story-wide-scene-matrix); the painted shape:

- A real `<table>` inside a `.scene-matrix-scroll` region with `tabindex="0"` and an accessible name.
  The Scene column is sticky at the left and carries the same 1-based bordered position pill the
  Scenes list uses; the fact columns wrap rather than forcing the page wider.
- The Scene title opens Scene Details and each linked Event opens its own page. The three count
  columns are plain right-aligned numbers under headers that name what they count, so a figure is
  never a bare number without its subject.
- An absent fact is secondary-colored words — **No tags**, **No point of view recorded**, **No
  in-world time recorded**, **No events linked** — never an empty cell. Tag badges keep their taxonomy
  colors.
- The page adds no buttons, forms, or hover actions. Print removes the sticky offset, avoids breaking
  a row across pages, and shrinks the type, so a Story can be read on paper as well as on screen.

### Appearance grid

The grid's rows, layers, and read-only contract are in
[features/appearances.md](features/appearances.md); the painted shape:

- A real `<table>` inside a `.appearance-grid-scroll` region with `tabindex="0"` and an accessible
  name, exactly as the Map's scroll region is reachable. The Character column is sticky at the left;
  Scene headers keep their `(position, id)` order and are the position pill alone, so a column is as
  narrow as its cell. Pointing at or focusing a pill opens the shared `custom-popover` with no title:
  each Section level from the root on its own line, then `Scene: (N) name`, and
  `.appearance-grid-popover .popover-body` uses `white-space: pre-line` so the server's newlines are
  the line breaks. The pill is the link to Scene Details, and its accessible name is the whole Scene
  sentence.
- A recorded appearance is `.appearance-mark--present`, a filled square. A prose mention is
  `.appearance-mark--mention`, a dashed outline. A cell can hold both marks, and they always sit side
  by side rather than stacking in a narrow column; the legend names the two layers rather than
  merging them. Neither mark depends on hue, so light, dark, and print keep the distinction.
- The legend sits above the table, outside the scroll region, and carries the sentence that a mention
  is not an appearance. Empty cells have a visually hidden **Not present** label; the table has a
  caption, column headers, and row headers for keyboard and screen-reader navigation.
- Print removes the sticky offsets, keeps the marks as black fill and black dashes, and avoids
  breaking a row across pages. A popover has no print equivalent, so the printed header restores the
  Scene name under its position. The grid adds no buttons or forms; its one hover affordance is the
  header popover, which only repeats the Scene's own facts.

### Scenes-per-character chart

The chart's count, empty states, and Story scope are in
[features/appearances.md](features/appearances.md#the-scenes-per-character-chart); the painted shape:

- A server-rendered SVG sits inside a vertically scrollable `.character-scene-chart-scroll` region
  with `tabindex="0"` and an accessible name, so a long cast never pushes the rest of the overview
  down and a keyboard user can reach every bar.
- A row shows the Character's name at the left and the count at the right above a full-width track;
  the primary-colored bar is the share of the Story's Scenes. The visible name is shortened with an
  ellipsis when it is very long; the link's accessible name and the table carry the whole name.
- Every bar is a link and paints a visible focus ring on the bar itself. The table equivalent sits in
  a native disclosure below the figure, so it needs no JavaScript.
- The track, bar, labels, and focus state come from Bootstrap theme tokens, so the chart stays
  legible in Light and Dark. Print removes the scroll limit and paints the bar black on a white
  track.

### Map diagram

The Map's domain rules and text alternative are in [features/map.md](features/map.md); the painted
surface is a scrollable SVG inside the shared content surface:

- Location cards use the page's body surface and border tokens. Their SVG links retain a visible
  primary-color focus ring and a touch-sized card target.
- Parent/child connectors use the neutral border color; directional Routes use a dashed primary-color
  path and arrow, so the distinction is not carried by color alone. The legend repeats both meanings.
- The SVG keeps its derived dimensions and scrolls horizontally when those exceed the available width.
  The accessible Location and Route lists remain on the page as an equivalent text-and-link view.
- Every painted value comes from Bootstrap theme variables, so cards, hierarchy lines, Route arrows,
  and focus states remain legible in Light and Dark.

## Accessibility and interaction

- Every icon-only control has an accessible label or visually hidden text.
- Current navigation uses `aria-current="page"` and a non-color indicator, including the top bar's
  scope links, which are current only on the page they point at.
- Dropdown menus have unique IDs and `aria-labelledby` targets.
- Delete actions are labeled as destructive and retain confirmation.
- The **Details** menu item repeats the record name in its accessible name, so many identical looking
  items stay distinguishable in a long list. A row's name link uses the name itself as its accessible
  name, so the two destinations do not share a label. A count is a separate pill whose visible text
  names what it counts, so it is announced as a fact about the record rather than as part of a link.
- Placeholder navigation keeps `aria-disabled` and is additionally styled as unavailable, so the
  visual state and the semantics agree.
- Keep focus states visible; do not use hover as the only way to discover an action. A row's name
  link and menu toggle are always rendered, so no list control depends on hover, on a pointer
  device, or on a wide viewport.
- Focus rings use one vocabulary. Buttons and form fields keep Bootstrap's primary glow; plain links
  and `summary` elements draw the same primary color as a 2px outline instead of falling back to the
  browser's black outline. A control that already has a component ring keeps it rather than drawing
  a second one.
- Taxonomy insertion targets are at least 44×44 CSS pixels and reordering never depends on
  hover/drag or a drag-only path.
- Preserve `prefers-reduced-motion` handling for transitions and drag feedback.
- Tag color is supplementary information, never the only way to identify a record.

## Comparison prototypes

A UI change that has more than one reasonable shape starts as a **static comparison prototype**
before any application view, stylesheet, or test changes. The page shows the current design and the
proposed one on the same page, with the same content in each, and a review bar that switches layout,
state, light/dark, and desktop/phone, so the two are judged like for like rather than from a
description. The [visual directions](visual_directions.md) exercise is the precedent for a large
comparison, and the [Scene filter comparison](scene_filter_prototype.html) is the working example.

- Copy the built values from `_theme.scss` and the real view markup. A prototype is a hand-built
  mock, not a running Rails page, but it must not introduce a second palette or a simplified
  component that makes the proposal look better than it would ship.
- Run both designs through the same states: unfiltered and empty, populated, filtered, and no match
  where the surface has them. Keep the current design faithful, including its awkward states.
- Measure both blocks at the selected width and state, and state the measurements on the page. A
  proposal can be shorter in one state and taller in another; showing that is the point, not a
  claim that the new one always wins.
- Save it as `docs/<subject>_prototype.html`, link it from the backlog item that owns the decision,
  and leave application code untouched until the owner accepts a direction. An accepted comparison
  stays as a record; the implementation then updates the owning document and the changelog.
- A comparison does not replace rendered browser checks, accessibility inspection, or participant
  testing.

## Change checklist for a new page

1. Choose the existing functional pattern (tree, flat modal list, or full-page form). A read-only
   details page is composed from `shared/_record_details` and `shared/_detail_section`, never from
   a modal and never with its own editor.
2. Start with `shared/_page_header` and `shared/_empty_state` where applicable.
3. Use the correct universe/story scope in every path.
4. Use `shared/_row_actions` for modal-list rows rather than inventing another action layout, and
   render `record_title_link` on the name and pass `details_url` so the menu's **Details** item keeps
   the record's own page one click away. Keep the [list row shape](#list-rows): a linked name on the
   left, the action menu on the right.
5. Add the record link to the Bible or Story workspace; use `shared/_content_tabs` for related
   records and `shared/_tag_workspace_navigation` for taxonomy management. Put universe
   configuration tools and the Members access manager in the right sidebar's **Configuration**
   section, and a preference that belongs to the person rather than the universe in the top bar's
   **Settings** page, behind `shared/_settings_navigation`.
6. Check keyboard focus, mobile width, empty state, long text, and the page in **both** themes.
7. Update the relevant docs and tests in the same change.
