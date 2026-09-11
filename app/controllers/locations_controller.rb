class LocationsController < ApplicationController
  include MaintainsSiblingPositions
  maintains_sibling_positions_for :location

  before_action :set_location, only: %i[ update destroy ]

  def index
    @locations = Current.story.locations
    @locations = @locations.includes(:children, :location_types)
    @locations = @locations.where(parent_id: nil)
    @locations = @locations.order(:position, :id)

    @location_types = Current.story.location_types
    @location_types = @location_types.order(:name)
  end

  def create
    @location = Current.story.locations.new(location_params)
    @location.location_type_ids = [ Current.story.location_types.order(:id).first.id ] if @location.location_type_ids.empty?
    @location.position = sibling_count(@location.parent_id)

    respond_to do |format|
      if @location.save
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
    @location.destroy!
    head :no_content
  end

  private

  def set_location
    @location = Current.story.locations.find(params.expect(:id))
  end

  def location_params
    params.expect(location: [ :name, :description, { location_type_ids: [] }, :parent_id, :position ])
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
      location_type_ids: @location.location_type_ids,
      parent_id: @location.parent_id,
      position: @location.position,
      url: story_location_path(id: @location)
    }
  end
end
