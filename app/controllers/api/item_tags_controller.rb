# The API-surface counterpart of `ItemTagsController`: index and show as JSON.
class Api::ItemTagsController < Api::BaseController
  before_action :set_item_tag, only: %i[ show ]

  # GET /api/u/:universe_slug/item_tags
  def index
    @item_tags = Current.universe.item_tags.order(:position, :id)
    render json: @item_tags.map { |tag| tag_json(tag) }
  end

  # GET /api/u/:universe_slug/item_tags/:id
  def show
    render json: tag_json(@item_tag)
  end

  private

    def set_item_tag
      @item_tag = Current.universe.item_tags.find(params.expect(:id))
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
