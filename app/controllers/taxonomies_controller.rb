class TaxonomiesController < ApplicationController
  before_action :set_taxonomy, only: [ :show, :edit, :update, :destroy ]

  def index
    @taxonomies = Taxonomy.all
  end

  def show
    respond_to do |format|
      format.html
      format.json { render json: @taxonomy }
    end
  end

  def new
    @taxonomy = Taxonomy.new
  end

  def create
    @taxonomy = Taxonomy.new(taxonomy_params)

    if @taxonomy.save
      redirect_to @taxonomy, notice: "Taxonomy was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @taxonomy.update(taxonomy_params)
      redirect_to @taxonomy, notice: "Taxonomy was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @taxonomy.fixed?
      redirect_to @taxonomy, alert: "Cannot delete a fixed taxonomy."
    else
      @taxonomy.destroy
      redirect_to taxonomies_url, notice: "Taxonomy was successfully deleted."
    end
  end

  private

  def set_taxonomy
    @taxonomy = Taxonomy.find_by!(slug: params[:slug])
  end

  def taxonomy_params
    params.require(:taxonomy).permit(:name, :description, :slug, :fixed)
  end
end
