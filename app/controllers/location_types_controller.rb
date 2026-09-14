class LocationTypesController < ApplicationController
  include MaintainsSiblingPositions
  maintains_sibling_positions_for :location_type

  before_action :set_location_type, only: %i[ update destroy ]

  def index
    @location_types = Current.universe.location_types
    @location_types = @location_types.includes(:children)
    @location_types = @location_types.where(parent_id: nil)
    @location_types = @location_types.order(:position, :id)
  end

  def create
    @location_type = Current.universe.location_types.new(location_type_params)
    @location_type.position = sibling_count(@location_type.parent_id)

    respond_to do |format|
      if @location_type.save
        format.json { render json: location_type_json, status: :created }
      else
        format.json { render json: @location_type.errors, status: :unprocessable_content }
      end
    end
  end

  def update
    respond_to do |format|
      if update_location_type
        format.json { render json: location_type_json, status: :ok }
      else
        format.json { render json: @location_type.errors, status: :unprocessable_content }
      end
    end
  end

  def destroy
    @location_type.destroy!
    head :no_content
  end

  private

  def set_location_type
    @location_type = Current.universe.location_types.find(params.expect(:id))
  end

  def location_type_params
    params.expect(location_type: [ :name, :description, :bgcolor, :fgcolor, :parent_id, :position ])
  end

  def update_location_type
    attributes = location_type_params
    update_with_sibling_position(@location_type, attributes)
  end

  def location_type_json
    {
      id: @location_type.id,
      name: @location_type.name,
      description: @location_type.description,
      bgcolor: @location_type.bgcolor,
      fgcolor: @location_type.fgcolor,
      parent_id: @location_type.parent_id,
      position: @location_type.position,
      url: universe_location_type_path(id: @location_type)
    }
  end
end
