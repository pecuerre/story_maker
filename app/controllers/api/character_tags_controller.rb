# The API-surface counterpart of `CharacterTagsController`: index and show as JSON.
class Api::CharacterTagsController < Api::BaseController
  before_action :set_character_tag, only: %i[ show ]

  # GET /api/u/:universe_slug/character_tags
  def index
    @character_tags = Current.universe.character_tags.order(:position, :id)
    render json: @character_tags.map { |tag| tag_json(tag) }
  end

  # GET /api/u/:universe_slug/character_tags/:id
  def show
    render json: tag_json(@character_tag)
  end

  private

    def set_character_tag
      @character_tag = Current.universe.character_tags.find(params.expect(:id))
    end

    def tag_json(tag)
      {
        id: tag.id,
        name: tag.name,
        description: tag.description,
        parent_id: tag.parent_id,
        position: tag.position,
        taggable: tag.taggable,
        bgcolor: tag.bgcolor,
        fgcolor: tag.fgcolor,
        slug: tag.slug
      }
    end
end
