class ScenesController < ApplicationController
  include PhotoParams
  include MaintainsSiblingPositions
  include DraftMutation
  include FilteredListQuery

  allow_unauthenticated_access only: %i[ index show ]
  maintains_flat_positions_for :scene

  MOVE_DIRECTIONS = %w[ up down ].freeze

  # The filter keys ride along with the index, and with the two mutations that
  # are performed from inside a filtered list.
  filters_list_with SceneFilter, only: %i[ index move destroy ]

  before_action :set_story
  before_action :set_scene, only: %i[ show edit update destroy move ]
  before_action :set_grouped_scene, only: %i[ group ]
  # `create` and `update` re-render the same editor, so they need the same
  # descriptors as `new` and `edit`.
  before_action :set_section_paths, only: %i[ index show new edit create update group ]
  before_action :set_character_options, only: %i[ new edit create update ]
  before_action :set_scene_tag_data, only: %i[ index show new edit create update ]
  before_action :set_plot_options, only: %i[ show new edit create update ]
  # Scene Details hosts the ordered Element list and its speaker picker.
  before_action :set_element_data, only: %i[ show ]

  # GET /u/:universe_slug/s/:story_id/scenes
  #
  # The list is always the Story's canonical narrative order. A filter narrows
  # what is shown and is visible in the URL; it never reorders, regroups, or
  # renumbers a scene, and the totals and sequence boundaries below still come
  # from the whole sequence.
  def index
    @list_filter = SceneFilter.new(@filter_query, section_ids: @section_paths.ids, scene_tags: @scene_tags)
    # A GET form submits every field, so the ones the author left alone arrive
    # blank. Redirecting once to the canonical query keeps the address bar, a
    # bookmark, and a shared link limited to the filters really in effect.
    return redirect_to_canonical_filtered_list if blank_filter_values?

    @scenes = @list_filter.apply(@story.scenes).includes(:scene_tags).to_a
    # One aggregate query answers the Story total shown by the position badges
    # and the real sequence boundaries, so a narrowed view never mistakes the
    # first visible row for the first scene of the Story.
    @scene_total, @first_position, @last_position = @story.scenes.pick(
      Arel.sql("COUNT(*)"), Arel.sql("MIN(position)"), Arel.sql("MAX(position)")
    )
    set_scene_listing_counts
    flash_discarded_filter_values
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
    attributes = scene_params
    @scene = @story.scenes.new(attributes)
    return if remember_draft_create(@scene, attributes)

    respond_to do |format|
      if create_with_sibling_position(@scene)
        format.html do
          redirect_to universe_story_scene_path(story_id: @story, id: @scene),
            notice: t("scenes.flash.created")
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
    attributes = scene_params
    return if remember_draft_update(@scene, attributes)

    respond_to do |format|
      if update_with_sibling_position(@scene, attributes)
        format.html do
          redirect_to universe_story_scene_path(story_id: @story, id: @scene),
            notice: t("scenes.flash.updated"),
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
    return if remember_draft_update(@scene, position: target_position)

    flash_message = move_flash(direction, original_position, target_position)

    respond_to do |format|
      format.html do
        redirect_to filtered_list_path, **flash_message, status: :see_other
      end
    end
  end

  # PATCH /u/:universe_slug/s/:story_id/scenes/group
  #
  # The Section grouping workspace alternative to the Details form. It changes
  # only `section_id`; the narrative position is never touched here.
  #
  # The chosen Section is resolved *before* the change is remembered, so a foreign
  # or unknown group is still a 404 rather than something a draft would carry.
  def group
    section = grouping_section
    return if remember_draft_update(@scene, section_id: section&.id)

    assign_scene_group(section)

    respond_to do |format|
      format.html do
        redirect_to universe_story_sections_path(story_id: @story), **group_flash, status: :see_other
      end
    end
  end

  # DELETE /u/:universe_slug/s/:story_id/scenes/:id
  def destroy
    return if remember_draft_delete(@scene)

    destroy_with_sibling_position(@scene)

    respond_to do |format|
      format.html do
        redirect_to filtered_list_path,
          notice: t("scenes.flash.deleted"),
          status: :see_other
      end
    end
  end

  private

  # The canonical index URL for a set of filter values. `FilteredListQuery` owns
  # everything else about reading and carrying the filter, and this is the one
  # thing it cannot know: where this list's own URL is.
  def filtered_list_path_with(query)
    path = universe_story_scenes_path(story_id: @story)

    query.any? ? "#{path}?#{query.to_query}" : path
  end

  def set_scene
    @scene = @story.scenes.includes(:scene_tags, :scene_tropes, :pov_character).find(params.expect(:id))
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

  # Every universe character can present a scene, so the selector offers them
  # all. A blank choice records no point of view.
  def set_character_options
    @character_options = Current.universe.characters.reorder(:name, :id).to_a
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

  def set_plot_options
    @plot_options = @story.plots.order(:name, :id).to_a
  end

  # The ordered Element list and the speaker picker that fills a Dialogue. Both
  # are preloaded here: every row shows its Element's speakers, so a page that
  # queried per Element would be a query per row.
  def set_element_data
    @scene_elements = @scene.scene_elements.includes(:characters, scene_dialogue_turns: :speaker)
      .reorder(:position, :id).to_a
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
    params.expect(scene: [ *photo_params, :name, :description, :section_id, :datetime, :pov_character_id,
      { scene_tag_ids: [], plot_ids: [] } ])
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
    return { alert: t("scenes.flash.move_failed") } unless update_with_sibling_position(@scene, position: target_position)

    if @scene.reload.position == original_position
      if direction == "up"
        { alert: t("scenes.flash.already_first") }
      else
        { alert: t("scenes.flash.already_last") }
      end
    else
      { notice: t("scenes.flash.moved") }
    end
  end

  def assign_scene_group(section)
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

  # The ungrouped branch names the group through `SectionPaths`, so the flash and
  # the Section selector call it the same word. The scene's own name is the
  # author's record name and is interpolated, never translated.
  def group_flash
    return { alert: @scene.errors.full_messages.to_sentence } if @scene.errors.any?

    label = @section_paths.label_for(@scene.section_id)
    if label.present?
      { notice: t("scenes.flash.grouped", name: @scene.name, grouping: label) }
    else
      { notice: t("scenes.flash.ungrouped", name: @scene.name) }
    end
  end
end
