class ScenesController < ApplicationController
  allow_unauthenticated_access only: %i[ index show ]
  include PhotoParams
  include MaintainsSiblingPositions
  maintains_flat_positions_for :scene

  MOVE_DIRECTIONS = %w[ up down ].freeze

  before_action :set_story
  before_action :set_scene, only: %i[ show edit update destroy move ]
  before_action :set_grouped_scene, only: %i[ group ]
  # The filter keys ride along with the index, and with the two mutations that
  # are performed from inside a filtered list.
  before_action :set_filter_query, only: %i[ index move destroy ]
  # `create` and `update` re-render the same editor, so they need the same
  # descriptors as `new` and `edit`.
  before_action :set_section_paths, only: %i[ index show new edit create update group ]
  before_action :set_event_options, only: %i[ show new edit create update ]
  before_action :set_scene_tag_data, only: %i[ index show new edit create update ]
  # Scene Details hosts the ordered Element list and its speaker picker.
  before_action :set_element_data, only: %i[ show ]

  # GET /u/:universe_slug/s/:story_id/scenes
  #
  # The list is always the Story's canonical narrative order. A filter narrows
  # what is shown and is visible in the URL; it never reorders, regroups, or
  # renumbers a scene, and the totals and sequence boundaries below still come
  # from the whole sequence.
  def index
    @scene_filter = SceneFilter.new(@filter_query, section_ids: @section_paths.ids, scene_tags: @scene_tags)
    # A GET form submits every field, so the ones the author left alone arrive
    # blank. Redirecting once to the canonical query keeps the address bar, a
    # bookmark, and a shared link limited to the filters really in effect.
    return redirect_to canonical_scenes_path, status: :found if blank_filter_values?

    @scenes = @scene_filter.apply(@story.scenes).includes(:scene_tags).to_a
    # One aggregate query answers the Story total shown by the position badges
    # and the real sequence boundaries, so a narrowed view never mistakes the
    # first visible row for the first scene of the Story.
    @scene_total, @first_position, @last_position = @story.scenes.pick(
      Arel.sql("COUNT(*)"), Arel.sql("MIN(position)"), Arel.sql("MAX(position)")
    )
    set_scene_listing_counts
    flash.now[:alert] = @scene_filter.discarded.to_sentence if @scene_filter.discarded.any?
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
        redirect_to filtered_scenes_path, **flash_message, status: :see_other
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
        redirect_to filtered_scenes_path,
          notice: "Scene was successfully destroyed.",
          status: :see_other
      end
    end
  end

  private

  # The recognized filter keys only. `slice` keeps the route, controller, and
  # action keys out, so permitting the rest cannot report anything the request
  # legitimately carries.
  def set_filter_query
    @filter_query = params.slice(*SceneFilter::PARAMS).permit(*SceneFilter::PARAMS)
  end

  # True when the request carried a filter key with no value, which is what a
  # plain form submission of the search area always looks like.
  def blank_filter_values?
    values = @filter_query.to_h
    values.compact_blank.size < values.size
  end

  # The canonical index URL for a set of filter values: only the recognized keys
  # that carry a value, so the address bar, a bookmark, and a shared link never
  # depend on how the search area was filled in.
  def scenes_path_with(query)
    path = universe_story_scenes_path(story_id: @story)

    query.any? ? "#{path}?#{query.to_query}" : path
  end

  def canonical_scenes_path
    scenes_path_with(@scene_filter.query_params)
  end

  # A list-embedded mutation returns to the same narrowed list when a filter is
  # in the URL, so reordering or deleting inside a filtered view does not dump
  # the author back on the full story. The index validates the values again.
  def filtered_scenes_path
    scenes_path_with(@filter_query.to_h.compact_blank)
  end

  def set_story
    @story = Current.universe.stories.find(params.expect(:story_id))
  end

  def set_scene
    @scene = @story.scenes.includes(:scene_tags).find(params.expect(:id))
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

  # Scene Tag definitions and their paths are story-scoped. One ordered tag
  # query serves the form and Details page; the Scenes list preloads each
  # Scene's tag association separately. The list filter keeps every tag, but
  # the assignment editor offers assignable tags only.
  def set_scene_tag_data
    @scene_tags = @story.scene_tags.order(:position, :id).to_a
    @taggable_scene_tags = @scene_tags.select(&:taggable)
    @scene_tag_paths = SceneTagPaths.build(@scene_tags)
  end

  # The ordered Element list and the speaker picker that fills a Dialogue. Both
  # are preloaded here: every row shows its Element's speakers, so a page that
  # queried per Element would be a query per row.
  def set_element_data
    @scene_elements = @scene.scene_elements.includes(:characters).reorder(:position, :id).to_a
    @element_total = @scene_elements.size
    @character_options = Current.universe.characters.reorder(:name, :id).to_a
  end

  # Two grouped queries answer both row counts for the whole list, once the rows
  # themselves are known. The participant count is the union of stored presence
  # links and derived speakers, so a Character who both participates and speaks is
  # counted once.
  def set_scene_listing_counts
    @element_counts = SceneElement.where(scene_id: @scenes.map(&:id)).group(:scene_id).count
    @participant_counts = SceneParticipants.counts_by_scene(@scenes)
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
    params.expect(scene: [ *photo_params, :name, :description, :section_id, :event_id, :datetime, { scene_tag_ids: [] } ])
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
