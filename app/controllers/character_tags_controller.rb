class CharacterTagsController < ApplicationController
  include PhotoParams
  include TagDetails
  include MaintainsSiblingPositions

  allow_unauthenticated_access only: %i[ index show ]
  maintains_sibling_positions_for :character_tag

  before_action :set_character_tag, only: %i[ show update destroy ]

  def index
    # One query for the whole taxonomy, and the index the tree descends through.
    # `includes(:children)` used to reach the first level only, and the photo is
    # read for every node because the editor carries its stored image.
    @hierarchy = HierarchyIndex.build(Current.universe.character_tags.includes(:photo))
    @character_tags = @hierarchy.roots
    @tagged_counts = TaggedRecordCounts.for(Current.universe.character_tags)
  end

  # GET /character_tags/:id — the tag's own details page: the records that carry it.
  # The taxonomy tree links here with that count.
  def show
    load_tag_details(@character_tag)
  end

  def create
    attributes = character_tag_params
    @character_tag = Current.universe.character_tags.new(attributes)

    respond_to do |format|
      if create_with_sibling_position(@character_tag, requested_position: attributes[:position])
        format.json { render json: character_tag_json, status: :created }
      else
        format.json { render json: @character_tag.errors, status: :unprocessable_content }
      end
    end
  end

  def update
    respond_to do |format|
      if update_character_tag
        format.json { render json: character_tag_json, status: :ok }
      else
        format.json { render json: @character_tag.errors, status: :unprocessable_content }
      end
    end
  end

  def destroy
    destroy_with_sibling_position(@character_tag)
    head :no_content
  end

  private

  def set_character_tag
    @character_tag = Current.universe.character_tags.find(params.expect(:id))
  end

  def character_tag_params
    params.expect(character_tag: [ *photo_params, :name, :description, :bgcolor, :fgcolor, :parent_id, :position, :taggable, :show_in_menu ])
  end

  def update_character_tag
    attributes = character_tag_params
    update_with_sibling_position(@character_tag, attributes)
  end

  def character_tag_json
    {
      id: @character_tag.id,
      name: @character_tag.name,
      description: @character_tag.description,
      bgcolor: @character_tag.bgcolor,
      fgcolor: @character_tag.fgcolor,
      parent_id: @character_tag.parent_id,
      position: @character_tag.position,
      taggable: @character_tag.taggable,
      show_in_menu: @character_tag.show_in_menu,
      url: universe_character_tag_path(id: @character_tag)
    }
  end
end
