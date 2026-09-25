class LocationTagsController < ApplicationController
  allow_unauthenticated_access only: :index
  include MaintainsSiblingPositions
  maintains_sibling_positions_for :location_tag

  before_action :set_location_tag, only: %i[ update destroy ]

  def index
    @location_tags = Current.universe.location_tags
    @location_tags = @location_tags.includes(:children)
    @location_tags = @location_tags.where(parent_id: nil)
    @location_tags = @location_tags.order(:position, :id)
  end

  def create
    attributes = location_tag_params
    @location_tag = Current.universe.location_tags.new(attributes)

    respond_to do |format|
      if create_with_sibling_position(@location_tag, requested_position: attributes[:position])
        format.json { render json: location_tag_json, status: :created }
      else
        format.json { render json: @location_tag.errors, status: :unprocessable_content }
      end
    end
  end

  def update
    respond_to do |format|
      if update_location_tag
        format.json { render json: location_tag_json, status: :ok }
      else
        format.json { render json: @location_tag.errors, status: :unprocessable_content }
      end
    end
  end

  def destroy
    destroy_with_sibling_position(@location_tag)
    head :no_content
  end

  private

  def set_location_tag
    @location_tag = Current.universe.location_tags.find(params.expect(:id))
  end

  def location_tag_params
    params.expect(location_tag: [ :name, :description, :bgcolor, :fgcolor, :parent_id, :position ])
  end

  def update_location_tag
    attributes = location_tag_params
    update_with_sibling_position(@location_tag, attributes)
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
      url: universe_location_tag_path(id: @location_tag)
    }
  end
end
