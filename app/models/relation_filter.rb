# Narrows the universe's canonical Relation list without changing what that list
# is.
#
# This is the fourth filter on a **flat** list, and the first whose text reaches
# **past** the record. A Relation's label is `"A → B"`, composed from its two
# endpoints and never stored, so a `LIKE` on the relation's own columns cannot
# find a reader who types one of the character names; `narrowed_by_linked_text`
# searches both endpoints, and the relation's own name and description with them.
# The shared contract is in
# [`docs/features/list_filters.md`](../docs/features/list_filters.md); this file
# holds only what the Relations list's own is.
#
# Query contract for `GET /u/:universe_slug/relations`:
#
#   `q`               free text over the relation's own name and description and
#                     over the names of its two characters
#   `relation_tag_id` a Relation Tag of this universe: a tag a reader can pick
#   `sort`            one of `SORTS`, which is an allowlist rather than an order
#
# `relation_tags` is every tag of the universe, **not** the assignable subset the
# editor offers. A grouping tag cannot be assigned in the modal, but records that
# already carry one are still records a reader filters by, so validating against
# the editor's list would drop a tag that is really in effect.
class RelationFilter < ListFilter
  PARAMS = %i[ q relation_tag_id sort ].freeze

  # The orders this list offers, as a query value to order clause. There is
  # deliberately no `position`: a Relation is not positioned, it links two
  # characters, and the order it is presented in is a reading choice.
  #
  # The default is **name**, the same default the other flat lists keep. A name is
  # optional here — the two endpoints are the label — so an unnamed record sorts
  # under its empty name, ahead of the named ones on SQLite, and falls back to the
  # `id` tiebreaker; an all-unnamed list therefore keeps the creation order it had
  # before a reader could choose one.
  SORTS = {
    "name" => { name: :asc },
    "created" => { created_at: :desc },
    "updated" => { updated_at: :desc }
  }.freeze
  DEFAULT_SORT = "name"

  attr_reader :relation_tag

  # `relation_tags` is the universe-scoped list the index already loaded for the
  # filter's tag selector, so a filter value is validated against it without
  # another query and a foreign id can never reach the query.
  def initialize(params, relation_tags:)
    @relation_tags = relation_tags
    super(params)
  end

  # The resolved Relation Tag id, used by the query string and by the selected
  # option.
  def relation_tag_id
    relation_tag&.id
  end

  # The filter as canonical query keys, so a link or a redirect can carry exactly
  # the filters that are really in effect. A dropped value is not carried over,
  # and the default sort is not spelled out because it is what the URL means when
  # `sort` is absent.
  def query_params
    query = {}
    query[:q] = text if text.present?
    query[:relation_tag_id] = relation_tag.id.to_s if relation_tag
    query[:sort] = sort if sort != DEFAULT_SORT
    query
  end

  # The universe's relations, narrowed by the active filters and ordered by the
  # reader's choice. The order is the last thing applied and is never persisted.
  def apply(relation)
    relation = narrowed_by_tag(relation, relation_tag)
    relation = narrowed_by_linked_text(relation,
      table: "relations", columns: %w[ name description ],
      endpoints: %i[ character1 character2 ], endpoint_columns: %w[ name ])
    sorted(relation)
  end

  private
    def resolve
      resolve_text
      @relation_tag = resolve_in_list(@params[:relation_tag_id], @relation_tags,
        "relations.filter.discarded.tag", identifier: :id)
      resolve_sort("relations.filter.discarded.sort")
    end
end
