# The scope dropdown, shared by the top-bar search box and the results page, so
# the two can never offer a different set of scopes.
#
# The list is rendered on the server rather than built in the browser, which is
# what lets the two parts agree for free and what makes the box work with
# scripting turned off: the `<select>` is a plain control inside a plain GET
# form, and a scope is an ordinary query value.
#
# An option's `value` is that query value and is never translated, while its
# `label` is resolved per request from `searches.scopes.*` by
# `Search::Scope::Option#label`. Both surfaces therefore offer the same fourteen
# scopes with the same fourteen wordings, in whatever language the reader asked
# for, and a link carrying `?scope=characters` keeps working in all of them.
module SearchesHelper
  def search_scope_options(universe:, story:)
    Search::Scope::OPTIONS.map do |option|
      {
        value: option.value,
        label: option.label,
        available: Search::Scope.available?(option, universe: universe, story: story)
      }
    end
  end

  # The scope the top-bar dropdown shows. On the search page that is the scope
  # the request actually resolved to, which is not always the one that was asked
  # for: a story search with no story selected is widened, and the box must show
  # what was searched rather than what was requested.
  def search_selected_scope
    @query&.scope&.display_value.presence || params[:scope].presence ||
      Search::Scope.default_for(Current.universe)
  end

  # Where a search form points, and where a result page's links point. A search
  # made inside a universe keeps that universe in its URL, so the shared universe
  # callbacks resolve and authorize the scope the same way they do for every
  # other page of that universe.
  def search_path_for(universe, query = {})
    if universe
      universe_search_path(universe_slug: universe.slug, **query.symbolize_keys)
    else
      search_path(query.symbolize_keys)
    end
  end
end
