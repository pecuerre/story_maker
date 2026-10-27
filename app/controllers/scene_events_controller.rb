# The Events a Scene depicts: its own ordered list of link rows.
#
# This is a real read page (guests and read-only members see it), while every
# mutation is JSON-only under the shared modal contract, exactly like the
# Characters, Items, and Locations tabs (ADR 0011). A Scene may depict several
# Events, and each link carries the author's own free-text role and a position
# that orders it inside this Scene.
class SceneEventsController < ApplicationController
  include MaintainsSiblingPositions
  include RequiresJsonMutationFormat
  include DraftMutation

  maintains_flat_positions_for :scene_event

  allow_unauthenticated_access only: %i[ index ]

  before_action :set_story
  before_action :set_scene
  before_action :set_scene_event, only: %i[ update destroy move ]
  before_action :require_json_mutation_format, only: %i[ create update destroy move ]

  # GET /u/:universe_slug/s/:story_id/scenes/:scene_id/events
  #
  # The rows are the Scene's own links in their own order, not the Universe's
  # Events. Every Universe Event is offered in the picker, because an Event is a
  # shared record and the same one can be depicted by several Scenes.
  def index
    @scene_tab = "events"
    @scene_events = @scene.scene_events.includes(:event).reorder(:position, :id).to_a
    @event_options = Current.universe.events
      .includes(:before_event, :after_event, :simultaneous_event)
      .reorder(:name, :id)
      .to_a
  end

  # POST /u/:universe_slug/s/:story_id/scenes/:scene_id/events
  #
  # The Event is resolved through the current Universe, so another universe's id
  # is a 404 rather than a cross-scope write. The model's own same-Universe rule
  # then covers every other caller, including direct model use.
  def create
    attributes = scene_event_params
    raise ActionController::ParameterMissing, :event_id unless attributes[:event_id].present?

    link = @scene.scene_events.new(event: Current.universe.events.find(attributes[:event_id]),
      role: attributes[:role])
    return if remember_draft_create(link, attributes)

    respond_to do |format|
      if create_with_sibling_position(link)
        format.json { render json: scene_event_json(link), status: :created }
      else
        format.json { render json: link.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH /u/:universe_slug/s/:story_id/scenes/:scene_id/events/:id
  #
  # Both the Event and the role are editable, because the editor offers both
  # controls and a control that looks editable but is ignored would be worse than
  # no control at all. Repointing a link at an Event the Scene already depicts is
  # the model's duplicate error rather than a second row.
  def update
    @scene_event.assign_attributes(editable_scene_event_attributes)
    # No attributes are passed: the link has already been assigned, and what the
    # live path would have written is the record's own pending change rather than
    # the submitted payload — a blank `event_id` means "keep the stored one" here,
    # and the resolved foreign key is the value that must be remembered.
    return if remember_draft_update(@scene_event)

    respond_to do |format|
      if @scene_event.save
        format.json { render json: scene_event_json(@scene_event), status: :ok }
      else
        format.json { render json: @scene_event.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH /u/:universe_slug/s/:story_id/scenes/:scene_id/events/:id/move
  #
  # The only way to reorder a Scene's Events. `position` is not a permitted form
  # field, so a save never rewrites it by accident.
  def move
    target = @scene_event.position + (move_direction == "up" ? -1 : 1)
    return if remember_draft_update(@scene_event, position: target)

    respond_to do |format|
      if update_with_sibling_position(@scene_event, position: target)
        format.json { render json: scene_event_json(@scene_event), status: :ok }
      else
        format.json { render json: @scene_event.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /u/:universe_slug/s/:story_id/scenes/:scene_id/events/:id
  #
  # Removing a depiction never removes the Event or the Scene: the link is its own
  # row, and the Scene keeps its narrative position and its own in-world time.
  def destroy
    return if remember_draft_delete(@scene_event)

    destroy_with_sibling_position(@scene_event)

    head :no_content
  end

  private

    def set_scene
      @scene = @story.scenes.find(params.expect(:scene_id))
    end

    # Loaded through the Scene association, so a link from another Scene, Story,
    # or Universe is a 404 rather than a cross-scope write.
    def set_scene_event
      @scene_event = @scene.scene_events.find(params.expect(:id))
    end

    def sibling_collection
      @scene.scene_events
    end

    def sibling_position_scope_owner
      @scene
    end

    def move_direction
      direction = params.expect(:direction)
      raise ActionController::ParameterMissing, :direction unless %w[ up down ].include?(direction)

      direction
    end

    def scene_event_params
      params.expect(scene_event: [ :event_id, :role ])
    end

    # An update may carry either field on its own, so a role-only edit never
    # clears the link and an event-only edit never clears the role. A blank Event
    # means "keep the current one". A payload with neither field is malformed
    # rather than a no-op that would look like a successful save.
    def editable_scene_event_attributes
      attributes = scene_event_params
      resolved = {}
      resolved[:role] = attributes[:role] if attributes.key?(:role)

      event_id = attributes[:event_id]
      resolved[:event] = Current.universe.events.find(event_id) if event_id.present?

      raise ActionController::BadRequest, "a scene event update must change the event or the role" if resolved.empty?

      resolved
    end

    def scene_event_json(link)
      {
        id: link.id,
        event_id: link.event_id,
        event_label: link.event.display_label,
        role: link.role,
        position: link.position,
        url: universe_story_scene_scene_event_path(story_id: @story, scene_id: @scene, id: link)
      }
    end
end
