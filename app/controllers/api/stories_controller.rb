# The API-surface counterpart of `StoriesController`: index, show, and the
# mutations, all of them JSON. A mutation in a draft-based universe is remembered
# (`202`) instead of written; both demo universes are `direct`, so it is
# invisible locally and only appears in production.
class Api::StoriesController < Api::BaseController
  include RequiresJsonMutationFormat
  include DraftMutation

  before_action :set_story, only: %i[ show update destroy ]
  before_action :require_json_mutation_format, only: %i[ create update destroy ]

  # GET /api/u/:universe_slug/stories
  def index
    @stories = Current.universe.stories.order(:id)
    render json: @stories.map { |story| story_json(story) }
  end

  # GET /api/u/:universe_slug/stories/:id
  def show
    render json: story_json(@story)
  end

  # POST /api/u/:universe_slug/stories
  def create
    attributes = story_params
    @story = Current.universe.stories.new(attributes)
    return if remember_draft_create(@story, attributes)

    if @story.save
      render json: story_json(@story), status: :created
    else
      render json: @story.errors, status: :unprocessable_content
    end
  end

  # PATCH /api/u/:universe_slug/stories/:id
  def update
    attributes = story_params
    return if remember_draft_update(@story, attributes)

    if @story.update(attributes)
      render json: story_json(@story)
    else
      render json: @story.errors, status: :unprocessable_content
    end
  end

  # DELETE /api/u/:universe_slug/stories/:id
  def destroy
    return if remember_draft_delete(@story)

    @story.soft_delete
    head :no_content
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

    def story_params
      params.expect(story: [ :name, :description ])
    end
end
