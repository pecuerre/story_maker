# The API-surface counterpart of `ScenesController`: index and show as JSON.
# Scenes are story-scoped: a request reaches them through its story.
class Api::ScenesController < Api::BaseController
  before_action :set_story
  before_action :set_scene, only: %i[ show ]

  # GET /api/u/:universe_slug/s/:story_id/scenes
  def index
    @scenes = @story.scenes.reorder(:position, :id)
    render json: @scenes.map { |scene| scene_json(scene) }
  end

  # GET /api/u/:universe_slug/s/:story_id/scenes/:id
  def show
    render json: scene_json(@scene)
  end

  private

    def set_story
      @story = Current.universe.stories.find(params.expect(:story_id))
    end

    def set_scene
      @scene = @story.scenes.find(params.expect(:id))
    end

    def scene_json(scene)
      {
        id: scene.id,
        name: scene.name,
        description: scene.description,
        section_id: scene.section_id,
        event_id: scene.event_id,
        datetime: scene.datetime,
        position: scene.position,
        scene_tag_ids: scene.scene_tag_ids,
        slug: scene.slug
      }
    end
end
