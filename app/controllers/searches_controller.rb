# The top-bar search. One read that answers both surfaces.
#
# HTML is the results page: a shareable, keyboard-reachable answer that works
# with scripting turned off, and a place where a result set can be explained.
# JSON is the autocomplete dropdown the Stimulus controller asks for as the
# reader types. Neither ever writes, so this controller has no mutation path, no
# mass assignment, and nothing for a CSRF token to protect.
#
# The search box is in the top bar, so this action answers on every page,
# including the landing page and for a guest. That is why it never raises for an
# unavailable engine: the page it is on still has to render.
class SearchesController < ApplicationController
  # The box is in the top bar of every page, and a public universe is readable by
  # a guest, so a search is too. Reading is the whole of this action: it writes
  # nothing and changes nothing, so there is no access level to require.
  allow_unauthenticated_access

  # A search must never change the story the rest of the application is working
  # in. `set_current_story` remembers `params[:story_id]` in the session, so
  # typing in the search box would silently switch the current story as a side
  # effect of reading. The story *boundary* is resolved by `Search::Query`
  # instead, and nothing about it is written down.
  skip_before_action :set_current_story

  # A page number beyond this is a hand-edited URL, not a reader's choice.
  MAX_PAGE = 100
  helper_method :current_page

  # The current story, resolved the way the shared callback resolves it but
  # without writing it down. The box on this page still has to know which story it
  # is in — otherwise "this story" would be unavailable on the one page whose
  # whole purpose is choosing a scope, and the story boundary could only be set
  # from somewhere else.
  before_action :set_search_story

  def show
    @query = Search::Query.new(search_params, universe: Current.universe)
    @search_results = search_results
    @search_commands = search_commands
    flash.now[:alert] = @query.discarded.to_sentence if @query.discarded.any?

    respond_to do |format|
      format.html
      format.json { render json: search_payload }
    end
  end

  private
    def set_search_story
      Current.story = nil
      return if Current.universe.nil?
      # A requested story is the search's boundary, resolved by `Search::Query`
      # from this universe's stories. It is deliberately not made current.
      return if params[:story_id].present?

      Current.story = Current.universe.stories
        .find_by(id: remembered_story_ids[Current.universe.id.to_s])
    end

    # The same read for both formats. A search too short to be worth asking, or
    # an engine that cannot answer, is a stated state and never an exception:
    # `flash.now[:alert]` is how the page reports a value it could not use.
    def search_results
      @search_results ||= begin
        Search::Catalog.new.results(@query, limit: result_limit, offset: result_offset)
      rescue Search::Unavailable => error
        Rails.logger.warn { "[search] #{error.message}" }
        @search_unavailable = error.message
        Search::ResultSet.new
      end
    end

    # Commands follow the same minimum length as records. A one-character query
    # that returned destinations but no records would say two different things
    # about the same question, and the page would have said neither.
    def search_commands
      @search_commands ||= if @query.searchable? && @query.scope.commands?
        Search::Commands.new(text: @query.text, universe: Current.universe,
          story: @query.story, user: Current.user).to_a
      else
        []
      end
    end

    def result_limit
      request.format.json? ? Search::Catalog::DROPDOWN_LIMIT : Search::Catalog::PAGE_LIMIT
    end

    def current_page
      @current_page ||= params[:page].to_s.to_i.clamp(1, MAX_PAGE)
    end

    # The engine refuses an offset past the index's own result limit, and that
    # refusal would reach the reader as "search is unavailable". The furthest page
    # is therefore the last one the engine can answer for.
    def result_offset
      return 0 if request.format.json?

      last_offset = Search::Client::SETTINGS[:pagination][:maxTotalHits] - Search::Catalog::PAGE_LIMIT
      [ (current_page - 1) * Search::Catalog::PAGE_LIMIT, last_offset ].min
    end

    def search_payload
      {
        available: @search_unavailable.nil?,
        reason: @search_unavailable,
        query: @query.text,
        scope: @query.scope.value,
        scope_label: @query.scope.label,
        total: search_results.total,
        discarded: @query.discarded,
        commands: search_commands.map(&:as_json),
        results: search_results.hits.map(&:as_json)
      }
    end

    # Only the keys a search is made of, exactly as `SceneFilter` reads its own.
    # Nothing here is ever assigned to a record.
    def search_params
      params.slice(*Search::Query::PARAMS).permit(*Search::Query::PARAMS)
    end
end
