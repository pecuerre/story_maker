class CharacterTagsController < ApplicationController
  include PhotoParams
  include TagDetails
  include MaintainsSiblingPositions
  include DraftMutation
  include FilteredListQuery

  allow_unauthenticated_access only: %i[ index show ]
  maintains_sibling_positions_for :character_tag

  # The filter rides along with the index. A tree keeps its drag order and
  # offers no reader sort, so `index` is the only action that reads the filter.
  filters_list_with CharacterTagFilter, only: %i[ index ]

  before_action :set_character_tag, only: %i[ show update destroy ]

  def index
    @list_filter = CharacterTagFilter.new(@filter_query)
    # A GET form submits every field, so the ones the author left alone arrive
    # blank. Redirecting once to the canonical query keeps the address bar, a
    # bookmark, and a shared link limited to the filters really in effect.
    return redirect_to_canonical_filtered_list if blank_filter_values?

    # One query for the whole taxonomy, and the index the tree descends through.
    # `includes(:children)` used to reach the first level only, and the photo is
    # read for every node because the editor carries its stored image.
    @hierarchy = HierarchyIndex.build(@list_filter.apply(
      Current.universe.character_tags.includes(:photo)))
    @character_tags = @hierarchy.roots
    @tagged_counts = TaggedRecordCounts.for(Current.universe.character_tags)
    # The total is read only when a filter is really in effect, so the ordinary
    # unfiltered visit costs no extra query for it.
    @character_tag_total = Current.universe.character_tags.count if @list_filter.narrowed?
    flash_discarded_filter_values
  end

  # GET /character_tags/:id — the tag's own details page: the records that carry it.
  # The taxonomy tree links here with that count.
  def show
    load_tag_details(@character_tag)
  end

  def create
    attributes = character_tag_params
    @character_tag = Current.universe.character_tags.new(attributes)
    return if remember_draft_create(@character_tag, attributes)

    respond_to do |format|
      if create_with_sibling_position(@character_tag, requested_position: attributes[:position])
        format.json { render json: character_tag_json, status: :created }
      else
        format.json { render json: @character_tag.errors, status: :unprocessable_content }
      end
    end
  end

  def update
    attributes = character_tag_params
    return if remember_draft_update(@character_tag, attributes)

    respond_to do |format|
      if update_character_tag(attributes)
        format.json { render json: character_tag_json, status: :ok }
      else
        format.json { render json: @character_tag.errors, status: :unprocessable_content }
      end
    end
  end

  def destroy
    return if remember_draft_delete(@character_tag)

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

  def update_character_tag(attributes)
    update_with_sibling_position(@character_tag, attributes)
  end

  # The canonical index URL for a set of filter values. `FilteredListQuery` owns
  # everything else about reading and carrying the filter, and this is the one
  # thing it cannot know: where this list's own URL is.
  def filtered_list_path_with(query)
    path = universe_character_tags_path

    query.any? ? "#{path}?#{query.to_query}" : path
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
