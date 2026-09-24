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

The old permanent right sidebar was removed because it contained only placeholder links and
consumed space on every page. Future contextual tooling should use a Bootstrap offcanvas or a
purpose-built inspector; see [`backlog.md`](backlog.md).

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
2. a responsive workspace navigation;
3. one flexible main content region with a `page-shell` wrapper;
4. a skip link and one shared flash region.

The navbar is intentionally explicit about context:

- `Universes` is the global picker;
- `Universe: <name>` is the current universe switcher;
- `Story: <name or Select>` is the current story switcher;
- `Account` contains the signed-in email and logout action.

The navbar does not render placeholder links. A feature that is not implemented should not look
like a live navigation item.

### Responsive behavior

- At `lg` and above, the left workspace navigation is a 16rem sticky column.
- Below `lg`, it becomes a Bootstrap `offcanvas-start`; the main area shows a compact `Menu`
  button and the current universe/story context.
- There is no permanent right column.
- The main column must have `min-width: 0` so long descriptions and tables do not break the grid.
- Keep `scroll-padding-top`/sticky offsets aligned with the fixed navbar height.

The old `.container-xl` 2/8/2 shell is not the content-arrangement model anymore. Use the shared
shell classes and let the main region grow.

## Navigation and information architecture

The left navigation is task-oriented and scope-aware:

### Story workspace

When a story is selected:

- Story overview;
- Sections.

When no story is selected:

- All stories;
- a prompt explaining that a story must be selected for story-specific structure;
- New story.

### Universe Bible

Universe-scoped records are grouped as:

- **People**: Characters, Relations;
- **Places**: Locations;
- **Time**: Events, Timeline;
- **Objects**: Items, Ownerships.

The Bible contains the records themselves. It does not contain taxonomy/configuration links nested
under each record.

### Configuration

Configuration is a separate sidebar section for organization and future settings. It currently
contains:

- **Story**: Section tags when a story is selected;
- **Universe**: Character tags, Location tags, Item tags, Event tags, Relation tags, and Ownership
  tags.

A taxonomy is a management layer, not a child navigation item of the record it classifies. New
configuration tools should be added here as top-level links, grouped by scope when needed.

Counts use aligned `.sidebar-count` pills. Current links use a soft primary background and
`aria-current="page"`; color is not the only state signal.

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
- a modal for quick create/edit, preserving the existing JSON-only mutation flow.

Relations should read naturally (`Character A → Character B`) rather than as an unlabeled database
row. Ownerships use the same readable relationship treatment.

### Taxonomy trees and other hierarchy pages

Use `shared/_taxonomy_tree` and `shared/_taxonomy_node` for tag indexes, Sections, and Locations.
The shared tree provides:

- a page header with explicit `title`, count, description, and human-readable add label;
- a secondary link back to the related content list;
- a consistent empty state;
- drag handles, inline rename, add-child, edit, and delete actions;
- a neutral overflow menu for edit/delete.

The add action must be human-readable (`Add relation tag`), never generated directly from a
model parameter (`Add Relation_tag`). The tree Stimulus controller owns the inline add form and
must keep the empty-state removal, hierarchy indentation, and keyboard/focus behavior in sync with
the rendered node partial.

### Full-page forms

Universes and Stories use the existing `_form` partials with:

- Bootstrap labels and controls;
- an alert-based error summary;
- a clear primary submit action;
- a cancel link back to the relevant scope.

Do not replace these with a modal: full-page forms remain appropriate for objects with a stable
URL and meaningful navigation.

## Accessibility and interaction

- Every icon-only control has an accessible label or visually hidden text.
- Current navigation uses `aria-current="page"` and a non-color indicator.
- Dropdown menus have unique IDs and `aria-labelledby` targets.
- Delete actions are labeled as destructive and retain confirmation.
- Keep focus states visible; do not use hover as the only way to discover an action.
- Taxonomy actions become visible on keyboard focus and on touch devices.
- Preserve `prefers-reduced-motion` handling for transitions and drag feedback.
- Tag color is supplementary information, never the only way to identify a record.

## Change checklist for a new page

1. Choose the existing functional pattern (tree, flat modal list, or full-page form).
2. Start with `shared/_page_header` and `shared/_empty_state` where applicable.
3. Use the correct universe/story scope in every path.
4. Use `shared/_row_actions` for modal-list rows rather than inventing another action layout.
5. Add the record link to the Bible or Story workspace; add taxonomy/configuration links to the
   separate Configuration section if the model needs them.
6. Check keyboard focus, mobile width, empty state, and long text.
7. Update the relevant docs and tests in the same change.
