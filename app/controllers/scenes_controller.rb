class ScenesController < ApplicationController
  allow_unauthenticated_access only: %i[ index show ]
  include MaintainsSiblingPositions
  maintains_flat_positions_for :scene

  MOVE_DIRECTIONS = %w[ up down ].freeze

  before_action :set_story
  before_action :set_scene, only: %i[ show edit update destroy move ]
  before_action :set_grouped_scene, only: %i[ group ]
  # `create` and `update` re-render the same editor, so they need the same
  # descriptors as `new` and `edit`.
  before_action :set_section_paths, only: %i[ index show new edit create update group ]
  before_action :set_event_options, only: %i[ show new edit create update ]

  # GET /u/:universe_slug/s/:story_id/scenes
  def index
    @scenes = @story.scenes.reorder(:position, :id).to_a
  end

  # GET /u/:universe_slug/s/:story_id/scenes/:id
  def show
    @scene_total = @story.scenes.count
    @scene_tab = "details"
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
    @scene_tab = "details"
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

  # PATCH /u/:universe_slug/s/:story_id/scenes/group
  #
  # The Section grouping workspace alternative to the Details form. It changes
  # only `section_id`; the narrative position is never touched here.
  def group
    assign_scene_group

    respond_to do |format|
      format.html do
        redirect_to universe_story_sections_path(story_id: @story), **group_flash, status: :see_other
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

  # The grouping form posts the chosen scene next to the chosen group, so the
  # scene is resolved by its own parameter rather than by the URL segment.
  def set_grouped_scene
    @scene = @story.scenes.find(params.expect(:scene_id))
  end

  # One ordered query per Story builds every ancestor path in memory, so neither
  # the list nor the form walks Section ancestors per Scene.
  def set_section_paths
    @section_paths = SectionPaths.build(@story.sections.reorder(:position, :id).to_a)
  end

  # Events are shared universe records. Their temporal references are preloaded
  # because `Event#display_string` can fall back to them for an option label.
  def set_event_options
    @event_options = Current.universe.events
      .includes(:before_event, :after_event, :simultaneous_event)
      .reorder(:name, :id)
      .to_a
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
    params.expect(scene: [ :name, :description, :section_id, :event_id, :datetime ])
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

  def assign_scene_group
    section = grouping_section

    update_with_sibling_position(@scene, section_id: section&.id)
  end

  # Resolved through the current Story, so another story's or another universe's
  # Section is a 404 rather than a cross-scope write.
  def grouping_section
    section_id = grouping_section_id
    return if section_id.nil?

    @story.sections.find(section_id)
  end

  # A blank group is the explicit "Ungrouped" choice, so the key is required but
  # its value may be empty. `params.expect` rejects a blank scalar, so key
  # presence is checked here instead and an absent key stays a bad request.
  def grouping_section_id
    raise ActionController::ParameterMissing, :section_id unless params.key?(:section_id)

    params[:section_id].presence
  end

  def group_flash
    return { alert: @scene.errors.full_messages.to_sentence } if @scene.errors.any?

    label = @section_paths.label_for(@scene.section_id)
    if label.present?
      { notice: "“#{@scene.name}” is now grouped under #{label}. Its narrative position did not change." }
    else
      { notice: "“#{@scene.name}” is now ungrouped. Its narrative position did not change." }
    end
  end
end
