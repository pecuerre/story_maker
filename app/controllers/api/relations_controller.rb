# The API-surface counterpart of `RelationsController`: index, show, and the
# mutations, all of them JSON. A mutation in a draft-based universe is remembered
# (`202`) instead of written; both demo universes are `direct`, so it is
# invisible locally and only appears in production.
class Api::RelationsController < Api::BaseController
  include RequiresJsonMutationFormat
  include DraftMutation

  before_action :set_relation, only: %i[ show update destroy ]
  before_action :require_json_mutation_format, only: %i[ create update destroy ]

  # GET /api/u/:universe_slug/relations
  def index
    @relations = Current.universe.relations.order(:id)
    render json: @relations.map { |relation| relation_json(relation) }
  end

  # GET /api/u/:universe_slug/relations/:id
  def show
    render json: relation_json(@relation)
  end

  # POST /api/u/:universe_slug/relations
  def create
    attributes = relation_params
    @relation = Current.universe.relations.new(attributes)
    return if remember_draft_create(@relation, attributes)

    if @relation.save
      render json: relation_json(@relation), status: :created
    else
      render json: @relation.errors, status: :unprocessable_content
    end
  end

  # PATCH /api/u/:universe_slug/relations/:id
  def update
    attributes = relation_params
    return if remember_draft_update(@relation, attributes)

    if @relation.update(attributes)
      render json: relation_json(@relation)
    else
      render json: @relation.errors, status: :unprocessable_content
    end
  end

  # DELETE /api/u/:universe_slug/relations/:id
  def destroy
    return if remember_draft_delete(@relation)

    @relation.soft_delete
    head :no_content
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

    def relation_params
      params.expect(relation: [ :name, :character1_id, :character2_id, { relation_tag_ids: [] }, :description, :from_date, :to_date ])
    end
end
