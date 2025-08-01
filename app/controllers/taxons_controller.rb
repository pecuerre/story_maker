class TaxonsController < ApplicationController
  before_action :set_taxonomy, if: -> { params[:taxonomy_id].present? }
  before_action :set_taxon, only: [ :show, :edit, :update, :destroy ]

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

  def show
  end

  def new
    @taxon = if @taxonomy
               @taxonomy.taxons.build
    else
               Taxon.new
    end
    @parent_taxons = available_parent_taxons
  end

  def create
    @taxon = if @taxonomy
               @taxonomy.taxons.build(taxon_params)
    else
               Taxon.new(taxon_params)
    end

    if @taxon.save
      respond_to do |format|
        format.html { redirect_to @taxonomy || @taxon, notice: "Taxon was successfully created." }
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

  def edit
    @parent_taxons = available_parent_taxons
  end

  def update
    if @taxon.update(taxon_params)
      respond_to do |format|
        format.html { redirect_to @taxonomy || @taxon, notice: "Taxon was successfully updated." }
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

  def destroy
    if @taxon.root? && @taxon.taxonomy.fixed?
      respond_to do |format|
        format.html { redirect_to @taxonomy || @taxon, alert: "Cannot delete the root taxon of a fixed taxonomy." }
        format.json { render json: { error: "Cannot delete the root taxon of a fixed taxonomy." }, status: :unprocessable_entity }
      end
    else
      @taxon.destroy
      respond_to do |format|
        format.html { redirect_to @taxonomy || taxons_url, notice: "Taxon was successfully deleted." }
        format.json { head :no_content }
      end
    end
  end

  private

  def set_taxonomy
    @taxonomy = Taxonomy.find_by!(slug: params[:taxonomy_slug])
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
