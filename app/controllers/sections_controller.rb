class SectionsController < ApplicationController
  allow_unauthenticated_access only: :index
  include MaintainsSiblingPositions
  maintains_sibling_positions_for :section

  before_action :set_story
  before_action :set_section, only: %i[ update destroy ]

  def index
    @sections = @story.sections
    @sections = @sections.includes(:children, :section_tags)
    @sections = @sections.where(parent_id: nil)
    @sections = @sections.order(:position, :id)

    @section_tags = @story.section_tags
    @section_tags = @section_tags.order(:name)
    @section_options = @story.sections.reorder(:position, :id).to_a
  end

  def new
    @section = @story.sections.new(parent_id: params[:parent_id])

    @section_tags = @story.section_tags
    @section_tags = @section_tags.order(:name)
    @section_options = @story.sections.reorder(:position, :id).to_a
  end

  def create
    attributes = section_params
    @section = @story.sections.new(attributes)

    respond_to do |format|
      if create_with_sibling_position(@section, requested_position: attributes[:position])
        format.json { render json: section_json, status: :created }
      else
        format.json { render json: @section.errors, status: :unprocessable_content }
      end
    end
  end

  def update
    respond_to do |format|
      if update_section
        format.json { render json: section_json, status: :ok }
      else
        format.json { render json: @section.errors, status: :unprocessable_content }
      end
    end
  end

  def destroy
    destroy_with_sibling_position(@section)
    respond_to do |format|
      format.json { head :no_content }
    end
  end

  private

  def set_story
    @story = Current.universe.stories.find(params.expect(:story_id))
  end

  def set_section
    @section = @story.sections.find(params.expect(:id))
  end

  # Positions are maintained among the story's sections, not the universe's.
  def sibling_collection
    @story.sections
  end

  def sibling_position_scope_owner
    @story
  end

  def section_params
    params.expect(section: [ :name, :description, { section_tag_ids: [] }, :parent_id, :position ])
  end

  def update_section
    attributes = section_params
    update_with_sibling_position(@section, attributes)
  end

  def section_json
    {
      id: @section.id,
      name: @section.name,
      description: @section.description,
      section_tag_ids: @section.section_tag_ids,
      parent_id: @section.parent_id,
      position: @section.position,
      url: universe_story_section_path(story_id: @story, id: @section)
    }
  end
end
