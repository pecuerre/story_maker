class EventTypesController < ApplicationController
  include MaintainsSiblingPositions
  maintains_sibling_positions_for :event_type

  before_action :set_event_type,
    only: %i[ update destroy ]

  # GET /event_types/new
  def new
    event_types = Current.story.event_types
    @event_type = event_types.new(parent_id: params[:parent_id])
  end

  # GET /event_types or /event_types.json
  def index
    @event_types = Current.story.event_types
    @event_types = @event_types.includes(:children)
    @event_types = @event_types.where(parent_id: nil)
    @event_types = @event_types.order(:position, :id)
  end

  # POST /event_types or /event_types.json
  def create
    @event_type = Current.story.event_types.new(event_type_params)
    @event_type.position = sibling_count(@event_type.parent_id)

    respond_to do |format|
      if @event_type.save
        format.json { render json: event_type_json, status: :created }
      else
        format.json { render json: @event_type.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /event_types/1 or /event_types/1.json
  def update
    respond_to do |format|
      if update_event_type
        format.json { render json: event_type_json, status: :ok }
      else
        format.json { render json: @event_type.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /event_types/1 or /event_types/1.json
  def destroy
    @event_type.destroy!

    respond_to do |format|
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
  def set_event_type
    @event_type = Current.story.event_types.find(params.expect(:id))
  end

  def current_story_event_type_path
    story_event_type_path(id: @event_type)
  end

  def current_story_event_types_path
    story_event_types_path()
  end

  def event_type_json
    {
      id: @event_type.id,
      name: @event_type.name,
      description: @event_type.description,
      color: @event_type.color,
      parent_id: @event_type.parent_id,
      position: @event_type.position,
      url: current_story_event_type_path,
    }
  end

  # Only allow a list of trusted parameters through.
  def event_type_params
    params.expect(event_type: [ :name, :description, :color, :parent_id, :position ])
  end

  def update_event_type
    attributes = event_type_params
    update_with_sibling_position(@event_type, attributes)
  end
end
