# The API-surface counterpart of `LocationTagsController`: index and show as JSON.
class Api::LocationTagsController < Api::BaseController
  before_action :set_location_tag, only: %i[ show ]

  # GET /api/u/:universe_slug/location_tags
  def index
    @location_tags = Current.universe.location_tags.order(:position, :id)
    render json: @location_tags.map { |tag| tag_json(tag) }
  end

  # GET /api/u/:universe_slug/location_tags/:id
  def show
    render json: tag_json(@location_tag)
  end

  private

    def set_location_tag
      @location_tag = Current.universe.location_tags.find(params.expect(:id))
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
