class SectionTypesController < ApplicationController
  include MaintainsSiblingPositions
  maintains_sibling_positions_for :section_type

  before_action :set_section_type,
    only: %i[ update destroy ]

  # GET /section_types/new
  def new
    section_types = Current.universe.section_types
    @section_type = section_types.new(parent_id: params[:parent_id])
  end

  # GET /section_types or /section_types.json
  def index
    @section_types = Current.universe.section_types
    @section_types = @section_types.includes(:children)
    @section_types = @section_types.where(parent_id: nil)
    @section_types = @section_types.order(:position, :id)
  end

  # POST /section_types or /section_types.json
  def create
    @section_type = Current.universe.section_types.new(section_type_params)
    @section_type.position = sibling_count(@section_type.parent_id)

    respond_to do |format|
      if @section_type.save
        format.json { render json: section_type_json, status: :created }
      else
        format.json { render json: @section_type.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /section_types/1 or /section_types/1.json
  def update
    respond_to do |format|
      if update_section_type
        format.json { render json: section_type_json, status: :ok }
      else
        format.json { render json: @section_type.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /section_types/1 or /section_types/1.json
  def destroy
    @section_type.destroy!

    respond_to do |format|
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
  def set_section_type
    @section_type = Current.universe.section_types.find(params.expect(:id))
  end

  def current_universe_section_type_path
    universe_section_type_path(id: @section_type)
  end

  def current_universe_section_types_path
    universe_section_types_path()
  end

  def section_type_json
    {
      id: @section_type.id,
      name: @section_type.name,
      description: @section_type.description,
      bgcolor: @section_type.bgcolor,
      fgcolor: @section_type.fgcolor,
      parent_id: @section_type.parent_id,
      position: @section_type.position,
      url: current_universe_section_type_path,
    }
  end

  # Only allow a list of trusted parameters through.
  def section_type_params
    params.expect(section_type: [ :name, :description, :bgcolor, :fgcolor, :parent_id, :position ])
  end

  def update_section_type
    attributes = section_type_params
    update_with_sibling_position(@section_type, attributes)
  end
end