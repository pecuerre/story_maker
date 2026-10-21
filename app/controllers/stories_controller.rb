class StoriesController < ApplicationController
  include PhotoParams

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
  end

  # GET /u/:universe_slug/s/new
  def new
    @story = Story.new(universe: Current.universe)
  end

  # POST /u/:universe_slug/s
  def create
    @story = Story.new(universe: Current.universe)
    @story.assign_attributes(story_params)

    respond_to do |format|
      if @story.save
        format.html { redirect_to universe_story_path(id: @story), notice: t("stories.flash.created") }
      else
        format.html { render :new, status: :unprocessable_content }
      end
    end
  end

  # GET /u/:universe_slug/s/:id/edit
  def edit
  end

  # PATCH/PUT /u/:universe_slug/s/:id
  def update
    respond_to do |format|
      if @story.update(story_params)
        format.html { redirect_to universe_story_path(id: @story), notice: t("stories.flash.updated"), status: :see_other }
      else
        format.html { render :edit, status: :unprocessable_content }
      end
    end
  end

  # DELETE /u/:universe_slug/s/:id
  def destroy
    @story.soft_delete

    respond_to do |format|
      format.html { redirect_to universe_stories_path, notice: t("stories.flash.deleted"), status: :see_other }
    end
  end

  private

  def story_params
    params.expect(story: [ *photo_params, :name, :description ])
  end
end
