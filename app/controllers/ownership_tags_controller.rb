class OwnershipTagsController < ApplicationController
  allow_unauthenticated_access only: :index
  include MaintainsSiblingPositions
  maintains_sibling_positions_for :ownership_tag

  before_action :set_ownership_tag, only: %i[ update destroy ]

  def index
    @ownership_tags = Current.universe.ownership_tags
    @ownership_tags = @ownership_tags.includes(:children)
    @ownership_tags = @ownership_tags.where(parent_id: nil)
    @ownership_tags = @ownership_tags.order(:position, :id)
  end

  def new
    ownership_tags = Current.universe.ownership_tags
    @ownership_tag = ownership_tags.new(parent_id: params[:parent_id])
  end

  def create
    @ownership_tag = Current.universe.ownership_tags.new(ownership_tag_params)
    @ownership_tag.position = sibling_count(@ownership_tag.parent_id)

    respond_to do |format|
      if @ownership_tag.save
        format.json { render json: ownership_tag_json, status: :created }
      else
        format.json { render json: @ownership_tag.errors, status: :unprocessable_content }
      end
    end
  end

  def update
    respond_to do |format|
      if update_ownership_tag
        format.json { render json: ownership_tag_json, status: :ok }
      else
        format.json { render json: @ownership_tag.errors, status: :unprocessable_content }
      end
    end
  end

  def destroy
    @ownership_tag.destroy!
    head :no_content
  end

  private

  def set_ownership_tag
    @ownership_tag = Current.universe.ownership_tags.find(params.expect(:id))
  end

  def ownership_tag_params
    params.expect(ownership_tag: [ :name, :description, :bgcolor, :fgcolor, :parent_id, :position ])
  end

  def update_ownership_tag
    update_with_sibling_position(@ownership_tag, ownership_tag_params)
  end

  def ownership_tag_json
    {
      id: @ownership_tag.id,
      name: @ownership_tag.name,
      description: @ownership_tag.description,
      bgcolor: @ownership_tag.bgcolor,
      fgcolor: @ownership_tag.fgcolor,
      parent_id: @ownership_tag.parent_id,
      position: @ownership_tag.position,
      url: universe_ownership_tag_path(id: @ownership_tag)
    }
  end
end
