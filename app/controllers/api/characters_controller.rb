# The API-surface counterpart of `CharactersController`: index, show, and the three
# mutations, all of them JSON. A mutation in a draft-based universe is remembered
# (`202`) instead of written; both demo universes are `direct`, so it is invisible
# locally and only appears in production.
class Api::CharactersController < Api::BaseController
  include RequiresJsonMutationFormat
  include DraftMutation

  before_action :set_character, only: %i[ show update destroy ]
  before_action :require_json_mutation_format, only: %i[ create update destroy ]

  # GET /api/u/:universe_slug/characters
  def index
    @characters = Current.universe.characters.order(:name)
    render json: @characters.map { |character| character_json(character) }
  end

  # GET /api/u/:universe_slug/characters/:id
  def show
    render json: character_json(@character)
  end

  # POST /api/u/:universe_slug/characters
  def create
    @character = Current.universe.characters.new(character_params)
    return if remember_draft_create(@character, character_params)

    if @character.save
      render json: character_json(@character), status: :created
    else
      render json: @character.errors, status: :unprocessable_content
    end
  end

  # PATCH /api/u/:universe_slug/characters/:id
  def update
    return if remember_draft_update(@character, character_params)

    if @character.update(character_params)
      render json: character_json(@character)
    else
      render json: @character.errors, status: :unprocessable_content
    end
  end

  # DELETE /api/u/:universe_slug/characters/:id
  def destroy
    return if remember_draft_delete(@character)

    @character.destroy
    head :no_content
  end

  private

    def set_character
      @character = Current.universe.characters.find(params.expect(:id))
    end

    def character_params
      params.expect(character: [ :name, :description, { character_tag_ids: [] }, :parent_id, :position ])
    end

    def character_json(character)
      {
        id: character.id,
        name: character.name,
        description: character.description,
        character_tag_ids: character.character_tag_ids,
        parent_id: character.parent_id,
        position: character.position
      }
    end
end
