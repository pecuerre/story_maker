class CanonRulesController < ApplicationController
  include DraftMutation
  include FilteredListQuery

  allow_unauthenticated_access only: %i[ index show ]

  # The filter rides along with every action that renders or returns to the list.
  # The index and a rejected create or update re-render the same page, and every
  # successful mutation returns to the narrowed list it was performed from rather
  # than dumping the reader on the full one.
  filters_list_with CanonRuleFilter, only: %i[ index create update destroy ]

  before_action :set_canon_rule, only: %i[ show update destroy ]

  def index
    build_canon_rule_filter
    # A GET form submits every field, so the ones the author left alone arrive
    # blank. Redirecting once to the canonical query keeps the address bar, a
    # bookmark, and a shared link limited to the filters really in effect.
    return redirect_to_canonical_filtered_list if blank_filter_values?

    apply_canon_rule_filter
    flash_discarded_filter_values
  end

  def show
    # A writer gets the workspace's editor here, so the page loads the Stories
    # its owner selector offers. A guest or read-only member pays for neither.
    @stories = Current.universe.stories.order(:name, :id) if can?(:write, Current.universe)
  end

  def create
    attributes = canon_rule_params
    @canon_rule = Current.universe.canon_rules.new(attributes)
    return if remember_draft_create(@canon_rule, attributes)

    if @canon_rule.save
      redirect_to filtered_list_path, notice: t("canon_rules.flash.created")
    else
      build_canon_rule_filter
      apply_canon_rule_filter
      render :index, status: :unprocessable_content
    end
  end

  def update
    attributes = canon_rule_params
    return if remember_draft_update(@canon_rule, attributes)

    if @canon_rule.update(attributes)
      redirect_to update_destination, notice: t("canon_rules.flash.updated"), status: :see_other
    else
      return render_rejected_details_edit if details_edit?

      build_canon_rule_filter
      apply_canon_rule_filter
      render :index, status: :unprocessable_content
    end
  end

  def destroy
    return if remember_draft_delete(@canon_rule)

    @canon_rule.soft_delete
    redirect_to filtered_list_path, notice: t("canon_rules.flash.deleted"), status: :see_other
  end

  private

  # The state both the list and its re-render need: the filter itself and the
  # Stories both the editor's owner selector and the filter's scope selector
  # offer.
  def build_canon_rule_filter
    @stories = Current.universe.stories.order(:name, :id)
    @list_filter = CanonRuleFilter.new(@filter_query, stories: @stories)
  end

  # The narrowed list, and the universe total a narrowed list is shown against.
  # The total is read only when a filter is really in effect, so the ordinary
  # unfiltered visit costs no extra query for it.
  def apply_canon_rule_filter
    # Universe-wide rules first, then each story's, is the unfiltered order. It
    # comes from the filter's default sort, which keeps that grouping under every
    # order the reader can choose.
    @canon_rules = @list_filter.apply(
      Current.universe.canon_rules.includes(:story))
    @canon_rule_total = Current.universe.canon_rules.count if @list_filter.narrowed?
  end

  # The canonical index URL for a set of filter values. `FilteredListQuery` owns
  # everything else about reading and carrying the filter, and this is the one
  # thing it cannot know: where this list's own URL is.
  def filtered_list_path_with(query)
    path = universe_canon_rules_path

    query.any? ? "#{path}?#{query.to_query}" : path
  end

  def set_canon_rule
    @canon_rule = Current.universe.canon_rules.find(params.expect(:id))
  end

  # Whether this update was opened from the rule's own page rather than from a
  # list row. The details page's editor carries the marker as a fixed word, so a
  # submitted value can never name a redirect destination of its own.
  def details_edit?
    params[:return_to] == "details"
  end

  # A save from a details page returns to the rule the reader was reading; a save
  # from a list row returns to the narrowed list it was performed from.
  def update_destination
    details_edit? ? universe_canon_rule_path(id: @canon_rule) : filtered_list_path
  end

  # A refused save from a details page re-renders that page, where the error
  # summary and the prefilled editor are, instead of rendering the list at the
  # rule's URL.
  def render_rejected_details_edit
    @stories = Current.universe.stories.order(:name, :id)
    render :show, status: :unprocessable_content
  end

  def canon_rule_params
    params.expect(canon_rule: [ :name, :slug, :category, :canon_type, :statement, :source, :story_id ])
  end
end
