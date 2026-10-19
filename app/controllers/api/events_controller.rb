# The API-surface counterpart of `EventsController`: index and show as JSON.
class Api::EventsController < Api::BaseController
  before_action :set_event, only: %i[ show ]

  # GET /api/u/:universe_slug/events
  def index
    @events = Current.universe.events.order(:position, :id)
    render json: @events.map { |event| event_json(event) }
  end

  # GET /api/u/:universe_slug/events/:id
  def show
    render json: event_json(@event)
  end

  private

    def set_event
      @event = Current.universe.events.find(params.expect(:id))
    end

    def event_json(event)
      {
        id: event.id,
        title: event.title,
        start_datetime: event.start_datetime,
        end_datetime: event.end_datetime,
        before_event_id: event.before_event_id,
        after_event_id: event.after_event_id,
        simultaneous_event_id: event.simultaneous_event_id,
        description: event.description,
        event_tag_ids: event.event_tag_ids,
        parent_id: event.parent_id,
        position: event.position,
        display_string: event.display_label
      }
    end
end
