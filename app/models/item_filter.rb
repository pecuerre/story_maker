# Narrows the universe's canonical Item list without changing what that list is.
#
# This is the second filter on a **flat** list, and it repeats the shape
# `CharacterFilter` settled: free text, a tag filter, and a reader-chosen order.
# The shared contract is in
# [`docs/features/list_filters.md`](../docs/features/list_filters.md); this file
# holds only what is the Items list's own.
#
# `Item` is hierarchical — it has a `position` inside a branch — exactly as a
# Character does, and the flat list is every item in the universe while `position`
# orders the branches. The sort allowlist therefore offers no `position`: sorting
# by it would interleave unrelated branches into an order that means nothing,
# and the hierarchy is read on the tree.
#
# Query contract for `GET /u/:universe_slug/items`:
#
#   `q`            free text over the item name and description
#   `item_tag_id`  an Item Tag of this universe: a tag a reader can pick
#   `sort`         one of `SORTS`, which is an allowlist rather than an order
#
# `item_tags` is every tag of the universe, **not** the assignable subset the
# editor offers. A grouping tag cannot be assigned in the modal, but records that
# already carry one are still records a reader filters by, so validating against
# the editor's list would drop a tag that is really in effect.
class ItemFilter < ListFilter
  PARAMS = %i[ q item_tag_id sort ].freeze

  # The orders this list offers, as an allowlist of query value to order clause.
  # There is deliberately no `position`: the flat list is every item in the
  # universe, while `position` is a sibling order inside one branch of the
  # hierarchy, so sorting a flat list by it would interleave unrelated branches
  # into an order that means nothing. The hierarchy is read on the tree.
  SORTS = {
    "name" => { name: :asc },
    "created" => { created_at: :desc },
    "updated" => { updated_at: :desc }
  }.freeze
  # What the list was ordered by before a reader could choose, and what an
  # unreadable choice falls back to. Like the Characters list, the default is
  # **name**: both are the same kind of flat universe list, and a default the
  # code never explained would be a decision rather than a default.
  DEFAULT_SORT = "name"

  attr_reader :item_tag

  # `item_tags` is every tag of the universe, the same list the index needs to
  # have loaded anyway for the tag selector, so a filter value is validated
  # against it without another query and a foreign id can never reach the query.
  def initialize(params, item_tags:)
    @item_tags = item_tags
    super(params)
  end

  # The resolved Item Tag id, used by the query string and by the selected
  # option.
  def item_tag_id
    item_tag&.id
  end

  # The filter as canonical query keys, so a link or a redirect can carry exactly
  # the filters that are really in effect. A dropped value is not carried over.
  #
  # The default sort is not spelled out: it is what the URL means when `sort` is
  # absent, so carrying it would put the list's own order in every bookmark for a
  # reader who never chose one.
  def query_params
    query = {}
    query[:q] = text if text.present?
    query[:item_tag_id] = item_tag.id.to_s if item_tag
    query[:sort] = sort if sort != DEFAULT_SORT
    query
  end

  # The universe's items, still in the reader's chosen order, narrowed by the
  # active filters. The order is the last thing applied, and it is never
  # persisted.
  def apply(relation)
    relation = narrowed_by_tag(relation, item_tag)
    relation = narrowed_by_text(relation, table: "items", columns: %w[ name description ])
    sorted(relation)
  end

  private
    def resolve
      resolve_text
      @item_tag = resolve_in_list(@params[:item_tag_id], @item_tags,
        "items.filter.discarded.tag", identifier: :id)
      resolve_sort("items.filter.discarded.sort")
    end
end
