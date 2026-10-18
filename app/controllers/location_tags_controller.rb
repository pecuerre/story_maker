class LocationTagsController < ApplicationController
  include PhotoParams
  include TagDetails
  include MaintainsSiblingPositions
  include DraftMutation
  include FilteredListQuery

  allow_unauthenticated_access only: %i[ index show ]
  maintains_sibling_positions_for :location_tag

  # The filter rides along with the index. A tree keeps its drag order and
  # offers no reader sort, so `index` is the only action that reads the filter.
  filters_list_with LocationTagFilter, only: %i[ index ]

  before_action :set_location_tag, only: %i[ show update destroy ]

  def index
    @list_filter = LocationTagFilter.new(@filter_query)
    # A GET form submits every field, so the ones the author left alone arrive
    # blank. Redirecting once to the canonical query keeps the address bar, a
    # bookmark, and a shared link limited to the filters really in effect.
    return redirect_to_canonical_filtered_list if blank_filter_values?

    # One query for the whole taxonomy, and the index the tree descends through.
    # `includes(:children)` used to reach the first level only, and the photo is
    # read for every node because the editor carries its stored image.
    @hierarchy = HierarchyIndex.build(@list_filter.apply(
      Current.universe.location_tags.includes(:photo)))
    @location_tags = @hierarchy.roots
    @tagged_counts = TaggedRecordCounts.for(Current.universe.location_tags)
    # The total is read only when a filter is really in effect, so the ordinary
    # unfiltered visit costs no extra query for it.
    @location_tag_total = Current.universe.location_tags.count if @list_filter.narrowed?
    flash_discarded_filter_values
  end

  # GET /location_tags/:id — the tag's own details page: the records that carry it.
  # The taxonomy tree links here with that count.
  def show
    load_tag_details(@location_tag)
  end

  def create
    attributes = location_tag_params
    @location_tag = Current.universe.location_tags.new(attributes)
    return if remember_draft_create(@location_tag, attributes)

    respond_to do |format|
      if create_with_sibling_position(@location_tag, requested_position: attributes[:position])
        format.json { render json: location_tag_json, status: :created }
      else
        format.json { render json: @location_tag.errors, status: :unprocessable_content }
      end
    end
  end

  def update
    attributes = location_tag_params
    return if remember_draft_update(@location_tag, attributes)

    respond_to do |format|
      if update_location_tag(attributes)
        format.json { render json: location_tag_json, status: :ok }
      else
        format.json { render json: @location_tag.errors, status: :unprocessable_content }
      end
    end
  end

  def destroy
    return if remember_draft_delete(@location_tag)

    destroy_with_sibling_position(@location_tag)
    head :no_content
  end

  private

  def set_location_tag
    @location_tag = Current.universe.location_tags.find(params.expect(:id))
  end

  def location_tag_params
    params.expect(location_tag: [ *photo_params, :name, :description, :bgcolor, :fgcolor, :parent_id, :position, :taggable, :show_in_menu ])
  end

  def update_location_tag(attributes)
    update_with_sibling_position(@location_tag, attributes)
  end

  # The canonical index URL for a set of filter values. `FilteredListQuery` owns
  # everything else about reading and carrying the filter, and this is the one
  # thing it cannot know: where this list's own URL is.
  def filtered_list_path_with(query)
    path = universe_location_tags_path

    query.any? ? "#{path}?#{query.to_query}" : path
  end

  def location_tag_json
    {
      id: @location_tag.id,
      name: @location_tag.name,
      description: @location_tag.description,
      bgcolor: @location_tag.bgcolor,
      fgcolor: @location_tag.fgcolor,
      parent_id: @location_tag.parent_id,
      position: @location_tag.position,
      taggable: @location_tag.taggable,
      show_in_menu: @location_tag.show_in_menu,
      url: universe_location_tag_path(id: @location_tag)
    }
  end
end
