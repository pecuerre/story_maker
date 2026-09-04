class LocationTypesController < ApplicationController
  before_action :set_location_type, only: %i[ update destroy ]

  def index
    @location_types = Current.story.location_types
    @location_types = @location_types.includes(:children)
    @location_types = @location_types.where(parent_id: nil)
    @location_types = @location_types.order(:position, :id)
  end

  def create
    @location_type = Current.story.location_types.new(location_type_params)
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
    @location_type = Current.story.location_types.find(params.expect(:id))
  end

  def location_type_params
    params.expect(location_type: [ :name, :description, :parent_id, :position ])
  end

  def sibling_count(parent_id)
    Current.story.location_types.where(parent_id: parent_id).where.not(id: @location_type&.id).count
  end

  def update_location_type
    attributes = location_type_params
    requested_position = attributes[:position]
    old_parent_id = @location_type.parent_id

    return false unless @location_type.update(attributes.except(:position))

    if requested_position.present? || old_parent_id != @location_type.parent_id
      normalize_siblings(Current.story.location_types.where(parent_id: old_parent_id).order(:position, :id).to_a) if old_parent_id != @location_type.parent_id
      siblings = @location_type.sibling_scope.to_a
      position = requested_position.present? ? requested_position.to_i.clamp(0, siblings.length) : siblings.length
      siblings.insert(position, @location_type)
      normalize_siblings(siblings)
    end

    true
  end

  def normalize_siblings(siblings)
    siblings.each_with_index { |location_type, index| location_type.update_columns(position: index) }
  end

  def location_type_json
    {
      id: @location_type.id,
      name: @location_type.name,
      description: @location_type.description,
      parent_id: @location_type.parent_id,
      position: @location_type.position,
      url: story_location_type_path(story_slug: Current.story.slug, id: @location_type)
    }
  end
end
