class SectionsController < ApplicationController
  include MaintainsSiblingPositions
  maintains_sibling_positions_for :section

  before_action :set_story
  before_action :set_section, only: %i[ update destroy ]

  def index
    @sections = @story.sections
    @sections = @sections.includes(:children, :section_tags)
    @sections = @sections.where(parent_id: nil)
    @sections = @sections.order(:position, :id)

    @section_tags = Current.universe.section_tags
    @section_tags = @section_tags.order(:name)
  end

  def new
    @section = @story.sections.new(parent_id: params[:parent_id])

    @section_tags = Current.universe.section_tags
    @section_tags = @section_tags.order(:name)
  end

  def create
    @section = @story.sections.new(section_params)
    @section.section_tag_ids = [ Current.universe.section_tags.order(:id).first.id ] if @section.section_tag_ids.empty?
    @section.position = sibling_count(@section.parent_id)

    respond_to do |format|
      if @section.save
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
    @section.destroy!
    respond_to do |format|
      format.json { head :no_content }
    end
  end

  private

  def set_story
    @story = Current.universe.stories.find(params.expect(:story_id))
  end

  def current_universe_sections_path
    universe_story_sections_path(story_id: @story)
  end

  def set_section
    @section = @story.sections.find(params.expect(:id))
  end

  # Positions are maintained among the story's sections, not the universe's.
  def sibling_collection
    @story.sections
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
      url: universe_story_section_path(story_id: @story, id: @section)
    }
  end
end
