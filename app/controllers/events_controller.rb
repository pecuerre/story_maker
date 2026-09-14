class EventsController < ApplicationController
  include MaintainsSiblingPositions
  maintains_sibling_positions_for :event

  before_action :set_event, only: %i[ update destroy ]

  def index
    @events = Current.universe.events.includes(:event_types).order(:id)
    @events_for_select = @events
    @event_types = Current.universe.event_types.order(:position, :id)
  end

  def new
    @event = Current.universe.events.new(parent_id: params[:parent_id])
    @events_for_select = Current.universe.events.order(:id)
    @event_types = Current.universe.event_types.order(:position, :id)
  end

  def create
    @event = Current.universe.events.new(event_params)
    @event.position = sibling_count(@event.parent_id)

    respond_to do |format|
      if @event.save
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
    @event.destroy!
    head :no_content
  end

  private

  def set_event
    @event = Current.universe.events.find(params.expect(:id))
  end

  def event_params
    params.expect(event: [ :title, :start_datetime, :end_datetime, :before_event_id, :after_event_id,
      :simultaneous_event_id, :description, { event_type_ids: [] }, :parent_id, :position ])
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
      event_type_ids: @event.event_type_ids,
      parent_id: @event.parent_id,
      position: @event.position,
      display_string: @event.display_string,
      url: universe_event_path(id: @event)
    }
  end
end
