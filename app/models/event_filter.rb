# Narrows the universe's canonical Event list without changing what that list is.
#
# This is the third filter on a **flat** list, and the one thing slice 2 never
# reached: an Event's own span is its `start_datetime` and `end_datetime`, so the
# narrowing has a date range. The shared contract is in
# [`docs/features/list_filters.md`](../docs/features/list_filters.md); this file
# holds the Events list's own keys, and
# [`docs/features/events.md`](../../docs/features/events.md) documents the
# decisions this file settles — the default order and what the date range
# bounds.
#
# `Event` is hierarchical — it has a `position` inside a branch — exactly as a
# Character does, and the flat list is every event in the universe while
# `position` orders the branches. The sort allowlist therefore offers no
# `position`: sorting by it would interleave unrelated branches into an order
# that means nothing, and the hierarchy is read on the tree.
#
# Query contract for `GET /u/:universe_slug/events`:
#
#   `q`             free text over the event name and description
#   `event_tag_id`  an Event Tag of this universe: a tag a reader can pick
#   `from`, `to`    inclusive days over the event's start datetime
#   `sort`          one of `SORTS`, which is an allowlist rather than an order
#
# `Event` derives its `name` from its `title` (see `Event#set_name`), so the name
# column always carries the title the reader entered, and searching the name
# finds the title.
#
# Both bounds are inclusive, and both bound the start: an event is identified by
# when it begins, and its `end_datetime` is an open or unknown end rather than a
# second bound a reader would have to combine. A record with no start datetime
# is excluded while either bound is set.
class EventFilter < ListFilter
  PARAMS = %i[ q event_tag_id from to sort ].freeze

  # The orders this list offers, as an allowlist of query value to order clause.
  # There is deliberately no `position`: the flat list is every event in the
  # universe, while `position` is a sibling order inside one branch of the
  # hierarchy, so sorting a flat list by it would interleave unrelated branches
  # into an order that means nothing. The default is **name**, the same default
  # the Characters and Items lists keep, because all three are the same kind of
  # flat universe list.
  SORTS = {
    "name" => { name: :asc },
    "created" => { created_at: :desc },
    "updated" => { updated_at: :desc }
  }.freeze
  DEFAULT_SORT = "name"

  attr_reader :event_tag, :from_date, :to_date

  # `event_tags` is every Event Tag of the universe, the same list the index
  # needs loaded anyway for the tag selector, so a filter value is validated
  # against it without another query and a foreign id can never reach the query.
  def initialize(params, event_tags:)
    @event_tags = event_tags
    super(params)
  end

  # The resolved Event Tag id, used by the query string and by the selected
  # option.
  def event_tag_id
    event_tag&.id
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
    query[:event_tag_id] = event_tag.id.to_s if event_tag
    query[:from] = from_date.iso8601 if from_date
    query[:to] = to_date.iso8601 if to_date
    query[:sort] = sort if sort != DEFAULT_SORT
    query
  end

  # The universe's events, still in the reader's chosen order, narrowed by the
  # active filters. The order is the last thing applied, and it is never
  # persisted.
  def apply(relation)
    relation = narrowed_by_tag(relation, event_tag)
    relation = narrowed_by_text(relation, table: "events", columns: %w[ name description ])
    relation = narrowed_by_day_range(relation, :start_datetime, from: from_date, to: to_date)
    sorted(relation)
  end

  private
    def resolve
      resolve_text
      @event_tag = resolve_in_list(@params[:event_tag_id], @event_tags,
        "events.filter.discarded.tag", identifier: :id)
      @from_date = resolve_day(@params[:from],
        label_key: "events.filter.bound.start",
        discard_key: "events.filter.discarded.date")
      @to_date = resolve_day(@params[:to],
        label_key: "events.filter.bound.end",
        discard_key: "events.filter.discarded.date")
      resolve_sort("events.filter.discarded.sort")
    end
end
