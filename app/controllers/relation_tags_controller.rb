class RelationTagsController < ApplicationController
  allow_unauthenticated_access only: %i[ index show ]
  include MaintainsSiblingPositions
  maintains_sibling_positions_for :relation_tag

  before_action :set_relation_tag, only: %i[ show update destroy ]

  def index
    @relation_tags = Current.universe.relation_tags
    @relation_tags = @relation_tags.includes(:children)
    @relation_tags = @relation_tags.where(parent_id: nil)
    @relation_tags = @relation_tags.order(:position, :id)
    @tagged_counts = TaggedRecordCounts.for(Current.universe.relation_tags)
  end

  def new
    relation_tags = Current.universe.relation_tags
    @relation_tag = relation_tags.new(parent_id: params[:parent_id])
  end

  # GET /relation_tags/:id — the tag's own details page: the records that carry it.
  # The taxonomy tree links here with that count.
  def show
    @tagged_records = @relation_tag.tagged_records
  end

  def create
    attributes = relation_tag_params
    @relation_tag = Current.universe.relation_tags.new(attributes)

    respond_to do |format|
      if create_with_sibling_position(@relation_tag, requested_position: attributes[:position])
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
    destroy_with_sibling_position(@relation_tag)
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
