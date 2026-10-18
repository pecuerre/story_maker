class ItemTagsController < ApplicationController
  include PhotoParams
  include TagDetails
  include MaintainsSiblingPositions
  include DraftMutation
  include FilteredListQuery

  allow_unauthenticated_access only: %i[ index show ]
  maintains_sibling_positions_for :item_tag

  # The filter rides along with the index. A tree keeps its drag order and
  # offers no reader sort, so `index` is the only action that reads the filter.
  filters_list_with ItemTagFilter, only: %i[ index ]

  before_action :set_item_tag, only: %i[ show update destroy ]

  def index
    @list_filter = ItemTagFilter.new(@filter_query)
    # A GET form submits every field, so the ones the author left alone arrive
    # blank. Redirecting once to the canonical query keeps the address bar, a
    # bookmark, and a shared link limited to the filters really in effect.
    return redirect_to_canonical_filtered_list if blank_filter_values?

    # One query for the whole taxonomy, and the index the tree descends through.
    # `includes(:children)` used to reach the first level only, and the photo is
    # read for every node because the editor carries its stored image.
    @hierarchy = HierarchyIndex.build(@list_filter.apply(
      Current.universe.item_tags.includes(:photo)))
    @item_tags = @hierarchy.roots
    @tagged_counts = TaggedRecordCounts.for(Current.universe.item_tags)
    # The total is read only when a filter is really in effect, so the ordinary
    # unfiltered visit costs no extra query for it.
    @item_tag_total = Current.universe.item_tags.count if @list_filter.narrowed?
    flash_discarded_filter_values
  end

  # GET /item_tags/:id — the tag's own details page: the records that carry it.
  # The taxonomy tree links here with that count.
  def show
    load_tag_details(@item_tag)
  end

  def create
    attributes = item_tag_params
    @item_tag = Current.universe.item_tags.new(attributes)
    return if remember_draft_create(@item_tag, attributes)

    respond_to do |format|
      if create_with_sibling_position(@item_tag, requested_position: attributes[:position])
        format.json { render json: item_tag_json, status: :created }
      else
        format.json { render json: @item_tag.errors, status: :unprocessable_content }
      end
    end
  end

  def update
    attributes = item_tag_params
    return if remember_draft_update(@item_tag, attributes)

    respond_to do |format|
      if update_item_tag(attributes)
        format.json { render json: item_tag_json, status: :ok }
      else
        format.json { render json: @item_tag.errors, status: :unprocessable_content }
      end
    end
  end

  def destroy
    return if remember_draft_delete(@item_tag)

    destroy_with_sibling_position(@item_tag)
    head :no_content
  end

  private

  def set_item_tag
    @item_tag = Current.universe.item_tags.find(params.expect(:id))
  end

  def item_tag_params
    params.expect(item_tag: [ *photo_params, :name, :description, :bgcolor, :fgcolor, :parent_id, :position, :taggable, :show_in_menu ])
  end

  def update_item_tag(attributes)
    update_with_sibling_position(@item_tag, attributes)
  end

  # The canonical index URL for a set of filter values. `FilteredListQuery` owns
  # everything else about reading and carrying the filter, and this is the one
  # thing it cannot know: where this list's own URL is.
  def filtered_list_path_with(query)
    path = universe_item_tags_path

    query.any? ? "#{path}?#{query.to_query}" : path
  end

  def item_tag_json
    {
      id: @item_tag.id,
      name: @item_tag.name,
      description: @item_tag.description,
      bgcolor: @item_tag.bgcolor,
      fgcolor: @item_tag.fgcolor,
      parent_id: @item_tag.parent_id,
      position: @item_tag.position,
      taggable: @item_tag.taggable,
      show_in_menu: @item_tag.show_in_menu,
      url: universe_item_tag_path(id: @item_tag)
    }
  end
end
