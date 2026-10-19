# The API-surface counterpart of `OwnershipsController`: index, show, and the
# mutations, all of them JSON. A mutation in a draft-based universe is remembered
# (`202`) instead of written; both demo universes are `direct`, so it is
# invisible locally and only appears in production.
class Api::OwnershipsController < Api::BaseController
  include RequiresJsonMutationFormat
  include DraftMutation

  before_action :set_ownership, only: %i[ show update destroy ]
  before_action :require_json_mutation_format, only: %i[ create update destroy ]

  # GET /api/u/:universe_slug/ownerships
  def index
    @ownerships = Current.universe.ownerships.order(:id)
    render json: @ownerships.map { |ownership| ownership_json(ownership) }
  end

  # GET /api/u/:universe_slug/ownerships/:id
  def show
    render json: ownership_json(@ownership)
  end

  # POST /api/u/:universe_slug/ownerships
  def create
    attributes = ownership_params
    @ownership = Current.universe.ownerships.new(attributes)
    return if remember_draft_create(@ownership, attributes)

    if @ownership.save
      render json: ownership_json(@ownership), status: :created
    else
      render json: @ownership.errors, status: :unprocessable_content
    end
  end

  # PATCH /api/u/:universe_slug/ownerships/:id
  def update
    attributes = ownership_params
    return if remember_draft_update(@ownership, attributes)

    if @ownership.update(attributes)
      render json: ownership_json(@ownership)
    else
      render json: @ownership.errors, status: :unprocessable_content
    end
  end

  # DELETE /api/u/:universe_slug/ownerships/:id
  def destroy
    return if remember_draft_delete(@ownership)

    @ownership.soft_delete
    head :no_content
  end

  private

    def set_ownership
      @ownership = Current.universe.ownerships.find(params.expect(:id))
    end

    def ownership_json(ownership)
      {
        id: ownership.id,
        name: ownership.name,
        description: ownership.description,
        item_id: ownership.item_id,
        character_id: ownership.character_id,
        from_date: ownership.from_date,
        to_date: ownership.to_date,
        ownership_tag_ids: ownership.ownership_tag_ids,
        slug: ownership.slug
      }
    end

    def ownership_params
      params.expect(ownership: [ :name, :item_id, :character_id, { ownership_tag_ids: [] }, :description, :from_date, :to_date ])
    end
end
