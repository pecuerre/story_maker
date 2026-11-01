# Narrows the universe's Canon list without changing what that list is.
#
# The list is one flat list of every rule the universe follows, and the filter
# narrows it by free text, by the rule's `canon_type`, and by the Story that owns
# it — or by the rules no Story owns, because those are the ones every Story
# shares. The shared contract is in
# [`docs/features/list_filters.md`](../docs/features/list_filters.md); this file
# holds only what the Canon list's own is.
#
# Every order keeps the universe-wide rules first, for the same reason the
# unfiltered list does: they are what every Story shares, and a reader looking
# for one should find it at the top of any order rather than among each Story's
# own rules.
#
# Query contract for `GET /u/:universe_slug/canon`:
#
#   `q`               free text over the rule's name, statement, and source passage
#   `canon_type`      one of `CanonRule::CANON_TYPES`, the model's own vocabulary
#   `owner_story_id`  a Story of this universe, or `universe` for the rules no
#                     Story owns: an empty string means every rule
#   `sort`            one of `SORTS`, which is an allowlist rather than an order
class CanonRuleFilter < ListFilter
  PARAMS = %i[ q canon_type owner_story_id sort ].freeze

  # The orders this list offers, as an allowlist of query value to order clause.
  # `story_id` is the first column in each, because a null `story_id` sorts
  # first on SQLite and the universe-wide rules therefore lead every order.
  SORTS = {
    "name" => { story_id: :asc, name: :asc },
    "created" => { story_id: :asc, created_at: :desc },
    "updated" => { story_id: :asc, updated_at: :desc }
  }.freeze
  DEFAULT_SORT = "name"

  # The value the scope selector submits for the rules no Story owns. A rule's
  # `story_id` is null for those, and a select cannot submit null as a choice of
  # its own, so the universe-wide scope needs a value here.
  UNIVERSE_SCOPE = "universe".freeze

  attr_reader :canon_type, :story

  # `stories` is the universe-scoped list the index already loaded for the
  # editor's owner selector, so a filter value is validated against it without
  # another query and a foreign id can never reach the query.
  def initialize(params, stories:)
    @stories = stories
    super(params)
  end

  # Whether the filter selects the rules no Story owns.
  def universe_wide?
    @universe_wide.present?
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
    query[:canon_type] = canon_type if canon_type.present?
    query[:owner_story_id] = UNIVERSE_SCOPE if universe_wide?
    query[:owner_story_id] = story.id.to_s if story
    query[:sort] = sort if sort != DEFAULT_SORT
    query
  end

  # The universe's rules, narrowed by the active filters and ordered by the
  # reader's choice. The order is the last thing applied and is never persisted.
  def apply(relation)
    relation = relation.where(canon_type: canon_type) if canon_type.present?
    relation = relation.where(story_id: nil) if universe_wide?
    relation = relation.where(story_id: story.id) if story
    relation = narrowed_by_text(relation, table: "canon_rules",
      columns: %w[ name statement source ])
    sorted(relation)
  end

  private
    def resolve
      resolve_text
      @canon_type = resolve_in_list(@params[:canon_type], CanonRule::CANON_TYPES,
        "canon_rules.filter.discarded.canon_type")
      resolve_story
      resolve_sort("canon_rules.filter.discarded.sort")
    end

    # The scope choice is the one filter value whose empty option means "every
    # rule": a blank `owner_story_id` is not a value to validate, it is the
    # absence of a narrowing. The universe-wide sentinel selects the null owner,
    # and anything else is a Story id resolved against the list already loaded.
    def resolve_story
      raw = @params[:owner_story_id].to_s.strip
      return if raw.blank?
      return @universe_wide = true if raw == UNIVERSE_SCOPE

      @story = resolve_in_list(raw, @stories,
        "canon_rules.filter.discarded.story", identifier: :id)
    end
end
