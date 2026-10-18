class OwnershipsController < ApplicationController
  include PhotoParams
  include DraftMutation
  include FilteredListQuery

  allow_unauthenticated_access only: %i[ index show ]

  # The filter rides along with every action that renders or returns to the list.
  # The index and the rejected create and update re-render the same page; the
  # destroy returns to the narrowed list it was performed from rather than dumping
  # the reader on the full one.
  filters_list_with OwnershipFilter, only: %i[ index create update destroy ]

  before_action :set_ownership, only: %i[ show update destroy ]

  # GET /ownerships
  #
  # The list is every ownership in the universe. A filter narrows what is shown
  # and is visible in the URL; it never writes anything.
  def index
    build_ownership_filter
    # A GET form submits every field, so the ones the author left alone arrive
    # blank. Redirecting once to the canonical query keeps the address bar, a
    # bookmark, and a shared link limited to the filters really in effect.
    return redirect_to_canonical_filtered_list if blank_filter_values?

    apply_ownership_filter
    flash_discarded_filter_values
  end

  # GET /ownerships/:id — the record's own read-only details page. It identifies the
  # record and is the destination of every "Details" link; later slices add
  # the related-records sections without changing this URL.
  def show
  end

  def create
    attributes = ownership_params
    @ownership = Current.universe.ownerships.new(attributes)
    return if remember_draft_create(@ownership, attributes)

    if @ownership.save
      redirect_to universe_ownerships_path(), notice: t("ownerships.flash.created")
    else
      # The re-render is the same page, so it builds the same state: a filter in
      # the URL survives the rejection instead of dropping the reader back on the
      # full list beside the error summary.
      build_ownership_filter
      apply_ownership_filter
      render :index, status: :unprocessable_content
    end
  end

  # PATCH and DELETE answer with `see_other`, as the documented HTML flow
  # requires (`docs/architecture.md`): a 302 after a non-GET verb asks the
  # browser to repeat the mutation as a GET against the redirect target, which
  # Turbo then has to reinterpret. `create` is a POST, so its 302 is correct.
  def update
    attributes = ownership_params
    return if remember_draft_update(@ownership, attributes)

    if @ownership.update(attributes)
      redirect_to universe_ownerships_path(), notice: t("ownerships.flash.updated"), status: :see_other
    else
      build_ownership_filter
      apply_ownership_filter
      render :index, status: :unprocessable_content
    end
  end

  def destroy
    return if remember_draft_delete(@ownership)

    @ownership.soft_delete
    redirect_to filtered_list_path, notice: t("ownerships.flash.deleted"), status: :see_other
  end

  private

  # The state both the list and its re-render need: the two form selects, the
  # filter itself, and the tag paths the filter's own selector is labelled by.
  def build_ownership_filter
    set_ownership_tag_data
    @items = Current.universe.items.order(:name, :id)
    @characters = Current.universe.characters.order(:name, :id)
    @list_filter = OwnershipFilter.new(@filter_query, ownership_tags: @ownership_tags)
  end

  # The narrowed list, and the universe total a narrowed list is shown against.
  # The total is read only when a filter is really in effect, so the ordinary
  # unfiltered visit costs no extra query for it.
  def apply_ownership_filter
    @ownerships = @list_filter.apply(
      Current.universe.ownerships.includes(:item, :character, :ownership_tags))
    @ownership_total = Current.universe.ownerships.count if @list_filter.narrowed?
  end

  # Ownership Tag definitions and their paths are universe-scoped. One ordered tag
  # query serves the list filter and its tag selector, and the same list builds
  # the root-first paths a hierarchical taxonomy is named by.
  #
  # The **editor** offers assignable tags only — a grouping tag stays in the tree
  # and on records that already carry one — so the two lists are deliberately
  # different. The filter validates against every tag, because a reader filtering
  # by a grouping tag is asking about records that really do carry it.
  def set_ownership_tag_data
    @ownership_tags = Current.universe.ownership_tags.reorder(:position, :id).to_a
    @assignable_ownership_tags = @ownership_tags.select(&:taggable)
    @ownership_tag_paths = OwnershipTagPaths.build(@ownership_tags)
  end

  # The canonical index URL for a set of filter values. `FilteredListQuery` owns
  # everything else about reading and carrying the filter, and this is the one
  # thing it cannot know: where this list's own URL is.
  def filtered_list_path_with(query)
    path = universe_ownerships_path

    query.any? ? "#{path}?#{query.to_query}" : path
  end

  def set_ownership
    @ownership = Current.universe.ownerships.find(params.expect(:id))
  end

  def ownership_params
    params.expect(ownership: [ :name, *photo_params, :item_id, :character_id, { ownership_tag_ids: [] }, :description, :from_date, :to_date ])
  end
end
