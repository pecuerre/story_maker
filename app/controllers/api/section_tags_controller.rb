# The API-surface counterpart of `SectionTagsController`: index and show as JSON.
# Section tags are story-scoped: a request reaches them through its story.
class Api::SectionTagsController < Api::BaseController
  before_action :set_story
  before_action :set_section_tag, only: %i[ show ]

  # GET /api/u/:universe_slug/s/:story_id/section_tags
  def index
    @section_tags = @story.section_tags.order(:position, :id)
    render json: @section_tags.map { |section_tag| section_tag_json(section_tag) }
  end

  # GET /api/u/:universe_slug/s/:story_id/section_tags/:id
  def show
    render json: section_tag_json(@section_tag)
  end

  private

    def set_story
      @story = Current.universe.stories.find(params.expect(:story_id))
    end

    def set_section_tag
      @section_tag = @story.section_tags.find(params.expect(:id))
    end

    def section_tag_json(section_tag)
      {
        id: section_tag.id,
        name: section_tag.name,
        description: section_tag.description,
        bgcolor: section_tag.bgcolor,
        fgcolor: section_tag.fgcolor,
        parent_id: section_tag.parent_id,
        position: section_tag.position,
        taggable: section_tag.taggable
      }
    end
end
