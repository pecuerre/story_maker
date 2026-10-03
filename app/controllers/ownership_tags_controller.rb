class OwnershipTagsController < ApplicationController
  include PhotoParams
  include MaintainsSiblingPositions
  include DraftMutation

  allow_unauthenticated_access only: %i[ index show ]
  maintains_sibling_positions_for :ownership_tag

  before_action :set_ownership_tag, only: %i[ show update destroy ]

  def index
    # One query for the whole taxonomy, and the index the tree descends through.
    # `includes(:children)` used to reach the first level only, and the photo is
    # read for every node because the editor carries its stored image.
    @hierarchy = HierarchyIndex.build(Current.universe.ownership_tags.includes(:photo))
    @ownership_tags = @hierarchy.roots
    @tagged_counts = TaggedRecordCounts.for(Current.universe.ownership_tags)
  end

  # GET /ownership_tags/:id — the tag's own details page: the records that carry it.
  # The taxonomy tree links here with that count.
  def show
    @include_descendants = params[:include_descendants] != "0"
    @tagged_records = if @include_descendants
      @ownership_tag.tagged_records_including_descendants
    else
      @ownership_tag.tagged_records
    end
  end

  def create
    attributes = ownership_tag_params
    @ownership_tag = Current.universe.ownership_tags.new(attributes)
    return if remember_draft_create(@ownership_tag, attributes)

    respond_to do |format|
      if create_with_sibling_position(@ownership_tag, requested_position: attributes[:position])
        format.json { render json: ownership_tag_json, status: :created }
      else
        format.json { render json: @ownership_tag.errors, status: :unprocessable_content }
      end
    end
  end

  def update
    attributes = ownership_tag_params
    return if remember_draft_update(@ownership_tag, attributes)

    respond_to do |format|
      if update_ownership_tag(attributes)
        format.json { render json: ownership_tag_json, status: :ok }
      else
        format.json { render json: @ownership_tag.errors, status: :unprocessable_content }
      end
    end
  end

  def destroy
    return if remember_draft_delete(@ownership_tag)

    destroy_with_sibling_position(@ownership_tag)
    head :no_content
  end

  private

  def set_ownership_tag
    @ownership_tag = Current.universe.ownership_tags.find(params.expect(:id))
  end

  def ownership_tag_params
    params.expect(ownership_tag: [ *photo_params, :name, :description, :bgcolor, :fgcolor, :parent_id, :position, :taggable ])
  end

  def update_ownership_tag(attributes)
    update_with_sibling_position(@ownership_tag, attributes)
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
      taggable: @ownership_tag.taggable,
      url: universe_ownership_tag_path(id: @ownership_tag)
    }
  end
end
