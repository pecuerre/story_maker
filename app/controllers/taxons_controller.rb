class TaxonsController < ApplicationController
  before_action :set_story, if: -> { params[:story_id].present? }
  before_action :set_taxonomy, if: -> { params[:taxonomy_slug].present? }
  before_action :set_taxon, only: [ :show, :edit, :update, :destroy ]

  # GET /stories/:story_id/t/:slug/taxons
  def index
    @taxons = if @taxonomy
      @taxonomy.taxons.roots.includes(:children)
    else
      Taxon.roots.includes(:taxonomy, :children)
    end

    respond_to do |format|
      format.html
      format.json { render json: serialize_taxons(@taxons) }
    end
  end

  # GET /stories/:story_id/t/:slug/taxons/:id
  def new
    @taxon = if @taxonomy
      @taxonomy.taxons.build
    else
      Taxon.new
    end
    @parent_taxons = available_parent_taxons
  end

  # POST /stories/:story_id/t/:slug/taxons/:id
  def create
    @taxon = if @taxonomy
      @taxonomy.taxons.build(taxon_params)
    else
      Taxon.new(taxon_params)
    end

    if @taxon.save
      respond_to do |format|
        format.html { redirect_to story_taxonomy_taxons_path(@story, @taxonomy), notice: "Taxon was successfully created." }
        format.json { render json: @taxon, status: :created }
      end
    else
      @parent_taxons = available_parent_taxons
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @taxon.errors, status: :unprocessable_entity }
      end
    end
  end

  # GET /stories/:story_id/t/:slug/taxons/:id/edit
  def edit
    @parent_taxons = available_parent_taxons
  end

  # PATCH/PUT /stories/:story_id/t/:slug/taxons/:id
  def update
    if @taxon.update(taxon_params)
      respond_to do |format|
        format.html { redirect_to story_taxonomy_taxons_path(@story, @taxonomy), notice: "Taxon was successfully updated." }
        format.json { render json: @taxon }
      end
    else
      @parent_taxons = available_parent_taxons
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @taxon.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /stories/:story_id/t/:slug/taxons/:id
  def destroy
    if @taxon.root? && @taxon.taxonomy.fixed?
      respond_to do |format|
        format.html { redirect_to story_taxonomy_taxons_path(@story, @taxonomy), alert: "Cannot delete the root taxon of a fixed taxonomy." }
        format.json { render json: { error: "Cannot delete the root taxon of a fixed taxonomy." }, status: :unprocessable_entity }
      end
    else
      @taxon.destroy
      respond_to do |format|
        format.html { redirect_to story_taxonomy_taxons_path(@story, @taxonomy), notice: "Taxon was successfully deleted." }
        format.json { head :no_content }
      end
    end
  end

  private

  def set_story
    @story = Story.find(params[:story_id])
  end

  def set_taxonomy
    if @story
      @taxonomy = @story.taxonomies.find_by!(slug: params[:taxonomy_slug])
    else
      @taxonomy = Taxonomy.find_by!(slug: params[:taxonomy_slug])
    end
  end

  def set_taxon
    @taxon = if @taxonomy
      @taxonomy.taxons.find(params[:id])
    else
      Taxon.find(params[:id])
    end
  end

  def available_parent_taxons
    if @taxonomy
      @taxonomy.taxons.where.not(id: @taxon&.id).where.not(id: @taxon&.descendants&.pluck(:id))
    else
      Taxon.where.not(id: @taxon&.id).where.not(id: @taxon&.descendants&.pluck(:id))
    end
  end

  def taxon_params
    params.require(:taxon).permit(:name, :parent_id)
  end

  def serialize_taxons(taxons)
    taxons.map do |taxon|
      {
        id: taxon.id,
        name: taxon.name,
        parent_id: taxon.parent_id,
        taxonomy_id: taxon.taxonomy_id,
        children: serialize_taxons(taxon.children)
      }
    end
  end
end
