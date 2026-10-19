# The API-surface counterpart of `RelationTagsController`: index and show as JSON.
class Api::RelationTagsController < Api::BaseController
  before_action :set_relation_tag, only: %i[ show ]

  # GET /api/u/:universe_slug/relation_tags
  def index
    @relation_tags = Current.universe.relation_tags.order(:position, :id)
    render json: @relation_tags.map { |tag| tag_json(tag) }
  end

  # GET /api/u/:universe_slug/relation_tags/:id
  def show
    render json: tag_json(@relation_tag)
  end

  private

    def set_relation_tag
      @relation_tag = Current.universe.relation_tags.find(params.expect(:id))
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
