# Dialogue turns are the spoken lines inside a Dialogue Scene Element. They are a
# component of their Element — ordered, scene-scoped through the element, and never
# addressed on their own URL. Every action is a JSON mutation the shared modal
# submits, so every action requires a session and the shared Universe write
# policy, and none of them may be reached with an HTML request.
#
# Positions are maintained by the shared flat-ordering service with the Scene
# Element as the scope owner, so a turn sequence is contiguous and independent of
# its Element's position in its Scene.
class SceneDialogueTurnsController < ApplicationController
  include MaintainsSiblingPositions
  include RequiresJsonMutationFormat
  include DraftMutation

  maintains_flat_positions_for :scene_dialogue_turn

  before_action :set_story
  before_action :set_scene
  before_action :set_scene_element
  before_action :set_scene_dialogue_turn, only: %i[ update destroy move ]
  before_action :require_json_mutation_format, only: %i[ create update destroy move ]

  # POST /u/:universe_slug/s/:story_id/scenes/:scene_id/elements/:scene_element_id/dialogue_turns
  #
  # A new turn is appended to the Element's sequence. `position` is not
  # permitted: the only way to order turns is the Move controls.
  def create
    attributes = scene_dialogue_turn_params
    @scene_dialogue_turn = @scene_element.scene_dialogue_turns.new(attributes)
    return if remember_draft_create(@scene_dialogue_turn, attributes)

    respond_to do |format|
      if create_with_sibling_position(@scene_dialogue_turn)
        format.json { render json: scene_dialogue_turn_json, status: :created }
      else
        format.json { render json: @scene_dialogue_turn.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH /u/:universe_slug/s/:story_id/scenes/:scene_id/elements/:scene_element_id/dialogue_turns/:id
  def update
    attributes = scene_dialogue_turn_params
    return if remember_draft_update(@scene_dialogue_turn, attributes)

    respond_to do |format|
      if update_with_sibling_position(@scene_dialogue_turn, attributes)
        format.json { render json: scene_dialogue_turn_json, status: :ok }
      else
        format.json { render json: @scene_dialogue_turn.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH /u/:universe_slug/s/:story_id/scenes/:scene_id/elements/:scene_element_id/dialogue_turns/:id/move
  def move
    target = @scene_dialogue_turn.position + (move_direction == "up" ? -1 : 1)
    return if remember_draft_update(@scene_dialogue_turn, position: target)

    respond_to do |format|
      if update_with_sibling_position(@scene_dialogue_turn, position: target)
        format.json { render json: scene_dialogue_turn_json, status: :ok }
      else
        format.json { render json: @scene_dialogue_turn.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /u/:universe_slug/s/:story_id/scenes/:scene_id/elements/:scene_element_id/dialogue_turns/:id
  def destroy
    return if remember_draft_delete(@scene_dialogue_turn)

    destroy_with_sibling_position(@scene_dialogue_turn)

    head :no_content
  end

  private

  def set_scene
    @scene = @story.scenes.find(params.expect(:scene_id))
  end

  def set_scene_element
    @scene_element = @scene.scene_elements.find(params.expect(:scene_element_id))
  end

  # Loaded through the Element association, so a turn from another Element,
  # Scene, Story, or Universe is a 404 rather than a cross-scope write.
  def set_scene_dialogue_turn
    @scene_dialogue_turn = @scene_element.scene_dialogue_turns.find(params.expect(:id))
  end

  def sibling_collection
    @scene_element.scene_dialogue_turns
  end

  def sibling_position_scope_owner
    @scene_element
  end

  def move_direction
    direction = params.expect(:direction)
    raise ActionController::ParameterMissing, :direction unless %w[ up down ].include?(direction)

    direction
  end

  def scene_dialogue_turn_params
    params.expect(scene_dialogue_turn: [ :speaker_id, :body, :parenthetical ])
  end

  def scene_dialogue_turn_json
    helpers.scene_dialogue_turn_fields(@scene_dialogue_turn)
  end
end
