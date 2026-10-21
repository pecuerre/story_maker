class ItemsController < ApplicationController
  include PhotoParams
  include MaintainsSiblingPositions
  include RequiresJsonMutationFormat
  include DraftMutation
  include FilteredListQuery

  allow_unauthenticated_access only: %i[ index show ]
  maintains_sibling_positions_for :item

  before_action :set_item, only: %i[ show update destroy ]
  before_action :require_json_mutation_format, only: %i[ create update destroy ]

  # The filter keys ride along with the index. The list's mutations are JSON and
  # answer with no redirect, so nothing on this controller has to carry a filter
  # back: `modal_form_controller.js` refreshes the same URL the reader is on.
  filters_list_with ItemFilter, only: %i[ index ]

  def index
    set_item_tag_data

    @list_filter = ItemFilter.new(@filter_query, item_tags: @item_tags)
    # A GET form submits every field, so the ones the author left alone arrive
    # blank. Redirecting once to the canonical query keeps the address bar, a
    # bookmark, and a shared link limited to the filters really in effect.
    return redirect_to_canonical_filtered_list if blank_filter_values?

    @items = @list_filter.apply(
      Current.universe.items.includes(:item_tags, ownerships: :character)
    )
    # The universe total is read only to say what the reader is looking at out
    # of, so an ordinary unfiltered visit costs no extra query for it. One
    # aggregate is enough: a narrowed list must not mistake its own size for
    # how many items the universe holds.
    @item_total = Current.universe.items.count if @list_filter.narrowed?
    flash_discarded_filter_values
  end

  # GET /items/:id — the record's own read-only details page. It identifies the
  # record and is the destination of every "Details" link; later slices add
  # the related-records sections without changing this URL.
  def show
  end

  def create
    attributes = item_params
    @item = Current.universe.items.new(attributes)
    return if remember_draft_create(@item, attributes)

    respond_to do |format|
      if create_with_sibling_position(@item, requested_position: attributes[:position])
        format.json { render json: item_json, status: :created }
      else
        format.json { render json: @item.errors, status: :unprocessable_content }
      end
    end
  end

  def update
    attributes = item_params
    return if remember_draft_update(@item, attributes)

    respond_to do |format|
      if update_item(attributes)
        format.json { render json: item_json, status: :ok }
      else
        format.json { render json: @item.errors, status: :unprocessable_content }
      end
    end
  end

  def destroy
    return if remember_draft_delete(@item)

    destroy_with_sibling_position(@item)
    head :no_content
  end

  private

  # Item Tag definitions and their paths are universe-scoped. One ordered tag
  # query serves the list filter and its tag selector, and the same list builds
  # the root-first paths a hierarchical taxonomy is named by.
  #
  # The **editor** offers assignable tags only — a grouping tag stays in the tree
  # and on records that already carry one — so the two lists are deliberately
  # different. The filter validates against every tag, because a reader
  # filtering by a grouping tag is asking about records that really do carry it.
  def set_item_tag_data
    @item_tags = Current.universe.item_tags.reorder(:position, :id).to_a
    @assignable_item_tags = @item_tags.select(&:taggable)
    @item_tag_paths = ItemTagPaths.build(@item_tags)
  end

  # The canonical index URL for a set of filter values. `FilteredListQuery` owns
  # everything else about reading and carrying the filter, and this is the one
  # thing it cannot know: where this list's own URL is.
  def filtered_list_path_with(query)
    path = universe_items_path

    query.any? ? "#{path}?#{query.to_query}" : path
  end

  def set_item
    @item = Current.universe.items.find(params.expect(:id))
  end

  def item_params
    params.expect(item: [ *photo_params, :name, :description, { item_tag_ids: [] }, :parent_id, :position ])
  end

  def update_item(attributes)
    update_with_sibling_position(@item, attributes)
  end

  def item_json
    {
      id: @item.id,
      name: @item.name,
      description: @item.description,
      item_tag_ids: @item.item_tag_ids,
      parent_id: @item.parent_id,
      position: @item.position,
      url: universe_item_path(id: @item)
    }
  end
end
