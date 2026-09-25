class LocationsController < ApplicationController
  allow_unauthenticated_access only: :index
  include MaintainsSiblingPositions
  maintains_sibling_positions_for :location

  before_action :set_location, only: %i[ update destroy ]

  def index
    @locations = Current.universe.locations
    @locations = @locations.includes(:children, :location_tags)
    @locations = @locations.where(parent_id: nil)
    @locations = @locations.order(:position, :id)

    @location_tags = Current.universe.location_tags
    @location_tags = @location_tags.order(:name)
    @location_options = Current.universe.locations.reorder(:position, :id).to_a
  end

  def create
    attributes = location_params
    @location = Current.universe.locations.new(attributes)

    respond_to do |format|
      if create_with_sibling_position(@location, requested_position: attributes[:position])
        format.json { render json: location_json, status: :created }
      else
        format.json { render json: @location.errors, status: :unprocessable_content }
      end
    end
  end

  def update
    respond_to do |format|
      if update_location
        format.json { render json: location_json, status: :ok }
      else
        format.json { render json: @location.errors, status: :unprocessable_content }
      end
    end
  end

  def destroy
    destroy_with_sibling_position(@location)
    head :no_content
  end

  private

  def set_location
    @location = Current.universe.locations.find(params.expect(:id))
  end

  def location_params
    params.expect(location: [ :name, :description, { location_tag_ids: [] }, :parent_id, :position ])
  end

  def update_location
    attributes = location_params
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
