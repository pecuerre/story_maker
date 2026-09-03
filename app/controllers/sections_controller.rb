class SectionsController < ApplicationController
  before_action :set_section, only: %i[ update destroy ]

  def index
    @sections = Current.story.sections.includes(:children, :section_type).where(parent_id: nil).order(:position, :id)
    @section_types = Current.story.section_types.order(:name)
  end

  def new
    @section = Current.story.sections.new(parent_id: params[:parent_id])
    @section_types = Current.story.section_types.order(:name)
  end

  def create
    @section = Current.story.sections.new(section_params)
    @section.section_type ||= Current.story.section_types.order(:id).first
    @section.position = sibling_count(@section.parent_id)

    respond_to do |format|
      if @section.save
        format.html { redirect_to story_sections_path(story_slug: Current.story.slug), notice: "Section was successfully created." }
        format.json { render json: section_json, status: :created }
      else
        format.html { redirect_to story_sections_path(story_slug: Current.story.slug), alert: @section.errors.full_messages.to_sentence }
        format.json { render json: @section.errors, status: :unprocessable_content }
      end
    end
  end

  def update
    respond_to do |format|
      if update_section
        format.html { redirect_to story_sections_path(story_slug: Current.story.slug), notice: "Section was successfully updated.", status: :see_other }
        format.json { render json: section_json, status: :ok }
      else
        format.html { redirect_to story_sections_path(story_slug: Current.story.slug), alert: @section.errors.full_messages.to_sentence }
        format.json { render json: @section.errors, status: :unprocessable_content }
      end
    end
  end

  def destroy
    @section.destroy!
    respond_to do |format|
      format.html { redirect_to story_sections_path(story_slug: Current.story.slug), notice: "Section was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private

  def set_section
    @section = Current.story.sections.find(params.expect(:id))
  end

  def section_params
    params.expect(section: [ :name, :description, :section_type_id, :parent_id, :position ])
  end

  def sibling_count(parent_id)
    Current.story.sections.where(parent_id: parent_id).where.not(id: @section&.id).count
  end

  def update_section
    attributes = section_params
    requested_position = attributes[:position]
    old_parent_id = @section.parent_id

    return false unless @section.update(attributes.except(:position))

    if requested_position.present? || old_parent_id != @section.parent_id
      normalize_siblings(Current.story.sections.where(parent_id: old_parent_id).order(:position, :id).to_a) if old_parent_id != @section.parent_id
      siblings = @section.sibling_scope.to_a
      position = requested_position.present? ? requested_position.to_i.clamp(0, siblings.length) : siblings.length
      siblings.insert(position, @section)
      normalize_siblings(siblings)
    end

    true
  end

  def normalize_siblings(siblings)
    siblings.each_with_index { |section, index| section.update_columns(position: index) }
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