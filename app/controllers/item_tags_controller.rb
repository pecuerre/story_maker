class ItemTagsController < ApplicationController
  include MaintainsSiblingPositions
  maintains_sibling_positions_for :item_tag

  before_action :set_item_tag, only: %i[ update destroy ]

  def index
    @item_tags = Current.universe.item_tags
    @item_tags = @item_tags.includes(:children)
    @item_tags = @item_tags.where(parent_id: nil)
    @item_tags = @item_tags.order(:position, :id)
  end

  def new
    item_tags = Current.universe.item_tags
    @item_tag = item_tags.new(parent_id: params[:parent_id])
  end

  def create
    @item_tag = Current.universe.item_tags.new(item_tag_params)
    @item_tag.position = sibling_count(@item_tag.parent_id)

    respond_to do |format|
      if @item_tag.save
        format.json { render json: item_tag_json, status: :created }
      else
        format.json { render json: @item_tag.errors, status: :unprocessable_content }
      end
    end
  end

  def update
    respond_to do |format|
      if update_item_tag
        format.json { render json: item_tag_json, status: :ok }
      else
        format.json { render json: @item_tag.errors, status: :unprocessable_content }
      end
    end
  end

  def destroy
    @item_tag.destroy!
    head :no_content
  end

  private

  def set_item_tag
    @item_tag = Current.universe.item_tags.find(params.expect(:id))
  end

  def item_tag_params
    params.expect(item_tag: [ :name, :description, :bgcolor, :fgcolor, :parent_id, :position ])
  end

  def update_item_tag
    attributes = item_tag_params
    update_with_sibling_position(@item_tag, attributes)
  end

  def item_tag_json
    {
      id: @item_tag.id,
      name: @item_tag.name,
      description: @item_tag.description,
      bgcolor: @item_tag.bgcolor,
      fgcolor: @item_tag.fgcolor,
      parent_id: @item_tag.parent_id,
      position: @item_tag.position,
      url: universe_item_tag_path(id: @item_tag)
    }
  end
end
