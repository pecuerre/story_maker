# The API-surface counterpart of `ScenesController`: index, show, and the
# mutations, all of them JSON. Scenes are story-scoped: a request reaches them
# through its story. A mutation in a draft-based universe is remembered (`202`)
# instead of written; both demo universes are `direct`, so it is invisible
# locally and only appears in production.
class Api::ScenesController < Api::BaseController
  include RequiresJsonMutationFormat
  include DraftMutation
  include MaintainsSiblingPositions

  before_action :set_story
  before_action :set_scene, only: %i[ show update destroy move ]
  before_action :set_grouped_scene, only: %i[ group ]
  before_action :require_json_mutation_format, only: %i[ create update destroy move group ]

  maintains_flat_positions_for :scene

  MOVE_DIRECTIONS = %w[ up down ].freeze

  # GET /api/u/:universe_slug/s/:story_id/scenes
  def index
    @scenes = @story.scenes.includes(:scene_events).reorder(:position, :id)
    render json: @scenes.map { |scene| scene_json(scene) }
  end

  # GET /api/u/:universe_slug/s/:story_id/scenes/:id
  def show
    render json: scene_json(@scene)
  end

  # POST /api/u/:universe_slug/s/:story_id/scenes
  def create
    attributes = scene_params
    @scene = @story.scenes.new(attributes)
    return if remember_draft_create(@scene, attributes)

    if create_with_sibling_position(@scene)
      render json: scene_json(@scene), status: :created
    else
      render json: @scene.errors, status: :unprocessable_content
    end
  end

  # PATCH /api/u/:universe_slug/s/:story_id/scenes/:id
  def update
    attributes = scene_params
    return if remember_draft_update(@scene, attributes)

    if update_with_sibling_position(@scene, attributes)
      render json: scene_json(@scene)
    else
      render json: @scene.errors, status: :unprocessable_content
    end
  end

  # DELETE /api/u/:universe_slug/s/:story_id/scenes/:id
  def destroy
    return if remember_draft_delete(@scene)

    destroy_with_sibling_position(@scene)
    head :no_content
  end

  # PATCH /api/u/:universe_slug/s/:story_id/scenes/:id/move
  def move
    direction = move_direction
    original_position = @scene.position
    target_position = original_position + (direction == "up" ? -1 : 1)
    return if remember_draft_update(@scene, position: target_position)

    if update_with_sibling_position(@scene, position: target_position)
      if @scene.reload.position == original_position
        alert = direction == "up" ? t("scenes.flash.already_first") : t("scenes.flash.already_last")
        render json: scene_json(@scene).merge(alert: alert)
      else
        render json: scene_json(@scene).merge(notice: t("scenes.flash.moved"))
      end
    else
      render json: { alert: t("scenes.flash.move_failed") }, status: :unprocessable_content
    end
  end

  # PATCH /api/u/:universe_slug/s/:story_id/scenes/group
  def group
    section = grouping_section
    return if remember_draft_update(@scene, section_id: section&.id)

    assign_scene_group(section)

    if @scene.errors.any?
      render json: { alert: @scene.errors.full_messages.to_sentence }, status: :unprocessable_content
    elsif section
      render json: scene_json(@scene).merge(
        notice: t("scenes.flash.grouped", name: @scene.name, grouping: section.name))
    else
      render json: scene_json(@scene).merge(notice: t("scenes.flash.ungrouped", name: @scene.name))
    end
  end

  private

    def set_story
      @story = Current.universe.stories.find(params.expect(:story_id))
    end

    def set_scene
      @scene = @story.scenes.find(params.expect(:id))
    end

    def set_grouped_scene
      @scene = @story.scenes.find(params.expect(:scene_id))
    end

    def scene_json(scene)
      {
        id: scene.id,
        name: scene.name,
        description: scene.description,
        status: scene.status,
        section_id: scene.section_id,
        events: scene.scene_events.sort_by { |link| [ link.position, link.id ] }.map do |link|
          { event_id: link.event_id, role: link.role, position: link.position }
        end,
        pov_character_id: scene.pov_character_id,
        datetime: scene.datetime,
        position: scene.position,
        scene_tag_ids: scene.scene_tag_ids,
        slug: scene.slug
      }
    end

    # Scenes are one flat sequence inside their story, not a universe-level
    # collection and not a section hierarchy.
    def sibling_collection
      @story.scenes
    end

    def sibling_position_scope_owner
      @story
    end

    def scene_params
      params.expect(scene: [ :name, :description, :status, :section_id, :datetime, :pov_character_id, { scene_tag_ids: [] } ])
    end

    def move_direction
      direction = params.expect(:direction)
      raise ActionController::ParameterMissing, :direction unless MOVE_DIRECTIONS.include?(direction)

      direction
    end

    # A blank group is the explicit "Ungrouped" choice, so the key is required
    # but its value may be empty. `params.expect` rejects a blank scalar, so key
    # presence is checked here instead and an absent key stays a bad request.
    def grouping_section
      raise ActionController::ParameterMissing, :section_id unless params.key?(:section_id)

      section_id = params[:section_id].presence
      return if section_id.nil?

      # Resolved through the current Story, so another story's or another
      # universe's Section is a 404 rather than a cross-scope write.
      @story.sections.find(section_id)
    end

    def assign_scene_group(section)
      update_with_sibling_position(@scene, section_id: section&.id)
    end
end
