class EventTagsController < ApplicationController
  include PhotoParams
  include TagDetails
  include MaintainsSiblingPositions
  include DraftMutation
  include FilteredListQuery

  allow_unauthenticated_access only: %i[ index show ]
  maintains_sibling_positions_for :event_tag

  # The filter rides along with the index. A tree keeps its drag order and
  # offers no reader sort, so `index` is the only action that reads the filter.
  filters_list_with EventTagFilter, only: %i[ index ]

  before_action :set_event_tag, only: %i[ show update destroy ]

  # GET /event_tags or /event_tags.json
  def index
    @list_filter = EventTagFilter.new(@filter_query)
    # A GET form submits every field, so the ones the author left alone arrive
    # blank. Redirecting once to the canonical query keeps the address bar, a
    # bookmark, and a shared link limited to the filters really in effect.
    return redirect_to_canonical_filtered_list if blank_filter_values?

    # One query for the whole taxonomy, and the index the tree descends through.
    # `includes(:children)` used to reach the first level only, and the photo is
    # read for every node because the editor carries its stored image.
    @hierarchy = HierarchyIndex.build(@list_filter.apply(
      Current.universe.event_tags.includes(:photo)))
    @event_tags = @hierarchy.roots
    @tagged_counts = TaggedRecordCounts.for(Current.universe.event_tags)
    # The total is read only when a filter is really in effect, so the ordinary
    # unfiltered visit costs no extra query for it.
    @event_tag_total = Current.universe.event_tags.count if @list_filter.narrowed?
    flash_discarded_filter_values
  end

  # POST /event_tags or /event_tags.json
  # GET /event_tags/:id — the tag's own details page: the records that carry it.
  # The taxonomy tree links here with that count.
  def show
    load_tag_details(@event_tag)
  end

  def create
    attributes = event_tag_params
    @event_tag = Current.universe.event_tags.new(attributes)
    return if remember_draft_create(@event_tag, attributes)

    respond_to do |format|
      if create_with_sibling_position(@event_tag, requested_position: attributes[:position])
        format.json { render json: event_tag_json, status: :created }
      else
        format.json { render json: @event_tag.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /event_tags/1 or /event_tags/1.json
  def update
    attributes = event_tag_params
    return if remember_draft_update(@event_tag, attributes)

    respond_to do |format|
      if update_event_tag(attributes)
        format.json { render json: event_tag_json, status: :ok }
      else
        format.json { render json: @event_tag.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /event_tags/1 or /event_tags/1.json
  def destroy
    return if remember_draft_delete(@event_tag)

    destroy_with_sibling_position(@event_tag)

    respond_to do |format|
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_event_tag
    @event_tag = Current.universe.event_tags.find(params.expect(:id))
  end

  # The canonical index URL for a set of filter values. `FilteredListQuery` owns
  # everything else about reading and carrying the filter, and this is the one
  # thing it cannot know: where this list's own URL is.
  def filtered_list_path_with(query)
    path = universe_event_tags_path

    query.any? ? "#{path}?#{query.to_query}" : path
  end

  def event_tag_json
    {
      id: @event_tag.id,
      name: @event_tag.name,
      description: @event_tag.description,
      bgcolor: @event_tag.bgcolor,
      fgcolor: @event_tag.fgcolor,
      parent_id: @event_tag.parent_id,
      position: @event_tag.position,
      taggable: @event_tag.taggable,
      show_in_menu: @event_tag.show_in_menu,
      url: universe_event_tag_path(id: @event_tag)
    }
  end

  # Only allow a list of trusted parameters through.
  def event_tag_params
    params.expect(event_tag: [ *photo_params, :name, :description, :bgcolor, :fgcolor, :parent_id, :position, :taggable, :show_in_menu ])
  end

  def update_event_tag(attributes)
    update_with_sibling_position(@event_tag, attributes)
  end
end
