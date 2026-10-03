class CharactersController < ApplicationController
  include PhotoParams
  include MaintainsSiblingPositions
  include RequiresJsonMutationFormat
  include DraftMutation

  allow_unauthenticated_access only: %i[ index show ]
  maintains_sibling_positions_for :character

  before_action :set_character, only: %i[ show update destroy ]
  before_action :require_json_mutation_format, only: %i[ create update destroy ]

  def index
    @characters = Current.universe.characters
    @characters = @characters.includes(:character_tags)
    @characters = @characters.order(:name, :id)

    # The editor offers assignable tags only; a grouping tag stays in the tree
    # and on records that already carry it. The tab strip links to the tags
    # the author pinned with `show_in_menu`.
    @character_tags = Current.universe.character_tags
    @character_tags = @character_tags.where(taggable: true).order(:name)
  end

  # GET /characters/:id — the record's own read-only details page. It identifies the
  # record and is the destination of every "Details" link; later slices add
  # the related-records sections without changing this URL.
  def show
  end

  def new
    @character = Current.universe.characters.new(parent_id: params[:parent_id])

    @character_tags = Current.universe.character_tags
    @character_tags = @character_tags.order(:name)
  end

  def create
    attributes = character_params
    @character = Current.universe.characters.new(attributes)
    return if remember_draft_create(@character, attributes)

    respond_to do |format|
      if create_with_sibling_position(@character, requested_position: attributes[:position])
        format.json { render json: character_json, status: :created }
      else
        format.json { render json: @character.errors, status: :unprocessable_content }
      end
    end
  end

  def update
    attributes = character_params
    return if remember_draft_update(@character, attributes)

    respond_to do |format|
      if update_with_sibling_position(@character, attributes)
        format.json { render json: character_json, status: :ok }
      else
        format.json { render json: @character.errors, status: :unprocessable_content }
      end
    end
  end

  def destroy
    return if remember_draft_delete(@character)

    destroy_with_sibling_position(@character)
    head :no_content
  end

  private

  def set_character
    @character = Current.universe.characters.find(params.expect(:id))
  end

  def character_params
    params.expect(character: [ *photo_params, :name, :description, { character_tag_ids: [] }, :parent_id, :position ])
  end

  def character_json
    {
      id: @character.id,
      name: @character.name,
      description: @character.description,
      character_tag_ids: @character.character_tag_ids,
      parent_id: @character.parent_id,
      position: @character.position,
      url: universe_character_path(id: @character)
    }
  end
end
