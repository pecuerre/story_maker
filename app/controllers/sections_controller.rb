class SectionsController < ApplicationController
  include MaintainsSiblingPositions
  maintains_sibling_positions_for :section

  before_action :set_section, only: %i[ update destroy ]

  def index
    @sections = Current.story.sections
    @sections = @sections.includes(:children, :section_type)
    @sections = @sections.where(parent_id: nil)
    @sections = @sections.order(:position, :id)

    @section_types = Current.story.section_types
    @section_types = @section_types.order(:name)
  end

  def new
    @section = Current.story.sections.new(parent_id: params[:parent_id])

    @section_types = Current.story.section_types
    @section_types = @section_types.order(:name)
  end

  def create
    @section = Current.story.sections.new(section_params)
    @section.section_type ||= Current.story.section_types.order(:id).first
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

  def current_story_sections_path
    story_sections_path(story_slug: Current.story.slug)
  end

  def set_section
    @section = Current.story.sections.find(params.expect(:id))
  end

  def section_params
    params.expect(section: [ :name, :description, :section_type_id, :parent_id, :position ])
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
      section_type_id: @section.section_type_id,
      parent_id: @section.parent_id,
      url: story_section_path(story_slug: Current.story.slug, id: @section)
    }
  end
end