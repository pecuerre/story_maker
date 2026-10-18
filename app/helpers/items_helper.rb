module ItemsHelper
  # "Label: value" descriptions of the filters currently in effect, in the order
  # the search area lists them. The result set of a large universe is otherwise
  # ambiguous, and an empty result has to be able to say what caused it.
  #
  # Each entry is its own key rather than one frame with the field name
  # interpolated, because "Sort: Recently edited" is a different sentence in each
  # language than "Tag: House / Winter" is.
  #
  # The sort is described rather than omitted because a reader who reordered the
  # list and got nothing back needs to know that the order was applied and was
  # not the reason the list is short.
  def item_filter_summaries(filter)
    summaries = []
    summaries << t("items.filter.summaries.search", value: filter.text) if filter.text.present?
    if filter.item_tag
      summaries << t("items.filter.summaries.tag", value: @item_tag_paths.label_for(filter.item_tag))
    end
    summaries << t("items.filter.summaries.sort", value: t("items.filter.sort_options.#{filter.sort}")) if filter.sort != ItemFilter::DEFAULT_SORT
    summaries
  end

  # The tag options the filter's selector offers, in root-first order. Built from
  # the paths rather than the flat query order so a child cannot appear before
  # its parent after a reparent or position edit.
  def item_filter_tag_choices
    @item_tag_paths.choices
  end
end
