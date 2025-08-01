class TaxonomiesController < ApplicationController
  before_action :set_story, only: [ :index, :new, :create ]
  before_action :set_taxonomy, only: [ :show, :edit, :update, :destroy ]

  # GET /stories/:story_id/t
  def index
    @taxonomies = @story.taxonomies
  end

  # GET /stories/:story_id/t/:slug
  def show
    respond_to do |format|
      format.html
      format.json { render json: @taxonomy }
    end
  end

  # GET /stories/:story_id/t/new
  def new
    @taxonomy = @story.taxonomies.build
  end

  # GET /stories/:story_id/t/:slug/edit
  def create
    @taxonomy = @story.taxonomies.build(taxonomy_params)

    if @taxonomy.save
      redirect_to story_taxonomy_path(@story, @taxonomy), notice: "Taxonomy was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # GET /stories/:story_id/t/:slug/edit
  def edit
  end

  # PATCH/PUT /stories/:story_id/t/:slug
  def update
    if @taxonomy.update(taxonomy_params)
      redirect_to story_taxonomy_path(@story, @taxonomy), notice: "Taxonomy was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /stories/:story_id/t/:slug
  def destroy
    if @taxonomy.fixed?
      redirect_to story_taxonomy_path(@story, @taxonomy), alert: "Cannot delete a fixed taxonomy."
    else
      @taxonomy.destroy
      redirect_to story_taxonomies_path(@story), notice: "Taxonomy was successfully deleted."
    end
  end

  private

  def set_story
    @story = Story.find(params[:story_id])
  end

  def set_taxonomy
    @story = Story.find(params[:story_id])
    @taxonomy = @story.taxonomies.find_by!(slug: params[:slug])
  end

  def taxonomy_params
    params.require(:taxonomy).permit(:name, :description, :slug, :is_story_taxonomy, :is_setting_taxonomy)
  end
end
