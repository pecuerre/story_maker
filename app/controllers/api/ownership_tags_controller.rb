# The API-surface counterpart of `OwnershipTagsController`: index and show as JSON.
class Api::OwnershipTagsController < Api::BaseController
  before_action :set_ownership_tag, only: %i[ show ]

  # GET /api/u/:universe_slug/ownership_tags
  def index
    @ownership_tags = Current.universe.ownership_tags.order(:position, :id)
    render json: @ownership_tags.map { |tag| tag_json(tag) }
  end

  # GET /api/u/:universe_slug/ownership_tags/:id
  def show
    render json: tag_json(@ownership_tag)
  end

  private

    def set_ownership_tag
      @ownership_tag = Current.universe.ownership_tags.find(params.expect(:id))
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
