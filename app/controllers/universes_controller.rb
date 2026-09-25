class UniversesController < ApplicationController
  before_action :set_universe, only: %i[ show edit update destroy ]
  allow_unauthenticated_access only: %i[ index show ]
  skip_before_action :set_current_universe, only: %i[ index ]
  skip_before_action :authorize_universe_access, only: %i[ index ]

  # GET /universes or /universes.json
  def index
    @universes = visible_universes
  end

  # GET /universes/1 or /universes/1.json
  # The page lists this universe's own stories, so entering a universe is one
  # click away from the story to work on. It reuses the navbar's memoized story
  # list (`nav_stories`) instead of loading them a second time, and deliberately
  # issues no COUNT query: the per-story section and scene counts are already
  # cached for the sidebar, so this page must not re-count every story.
  def show
  end

  # GET /universes/new
  def new
    @universe = Universe.new
  end

  # GET /universes/1/edit
  def edit
  end

  # POST /universes or /universes.json
  def create
    authorize! :create, Universe
    @universe = Universe.new(universe_params)
    @universe.owner = Current.user

    respond_to do |format|
      if @universe.save
        format.html { redirect_to @universe, notice: "Universe was successfully created." }
        format.json { render :show, status: :created, location: @universe }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @universe.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /universes/1 or /universes/1.json
  def update
    respond_to do |format|
      if @universe.update(universe_params)
        format.html { redirect_to @universe, notice: "Universe was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @universe }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @universe.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /universes/1 or /universes/1.json
  def destroy
    @universe.destroy!

    respond_to do |format|
      format.html { redirect_to universes_path, notice: "Universe was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private

  def visible_universes
    Universe.visible_to(Current.user)
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_universe
    @universe = Universe.find_by!(slug: params.expect(:universe_slug))
  end

  # Only allow a list of trusted parameters through.
  def universe_params
    params.expect(universe: [ :name, :private ])
  end
end
