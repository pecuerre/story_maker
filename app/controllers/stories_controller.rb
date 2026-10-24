class StoriesController < ApplicationController
  include PhotoParams
  include DraftMutation

  allow_unauthenticated_access only: %i[ index show ]

  before_action :set_story, only: %i[ show edit update destroy ]

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

  # DELETE /u/:universe_slug/s/:id
  def destroy
    return if remember_draft_delete(@story)

    @story.soft_delete

    respond_to do |format|
      format.html { redirect_to universe_stories_path, notice: t("stories.flash.deleted"), status: :see_other }
    end
  end

  private

  def story_params
    params.expect(story: [ *photo_params, :name, :description,
      { story_tropes_attributes: [ [ :id, :trope_slug, :selected, :context_note, :_destroy ] ] } ])
  end
end
