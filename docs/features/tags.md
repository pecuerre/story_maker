# Tags and taxonomies

Every content model has a hierarchical `_tag` taxonomy: a tree of labels an author applies to
records, with colors, and optionally pinned to a workspace tab. The schema — the tag tables, their
columns, the join tables, and the content↔tag matrix — is in
[data_model.md](../data_model.md#tag-taxonomy-matrix); this is the *system*.

## The two-sided DSL

A content model declares its taxonomy with `has_many_tags`, and the tag model declares the inverse
with `has_many_tagd`:

```ruby
# content model
has_many_tags :character_tag, scope: :universe_id

# tag model
has_many_tagd :character, scope: :universe_id
```

The `scope:` is **mandatory**, and it is the whole safety story. Section/SectionTag and Scene/SceneTag
use `scope: :story_id`; everything else uses `scope: :universe_id`. The scope is applied to reads and
builds on **both** sides, and a shared validation rejects foreign members whether they are assigned in
memory or through an id writer. That is what makes a cross-universe tag assignment impossible rather
than merely discouraged.

`has_many_tagd` also records the inverse association name (`Model.tagged_records_association`, e.g.
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

A content tag with `show_in_menu: true` also appears on its workspace page. Those links include
`from=workspace`, so the tag details page renders the same workspace tabs only for that explicit
navigation, while the taxonomy tree's Details link stays canonical and omits them.

## Ordering

A tag tree is a `Hierarchical` tree with a `position`, and the positioned-controller rules in
[conventions.md](../conventions.md#controllers) apply unchanged. `Hierarchy_scope` for SectionTag and
SceneTag is the **story**, not the universe.
