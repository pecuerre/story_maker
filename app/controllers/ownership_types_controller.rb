class OwnershipTypesController < ApplicationController
  include MaintainsSiblingPositions
  maintains_sibling_positions_for :ownership_type

  before_action :set_ownership_type, only: %i[ update destroy ]

  def index
    @ownership_types = Current.story.ownership_types
    @ownership_types = @ownership_types.includes(:children)
    @ownership_types = @ownership_types.where(parent_id: nil)
    @ownership_types = @ownership_types.order(:position, :id)
  end

  def new
    ownership_types = Current.story.ownership_types
    @ownership_type = ownership_types.new(parent_id: params[:parent_id])
  end

  def create
    @ownership_type = Current.story.ownership_types.new(ownership_type_params)
    @ownership_type.position = sibling_count(@ownership_type.parent_id)

    respond_to do |format|
      if @ownership_type.save
        format.json { render json: ownership_type_json, status: :created }
      else
        format.json { render json: @ownership_type.errors, status: :unprocessable_content }
      end
    end
  end

  def update
    respond_to do |format|
      if update_ownership_type
        format.json { render json: ownership_type_json, status: :ok }
      else
        format.json { render json: @ownership_type.errors, status: :unprocessable_content }
      end
    end
  end

  def destroy
    @ownership_type.destroy!
    head :no_content
  end

  private

  def set_ownership_type
    @ownership_type = Current.story.ownership_types.find(params.expect(:id))
  end

  def ownership_type_params
    params.expect(ownership_type: [ :name, :description, :color, :parent_id, :position ])
  end

  def update_ownership_type
    update_with_sibling_position(@ownership_type, ownership_type_params)
  end

  def ownership_type_json
    {
      id: @ownership_type.id,
      name: @ownership_type.name,
      description: @ownership_type.description,
      color: @ownership_type.color,
      parent_id: @ownership_type.parent_id,
      position: @ownership_type.position,
      url: story_ownership_type_path(id: @ownership_type)
    }
  end
end
