# The API-surface counterpart of `StoriesController`: index and show as JSON.
class Api::StoriesController < Api::BaseController
  before_action :set_story, only: %i[ show ]

  # GET /api/u/:universe_slug/stories
  def index
    @stories = Current.universe.stories.order(:id)
    render json: @stories.map { |story| story_json(story) }
  end

  # GET /api/u/:universe_slug/stories/:id
  def show
    render json: story_json(@story)
  end

  private

    def set_story
      @story = Current.universe.stories.find(params.expect(:id))
    end

    def story_json(story)
      {
        id: story.id,
        name: story.name,
        description: story.description,
        slug: story.slug
      }
    end
end
