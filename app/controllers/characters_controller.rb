class CharactersController < ApplicationController
  include PhotoParams
  include MaintainsSiblingPositions
  include RequiresJsonMutationFormat
  include DraftMutation
  include FilteredListQuery

  allow_unauthenticated_access only: %i[ index show ]
  maintains_sibling_positions_for :character

  # The filter keys ride along with the index. The list's mutations are JSON and
  # answer with no redirect, so nothing on this controller has to carry a filter
  # back: `modal_form_controller.js` refreshes the same URL the reader is on.
  filters_list_with CharacterFilter, only: %i[ index ]

  before_action :set_character, only: %i[ show update destroy ]
  before_action :require_json_mutation_format, only: %i[ create update destroy ]

  # GET /characters
  #
  # The list is every character in the universe, ordered by name unless the
  # reader chose otherwise. A filter narrows what is shown and is visible in the
  # URL; it never renumbers a position and never writes anything.
  def index
    set_character_tag_data

    @list_filter = CharacterFilter.new(@filter_query, character_tags: @character_tags)
    # A GET form submits every field, so the ones the author left alone arrive
    # blank. Redirecting once to the canonical query keeps the address bar, a
    # bookmark, and a shared link limited to the filters really in effect.
    return redirect_to_canonical_filtered_list if blank_filter_values?

    @characters = @list_filter.apply(
      Current.universe.characters.includes(:character_tags, :factions, :relations_as_character1, :relations_as_character2, :ownerships)
    )
    # The universe total is read only to say what the reader is looking at out
    # of, so the ordinary unfiltered visit costs no extra query for it. One
    # aggregate is enough: a narrowed list must not mistake its own size for how
    # many characters the universe holds.
    @character_total = Current.universe.characters.count if @list_filter.narrowed?
    flash_discarded_filter_values
  end

  # GET /characters/:id — the record's own read-only details page.
  def show
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

  # Character Tag definitions and their paths are universe-scoped. One ordered tag
  # query serves the list filter and its tag selector, and the same list builds
  # the root-first paths a hierarchical taxonomy is named by.
  #
  # The **editor** offers assignable tags only — a grouping tag stays in the tree
  # and on records that already carry one — so the two lists are deliberately
  # different. The filter validates against every tag, because a reader filtering
  # by a grouping tag is asking about records that really do carry it.
  def set_character_tag_data
    @character_tags = Current.universe.character_tags.reorder(:position, :id).to_a
    @assignable_character_tags = @character_tags.select(&:taggable)
    @factions = Current.universe.factions.order(:name, :id)
    @character_tag_paths = CharacterTagPaths.build(@character_tags)
  end

  # The canonical index URL for a set of filter values. `FilteredListQuery` owns
  # everything else about reading and carrying the filter, and this is the one
  # thing it cannot know: where this list's own URL is.
  def filtered_list_path_with(query)
    path = universe_characters_path

    query.any? ? "#{path}?#{query.to_query}" : path
  end

  def set_character
    @character = Current.universe.characters.find(params.expect(:id))
  end

  def character_params
    params.expect(character: [ *photo_params, :name, :pronouns, :aliases, :summary, :description,
      { character_tag_ids: [] }, { faction_ids: [] }, :parent_id, :position ])
  end

  def character_json
    {
      id: @character.id,
      name: @character.name,
      pronouns: @character.pronouns,
      aliases: @character.aliases,
      summary: @character.summary,
      description: @character.description,
      character_tag_ids: @character.character_tag_ids,
      faction_ids: @character.faction_ids,
      parent_id: @character.parent_id,
      position: @character.position,
      url: universe_character_path(id: @character)
    }
  end
end
