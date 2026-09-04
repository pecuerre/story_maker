class LocationsController < ApplicationController
  before_action :set_location, only: %i[ update destroy ]

  def index
    @locations = Current.story.locations
    @locations = @locations.includes(:children, :location_type)
    @locations = @locations.where(parent_id: nil)
    @locations = @locations.order(:position, :id)

    @location_types = Current.story.location_types
    @location_types = @location_types.order(:name)
  end

  def create
    @location = Current.story.locations.new(location_params)
    @location.location_type ||= Current.story.location_types.order(:id).first
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
    params.expect(location: [ :name, :description, :location_type_id, :parent_id, :position ])
  end

  def sibling_count(parent_id)
    Current.story.locations.where(parent_id: parent_id).where.not(id: @location&.id).count
  end

  def update_location
    attributes = location_params
    requested_position = attributes[:position]
    old_parent_id = @location.parent_id

    return false unless @location.update(attributes.except(:position))

    if requested_position.present? || old_parent_id != @location.parent_id
      normalize_siblings(Current.story.locations.where(parent_id: old_parent_id).order(:position, :id).to_a) if old_parent_id != @location.parent_id
      siblings = @location.sibling_scope.to_a
      position = requested_position.present? ? requested_position.to_i.clamp(0, siblings.length) : siblings.length
      siblings.insert(position, @location)
      normalize_siblings(siblings)
    end

    true
  end

  def normalize_siblings(siblings)
    siblings.each_with_index { |location, index| location.update_columns(position: index) }
  end

  def location_json
    {
      id: @location.id,
      name: @location.name,
      description: @location.description,
      location_type_id: @location.location_type_id,
      parent_id: @location.parent_id,
      position: @location.position,
      url: story_location_path(story_slug: Current.story.slug, id: @location)
    }
  end
end
