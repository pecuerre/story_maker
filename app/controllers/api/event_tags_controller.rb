# The API-surface counterpart of `EventTagsController`: index and show as JSON.
class Api::EventTagsController < Api::BaseController
  before_action :set_event_tag, only: %i[ show ]

  # GET /api/u/:universe_slug/event_tags
  def index
    @event_tags = Current.universe.event_tags.order(:position, :id)
    render json: @event_tags.map { |tag| tag_json(tag) }
  end

  # GET /api/u/:universe_slug/event_tags/:id
  def show
    render json: tag_json(@event_tag)
  end

  private

    def set_event_tag
      @event_tag = Current.universe.event_tags.find(params.expect(:id))
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
