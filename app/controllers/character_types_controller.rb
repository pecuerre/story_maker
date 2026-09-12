class CharacterTypesController < ApplicationController
  include MaintainsSiblingPositions
  maintains_sibling_positions_for :character_type

  before_action :set_character_type, only: %i[ update destroy ]

  def index
    @character_types = Current.story.character_types
    @character_types = @character_types.includes(:children)
    @character_types = @character_types.where(parent_id: nil)
    @character_types = @character_types.order(:position, :id)
  end

  def new
    character_types = Current.story.character_types
    @character_type = character_types.new(parent_id: params[:parent_id])
  end

  def create
    @character_type = Current.story.character_types.new(character_type_params)
    @character_type.position = sibling_count(@character_type.parent_id)

    respond_to do |format|
      if @character_type.save
        format.json { render json: character_type_json, status: :created }
      else
        format.json { render json: @character_type.errors, status: :unprocessable_content }
      end
    end
  end

  def update
    respond_to do |format|
      if update_character_type
        format.json { render json: character_type_json, status: :ok }
      else
        format.json { render json: @character_type.errors, status: :unprocessable_content }
      end
    end
  end

  def destroy
    @character_type.destroy!
    head :no_content
  end

  private

  def set_character_type
    @character_type = Current.story.character_types.find(params.expect(:id))
  end

  def character_type_params
    params.expect(character_type: [ :name, :description, :bgcolor, :fgcolor, :parent_id, :position ])
  end

  def update_character_type
    attributes = character_type_params
    update_with_sibling_position(@character_type, attributes)
  end

  def character_type_json
    {
      id: @character_type.id,
      name: @character_type.name,
      description: @character_type.description,
      bgcolor: @character_type.bgcolor,
      fgcolor: @character_type.fgcolor,
      parent_id: @character_type.parent_id,
      position: @character_type.position,
      url: story_character_type_path(id: @character_type)
    }
  end
end
