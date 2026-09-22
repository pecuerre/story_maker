class UniversesController < ApplicationController
  before_action :set_universe, only: %i[ show edit update destroy ]
  allow_unauthenticated_access only: %i[index show new create edit update destroy]
  skip_before_action :set_current_universe, only: %i[index]

  # GET /universes or /universes.json
  def index
    @universes = visible_universes
  end

  # GET /universes/1 or /universes/1.json
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
    @universe = Universe.new(universe_params)
    @universe.owner = Current.user || User.first

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
    @universe = Universe.find_by(slug: params.expect(:universe_slug))
  end

  # Only allow a list of trusted parameters through.
  def universe_params
    params.expect(universe: [ :name ])
  end
end
