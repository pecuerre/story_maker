class ScenesController < ApplicationController
  allow_unauthenticated_access only: %i[ index show ]
  include MaintainsSiblingPositions
  maintains_flat_positions_for :scene

  MOVE_DIRECTIONS = %w[ up down ].freeze

  before_action :set_story
  before_action :set_scene, only: %i[ show edit update destroy move ]

  # GET /u/:universe_slug/s/:story_id/scenes
  def index
    @scenes = @story.scenes.reorder(:position, :id).to_a
  end

  # GET /u/:universe_slug/s/:story_id/scenes/:id
  def show
    @scene_total = @story.scenes.count
  end

  # GET /u/:universe_slug/s/:story_id/scenes/new
  def new
    @scene = @story.scenes.new
  end

  # POST /u/:universe_slug/s/:story_id/scenes
  def create
    @scene = @story.scenes.new(scene_params)

    respond_to do |format|
      if create_with_sibling_position(@scene)
        format.html do
          redirect_to universe_story_scene_path(story_id: @story, id: @scene),
            notice: "Scene was successfully created."
        end
      else
        format.html { render :new, status: :unprocessable_content }
      end
    end
  end

  # GET /u/:universe_slug/s/:story_id/scenes/:id/edit
  def edit
  end

  # PATCH/PUT /u/:universe_slug/s/:story_id/scenes/:id
  def update
    respond_to do |format|
      if update_with_sibling_position(@scene, scene_params)
        format.html do
          redirect_to universe_story_scene_path(story_id: @story, id: @scene),
            notice: "Scene was successfully updated.",
            status: :see_other
        end
      else
        format.html { render :edit, status: :unprocessable_content }
      end
    end
  end

  # PATCH /u/:universe_slug/s/:story_id/scenes/:id/move
  def move
    direction = move_direction
    original_position = @scene.position
    target_position = original_position + (direction == "up" ? -1 : 1)
    flash_message = move_flash(direction, original_position, target_position)

    respond_to do |format|
      format.html do
        redirect_to universe_story_scenes_path(story_id: @story), **flash_message, status: :see_other
      end
    end
  end

  # DELETE /u/:universe_slug/s/:story_id/scenes/:id
  def destroy
    destroy_with_sibling_position(@scene)

    respond_to do |format|
      format.html do
        redirect_to universe_story_scenes_path(story_id: @story),
          notice: "Scene was successfully destroyed.",
          status: :see_other
      end
    end
  end

  private

  def set_story
    @story = Current.universe.stories.find(params.expect(:story_id))
  end

  def set_scene
    @scene = @story.scenes.find(params.expect(:id))
  end

  # Scenes form one flat sequence inside their story, not a universe-level
  # collection and not a section hierarchy.
  def sibling_collection
    @story.scenes
  end

  def sibling_position_scope_owner
    @story
  end

  def scene_params
    params.expect(scene: [ :name, :description ])
  end

  def move_direction
    direction = params.expect(:direction)
    raise ActionController::ParameterMissing, :direction unless MOVE_DIRECTIONS.include?(direction)

    direction
  end

  # The service clamps the requested position to the group, so a move past a
  # sequence boundary is a deliberate no-op with its own copy rather than a
  # partial write. A validation failure is reported separately.
  def move_flash(direction, original_position, target_position)
    return { alert: "Scene could not be moved." } unless update_with_sibling_position(@scene, position: target_position)

    if @scene.reload.position == original_position
      if direction == "up"
        { alert: "This scene is already first in the narrative order." }
      else
        { alert: "This scene is already last in the narrative order." }
      end
    else
      { notice: "Scene was moved." }
    end
  end
end
