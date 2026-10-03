class LocationsController < ApplicationController
  include PhotoParams
  include MaintainsSiblingPositions
  include RequiresJsonMutationFormat
  include DraftMutation

  allow_unauthenticated_access only: %i[ index show ]
  maintains_sibling_positions_for :location

  before_action :set_location, only: %i[ show update destroy ]
  before_action :require_json_mutation_format, only: %i[ create update destroy ]

  def index
    # One query for the whole hierarchy, and the index the tree descends through.
    # `includes(:children)` used to reach the first level only, every deeper node
    # asked again for its tags, and the parent selector below asked for the same
    # ordered list a third time.
    @hierarchy = HierarchyIndex.build(Current.universe.locations.includes(:location_tags, :photo))
    @locations = @hierarchy.roots
    @location_options = @hierarchy.records

    @location_tags = Current.universe.location_tags
    @location_tags = @location_tags.where(taggable: true).order(:name)
  end

  # GET /locations/:id — the record's own read-only details page. It identifies the
  # record and is the destination of every "Details" link; later slices add
  # the related-records sections without changing this URL.
  def show
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

  def location_params
    params.expect(location: [ *photo_params, :name, :description, { location_tag_ids: [] }, :parent_id, :position ])
  end

  def update_location(attributes)
    update_with_sibling_position(@location, attributes)
  end

  def location_json
    {
      id: @location.id,
      name: @location.name,
      description: @location.description,
      location_tag_ids: @location.location_tag_ids,
      parent_id: @location.parent_id,
      position: @location.position,
      url: universe_location_path(id: @location)
    }
  end
end
