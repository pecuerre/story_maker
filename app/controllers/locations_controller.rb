class LocationsController < ApplicationController
  include PhotoParams
  include MaintainsSiblingPositions
  include RequiresJsonMutationFormat
  include DraftMutation
  include FilteredListQuery

  allow_unauthenticated_access only: %i[ index show ]
  maintains_sibling_positions_for :location

  # The filter rides along with the index. The tree keeps its drag order and
  # offers no reader sort, so `index` is the only action that reads the filter.
  filters_list_with LocationFilter, only: %i[ index ]

  before_action :set_location, only: %i[ show update destroy ]
  before_action :require_json_mutation_format, only: %i[ create update destroy ]

  def index
    # One query for the whole hierarchy, and the index the tree descends through.
    # `includes(:children)` used to reach the first level only, every deeper node
    # asked again for its tags, and the parent selector below asked for the same
    # ordered list a third time.
    set_location_tag_data

    @list_filter = LocationFilter.new(@filter_query, location_tags: @all_location_tags)
    # A GET form submits every field, so the ones the author left alone arrive
    # blank. Redirecting once to the canonical query keeps the address bar, a
    # bookmark, and a shared link limited to the filters really in effect.
    return redirect_to_canonical_filtered_list if blank_filter_values?

    @hierarchy = HierarchyIndex.build(@list_filter.apply(
      Current.universe.locations.includes(:location_tags, :photo)))
    @locations = @hierarchy.roots
    @location_options = @hierarchy.records

    @location_tags = Current.universe.location_tags.where(taggable: true).order(:name)
    # The total is read only when a filter is really in effect, so the ordinary
    # unfiltered visit costs no extra query for it.
    @location_total = Current.universe.locations.count if @list_filter.narrowed?
    flash_discarded_filter_values
  end

  # GET /locations/:id — the record's own read-only details page. It identifies the
  # record and is the destination of every "Details" link; later slices add
  # the related-records sections without changing this URL.
  #
  # A writer also gets the tree's own editor here: the page renders the same
  # descriptor list and prefill payload a tree node carries, so the Edit control
  # opens the one Location editor rather than a second form.
  def show
    set_location_editor_data if can?(:write, Current.universe)
  end

  def create
    attributes = location_params
    @location = Current.universe.locations.new(attributes)
    return if remember_draft_create(@location, attributes)

    respond_to do |format|
      if create_with_sibling_position(@location, requested_position: attributes[:position])
        format.json { render json: location_json, status: :created }
      else
        format.json { render json: @location.errors, status: :unprocessable_content }
      end
    end
  end

  def update
    attributes = location_params
    return if remember_draft_update(@location, attributes)

    respond_to do |format|
      if update_location(attributes)
        format.json { render json: location_json, status: :ok }
      else
        format.json { render json: @location.errors, status: :unprocessable_content }
      end
    end
  end

  def destroy
    return if remember_draft_delete(@location)

    destroy_with_sibling_position(@location)
    head :no_content
  end

  private

  def set_location
    @location = Current.universe.locations.find(params.expect(:id))
  end

  # The editor's own fields. The full profile lives in `description`, which the
  # details page renders as Markdown, so there are no separate answer keys here;
  # `summary` is the one-line glance shown before it.
  def location_params
    params.expect(location: [ *photo_params, :name, :summary, :description,
      { location_tag_ids: [] }, :parent_id, :position ])
  end

  def update_location(attributes)
    update_with_sibling_position(@location, attributes)
  end

  def location_json
    {
      id: @location.id,
      name: @location.name,
      summary: @location.summary,
      description: @location.description,
      location_tag_ids: @location.location_tag_ids,
      parent_id: @location.parent_id,
      position: @location.position,
      url: universe_location_path(id: @location)
    }
  end

  # The canonical index URL for a set of filter values. `FilteredListQuery` owns
  # everything else about reading and carrying the filter, and this is the one
  # thing it cannot know: where this list's own URL is.
  def filtered_list_path_with(query)
    path = universe_locations_path

    query.any? ? "#{path}?#{query.to_query}" : path
  end

  # Location Tag definitions and their paths are universe-scoped. One ordered tag
  # query serves the list filter and its tag selector, and the same list builds
  # the root-first order a hierarchical taxonomy is named by.
  #
  # The **editor** offers assignable tags only — a grouping tag stays in the tree
  # and on records that already carry one — so the two lists are deliberately
  # different. The filter validates against every tag, because a reader filtering
  # by a grouping tag is asking about records that really do carry it.
  def set_location_tag_data
    @all_location_tags = Current.universe.location_tags.reorder(:position, :id).to_a
    @location_tags = @all_location_tags.select(&:taggable)
  end

  # The details page's editor is the shared tree editor, so it needs the tree's
  # two per-call answers: the assignable tags and the places this record may sit
  # inside. A Location may not be its own parent or a descendant of itself, and
  # the tree excludes that subtree from a row's parent selector; the index reads
  # it from the rendered row, but this page has no row, so the same exclusion is
  # computed here from one loaded hierarchy.
  def set_location_editor_data
    set_location_tag_data

    hierarchy = HierarchyIndex.build(Current.universe.locations.reorder(:position, :id))
    excluded = location_subtree_ids(hierarchy, @location)
    @location_options = hierarchy.records.reject { |location| excluded.include?(location.id) }
  end

  def location_subtree_ids(hierarchy, location)
    ids = [ location.id ]
    queue = [ location.id ]

    while (id = queue.shift)
      hierarchy.children_of(id).each do |child|
        ids << child.id
        queue << child.id
      end
    end

    ids
  end
end
