# Narrows the universe's canonical Ownership list without changing what that list
# is.
#
# This is the fifth filter on a **flat** list, and the second whose text reaches
# **past** the record. An Ownership's label is `"%{character} owns %{item}"`, a
# sentence composed by `display_label` rather than stored, so a `LIKE` cannot
# match it: the reader's words are searched on the item name and the character
# name, and on the ownership's own name and description. The composed sentence is
# deliberately not searchable — it is translated chrome, and matching "owns" in
# one language would be a search that silently means something only there. The
# shared contract is in
# [`docs/features/list_filters.md`](../docs/features/list_filters.md); this file
# holds only what the Ownerships list's own is.
#
# Query contract for `GET /u/:universe_slug/ownerships`:
#
#   `q`                free text over the ownership's own name and description and
#                      over the names of its character and its item
#   `ownership_tag_id` an Ownership Tag of this universe: a tag a reader can pick
#   `sort`             one of `SORTS`, which is an allowlist rather than an order
#
# `ownership_tags` is every tag of the universe, **not** the assignable subset the
# editor offers. A grouping tag cannot be assigned in the modal, but records that
# already carry one are still records a reader filters by, so validating against
# the editor's list would drop a tag that is really in effect.
class OwnershipFilter < ListFilter
  PARAMS = %i[ q ownership_tag_id sort ].freeze

  # The orders this list offers, as a query value to order clause. There is
  # deliberately no `position`: an Ownership is not positioned, it links an item
  # and a character, and the order it is presented in is a reading choice.
  #
  # The default is **name**, the same default the other flat lists keep. A name is
  # optional here — the item and the character are the label — so an unnamed
  # record sorts under its empty name, ahead of the named ones on SQLite, and
  # falls back to the `id` tiebreaker; an all-unnamed list therefore keeps the
  # creation order it had before a reader could choose one.
  SORTS = {
    "name" => { name: :asc },
    "created" => { created_at: :desc },
    "updated" => { updated_at: :desc }
  }.freeze
  DEFAULT_SORT = "name"

  attr_reader :ownership_tag

  # `ownership_tags` is the universe-scoped list the index already loaded for the
  # filter's tag selector, so a filter value is validated against it without
  # another query and a foreign id can never reach the query.
  def initialize(params, ownership_tags:)
    @ownership_tags = ownership_tags
    super(params)
  end

  # The resolved Ownership Tag id, used by the query string and by the selected
  # option.
  def ownership_tag_id
    ownership_tag&.id
  end

  # The filter as canonical query keys, so a link or a redirect can carry exactly
  # the filters that are really in effect. A dropped value is not carried over,
  # and the default sort is not spelled out because it is what the URL means when
  # `sort` is absent.
  def query_params
    query = {}
    query[:q] = text if text.present?
    query[:ownership_tag_id] = ownership_tag.id.to_s if ownership_tag
    query[:sort] = sort if sort != DEFAULT_SORT
    query
  end

  # The universe's ownerships, narrowed by the active filters and ordered by the
  # reader's choice. The order is the last thing applied and is never persisted.
  def apply(ownership)
    ownership = narrowed_by_tag(ownership, ownership_tag)
    ownership = narrowed_by_linked_text(ownership,
      table: "ownerships", columns: %w[ name description ],
      endpoints: %i[ character item ], endpoint_columns: %w[ name ])
    sorted(ownership)
  end

  private
    def resolve
      resolve_text
      @ownership_tag = resolve_in_list(@params[:ownership_tag_id], @ownership_tags,
        "ownerships.filter.discarded.tag", identifier: :id)
      resolve_sort("ownerships.filter.discarded.sort")
    end
end
