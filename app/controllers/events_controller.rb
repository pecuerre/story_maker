class EventsController < ApplicationController
  allow_unauthenticated_access only: %i[ index show ]
  include MaintainsSiblingPositions
  maintains_sibling_positions_for :event

  before_action :set_event, only: %i[ show update destroy ]

  def index
    @events = Current.universe.events.includes(:event_tags).order(:id)
    @events_for_select = @events
    @event_tags = Current.universe.event_tags.order(:position, :id)
  end

  # GET /events/:id — the record's own read-only details page. It identifies the
  # record and is the destination of every "Details" link; later slices add
  # the related-records sections without changing this URL.
  def show
  end

  def new
    @event = Current.universe.events.new(parent_id: params[:parent_id])
    @events_for_select = Current.universe.events.order(:id)
    @event_tags = Current.universe.event_tags.order(:position, :id)
  end

  def create
    attributes = event_params
    @event = Current.universe.events.new(attributes)

    respond_to do |format|
      if create_with_sibling_position(@event, requested_position: attributes[:position])
        format.json { render json: event_json, status: :created }
      else
        format.json { render json: @event.errors, status: :unprocessable_content }
      end
    end
  end

  def update
    respond_to do |format|
      if update_event
        format.json { render json: event_json, status: :ok }
      else
        format.json { render json: @event.errors, status: :unprocessable_content }
      end
    end
  end

  def destroy
    destroy_with_sibling_position(@event)
    head :no_content
  end

  private

  def set_event
    @event = Current.universe.events.find(params.expect(:id))
  end

  def event_params
    params.expect(event: [ :title, :start_datetime, :end_datetime, :before_event_id, :after_event_id,
      :simultaneous_event_id, :description, { event_tag_ids: [] }, :parent_id, :position ])
  end

  def update_event
    attributes = event_params
    update_with_sibling_position(@event, attributes)
  end

  def event_json
    {
      id: @event.id,
      title: @event.title,
      start_datetime: @event.start_datetime,
      end_datetime: @event.end_datetime,
      before_event_id: @event.before_event_id,
      after_event_id: @event.after_event_id,
      simultaneous_event_id: @event.simultaneous_event_id,
      description: @event.description,
      event_tag_ids: @event.event_tag_ids,
      parent_id: @event.parent_id,
      position: @event.position,
      display_string: @event.display_string,
      url: universe_event_path(id: @event)
    }
  end
end
