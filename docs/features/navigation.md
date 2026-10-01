# Navigation

The navbar and the two workspace columns: what they contain, in what order, and why. The visual
system — tokens, hues, breakpoints, the shell — is in [visual_design.md](../visual_design.md); the
routing rules are in [conventions.md](../conventions.md#routes) and
[architecture.md](../architecture.md#routing--url-generation-the-sharp-edges).

## Two-step scope selection

The whole interface follows one idea: a reader picks a universe, then a story, and everything
visible is scoped to that choice.

1. **No universe selected yet** (fresh login → the Universes index): workspace navigation is not
   rendered and the main column takes the full width. The only initial task is selecting or creating
   a universe from the landing page.
2. **Universe selected** (`Current.universe`): a 16rem workspace sidebar appears on large screens
   and as a left offcanvas below `lg`. At `xl` and above, a 14rem right utility sidebar is also
   visible.
3. **Story selected** (`Current.story`): the Story workspace gains the story overview plus
   **Sections** and **Scenes**.

There is deliberately **no fallback to the universe's first story** — a story only becomes current when
the user picks it, and the remembered selection is cleared whenever an authenticated session starts
or ends. A universe may hold any number of stories, so "the first story" would be an arbitrary
choice among equally valid ones. Why is in [architecture.md](../architecture.md#request-lifecycle);
what the reader sees because of it is the explicit **None selected** state below.

## Top bar — `app/views/layouts/_navbar.html.erb`

The navbar is deliberately three links, one search box, and one action. It is not a switcher, and it
issues **no query of its own**: the box renders from `Current`, from `Search::Scope`, and from what a
reader types.

- **Universe Maker** — the brand, and the landing page (`/`, the universes index). It is where the
  visitor sees the universes they may open and where a **New universe** is created, so there is no
  universe picker in the top bar.
- **Universe: [name]** — a plain link to the current universe page, present when `Current.universe`
  exists. Changing universes happens on the landing page.
- **Story: [name]** — a plain link to the current story page, present when `Current.story` exists.
  Changing stories happens on the universe page, which lists **every** story in the universe with an
  **Open** action each and a **Current** badge beside the selected one; the stories index carries
  **New story**. There is no **Select** placeholder: with no current story there is simply no story
  link, because a story is never implied.
- **Search** — one GET form between the scope links and the actions, plus the dropdown that answers
  while someone types. See [features/search.md](search.md).
- **Account** — the top bar's only action, a dropdown rendered for every visitor. A signed-in reader
  sees their email, **Settings**, and **Log out**; a guest sees **Log in** and **Settings**. It is
  the navbar's only Bootstrap dropdown, and the menu button carries `.active` and
  `aria-current="page"` on the settings page.
- **Settings** — the platform settings page (`/settings`), inside the account menu in
  `.navbar-actions`, and rendered for every visitor including a guest, because its preferences belong
  to the browser rather than to a universe. It is deliberately **not** a **Configuration** link in
  the right utility sidebar. See [features/settings.md](settings.md).

A scope link carries `.active` plus `aria-current="page"` only on the page it points at, never as a
permanent "you are in this scope" state. Nonfunctional dashboard links do not appear in the navbar
at all; the right utility sidebar is the intentional home for future placeholders.

## Left sidebar — `app/views/layouts/_left_sidebar.html.erb`

Renders only when `Current.universe` is present. It is one continuous navigation surface (not a stack
of cards) and becomes a left Bootstrap offcanvas below `lg`. It is ordered as two scoped blocks —
universe, story — and each block is a context header plus the section it introduces, so the reader
always knows which scope a link belongs to:

- **Current universe** context: the universe name. The navbar already states the universe's
  visibility and access level, and the universe page lists the stories, so the context block stays a
  statement of scope.
- **Universe Bible**: direct links to Characters, Locations, Events, Timeline, and Items. Characters
  and Items open their related record tabs (Relations and Ownerships respectively); Locations,
  Events, and Sections remain single-record workspaces.
- **Current story** context: the story name — or an explicit **None selected** state with a prompt
  when no story is current. The section/scene counts and the description stay out of this block and
  live on the story's own pages.
- **Story workspace**: Story overview + Sections + Scenes when a story is selected; otherwise All
  stories plus a prompt to select one. Creating a story belongs to the universe page (and the
  stories index), never to the sidebar. **Scenes** is a real story-scoped link with its own cached
  count once a story is selected, and an `aria-disabled` `#` placeholder while no story is current —
  it never falls back to the universe's first story.

Configuration is **not** in this column: this one stays about universe and story content only.

Real entries show `icon_text_count`; counts are aligned pills. Active entries use a soft primary
background and `aria-current="page"`. Placeholder entries are flat gray with no hover emphasis, and
nothing here depends on hover. The sidebar never gains a create action: creation belongs to the page
that lists the records.

## Right sidebar — `app/views/layouts/_right_sidebar.html.erb`

Renders only when `Current.universe` is present. It is a permanent 14rem column at `xl` and above,
and a Bootstrap `offcanvas-end` below `xl` (opened from the **Tools** button on the mobile workspace
bar). It is one continuous tools scope, so it opens with a green **Universe tools** context block and
then the sections that follow it:

- **Configuration**: **Tags**, which opens the shared taxonomy workspace with **Universe Tags**
  selected by default and **Story Tags** for the story-scoped taxonomies, plus the universe
  **Members** access manager, which only admins see. The list itself is unconditional, so a guest or
  read-only member still gets **Tags** without an empty Configuration header.
- **Collaboration**, **Analytics**, and **AI** placeholder groups; no model or route exists for
  those entries yet.

Configuration is about **the universe**: Tags and Members only. A platform preference belongs in the
top bar's **Settings** entry instead, because a theme is not universe state.

## Navigation entries are honest about what exists

Two rules apply to every navigation surface, and they are the reason the placeholders are rendered
the way they are:

- A tab or link is **never** rendered as a link to a route that does not exist. An entry with no
  destination is an `aria-disabled` placeholder whose `title` says why, and it is additionally styled
  as unavailable, so the visual state and the semantics agree. A tab is never an in-document
  Bootstrap pane either: every destination is a real request with its own canonical URL.
- Nothing a row offers is ever revealed on hover, and a placeholder therefore never looks like
  something to click. The reason, and the rest of the interaction rules, are in
  [visual_design.md](../visual_design.md#accessibility-and-interaction).

## What each block owns

The sidebar is the one place where color carries structure, and the three scope hues, their light and
dark values, and the rule that the story hue is a muted crimson rather than the danger red are in
[visual_design.md](../visual_design.md#theme-tokens). This document owns which block a given entry
belongs to, and the two rules above about honest placeholders and hover-free controls.
