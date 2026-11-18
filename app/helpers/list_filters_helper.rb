# The one thing every in-list filter's search area shares besides the
# `ListFilter` contract: how many of its narrowing controls are in effect, so the
# closed **Advanced filters** disclosure can still report its own state.
#
# The count comes from `query_params`, which is already the canonical answer to
# "what is really in effect", rather than from the form controls. A value that was
# dropped for being unusable is not in effect and therefore is not counted, which
# is the same rule the summary badges and `active?` follow.
module ListFiltersHelper
  # The always-visible controls are the search and, where a workspace offers one,
  # the order. The names come from `ListFilter` so the view helper and the value
  # object cannot disagree about which query keys they are.
  ALWAYS_VISIBLE_FILTER_KEYS = [ ListFilter::TEXT_PARAM, ListFilter::SORT_PARAM ].map(&:to_s).freeze

  # How many narrowing criteria are in effect. A chosen order is not counted: the
  # state line already names it, and the disclosure's badge is about filters.
  def advanced_filter_count(filter)
    filter.query_params.keys.count { |key| ALWAYS_VISIBLE_FILTER_KEYS.exclude?(key.to_s) }
  end
end
