# The API-surface counterpart of `SceneTagsController`: index and show as JSON.
# Scene tags are story-scoped: a request reaches them through its story.
class Api::SceneTagsController < Api::BaseController
  before_action :set_story
  before_action :set_scene_tag, only: %i[ show ]

  # GET /api/u/:universe_slug/s/:story_id/scene_tags
  def index
    @scene_tags = @story.scene_tags.order(:position, :id)
    render json: @scene_tags.map { |scene_tag| scene_tag_json(scene_tag) }
  end

  # GET /api/u/:universe_slug/s/:story_id/scene_tags/:id
  def show
    render json: scene_tag_json(@scene_tag)
  end

  private

    def set_story
      @story = Current.universe.stories.find(params.expect(:story_id))
    end

    def set_scene_tag
      @scene_tag = @story.scene_tags.find(params.expect(:id))
    end

    def scene_tag_json(scene_tag)
      {
        id: scene_tag.id,
        name: scene_tag.name,
        description: scene_tag.description,
        bgcolor: scene_tag.bgcolor,
        fgcolor: scene_tag.fgcolor,
        parent_id: scene_tag.parent_id,
        position: scene_tag.position,
        taggable: scene_tag.taggable
      }
    end
end
