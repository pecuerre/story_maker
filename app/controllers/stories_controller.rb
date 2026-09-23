class StoriesController < ApplicationController
  before_action :set_story, only: %i[ show edit update destroy ]

  # GET /u/:universe_slug/s
  def index
    @stories = Current.universe.stories.includes(:sections).order(:id)
  end

  # GET /u/:universe_slug/s/:id
  def show
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
        format.html { redirect_to universe_story_path(id: @story), notice: "Story was successfully created." }
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
        format.html { redirect_to universe_story_path(id: @story), notice: "Story was successfully updated.", status: :see_other }
      else
        format.html { render :edit, status: :unprocessable_content }
      end
    end
  end

  # DELETE /u/:universe_slug/s/:id
  def destroy
    @story.destroy!

    respond_to do |format|
      format.html { redirect_to universe_stories_path, notice: "Story was successfully destroyed.", status: :see_other }
    end
  end

  private

  def set_story
    @story = Current.universe.stories.find(params.expect(:id))
  end

  def story_params
    params.expect(story: [ :name, :description ])
  end
end
