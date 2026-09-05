class ItemsController < ApplicationController
  include MaintainsSiblingPositions
  maintains_sibling_positions_for :item

  before_action :set_item, only: %i[ update destroy ]

  def index
    @items = Current.story.items
    @items = @items.includes(:item_type)
    @items = @items.order(:name, :id)

    @item_types = Current.story.item_types
    @item_types = @item_types.order(:name)
  end

  def new
    @item = Current.story.items.new(parent_id: params[:parent_id])

    @item_types = Current.story.item_types
    @item_types = @item_types.order(:name)
  end

  def create
    @item = Current.story.items.new(item_params)
    @item.item_type ||= Current.story.item_types.order(:id).first
    @item.position = sibling_count(@item.parent_id)

    respond_to do |format|
      if @item.save
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
    @item.destroy!
    head :no_content
  end

  private

  def set_item
    @item = Current.story.items.find(params.expect(:id))
  end

  def item_params
    params.expect(item: [ :name, :description, :item_type_id, :parent_id, :position ])
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
      item_type_id: @item.item_type_id,
      parent_id: @item.parent_id,
      position: @item.position,
      url: story_item_path(story_slug: Current.story.slug, id: @item)
    }
  end
end
