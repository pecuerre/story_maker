# The API-surface counterpart of `LocationsController`: index and show as JSON.
class Api::LocationsController < Api::BaseController
  before_action :set_location, only: %i[ show ]

  # GET /api/u/:universe_slug/locations
  def index
    @locations = Current.universe.locations.order(:position, :id)
    render json: @locations.map { |location| location_json(location) }
  end

  # GET /api/u/:universe_slug/locations/:id
  def show
    render json: location_json(@location)
  end

  private

    def set_location
      @location = Current.universe.locations.find(params.expect(:id))
    end

    def location_json(location)
      {
        id: location.id,
        name: location.name,
        description: location.description,
        **Location::PROFILE_FIELDS.to_h { |field| [ field, location.public_send(field) ] },
        location_tag_ids: location.location_tag_ids,
        parent_id: location.parent_id,
        position: location.position
      }
    end
end
