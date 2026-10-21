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

  # The characters who currently own this item: ownerships with an open `to_date`
  # (still holding it), named as a sentence. An ownership with no `to_date` is an
  # open interval, so the character still holds the item.
  def item_current_owners(item)
    current = item.ownerships.select { |o| o.to_date.nil? }.map(&:character).compact
    current.map(&:name).to_sentence
  end

  # The characters who historically owned this item: ownerships with a `to_date`,
  # named as a sentence. An ownership with both dates is a closed interval, so
  # the character no longer holds the item.
  def item_historical_owners(item)
    historical = item.ownerships.select { |o| o.to_date.present? }.map(&:character).compact
    historical.map(&:name).to_sentence
  end
end
