# The API-surface counterpart of `RelationsController`: index and show as JSON.
class Api::RelationsController < Api::BaseController
  before_action :set_relation, only: %i[ show ]

  # GET /api/u/:universe_slug/relations
  def index
    @relations = Current.universe.relations.order(:id)
    render json: @relations.map { |relation| relation_json(relation) }
  end

  # GET /api/u/:universe_slug/relations/:id
  def show
    render json: relation_json(@relation)
  end

  private

    def set_relation
      @relation = Current.universe.relations.find(params.expect(:id))
    end

    def relation_json(relation)
      {
        id: relation.id,
        name: relation.name,
        description: relation.description,
        character1_id: relation.character1_id,
        character2_id: relation.character2_id,
        from_date: relation.from_date,
        to_date: relation.to_date,
        relation_tag_ids: relation.relation_tag_ids,
        slug: relation.slug
      }
    end
end
