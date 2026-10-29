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

The navbar is deliberately three links, one search box, and two actions. It is not a switcher. The search
box issues **no query of its own**: it renders from `Current`, from `Search::Scope`, and from what a
reader types. The notifications bell does issue one, and says why below.

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
- **Notifications** — a bell dropdown in `.navbar-actions`, beside the account menu rather than
  inside it, and **rendered only for a signed-in reader**: there is nothing there addressed to a
  guest, and asking costs a query. It is server-rendered Bootstrap, which is why this feature added
  no Stimulus controller and no `test/javascript` case. What it shows, and the two rules that decide
  it, are in [conventions.md](../conventions.md#notifications); the figure also moves under a reader
  who is on another page, through the reader stream described in
  [Real-time updates](../conventions.md#real-time-updates).
- **Account** — the other action, a dropdown rendered for every visitor. A signed-in reader
  sees their email, **Settings**, and **Log out**; a reader with the platform flag also sees
  **Import**, because replacing a universe is platform administration rather than a page inside one;
  a guest sees **Log in** and **Settings**. The menu button carries `.active` and
  `aria-current="page"` on the settings page.
- **Settings** — the platform settings page (`/settings`), inside the account menu in
  `.navbar-actions`, and rendered for every visitor including a guest, because its preferences belong
  to the browser rather than to a universe. It is deliberately **not** a **Configuration** link in
  the right utility sidebar. See [settings.md](settings.md).

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
- **Universe Bible**: direct links to Characters, Factions, Locations, Routes, Canon, Map, Events, and Items. Routes
  are universe-scoped paths between Locations and have their own workspace. Canon is the universe's
  list of rules with an optional story owner, and its page contract is in
  [features/canon.md](canon.md). Map is the read-only
  Location-hierarchy and Route view; its page contract is in [features/map.md](map.md). Characters
  and Items open their related record tabs (Relations and Ownerships respectively). **Events** opens
  the Event workspace, whose second tab is the **Timeline**, so the Timeline has no sidebar entry of
  its own and that one link stays current across both tabs. Locations and Sections remain
  single-record workspaces.
- **Current story** context: the story name — or an explicit **None selected** state with a prompt
  when no story is current. The section/plot/scene counts and the description stay out of this block and
  live on the story's own pages.
- **Story workspace**: Story overview + Sections + Plots + Scenes when a story is selected; otherwise All
  stories plus a prompt to select one. Creating a story belongs to the universe page (and the
  stories index), never to the sidebar. **Plots** and **Scenes** are real story-scoped links with
  their own cached counts once a story is selected, and `aria-disabled` `#` placeholders while no
  story is current — neither falls back to the universe's first story. **Export** follows Scenes and
  opens the Story's export options; its page contract is in
  [features/exports.md](exports.md).

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
  **Members** access manager and the **Backup** download, both of which only admins see. The list
  itself is unconditional, so a guest or read-only member still gets **Tags** without an empty
  Configuration header.
- **Collaboration**: the reader's own pending work, which exists only in a universe that remembers changes
  rather than writing them and only for a signed-in reader. It is **a panel and a link**, in that order:
  the panel states how many changes are waiting and names each one with the action and the record, and
  the **Pending changes** entry below it leads to the drafts list. The panel exists because the link alone
  answers "where are they" and not "are there any" — an editor who is told their change was remembered
  would otherwise have to open the draft to find out whether anything is waiting at all. It is a **glance,
  not a second drafts page**: each row resolves the record its change names, so it is capped at
  `DraftPreview::PANEL_LIMIT` and the remainder is counted rather than dropped, and it renders at **zero** as
  well as at any count. The **Review requests** entry described below follows it, and nothing closes the
  group: its **Collaborators**, **Conflicts**, **Branches**, and **Forks** placeholders were removed on
  2026-10-05, because an entry with no route is noise rather than a promise, and **Collaborators** is
  reserved for the page that will replace it. The live block is first because it is the one a reader
  arrives at from the flash that told them their change was remembered; an editor who cannot find that
  change has no way to apply or throw it away. Its presence is **not** conditional on the reader having
  something pending — it is also how a reader reaches the drafts list, and a navigation entry
  that appears and disappears with a count needs an explanation whenever it is absent. The panel is its own
  `<li>` beside the link rather than around it, because the shared link partial is itself a list item and
  a `<li>` inside a `<li>` is hoisted back out by the parser. The **Start editing** / **Stop editing**
  control on the universe page is a second way in, and it is the one that opens a draft; both belong to the
  universe workspace rather than to either sidebar.
- **Change history**: the universe's closed drafts, grouped by the day each one closed, and the
  third kind of answer in this group — not the reader's own work, not what a reviewer must decide, but
  what the universe already holds. It is gated on **admin**, because the page names every author who
  has closed a draft here, and it asks for the same reason the review queue does: a list of other
  people's work is itself an answer. It is additionally gated on the universe's collaboration mode being
  draft-based, because a `direct` universe remembers nothing and so has no runs to list — the entry
  could only ever lead to an empty page. Its figure counts **closed drafts**, applied and discarded
  alike, because the page groups by draft and a draft is the row it draws; it is **uncached**, for
  the review queue's reason, since it moves on the very request that ran an apply. Both of its rows
  are the ones `drafts/_change` already renders, and its day heading is the draft's `closed_at` rather
  than a change's own `created_at`, which is when it was first remembered and can be days earlier.
- **Collaborators**: who has changed this universe, each with the number of changes they remembered,
  and a per-person page that is the change history above narrowed to that author — the same
  `histories/_day` grouping and the same `drafts/_change` rows, with the author's own name omitted
  because the page's heading is already that name. It shares the history's two gates: **admin**,
  because the list names every author who has closed a draft here, and a draft-based collaboration
  mode, because a `direct` universe has none. Its figure counts **people** while the history's counts
  **runs**, which is the whole reason these are two entries rather than one filtered page: a reader
  has to be able to ask "how many of us have worked here" and "how much has happened" and get an
  answer to each. A collaborator is read from **closed drafts**, not from memberships — a member who
  has changed nothing has not collaborated, and a writer in a public universe never gets a membership
  row at all. A person who has not collaborated here is a **404**, not an empty page.
- **Review requests**: the reviewer's queue, and the one entry in this group that answers for the reader
  rather than about them. It is gated on **admin**, which is the whole of `review_requests`'s
  authorization (`review_requests`, `memberships`, `histories`, `collaborators`, and
  `universe_backups` are the controllers whose every action asks for `admin` rather than the
  `index`/`show` → `read` rule), because the queue names every author who has submitted something. It is **not** gated on the collaboration mode: the mode is enforced on the one
  control that can make a submission, so a submission made before a mode change is still a queue row
  somebody has to decide, and the queue is a page in every mode. Its figure counts **what is waiting**
  rather than what the queue holds, so decided and withdrawn submissions lower nothing a reviewer is
  being asked to do, and it reads at **zero** rather than disappearing — the entry is also how a reviewer
  reads who let a change through. That figure is **uncached**, unlike the left sidebar's counts: a
  decision has to be able to lower it on the page it redirects to, which a `MenuCountCache` entry could
  not promise for up to its TTL. It costs one `COUNT` over `review_requests.universe_id`, asked only by
  the readers who may see the queue.
- **Inspector**: page-relevant details beside Configuration and Collaboration — the selected story's section and scene counts, and a selected record's relations and ownerships. It renders at most five rows and nothing at all when the page has nothing useful to say, so it stays hidden rather than rendering an empty box. It replaced the Analytics and AI placeholder groups, which had no model or route behind them.

Configuration is about **the universe**: Tags, Members, and Backup. A platform preference belongs in
the top bar's **Settings** entry instead, because a theme is not universe state.

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
