class EventTagsController < ApplicationController
  allow_unauthenticated_access only: :index
  include MaintainsSiblingPositions
  maintains_sibling_positions_for :event_tag

  before_action :set_event_tag,
    only: %i[ update destroy ]

  # GET /event_tags/new
  def new
    event_tags = Current.universe.event_tags
    @event_tag = event_tags.new(parent_id: params[:parent_id])
  end

  # GET /event_tags or /event_tags.json
  def index
    @event_tags = Current.universe.event_tags
    @event_tags = @event_tags.includes(:children)
    @event_tags = @event_tags.where(parent_id: nil)
    @event_tags = @event_tags.order(:position, :id)
  end

  # POST /event_tags or /event_tags.json
  def create
    attributes = event_tag_params
    @event_tag = Current.universe.event_tags.new(attributes)

    respond_to do |format|
      if create_with_sibling_position(@event_tag, requested_position: attributes[:position])
        format.json { render json: event_tag_json, status: :created }
      else
        format.json { render json: @event_tag.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /event_tags/1 or /event_tags/1.json
  def update
    respond_to do |format|
      if update_event_tag
        format.json { render json: event_tag_json, status: :ok }
      else
        format.json { render json: @event_tag.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /event_tags/1 or /event_tags/1.json
  def destroy
    destroy_with_sibling_position(@event_tag)

    respond_to do |format|
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_event_tag
    @event_tag = Current.universe.event_tags.find(params.expect(:id))
  end

  def event_tag_json
    {
      id: @event_tag.id,
      name: @event_tag.name,
      description: @event_tag.description,
      bgcolor: @event_tag.bgcolor,
      fgcolor: @event_tag.fgcolor,
      parent_id: @event_tag.parent_id,
      position: @event_tag.position,
      url: universe_event_tag_path(id: @event_tag)
    }
  end

  # Only allow a list of trusted parameters through.
  def event_tag_params
    params.expect(event_tag: [ :name, :description, :bgcolor, :fgcolor, :parent_id, :position ])
  end

  def update_event_tag
    attributes = event_tag_params
    update_with_sibling_position(@event_tag, attributes)
  end
end
