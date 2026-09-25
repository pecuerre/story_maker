class ItemsController < ApplicationController
  allow_unauthenticated_access only: :index
  include MaintainsSiblingPositions
  maintains_sibling_positions_for :item

  before_action :set_item, only: %i[ update destroy ]

  def index
    @items = Current.universe.items
    @items = @items.includes(:item_tags)
    @items = @items.order(:name, :id)

    @item_tags = Current.universe.item_tags
    @item_tags = @item_tags.order(:name)
  end

  def new
    @item = Current.universe.items.new(parent_id: params[:parent_id])

    @item_tags = Current.universe.item_tags
    @item_tags = @item_tags.order(:name)
  end

  def create
    attributes = item_params
    @item = Current.universe.items.new(attributes)

    respond_to do |format|
      if create_with_sibling_position(@item, requested_position: attributes[:position])
        format.json { render json: item_json, status: :created }
      else
        format.json { render json: @item.errors, status: :unprocessable_content }
      end
    end
  end

  def update
    respond_to do |format|
      if update_item
        format.json { render json: item_json, status: :ok }
      else
        format.json { render json: @item.errors, status: :unprocessable_content }
      end
    end
  end

  def destroy
    destroy_with_sibling_position(@item)
    head :no_content
  end

  private

  def set_item
    @item = Current.universe.items.find(params.expect(:id))
  end

  def item_params
    params.expect(item: [ :name, :description, { item_tag_ids: [] }, :parent_id, :position ])
  end

  def update_item
    attributes = item_params
    update_with_sibling_position(@item, attributes)
  end

  def item_json
    {
      id: @item.id,
      name: @item.name,
      description: @item.description,
      item_tag_ids: @item.item_tag_ids,
      parent_id: @item.parent_id,
      position: @item.position,
      url: universe_item_path(id: @item)
    }
  end
end
