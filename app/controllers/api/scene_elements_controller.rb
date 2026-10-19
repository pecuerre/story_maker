# The API-surface counterpart of `SceneElementsController`: a scene_id-scoped
# index. Elements have no read action in the browser surface — they are read on
# Scene Details — so this index is the API's first read of them.
class Api::SceneElementsController < Api::BaseController
  before_action :set_story
  before_action :set_scene

  # GET /api/u/:universe_slug/s/:story_id/scenes/:scene_id/elements
  def index
    @scene_elements = @scene.scene_elements.reorder(:position, :id)
    render json: @scene_elements.map { |element| scene_element_json(element) }
  end

  private

    def set_story
      @story = Current.universe.stories.find(params.expect(:story_id))
    end

    def set_scene
      @scene = @story.scenes.find(params.expect(:scene_id))
    end

    def scene_element_json(element)
      {
        id: element.id,
        name: element.name,
        kind: element.kind,
        body: element.body,
        position: element.position,
        character_ids: element.character_ids
      }
    end
end
