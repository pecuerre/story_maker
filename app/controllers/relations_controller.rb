class RelationsController < ApplicationController
  include PhotoParams
  include DraftMutation
  include FilteredListQuery

  allow_unauthenticated_access only: %i[ index show ]

  # The filter rides along with every action that renders or returns to the list.
  # The index and the rejected create and update re-render the same page; the
  # destroy returns to the narrowed list it was performed from rather than dumping
  # the reader on the full one.
  filters_list_with RelationFilter, only: %i[ index create update destroy ]

  before_action :set_relation, only: %i[ show update destroy ]

  # GET /relations
  #
  # The list is every relation in the universe. A filter narrows what is shown and
  # is visible in the URL; it never writes anything.
  def index
    build_relation_filter
    # A GET form submits every field, so the ones the author left alone arrive
    # blank. Redirecting once to the canonical query keeps the address bar, a
    # bookmark, and a shared link limited to the filters really in effect.
    return redirect_to_canonical_filtered_list if blank_filter_values?

    apply_relation_filter
    flash_discarded_filter_values
  end

  # GET /relations/:id — the record's own read-only details page. It identifies the
  # record and is the destination of every "Details" link; later slices add
  # the related-records sections without changing this URL.
  def show
  end

  def create
    attributes = relation_params
    @relation = Current.universe.relations.new(attributes)
    return if remember_draft_create(@relation, attributes)

    if @relation.save
      redirect_to universe_relations_path(), notice: t("relations.flash.created")
    else
      # The re-render is the same page, so it builds the same state: a filter in
      # the URL survives the rejection instead of dropping the reader back on the
      # full list beside the error summary.
      build_relation_filter
      apply_relation_filter
      render :index, status: :unprocessable_content
    end
  end

  # PATCH and DELETE answer with `see_other`, as the documented HTML flow
  # requires (`docs/architecture.md`): a 302 after a non-GET verb asks the
  # browser to repeat the mutation as a GET against the redirect target, which
  # Turbo then has to reinterpret. `create` is a POST, so its 302 is correct.
  def update
    attributes = relation_params
    return if remember_draft_update(@relation, attributes)

    if @relation.update(attributes)
      redirect_to universe_relations_path(), notice: t("relations.flash.updated"), status: :see_other
    else
      build_relation_filter
      apply_relation_filter
      render :index, status: :unprocessable_content
    end
  end

  def destroy
    return if remember_draft_delete(@relation)

    @relation.soft_delete
    redirect_to filtered_list_path, notice: t("relations.flash.deleted"), status: :see_other
  end

  private

  # The state both the list and its re-render need: the two form selects, the
  # filter itself, and the tag paths the filter's own selector is labelled by.
  def build_relation_filter
    set_relation_tag_data
    @characters = Current.universe.characters.order(:name, :id)
    @list_filter = RelationFilter.new(@filter_query, relation_tags: @relation_tags)
  end

  # The narrowed list, and the universe total a narrowed list is shown against.
  # The total is read only when a filter is really in effect, so the ordinary
  # unfiltered visit costs no extra query for it.
  def apply_relation_filter
    @relations = @list_filter.apply(
      Current.universe.relations.includes(:character1, :character2, :relation_tags))
    @relation_total = Current.universe.relations.count if @list_filter.narrowed?
  end

  # Relation Tag definitions and their paths are universe-scoped. One ordered tag
  # query serves the list filter and its tag selector, and the same list builds
  # the root-first paths a hierarchical taxonomy is named by.
  #
  # The **editor** offers assignable tags only — a grouping tag stays in the tree
  # and on records that already carry one — so the two lists are deliberately
  # different. The filter validates against every tag, because a reader filtering
  # by a grouping tag is asking about records that really do carry it.
  def set_relation_tag_data
    @relation_tags = Current.universe.relation_tags.reorder(:position, :id).to_a
    @assignable_relation_tags = @relation_tags.select(&:taggable)
    @relation_tag_paths = RelationTagPaths.build(@relation_tags)
  end

  # The canonical index URL for a set of filter values. `FilteredListQuery` owns
  # everything else about reading and carrying the filter, and this is the one
  # thing it cannot know: where this list's own URL is.
  def filtered_list_path_with(query)
    path = universe_relations_path

    query.any? ? "#{path}?#{query.to_query}" : path
  end

  def set_relation
    @relation = Current.universe.relations.find(params.expect(:id))
  end

  def relation_params
    params.expect(relation: [ :name, *photo_params, :character1_id, :character2_id, { relation_tag_ids: [] }, :description, :from_date, :to_date ])
  end
end
