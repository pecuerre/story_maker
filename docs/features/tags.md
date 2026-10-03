# Tags and taxonomies

Every content model has a hierarchical `_tag` taxonomy: a tree of labels an author applies to
records, with colors, and optionally pinned to a workspace tab. The schema — the tag tables, their
columns, the join tables, and the content↔tag matrix — is in
[data_model.md](../data_model.md#tag-taxonomy-matrix); this is the *system*.

## The two-sided DSL

A content model declares its taxonomy with `has_many_tags`, and the tag model declares the inverse
with `has_many_tagged`:

```ruby
# content model
has_many_tags :character_tag, scope: :universe_id

# tag model
has_many_tagged :character, scope: :universe_id
```

The `scope:` is **mandatory**, and it is the whole safety story. Section/SectionTag and Scene/SceneTag
use `scope: :story_id`; everything else uses `scope: :universe_id`. The scope is applied to reads and
builds on **both** sides, and a shared validation rejects foreign members whether they are assigned in
memory or through an id writer. That is what makes a cross-universe tag assignment impossible rather
than merely discouraged.

`has_many_tagged` also records the inverse association name (`Model.tagged_records_association`, e.g.
`:characters`), and `tagged_records` is the read side used by a tag's details page: the scoped
association ordered by name, or `none` on a content model.

**Tags are optional on every content model.** The DSL adds no presence validation and no controller
force-assigns a default tag, so a record is saved untagged when the author picks none. Do not add
default-tag creation or tag presence validation without an explicit product decision.

## The eager-loading consequence

Because both scopes are instance-dependent lambdas, Rails cannot eager load or group through these
associations. That single fact explains two value objects, and neither is optional:

- **`TaggedRecordCounts`** (`app/models/tagged_record_counts.rb`) answers "how many records carry each
  tag" for a whole taxonomy with **one grouped query**, over the HABTM table. It returns a
  `tag id => count` hash and backs the taxonomy rows' `(N records)` count pill. Every taxonomy index
  and the shared taxonomy workspace load it once, so a pill is never an N+1.
- **`tagged_records`** is the per-record read side, and it is what a tag's details page lists. A
  non-taggable grouping tag instead lists records under each direct child tag, which
  `TaggedRecordsByTag` batches through the scoped join table; the shared tagged-record list accepts a
  precomputed badge map so grouped pages do not query once per child.

## The tree page

All `_tag` indexes, plus `sections` and `locations`, use the taxonomy tree pattern. The page shape
and its partials are in [conventions.md](../conventions.md#views---three-patterns); the painted
treatment is in [visual_design.md](../visual_design.md). What defines it:

- `shared/_taxonomy_tree` wraps `shared/_taxonomy_node`, and takes the `create_url`/`update_url`
  lambdas + `model_param` + `modal_fields` locals, plus `details_url`/`details_count`/
  `details_count_label` for the row's **Details** link and count pill. A row's only URL surface is
  `data-update-url` (update, move, delete, inline rename) and the Details link; the editor is a
  DOM-built modal, so there are no `new`/`edit` routes and no per-row edit/delete URL attributes.
- The tree descends through a **`HierarchyIndex`** (`app/models/hierarchy_index.rb`) built from the
  page's own load of the hierarchy, and `hierarchy` is a **required** local for that reason: the
  partial asks the index for a node's children instead of `node.children`, so one query answers every
  depth. The index is built from the same ordered list the page already needed for its parent
  selector and editor descriptors, and that load carries each row's tags and photo.
- The page header's count badge is **every tag in the taxonomy, nested children included**, not the
  number of root rows the tree lists: `tags_helper.rb` passes `Current.universe.<type>_tags.count`,
  and a nested grouping tag is a tag like any other. A create, rename, or delete performs a same-URL
  Turbo visit, so the badge tracks live changes.
- A row carries five things and no more: the **name** (the only inline-rename target, sized to its own
  text so clicking the empty space beside it does nothing), the record's **tags**, its **count** pill
  when the taxonomy has one, the **Details** link on the right, and one **overflow menu** holding Add
  child, Insert before, Insert after, Move up, Move down, Edit, and Delete. Move up/down are disabled
  menu items at the sequence boundaries, so the row itself has no add or arrow buttons. The Details
  link and the menu are both always visible: a row never depends on hover.
- The add action must be human-readable (`Add relation tag`), never generated directly from a model
  parameter (`Add Relation_tag`).

## The editor

The tag editor's field descriptors come from `ModalFields#taxonomy_tag_fields` (shared by every
taxonomy) and `ModalFields#content_tag_taxonomy_fields` (Character/Location/Item/Event tags, which add
`show_in_menu`). The per-type `*_tag_taxonomy_fields(nodes)` helpers delegate to these, e.g.
`event_tag_taxonomy_fields`, `section_tag_taxonomy_fields`, `scene_tag_taxonomy_fields`.

Every tag editor carries a `taggable` checkbox: a tag with `taggable: false` is a grouping for its
children and is excluded from element tag editors, while staying in the tree and on records that
already carry it. A content tag with `show_in_menu: true` is pinned to its workspace tab strip and links
to the tag's own details page.

`taxonomy_tree_controller.js` provides safe DOM-built modal fields and nodes, inline name editing,
insertion boundaries, and the move/insert menu actions. HTML5 drag/drop is an optional enhancement. It
never builds a whole row: only the rename button is created in JavaScript, because a create always
refreshes the same URL, so there is no second copy of the row layout to drift. That button's content is
rebuilt from the node's data attributes when a rename is cancelled, so a new element rendered there
(the count pill) must be serialized onto the node too.

## Workspace navigation

Tag management lives under the right sidebar's **Configuration → Tags**
([features/navigation.md](navigation.md)). `shared/_tag_workspace_navigation` and
`app/helpers/tags_helper.rb` build it, and `TagsHelper#tagged_record_counts` is the per-page grouped
count described above. The scope tabs are Universe/Story and the scope-specific taxonomy selector.

A taxonomy's workspace block is declarative metadata rather than a hand-written block per type: its
copy is a set of `tags.types.<type>.*` keys, and everything mechanical — the model parameter, the name
of its editor's field builder, and all four of its URLs — is derived from the type name. Adding a
taxonomy is therefore one metadata entry plus its locale block, and that trade only holds while the
two type lists, the two metadata tables, the field-builder helpers, and the routes agree with each
other. A type listed without a metadata entry raises a `KeyError` while the page renders, a block that
drops one of its five copy keys still renders but hands the tree a `nil` where a sentence was expected,
and a route renamed away from the derived name is a URL that cannot be generated. All four are checked
in `test/helpers/tags_helper_test.rb`.

The copy keys themselves are derived the same way, because every taxonomy's locale block is the same
shape: `COPY_SUFFIXES` in `tags_helper.rb` is that shape written once, `EXTRA_COPY_SUFFIXES` holds
the sentences a taxonomy needs beyond the shared five, and `UNIVERSE_TAG_METADATA` /
`STORY_TAG_METADATA` are built from the type lists. So a shared sentence added to every taxonomy is
one line rather than eight, and a taxonomy cannot be listed without all five keys — which the
hand-written blocks allowed, because `translated_metadata` merges only the keys a block happens to
contain. `TagsHelper.tag_copy_metadata` is a module function rather than a view helper because it
runs while those constants are being built.

A content tag with `show_in_menu: true` also appears on its workspace page. Those links include
`from=workspace`, so the tag details page renders the same workspace tabs only for that explicit
navigation, while the taxonomy tree's Details link stays canonical and omits them.

## The tag details card

All eight tag pages share one identity card, built by
`TagsHelper#tag_identity_details` and rendered through `shared/_record_details`. Its shape is a
deliberate split between **information** and **settings**:

- the **description** is the only labelled fact, and it is given the card's **whole width**
  (`wide_facts`, not `facts`) rather than the column a photo leaves, because it is prose;
- the **scope** and the **colour** are the tag's settings, so they are one quiet line at the bottom of
  the card (`footer`, rendered by `shared/_detail_footer`) instead of two rows in the grid above. Each
  is a whole `label: value` sentence written per locale (`tags.show.scope_line.*`,
  `tags.show.color_line`), never a label with its value spliced into it;
- the **explanation of what a scope means** moved out of the card and behind the scope line's info
  button (`popover_controller.js`, `hover focus click`, the same trigger set the Timeline's node
  popovers use). It is the same `tags.show.scope_*_description` copy the grid showed inline, not a
  rewording, and the button's accessible name is `tags.show.scope_hint_label` because its visible
  content is an icon.

The scope is derived from the record — a `story_id` means story-scoped — rather than passed in, so a
taxonomy cannot disagree with its own model about who owns it.

## Ordering

A tag tree is a `Hierarchical` tree with a `position`, and the positioned-controller rules in
[conventions.md](../conventions.md#controllers) apply unchanged. `Hierarchy_scope` for SectionTag and
SceneTag is the **story**, not the universe.
