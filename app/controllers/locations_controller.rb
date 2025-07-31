class LocationsController < ApplicationController
  before_action :set_location, only: %i[ show edit update destroy ]
  before_action :set_story
  before_action :set_parent_locations, only: %i[new edit create update]

  # GET /stories/:story_id/locations
  def index
    @locations = Location.all.where(story_id: @story.id)
  end

  # GET /stories/:story_id/locations/:id
  def show
  end

  # GET /stories/:story_id/locations/new
  def new
    @location = Location.new
  end

  # GET /stories/:story_id/locations/:id/edit
  def edit
  end

  # POST /stories/:story_id/locations
  def create
    @location = Location.new(location_params)

    respond_to do |format|
      if @location.save
        format.html { redirect_to story_locations_path(@story), notice: "Location was successfully created." }
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /stories/:story_id/locations/:id
  def update
    respond_to do |format|
      if @location.update(location_params)
        format.html { redirect_to story_locations_path(@story), notice: "Location was successfully updated." }
      else
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /stories/:story_id/locations/:id
  def destroy
    @location.destroy!

    respond_to do |format|
      format.html { redirect_to locations_path, status: :see_other, notice: "Location was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    def set_location
      @location = Location.find(params.expect(:id))
    end

    def set_parent_locations
      @parent_locations = Location.where(story_id: @story.id)
      @parent_locations = @parent_locations.where.not(id: @location.id) if @location.present?
      @parent_locations = @parent_locations.pluck(:name, :id)
      @parent_locations.unshift([ "Select Parent Location", nil ]) # Add a placeholder option
    end

    # Only allow a list of trusted parameters through.
    def location_params
      params.expect(location: [ :name, :description, :story_id, :location_type_id, :parent_id ])
    end
end
