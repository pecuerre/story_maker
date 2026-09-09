class CharactersController < ApplicationController
  include MaintainsSiblingPositions
  maintains_sibling_positions_for :character

  before_action :set_character, only: %i[ update destroy ]

  def index
    @characters = Current.story.characters
    @characters = @characters.includes(:character_type)
    @characters = @characters.order(:name, :id)

    @character_types = Current.story.character_types
    @character_types = @character_types.order(:name)
  end

  def new
    @character = Current.story.characters.new(parent_id: params[:parent_id])

    @character_types = Current.story.character_types
    @character_types = @character_types.order(:name)
  end

  def create
    @character = Current.story.characters.new(character_params)
    @character.character_type ||= Current.story.character_types.order(:id).first
    @character.position = sibling_count(@character.parent_id)

    respond_to do |format|
      if @character.save
        format.json { render json: character_json, status: :created }
      else
        format.json { render json: @character.errors, status: :unprocessable_content }
      end
    end
  end

  def update
    respond_to do |format|
      if update_character
        format.json { render json: character_json, status: :ok }
      else
        format.json { render json: @character.errors, status: :unprocessable_content }
      end
    end
  end

  def destroy
    @character.destroy!
    head :no_content
  end

  private

  def set_character
    @character = Current.story.characters.find(params.expect(:id))
  end

  def character_params
    params.expect(character: [ :name, :description, :character_type_id, :parent_id, :position ])
  end

  def update_character
    attributes = character_params
    update_with_sibling_position(@character, attributes)
  end

  def character_json
    {
      id: @character.id,
      name: @character.name,
      description: @character.description,
      character_type_id: @character.character_type_id,
      parent_id: @character.parent_id,
      position: @character.position,
      url: story_character_path(id: @character)
    }
  end
end
