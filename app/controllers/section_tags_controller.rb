class SectionTagsController < ApplicationController
  allow_unauthenticated_access only: :index
  include MaintainsSiblingPositions
  maintains_sibling_positions_for :section_tag

  before_action :set_story
  before_action :set_section_tag,
    only: %i[ update destroy ]

  # GET /section_tags/new
  def new
    @section_tag = @story.section_tags.new(parent_id: params[:parent_id])
  end

  # GET /section_tags or /section_tags.json
  def index
    @section_tags = @story.section_tags
    @section_tags = @section_tags.includes(:children)
    @section_tags = @section_tags.where(parent_id: nil)
    @section_tags = @section_tags.order(:position, :id)
  end

  # POST /section_tags or /section_tags.json
  def create
    attributes = section_tag_params
    @section_tag = @story.section_tags.new(attributes)

    respond_to do |format|
      if create_with_sibling_position(@section_tag, requested_position: attributes[:position])
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
    destroy_with_sibling_position(@section_tag)

    respond_to do |format|
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_story
    @story = Current.universe.stories.find(params.expect(:story_id))
  end

  def set_section_tag
    @section_tag = @story.section_tags.find(params.expect(:id))
  end

  # Positions are maintained among the story's section tags, not the universe's.
  def sibling_collection
    @story.section_tags
  end

  def sibling_position_scope_owner
    @story
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
      url: universe_story_section_tag_path(story_id: @story, id: @section_tag)
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
