class SectionTagsController < ApplicationController
  include MaintainsSiblingPositions
  maintains_sibling_positions_for :section_tag

  before_action :set_section_tag,
    only: %i[ update destroy ]

  # GET /section_tags/new
  def new
    section_tags = Current.universe.section_tags
    @section_tag = section_tags.new(parent_id: params[:parent_id])
  end

  # GET /section_tags or /section_tags.json
  def index
    @section_tags = Current.universe.section_tags
    @section_tags = @section_tags.includes(:children)
    @section_tags = @section_tags.where(parent_id: nil)
    @section_tags = @section_tags.order(:position, :id)
  end

  # POST /section_tags or /section_tags.json
  def create
    @section_tag = Current.universe.section_tags.new(section_tag_params)
    @section_tag.position = sibling_count(@section_tag.parent_id)

    respond_to do |format|
      if @section_tag.save
        format.json { render json: section_tag_json, status: :created }
      else
        format.json { render json: @section_tag.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /section_tags/1 or /section_tags/1.json
  def update
    respond_to do |format|
      if update_section_tag
        format.json { render json: section_tag_json, status: :ok }
      else
        format.json { render json: @section_tag.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /section_tags/1 or /section_tags/1.json
  def destroy
    @section_tag.destroy!

    respond_to do |format|
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
  def set_section_tag
    @section_tag = Current.universe.section_tags.find(params.expect(:id))
  end

  def current_universe_section_tag_path
    universe_section_tag_path(id: @section_tag)
  end

  def current_universe_section_tags_path
    universe_section_tags_path()
  end

  def section_tag_json
    {
      id: @section_tag.id,
      name: @section_tag.name,
      description: @section_tag.description,
      bgcolor: @section_tag.bgcolor,
      fgcolor: @section_tag.fgcolor,
      parent_id: @section_tag.parent_id,
      position: @section_tag.position,
      url: current_universe_section_tag_path,
    }
  end

  # Only allow a list of trusted parameters through.
  def section_tag_params
    params.expect(section_tag: [ :name, :description, :bgcolor, :fgcolor, :parent_id, :position ])
  end

  def update_section_tag
    attributes = section_tag_params
    update_with_sibling_position(@section_tag, attributes)
  end
end