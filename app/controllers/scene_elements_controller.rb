# Scene Elements are the ordered prose blocks of a Scene. They are read on Scene
# Details, so this controller has no read action of its own: every action is a
# mutation, which means every action requires a session and the shared Universe
# write policy, and none of them may be reached with an HTML request.
#
# Positions are maintained by the shared flat-ordering service with the Scene as
# the scope owner, so an Element sequence is contiguous and independent of the
# Scene's own narrative position in its Story.
class SceneElementsController < ApplicationController
  include MaintainsSiblingPositions
  include RequiresJsonMutationFormat

  maintains_flat_positions_for :scene_element

  MOVE_DIRECTIONS = %w[ up down ].freeze

  before_action :set_story
  before_action :set_scene
  before_action :set_scene_element, only: %i[ update destroy move ]
  before_action :require_json_mutation_format, only: %i[ create update destroy move ]

  # POST /u/:universe_slug/s/:story_id/scenes/:scene_id/elements
  #
  # A new Element is appended to the Scene's sequence. `position` is not
  # permitted: the only way to order Elements is the Move controls, so a form
  # can never renumber the sequence behind the author's back.
  def create
    @scene_element = @scene.scene_elements.new(scene_element_attributes)

    respond_to do |format|
      if create_with_sibling_position(@scene_element)
        format.json { render json: scene_element_json, status: :created }
      else
        format.json { render json: @scene_element.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH /u/:universe_slug/s/:story_id/scenes/:scene_id/elements/:id
  #
  # Changing a Dialogue to Narration is refused while speakers remain, so the
  # modal asks for an explicit confirmation and sends an empty speaker list in
  # the same request. `remove_speakers` is that confirmation; without it the
  # stored speakers are simply left alone.
  def update
    respond_to do |format|
      if update_with_sibling_position(@scene_element, scene_element_attributes)
        format.json { render json: scene_element_json, status: :ok }
      else
        format.json { render json: @scene_element.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH /u/:universe_slug/s/:story_id/scenes/:scene_id/elements/:id/move
  #
  # A move past either end of the sequence is a deliberate no-op: the service
  # clamps the requested position to the group, and the view disables the
  # control there, so nothing partial is ever written.
  def move
    target = @scene_element.position + (move_direction == "up" ? -1 : 1)

    respond_to do |format|
      if update_with_sibling_position(@scene_element, position: target)
        format.json { render json: scene_element_json, status: :ok }
      else
        format.json { render json: @scene_element.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /u/:universe_slug/s/:story_id/scenes/:scene_id/elements/:id
  def destroy
    destroy_with_sibling_position(@scene_element)

    head :no_content
  end

  private

  def set_story
    @story = Current.universe.stories.find(params.expect(:story_id))
  end

  def set_scene
    @scene = @story.scenes.find(params.expect(:scene_id))
  end

  # Loaded through the Scene association, so an Element of another Scene, Story,
  # or Universe is a 404 rather than a cross-scope write.
  def set_scene_element
    @scene_element = @scene.scene_elements.find(params.expect(:id))
  end

  # Elements form one flat sequence inside their Scene.
  def sibling_collection
    @scene.scene_elements
  end

  def sibling_position_scope_owner
    @scene
  end

  def move_direction
    direction = params.expect(:direction)
    raise ActionController::ParameterMissing, :direction unless MOVE_DIRECTIONS.include?(direction)

    direction
  end

  def scene_element_params
    params.expect(scene_element: [ :kind, :name, :body, :remove_speakers, { character_ids: [] } ])
  end

  def scene_element_attributes
    attributes = scene_element_params.except(:remove_speakers)
    # The confirmation is only a confirmation: without it the request never
    # mentions the speakers and the stored ones survive.
    attributes[:character_ids] = [] if scene_element_params[:remove_speakers] == "1"
    attributes
  end

  def scene_element_json
    {
      id: @scene_element.id,
      name: @scene_element.name,
      kind: @scene_element.kind,
      body: @scene_element.body,
      position: @scene_element.position,
      character_ids: @scene_element.character_ids,
      url: universe_story_scene_scene_element_path(story_id: @story, scene_id: @scene, id: @scene_element)
    }
  end
end
