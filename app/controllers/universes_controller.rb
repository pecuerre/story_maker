class UniversesController < ApplicationController
  include PhotoParams

  allow_unauthenticated_access only: %i[ index show ]

  before_action :set_universe, only: %i[ show edit update destroy ]
  skip_before_action :set_current_universe, only: %i[ index ]
  skip_before_action :authorize_universe_access, only: %i[ index ]

  # GET /universes or /universes.json
  def index
    @universes = visible_universes
  end

  # GET /universes/1 or /universes/1.json
  # The page lists this universe's own stories, so entering a universe is one
  # click away from the story to work on: the top bar links straight here, which
  # makes it the place stories are switched and created. It reuses the memoized
  # story list (`nav_stories`) instead of loading them a second time, and
  # deliberately issues no COUNT query: the per-story section and scene counts are
  # already cached for the sidebar, so this page must not re-count every story.
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
        format.html { redirect_to @universe, notice: t("universes.flash.created") }
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
        format.html { redirect_to @universe, notice: t("universes.flash.updated"), status: :see_other }
        format.json { render :show, status: :ok, location: @universe }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @universe.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /universes/1 or /universes/1.json
  def destroy
    @universe.soft_delete

    respond_to do |format|
      format.html { redirect_to universes_path, notice: t("universes.flash.deleted"), status: :see_other }
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
  #
  # The form's address slug is optional, and a blank one means "derive it from
  # the name", not "clear it". Forwarding the empty string would make `HasSlug`
  # regenerate the slug on an *unrelated* save — toggling Private would silently
  # republish the universe under a new address and invalidate every path stored
  # below it — so a blank value is dropped and the attribute is never assigned.
  #
  # `collaboration_mode` needs no guard of its own: a value the model does not
  # accept is a field error rather than a silent fallback, and `update` is already
  # an admin-level action, so this parameter cannot change how a universe writes
  # for anyone but its owner or an administrator.
  def universe_params
    permitted = params.expect(universe: [ *photo_params, :name, :private, :slug, :collaboration_mode ])
    permitted.delete(:slug) if permitted[:slug].blank?
    permitted
  end
end
