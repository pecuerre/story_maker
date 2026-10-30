# Narrows the universe's canonical Character list without changing what that list
# is.
#
# This is the first filter on a **flat** list, and the first one a reader can
# sort, so it is where the rules that are not the Scene filter's are written
# down. The shared contract is in
# [`docs/features/list_filters.md`](../docs/features/list_filters.md); this file
# holds only what is the Characters list's own.
#
# Query contract for `GET /u/:universe_slug/characters`:
#
#   `q`                free text over the character name and profile fields
#   `character_tag_id` a Character Tag of this universe: a tag a reader can pick
#   `sort`             one of `SORTS`, which is an allowlist rather than an order
#
# `character_tags` is every tag of the universe, **not** the assignable subset the
# editor offers. A grouping tag cannot be assigned in the modal, but records that
# already carry one are still records a reader filters by, so validating against
# the editor's list would drop a tag that is really in effect.
class CharacterFilter < ListFilter
  PARAMS = %i[ q character_tag_id sort ].freeze

  # The orders this list offers, as an allowlist of query value to order clause.
  # There is deliberately no `position`: the flat list is every character in the
  # universe, while `position` is a sibling order inside one branch of the
  # hierarchy, so sorting a flat list by it would interleave unrelated branches
  # into an order that means nothing. The hierarchy is read on the tree.
  SORTS = {
    "name" => { name: :asc },
    "created" => { created_at: :desc },
    "updated" => { updated_at: :desc }
  }.freeze
  # What the list was ordered by before a reader could choose, and what an
  # unreadable choice falls back to.
  DEFAULT_SORT = "name"

  attr_reader :character_tag

  # `character_tags` is the universe-scoped list the index already loaded for the
  # filter's tag selector, so a filter value is validated against it without
  # another query and a foreign id can never reach the query.
  def initialize(params, character_tags:)
    @character_tags = character_tags
    super(params)
  end

  # The resolved Character Tag id, used by the query string and by the selected
  # option.
  def character_tag_id
    character_tag&.id
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
    query[:character_tag_id] = character_tag.id.to_s if character_tag
    query[:sort] = sort if sort != DEFAULT_SORT
    query
  end

  # The universe's characters, narrowed by the active filters and ordered by the
  # reader's choice. The order is the last thing applied and is never persisted.
  def apply(relation)
    relation = narrowed_by_tag(relation, character_tag)
    relation = narrowed_by_text(relation, table: "characters", columns: %w[
      name summary pronouns aliases description
    ])
    sorted(relation)
  end

  private
    def resolve
      resolve_text
      @character_tag = resolve_in_list(@params[:character_tag_id], @character_tags,
        "characters.filter.discarded.tag", identifier: :id)
      resolve_sort("characters.filter.discarded.sort")
    end
end
