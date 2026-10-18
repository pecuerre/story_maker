# Narrows the universe's Event Tag tree without changing what that tree is.
#
# A tag taxonomy is a tree, and a tree is drag-sorted on `position`, so it
# offers no reader-chosen order: an order would show a sequence the drag control
# contradicts, and `ListFilter` answers `sortable?` false for this reason. The
# filter narrows by free text over the tag's name and description and nothing
# else: tags carry no tags of their own.
#
# The shared contract is in
# [`docs/features/list_filters.md`](../docs/features/list_filters.md); this file
# holds only what the Event Tag taxonomy's own is.
#
# Query contract for `GET /u/:universe_slug/event_tags`:
#
#   `q`  free text over the tag name and description
class EventTagFilter < ListFilter
  PARAMS = %i[ q ].freeze

  # The filter as canonical query keys, so a link or a redirect can carry exactly
  # the filters that are really in effect.
  def query_params
    query = {}
    query[:q] = text if text.present?
    query
  end

  # The universe's event tags, narrowed by the active filters. The tree keeps its
  # drag order (`position, id`) and this filter never reorders it.
  def apply(relation)
    narrowed_by_text(relation, table: "event_tags", columns: %w[ name description ])
  end

  private
    def resolve
      resolve_text
    end
end
