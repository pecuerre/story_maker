class StoriesController < ApplicationController
  include PhotoParams
  include DraftMutation

  allow_unauthenticated_access only: %i[ index show ]

  before_action :set_story, only: %i[ show edit update destroy apply_structure ]

  # GET /u/:universe_slug/s
  def index
    @stories = Current.universe.stories.includes(:sections).order(:id)
  end

  # GET /u/:universe_slug/s/:id
  def show
    # One query for the section hierarchy, loaded once and reused for both the
    # tree preview and the recently-edited list below.
    @sections = @story.sections.order(:position, :id).to_a
    @recent_sections = @sections.sort_by { |section| section.updated_at || Time.zone.at(0) }.reverse.first(5)
    @story_tropes = @story.story_tropes.to_a
    # The structure card states the Story's whole prose total, grouped or not.
    @word_counts = WordCounts.for_story(@story)
    @story_structure_empty = @sections.empty? && !@story.scenes.exists?
    @story_structure_available = @story_structure_empty && Current.universe.direct?
    @story_structure_options = StoryStructureCatalog.entries if @story_structure_available
  end

  # GET /u/:universe_slug/s/new
  def new
    @story = Story.new(universe: Current.universe)
    @story.build_trope_assignments
  end

  # POST /u/:universe_slug/s
  def create
    attributes = story_params
    @story = Story.new(universe: Current.universe)
    @story.assign_attributes(attributes)
    return if remember_draft_create(@story, attributes)

    respond_to do |format|
      if @story.save
        format.html { redirect_to universe_story_path(id: @story), notice: t("stories.flash.created") }
      else
        @story.build_trope_assignments
        format.html { render :new, status: :unprocessable_content }
      end
    end
  end

  # GET /u/:universe_slug/s/:id/edit
  def edit
    @story.build_trope_assignments
  end

  # PATCH/PUT /u/:universe_slug/s/:id
  def update
    attributes = story_params
    return if remember_draft_update(@story, attributes)

    respond_to do |format|
      if @story.update(attributes)
        format.html { redirect_to universe_story_path(id: @story), notice: t("stories.flash.updated"), status: :see_other }
      else
        @story.build_trope_assignments
        format.html { render :edit, status: :unprocessable_content }
      end
    end
  end

  # POST /u/:universe_slug/s/:id/apply_structure
  #
  # Applies one code-owned structure to an empty Story. The catalogue is not a
  # record, so an unknown slug is a 404 like any other foreign reference, and
  # the guards below are the same answer the Story page uses to decide whether
  # to render the control at all.
  def apply_structure
    entry = StoryStructureCatalog.find(params.expect(:structure_slug))
    raise ActiveRecord::RecordNotFound, "Story structure not found" if entry.nil?

    if Current.universe.draft_based?
      redirect_to universe_story_path(id: @story), alert: t("stories.structures.flash.draft_based")
    elsif !structure_available?
      redirect_to universe_story_path(id: @story), alert: t("stories.structures.flash.not_empty")
    elsif StoryStructureApplier.call(@story, entry)
      redirect_to universe_story_path(id: @story),
        notice: t("stories.structures.flash.applied", name: t(entry.name_key))
    else
      redirect_to universe_story_path(id: @story), alert: t("stories.structures.flash.not_applied")
    end
  end

  # DELETE /u/:universe_slug/s/:id
  def destroy
    return if remember_draft_delete(@story)

    @story.soft_delete

    respond_to do |format|
      format.html { redirect_to universe_stories_path, notice: t("stories.flash.deleted"), status: :see_other }
    end
  end

  private

  # A template is a starting shape, so it is offered only while the Story has no
  # live Sections or Scenes. It is also refused in a draft-based universe: a
  # template is a batch of creates whose Scenes name Sections that do not exist
  # until the draft is applied, and a remembered change carries one record.
  def structure_available?
    Current.universe.direct? && !@story.sections.exists? && !@story.scenes.exists?
  end

  def story_params
    params.expect(story: [ *photo_params, :name, :description,
      { story_tropes_attributes: [ [ :id, :trope_slug, :selected, :context_note, :_destroy ] ] } ])
  end
end
