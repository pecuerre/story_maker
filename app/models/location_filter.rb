# Narrows the universe's Location tree without changing what that tree is.
#
# This is the first filter on a **tree** rather than a flat list. A tree is
# drag-sorted on `position`, so it offers no reader-chosen order: an order would
# show a sequence the drag control contradicts, and `ListFilter` answers
# `sortable?` false for this reason. The tag taxonomies are trees too, and each
# of them narrows by text alone.
#
# The shared contract is in
# [`docs/features/list_filters.md`](../docs/features/list_filters.md); this file
# holds only what the Locations list's own is.
#
# Query contract for `GET /u/:universe_slug/locations`:
#
#   `q`                free text over the location name and description
#   `location_tag_id`  a Location Tag of this universe: a tag a reader can pick
#
# `location_tags` is every tag of the universe, **not** the assignable subset the
# editor offers. A grouping tag cannot be assigned in the modal, but locations
# that already carry one are still locations a reader filters by, so validating
# against the editor's list would drop a tag that is really in effect.
class LocationFilter < ListFilter
  PARAMS = %i[ q location_tag_id ].freeze

  attr_reader :location_tag

  def initialize(params, location_tags:)
    @location_tags = location_tags
    super(params)
  end

  # The resolved Location Tag id, used by the query string and by the selected
  # option.
  def location_tag_id
    location_tag&.id
  end

  # The filter as canonical query keys, so a link or a redirect can carry exactly
  # the filters that are really in effect. A dropped value is not carried over.
  def query_params
    query = {}
    query[:q] = text if text.present?
    query[:location_tag_id] = location_tag.id.to_s if location_tag
    query
  end

  # The universe's locations, narrowed by the active filters. The tree keeps its
  # drag order (`position, id`) and this filter never reorders it.
  def apply(relation)
    relation = narrowed_by_tag(relation, location_tag)
    relation = narrowed_by_text(relation, table: "locations", columns: %w[ name description ])
    relation
  end

  private
    def resolve
      resolve_text
      @location_tag = resolve_in_list(@params[:location_tag_id], @location_tags,
        "locations.filter.discarded.tag", identifier: :id)
    end
end
