class RelationTagsController < ApplicationController
  allow_unauthenticated_access only: :index
  include MaintainsSiblingPositions
  maintains_sibling_positions_for :relation_tag

  before_action :set_relation_tag, only: %i[ update destroy ]

  def index
    @relation_tags = Current.universe.relation_tags
    @relation_tags = @relation_tags.includes(:children)
    @relation_tags = @relation_tags.where(parent_id: nil)
    @relation_tags = @relation_tags.order(:position, :id)
  end

  def new
    relation_tags = Current.universe.relation_tags
    @relation_tag = relation_tags.new(parent_id: params[:parent_id])
  end

  def create
    @relation_tag = Current.universe.relation_tags.new(relation_tag_params)
    @relation_tag.position = sibling_count(@relation_tag.parent_id)

    respond_to do |format|
      if @relation_tag.save
        format.json { render json: relation_tag_json, status: :created }
      else
        format.json { render json: @relation_tag.errors, status: :unprocessable_content }
      end
    end
  end

  def update
    respond_to do |format|
      if update_relation_tag
        format.json { render json: relation_tag_json, status: :ok }
      else
        format.json { render json: @relation_tag.errors, status: :unprocessable_content }
      end
    end
  end

  def destroy
    @relation_tag.destroy!
    head :no_content
  end

  private

  def set_relation_tag
    @relation_tag = Current.universe.relation_tags.find(params.expect(:id))
  end

  def relation_tag_params
    params.expect(relation_tag: [ :name, :description, :bgcolor, :fgcolor, :parent_id, :position, :symmetric, :inverse ])
  end

  def update_relation_tag
    update_with_sibling_position(@relation_tag, relation_tag_params)
  end

  def relation_tag_json
    {
      id: @relation_tag.id,
      name: @relation_tag.name,
      description: @relation_tag.description,
      bgcolor: @relation_tag.bgcolor,
      fgcolor: @relation_tag.fgcolor,
      parent_id: @relation_tag.parent_id,
      position: @relation_tag.position,
      symmetric: @relation_tag.symmetric,
      inverse: @relation_tag.inverse,
      url: universe_relation_tag_path(id: @relation_tag)
    }
  end
end
