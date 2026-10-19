# The API-surface counterpart of `SectionsController`: index and show as JSON.
# Sections are story-scoped: a request reaches them through its story.
class Api::SectionsController < Api::BaseController
  before_action :set_story
  before_action :set_section, only: %i[ show ]

  # GET /api/u/:universe_slug/s/:story_id/sections
  def index
    @sections = @story.sections.order(:position, :id)
    render json: @sections.map { |section| section_json(section) }
  end

  # GET /api/u/:universe_slug/s/:story_id/sections/:id
  def show
    render json: section_json(@section)
  end

  private

    def set_story
      @story = Current.universe.stories.find(params.expect(:story_id))
    end

    def set_section
      @section = @story.sections.find(params.expect(:id))
    end

    def section_json(section)
      {
        id: section.id,
        name: section.name,
        description: section.description,
        section_tag_ids: section.section_tag_ids,
        parent_id: section.parent_id,
        position: section.position
      }
    end
end
