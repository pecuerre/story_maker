class TaxonomiesController < ApplicationController
  before_action :set_story, only: [ :index, :new, :create ]
  before_action :set_taxonomy, only: [ :show, :edit, :update, :destroy ]

  def index
    @taxonomies = @story.taxonomies
  end

  def show
    respond_to do |format|
      format.html
      format.json { render json: @taxonomy }
    end
  end

  def new
    @taxonomy = @story.taxonomies.build
  end

  def create
    @taxonomy = @story.taxonomies.build(taxonomy_params)

    if @taxonomy.save
      redirect_to story_taxonomy_path(@story, @taxonomy), notice: "Taxonomy was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @taxonomy.update(taxonomy_params)
      redirect_to story_taxonomy_path(@story, @taxonomy), notice: "Taxonomy was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

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
    params.require(:taxonomy).permit(:name, :description, :slug, :story_taxonomy, :setting_taxonomy)
  end
end
