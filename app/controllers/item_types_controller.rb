class ItemTypesController < ApplicationController
  include MaintainsSiblingPositions
  maintains_sibling_positions_for :item_type

  before_action :set_item_type, only: %i[ update destroy ]

  def index
    @item_types = Current.story.item_types
    @item_types = @item_types.includes(:children)
    @item_types = @item_types.where(parent_id: nil)
    @item_types = @item_types.order(:position, :id)
  end

  def new
    item_types = Current.story.item_types
    @item_type = item_types.new(parent_id: params[:parent_id])
  end

  def create
    @item_type = Current.story.item_types.new(item_type_params)
    @item_type.position = sibling_count(@item_type.parent_id)

    respond_to do |format|
      if @item_type.save
        format.json { render json: item_type_json, status: :created }
      else
        format.json { render json: @item_type.errors, status: :unprocessable_content }
      end
    end
  end

  def update
    respond_to do |format|
      if update_item_type
        format.json { render json: item_type_json, status: :ok }
      else
        format.json { render json: @item_type.errors, status: :unprocessable_content }
      end
    end
  end

  def destroy
    @item_type.destroy!
    head :no_content
  end

  private

  def set_item_type
    @item_type = Current.story.item_types.find(params.expect(:id))
  end

  def item_type_params
    params.expect(item_type: [ :name, :description, :bgcolor, :fgcolor, :parent_id, :position ])
  end

  def update_item_type
    attributes = item_type_params
    update_with_sibling_position(@item_type, attributes)
  end

  def item_type_json
    {
      id: @item_type.id,
      name: @item_type.name,
      description: @item_type.description,
      bgcolor: @item_type.bgcolor,
      fgcolor: @item_type.fgcolor,
      parent_id: @item_type.parent_id,
      position: @item_type.position,
      url: story_item_type_path(id: @item_type)
    }
  end
end
