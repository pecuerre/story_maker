class CharacterTagsController < ApplicationController
  include MaintainsSiblingPositions
  maintains_sibling_positions_for :character_tag

  before_action :set_character_tag, only: %i[ update destroy ]

  def index
    @character_tags = Current.universe.character_tags
    @character_tags = @character_tags.includes(:children)
    @character_tags = @character_tags.where(parent_id: nil)
    @character_tags = @character_tags.order(:position, :id)
  end

  def new
    character_tags = Current.universe.character_tags
    @character_tag = character_tags.new(parent_id: params[:parent_id])
  end

  def create
    @character_tag = Current.universe.character_tags.new(character_tag_params)
    @character_tag.position = sibling_count(@character_tag.parent_id)

    respond_to do |format|
      if @character_tag.save
        format.json { render json: character_tag_json, status: :created }
      else
        format.json { render json: @character_tag.errors, status: :unprocessable_content }
      end
    end
  end

  def update
    respond_to do |format|
      if update_character_tag
        format.json { render json: character_tag_json, status: :ok }
      else
        format.json { render json: @character_tag.errors, status: :unprocessable_content }
      end
    end
  end

  def destroy
    @character_tag.destroy!
    head :no_content
  end

  private

  def set_character_tag
    @character_tag = Current.universe.character_tags.find(params.expect(:id))
  end

  def character_tag_params
    params.expect(character_tag: [ :name, :description, :bgcolor, :fgcolor, :parent_id, :position ])
  end

  def update_character_tag
    attributes = character_tag_params
    update_with_sibling_position(@character_tag, attributes)
  end

  def character_tag_json
    {
      id: @character_tag.id,
      name: @character_tag.name,
      description: @character_tag.description,
      bgcolor: @character_tag.bgcolor,
      fgcolor: @character_tag.fgcolor,
      parent_id: @character_tag.parent_id,
      position: @character_tag.position,
      url: universe_character_tag_path(id: @character_tag)
    }
  end
end
