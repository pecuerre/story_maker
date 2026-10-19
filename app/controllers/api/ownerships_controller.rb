# The API-surface counterpart of `OwnershipsController`: index and show as JSON.
class Api::OwnershipsController < Api::BaseController
  before_action :set_ownership, only: %i[ show ]

  # GET /api/u/:universe_slug/ownerships
  def index
    @ownerships = Current.universe.ownerships.order(:id)
    render json: @ownerships.map { |ownership| ownership_json(ownership) }
  end

  # GET /api/u/:universe_slug/ownerships/:id
  def show
    render json: ownership_json(@ownership)
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
end
