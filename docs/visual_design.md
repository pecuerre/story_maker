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

The navbar is intentionally small: three links and the account menu.

- `Universe Maker` is the brand and the **landing page** — the universes list, which is also where a
  universe is created;
- `Universe: <name>` links to the current universe page;
- `Story: <name>` links to the current story page and exists only while a story is current;
- `Account` contains the signed-in email and logout action.

There is no universe or story switcher in the top bar: changing universes happens on the landing
page, and changing or creating stories happens on the universe page, which lists the universe's
stories. A scope link is marked current with `.active` **and** `aria-current="page"` only on the
page it points at, so the bar never claims a scope that is not the page being viewed. The account
menu is the navbar's only dropdown, which also means the top bar issues no query.

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

The left navigation is task-oriented and scope-aware. It is one continuous surface read as two
scoped blocks, and each block is a **context header** followed by the **section** it introduces, so
the reader can always tell which scope a link belongs to:

1. **Current universe** context — universe name.
2. **Universe Bible** — Characters, Locations, Events, Timeline, Items.
3. **Current story** context — story name, or an explicit
   **None selected** state.
4. **Story workspace** — Story overview, Sections, Scenes (or All stories plus a prompt).

Configuration is not in this column: it belongs to the right utility sidebar, so the left column
carries universe and story content only.

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

Configuration is the first section of the right utility sidebar. **Tags** opens the shared taxonomy
workspace: **Universe Tags** is selected by default and contains Character, Relation, Location,
Event, Item, and Ownership tag tabs; **Story Tags** contains separate story-scoped Section tags and
Scene tags tabs. The same section holds **Members** for universe admins, where the read/write/admin
access list is managed, and the entry itself is always rendered so **Tags** stays available to a
guest or read-only member. New configuration tools should be added as top-level entries here,
grouped by scope when needed.

Counts use aligned `.sidebar-count` pills, and a list row's own count uses the identical
`.record-count` pill. Current links use a soft primary background and
`aria-current="page"`; color is not the only state signal. **Scenes** is a real link with its own
count while a story is selected and an `aria-disabled` placeholder otherwise; the right-sidebar
entries are the intentional placeholders for future functionality and are rendered in the flat
disabled gray so they never look like something to click.

### Right utility sidebar

The right sidebar is the tools scope, so it is one continuous surface: a green **Universe tools**
context block, then the **Configuration** section with **Tags** and the universe **Members** access
manager for admins, then **Collaboration**, **Analytics**, and **AI** placeholders. Its green hue is
the same `--um-scope-tools` pair the section headers use, so the block reads like the two left-hand
scopes. Keeping Configuration and the access manager here leaves the left column purely about
universe and story content while preserving a stable home for richer collaboration and analysis
features without adding fake routes.

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

### List rows

Every list row in the application — Characters, Relations, Locations, Events, Items, Ownerships,
Sections, every tag tree, and Scenes — has the same shape, so a row means the same thing wherever
it appears:

- **left**: the record's name as plain text, followed by its tag badges and, where a count exists
  (a tag, a Section), a `.record-count` pill that names what it counts — `(4 characters)`,
  `(3 scenes)` — next to the name it belongs to;
- **right**: the **Details** link into the record's own page, then the overflow action menu.

Both parts of the right-hand group are always visible at every access level. Nothing on a row
depends on hover, so a list reads the same with a pointer, a keyboard, on touch, and at a narrow
width, and a read-only member sees the same right edge as a writer. The name is never a link: the
Details link is the single, predictable way into a record, which is why it repeats the record name in
its accessible name.

A count is a quiet pill, never part of a link label. Keeping it out of the Details label leaves that
label short in a long list and puts the number where it can be compared across rows. It always says
what it counts — a bare figure beside a name is ambiguous once a list has more than a few rows — and
because the label is visible text, the pill is its own accessible name.

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
(Section/Scene) tabs. All tabs are URL-backed Bootstrap `nav-tabs`: use the active class and
`aria-current="page"`, but do not add `data-bs-toggle="tab"` because each destination is a separate
request.

### Record details pages

Every record has exactly one details page, and every list row and taxonomy node links to it. Build
the page from `shared/_record_details` plus `shared/_detail_section`, so the shape stays the same as
more information is added to it:

- the shared page header, with the record's name as the title and a link back to the list it was
  opened from;
- an identity card: the record type, then a `.detail-facts` grid of labelled values. A value that is
  not set renders explicit copy instead of an empty cell;
- one or more related-records sections, each with a count badge and an empty state when there is
  nothing to list yet. The empty copy states what will appear later and must not tell a guest or a
  read-only member to add records.

A details page renders no mutation control, so read-only members and public guests see exactly the
same page. A tag's page lists the records carrying it; a Section's page lists the scenes grouped
under it, each still showing its narrative position.

### Taxonomy trees and other hierarchy pages

Use `shared/_taxonomy_tree` and `shared/_taxonomy_node` for tag indexes, Sections, and Locations.
The shared tree provides:

- a page header with explicit `title`, count, description, and human-readable add label;
- optional URL-backed workspace tabs via `tabs` and `tabs_aria_label` locals;
- a consistent empty state;
- a native rename button with inline rename for users with write access. The button is sized to its
  own text, so only hovering or focusing the name starts a rename — clicking the rest of the row
  does nothing;
- a `.record-count` pill next to the name and its tags, naming the number of records that page will
  list (`(4 characters)`, `(3 scenes)`), and a **Details** link on the right that is visible at every
  access level;
- one neutral overflow menu per row holding Add child, Insert before, Insert after, Move up, Move
  down, Edit, and Delete. Move up/down are disabled menu items at the sequence boundaries; the row
  itself carries no add or arrow buttons, and drag handles remain an optional enhancement;
- successful mutations refresh the same URL so counts and serialized parent/tag options are never
  stale; dynamic names and option labels are rendered as text, not HTML.

The row's right-hand group (Details + menu) is never a hover affordance. A hover-revealed control is
not usable on touch and is invisible to a keyboard user scanning a long list, so both are always
rendered and the row is the same shape as a flat list row.

The first insert target of the tree needs room for its 44px button, so the root list keeps top
padding; otherwise the button would hang over the hint paragraph above it.

The add action must be human-readable (`Add relation tag`), never generated directly from a
model parameter (`Add Relation_tag`). The tree Stimulus controller owns the inline add form and
must keep the empty-state removal, hierarchy indentation, and keyboard/focus behavior in sync with
the rendered node partial. It must not grow a second JavaScript copy of the row: a successful
create always refreshes the same URL, so only the rename button is ever built in JavaScript, and
that button's content is rebuilt from the node's data attributes when a rename is cancelled.

### Full-page forms

Universes, Stories, and universe membership management use the existing form patterns with:

- Bootstrap labels and controls;
- an alert-based error summary;
- a clear primary submit action;
- a cancel link back to the relevant scope.

Do not replace these with a modal: full-page forms remain appropriate for objects with a stable
URL and meaningful navigation.

### Scene workspace (core, references, grouping, tags, Elements, and presence shipped in 11.1–11.7; later slices pending)

The accepted [ADR 0007](adr/0007-story-owned-scenes-and-elements.md) defines a calm, explicit
Scene workspace. The **Scenes** sidebar entry is a real story-scoped link with its own count while a
story is selected, and remains an `aria-disabled` placeholder with no story.

The global Scenes page is a flat list in narrative order, not a Section-grouped tree. It uses the
shared page header, content surface, entity rows, and empty state. Rows show:

- the 1-based narrative position as a bordered pill with an
  `aria-label="Narrative position N of M"`, where both numbers come from the whole sequence;
- the required Title as plain text and a clamped description preview, like every other list;
- a bordered grouping badge showing the Scene's full nested Section path, or **Ungrouped** with an
  open-folder icon. The `title` states that grouping does not change the narrative order;
- optional Scene Tag badges using the taxonomy colors, with untagged Scenes remaining valid;
- two small bordered count pills: the Scene's **Element** count and how many **Characters take part**
  in it. A derived speaker counts once, so the figure is the union the Characters tab shows, never
  the sum of the two sources;
- a right-hand group with the **Details** link into Scene Details for every access level, followed by
  the writer-only Move up/Move down controls and the Edit/Delete menu, with a clear disabled state at
  the sequence boundaries.

The three Scene workspace tabs — **Characters**, **Items**, and **Locations** — share one row shape:
the linked record's name as plain text, a bordered **Linked** badge, and `Role: …` with **No role
recorded** when the author recorded the fact without annotating it. Writers get the same
**Edit**/**Remove** dropdown as every other JSON-only row, and the details link renders for every
access level. The Characters tab is the exception to the badge, because it has a second source: a
Character who only speaks carries **Speaks in N element(s)** instead of **Linked** and has no
dropdown, because there is no stored row to act on.

The Locations tab is the only one of the three whose rows are hierarchical, so its title is the full
ancestor path (`Winden / Nielsen House / Martha Room`) and its picker is depth-indented in
root-first order. Two places called "Room" are never ambiguous there.

A shared universe record's details page ends with an **Appears in scenes of &lt;Story&gt;** section:
the same entity rows, prefixed with the same 1-based narrative-position pill, so the order the Story
is told in is visible from a record that knows nothing about that order. Its reason badges
(**Linked**, **Speaks in N element(s)**, **Depicted**) are listed, never collapsed. The section is
read-only navigation, so it carries no mutation control for any access level. Without a current
Story it renders the shared empty state with a link to the story list, because a Scene has no
Universe-level URL to point at.

The global Scenes list keeps the two count pills it already had. Item and Location counts are
deliberately absent: they would need one extra grouped query each per page, and the three workspace
tabs are the place that detail belongs. Do not render placeholder counts for them.

A Story can hold hundreds or thousands of Scenes, so the list is preceded by a **Find scenes**
surface (`scenes/_filter`): a full-width `search` field, a **Section** select, a **Scene Tag**
select, two `date` fields labelled **In-world from** and **In-world to**, a **Filter scenes**
submit, and a **Clear filters** link that appears only while a filter is in effect. The fields fold
into one column below the `sm` breakpoint with the two date fields side by side, and the area never
depends on hover or a wide viewport. One sentence states the two rules an author needs: filtering
does not change the narrative order, and a Scene without an in-world time is not in a date range.
Every access level sees it, because filtering is reading.

While a filter is active the surface adds `Showing N scenes of M scenes.` followed by the active
filters as neutral badges, so a result set is never ambiguous. A filter that matches nothing gets
its own empty state — **No scenes match these filters**, the story's total, the same filter badges,
and a **Clear filters** action — which is never reused for a Story that has no Scenes
(**No scenes yet**).

The page's primary **Add scene** action opens the stable new Scene form. The page header states
that the order is the order the story is told, not in-world chronology, and that a section group
only organizes a scene. Move controls are real forms, so they work with a keyboard and on touch, and
the action group wraps below the title at narrow widths instead of hiding it or relying on hover.

Scene Details (`/scenes/:id`) is the canonical, inspectable page: the Title, narrative position,
short description, Section group, Scene Tag badges, linked Event, in-world time, and story context
render for every access level, and only writers get the **Edit scene** action. `/scenes/:id/edit` is
the full-page editor form and `new` reuses the same partial, so the Title/Description/Section/Event/
time/Scene Tag fields exist in exactly one place. The Details page labels narrative position and
in-world time separately and says explicitly that the two values are independent and that a
disagreement between them is not detected. Scene Tags are optional; an empty tag state remains
valid and never receives a default.

The editor's **Scene Details / Characters / Items / Locations** shell is a URL-backed
`shared/_content_tabs` nav. **Scene Details** and **Characters** are live links; **Items** and
**Locations** are `aria-disabled` placeholders with an explanatory `title` until their slices add a
destination. A tab is never a link to a route that does not exist.

The Scene form groups its fields: **Scene tags** holds the optional native multi-select with
root-first tag paths, **Organization** holds the Section selector (with **Ungrouped** and
depth-indented Section names), and **In-world time** holds the Event selector (with **None**) and
the `datetime-local` field. Each field has copy that states what it does *not* do — grouping never
changes the narrative position, Scene Tags do not change order, and the event link and the in-world
time never write or clear each other.

The Sections workspace keeps its taxonomy tree and adds an **Ungrouped scenes** surface below it: only
the Scenes that belong to no Section, headed by a badge that says how many that is
("3 ungrouped scenes") because a bare figure next to the story's own Scene count is ambiguous, each
row showing its narrative position and Title
in canonical order, and a line saying how many Scenes are grouped and that they are listed on their
own Section's page. A grouped Scene is therefore never shown twice: the tree's **Details** link is
the way in. When nothing is ungrouped the surface says so instead of showing an empty list. A long
Section name wraps instead of pushing the layout. Writers also get one selector-driven move form
(**Ungrouped scene** → group, offering **Ungrouped** plus every Section path) with a
real submit button; it offers only the ungrouped Scenes the surface above lists, because the form
belongs to that block — a grouped Scene is regrouped from its own Section's page, where the editor
carries the Section selector. Drag-and-drop is not offered, so the move always works by keyboard and
on touch.
Read-only members and guests see the same surface with no controls and no instruction to add scenes.

Narration and Dialogue Elements use one Bootstrap modal and the shared modal contract, not a second
editor: the form has an **Element type** selector, a required
**Title**, optional plain-text **Content**, and a multi-speaker **Speakers** picker shown only for
Dialogue. A one-line hint under the type selector states what each kind is, and the same line changes
with the selection. Narration has no speaker control; switching a Dialogue that has speakers to
Narration reveals a single **Remove the speakers and make this narration** confirmation rather than
dropping them silently. Error summaries stay in the modal with the entered
values; a failed request does not close it. The Element list renders on Scene Details, below the
Scene's own facts, as a `detail-section` with its own count badge and an **Add element** action. Rows
show a 1-based position in this Scene's sequence, the kind, the content (or an explicit "No content
yet. A title is all an element needs."), a Dialogue's speakers with the sentence that says the link
records who is in the conversation and not which line belongs to whom, and accessible Move up/Move
down controls plus the Edit/Delete menu for writers. An empty Element list gets its own empty state:
a Scene may hold any number of Elements, including none.

The **Characters** tab (`/scenes/:id/characters`) is a real read page. Rows are one per Character
in the union of the two participation sources, ordered by name, each with a neutral **Participant**
badge for a stored link, a **Speaks in N element(s)** badge for a Dialogue speaker, the role (or
**No role recorded**), and a line naming the Elements a speaker speaks in. A Character who is both
carries both badges on one row. Only a stored link offers the Edit/Delete menu, because a derived
speaker has no row of its own to act on; the row still links to the Character's own details page for
every access level. Writers also get **Add character**; the picker offers every Universe Character
and says plainly that a duplicate is reported in the window, because Characters are shared by every
Story in the Universe. Read-only members and guests see the same list with no controls and a
non-instructional empty state.

The Scene/Story/Section/Event/shared-record destructive copy from ADR 0007 is mandatory. Do not
replace the consequences with only “Delete {record}?” merely to save space. Scene, Story, and
Event rows and the Section tree already use the full templates, and they must keep that wording as
later dependents are added.

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
   records and `shared/_tag_workspace_navigation` for taxonomy management. Put configuration
   tools and the Members access manager in the right sidebar's **Configuration** section.
6. Check keyboard focus, mobile width, empty state, and long text.
7. Update the relevant docs and tests in the same change.
