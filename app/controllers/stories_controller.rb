class StoriesController < ApplicationController
  before_action :set_story, only: %i[ show edit update destroy ]
  allow_unauthenticated_access only: %i[index]
  skip_before_action :set_current_story, only: %i[index]

  # GET /stories or /stories.json
  def index
    @stories = visible_stories
  end

  # GET /stories/1 or /stories/1.json
  def show
  end

  # GET /stories/new
  def new
    @story = Story.new
  end

  # GET /stories/1/edit
  def edit
  end

  # POST /stories or /stories.json
  def create
    @story = Story.new(story_params)

    respond_to do |format|
      if @story.save
        format.html { redirect_to @story, notice: "Story was successfully created." }
        format.json { render :show, status: :created, location: @story }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @story.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /stories/1 or /stories/1.json
  def update
    respond_to do |format|
      if @story.update(story_params)
        format.html { redirect_to @story, notice: "Story was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @story }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @story.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /stories/1 or /stories/1.json
  def destroy
    @story.destroy!

    respond_to do |format|
      format.html { redirect_to stories_path, notice: "Story was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private

  def visible_stories
    scope = Story.all

    if authenticated?
      scope.where(private: false).or(scope.where(owner_id: Current.user.id))
    else
      scope.where(private: false)
    end
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_story
    @story = Story.find_by(slug: params.expect(:story_slug))
  end

  # Only allow a list of trusted parameters through.
  def story_params
    params.expect(story: [ :name ])
  end
end
