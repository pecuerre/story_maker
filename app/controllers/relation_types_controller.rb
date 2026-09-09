class RelationTypesController < ApplicationController
  include MaintainsSiblingPositions
  maintains_sibling_positions_for :relation_type

  before_action :set_relation_type, only: %i[ update destroy ]

  def index
    @relation_types = Current.story.relation_types
    @relation_types = @relation_types.includes(:children)
    @relation_types = @relation_types.where(parent_id: nil)
    @relation_types = @relation_types.order(:position, :id)
  end

  def new
    relation_types = Current.story.relation_types
    @relation_type = relation_types.new(parent_id: params[:parent_id])
  end

  def create
    @relation_type = Current.story.relation_types.new(relation_type_params)
    @relation_type.position = sibling_count(@relation_type.parent_id)

    respond_to do |format|
      if @relation_type.save
        format.json { render json: relation_type_json, status: :created }
      else
        format.json { render json: @relation_type.errors, status: :unprocessable_content }
      end
    end
  end

  def update
    respond_to do |format|
      if update_relation_type
        format.json { render json: relation_type_json, status: :ok }
      else
        format.json { render json: @relation_type.errors, status: :unprocessable_content }
      end
    end
  end

  def destroy
    @relation_type.destroy!
    head :no_content
  end

  private

  def set_relation_type
    @relation_type = Current.story.relation_types.find(params.expect(:id))
  end

  def relation_type_params
    params.expect(relation_type: [ :name, :description, :parent_id, :position, :symmetric, :inverse ])
  end

  def update_relation_type
    update_with_sibling_position(@relation_type, relation_type_params)
  end

  def relation_type_json
    {
      id: @relation_type.id,
      name: @relation_type.name,
      description: @relation_type.description,
      parent_id: @relation_type.parent_id,
      position: @relation_type.position,
      symmetric: @relation_type.symmetric,
      inverse: @relation_type.inverse,
      url: story_relation_type_path(id: @relation_type)
    }
  end
end