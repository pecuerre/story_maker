module Search
  # The search request, as a value object: the text, the scope, and the story
  # boundary, with every value that could not be used reported in `discarded`.
  #
  # It reads only the query keys in `PARAMS` and never assigns them to a record,
  # and it is the single place a request is judged usable — so the results page,
  # the autocomplete, and the search tasks all agree about what was asked for.
  #
  # Query contract for `GET /search` and `GET /u/:universe_slug/search`:
  #
  #   `q`         free text over a record's own title and body
  #   `scope`     a `Search::Scope` value: a boundary or a record kind
  #   `story_id`  the story boundary, a story of the current universe
  #
  # A value that cannot be used is dropped and reported, exactly as `SceneFilter`
  # reports a section id from another story, rather than silently emptying the
  # result. Each message is translated where it is dropped, so the controller's
  # `to_sentence` joins them in the reader's language.
  class Query
    PARAMS = %i[ q scope story_id ].freeze
    MINIMUM_LENGTH = Search::Dropdown::MINIMUM_LENGTH
    # A long query cannot be answered by anything, and the engine spends real
    # time on it. It is cut rather than refused so the reason stays visible.
    MAXIMUM_LENGTH = 200

    attr_reader :text, :scope, :story, :universe, :discarded

    def initialize(params, universe: nil)
      @universe = universe
      @text = normalize(params[:q])
      @story = resolve_story(params[:story_id], universe)
      @scope = Scope.new(params[:scope], universe: universe, story: story)
      @discarded = @story_discarded + scope.discarded
    end

    # Enough characters to be worth asking the engine.
    def searchable?
      text.length >= MINIMUM_LENGTH
    end

    def applied?
      text.present?
    end

    # Something was typed, but not enough to search for. The interface says so
    # instead of pretending there were no matches.
    def too_short?
      applied? && !searchable?
    end

    def kind
      scope.kind
    end

    def boundary
      scope.boundary
    end

    # The request as canonical query keys, so a link, a form, or a redirect can
    # carry exactly the search that is really in effect. A dropped story is not
    # carried over.
    def query_params
      params = {}
      params[:q] = text if text.present?
      params[:scope] = scope.value
      params[:story_id] = story.id.to_s if story
      params
    end

    private
      def normalize(value)
        text = value.to_s.strip
        text = text.first(MAXIMUM_LENGTH) if text.length > MAXIMUM_LENGTH
        text
      end

      # The story boundary is a story of the current universe and nothing else.
      # `SearchesController` skips the shared `set_current_story` callback, so
      # this is a search boundary only: searching within a story must never
      # change the story the rest of the application is working in.
      def resolve_story(value, universe)
        @story_discarded = []
        requested = value.to_s.strip
        return if requested.blank?

        if universe.nil?
          @story_discarded << I18n.t("searches.discarded.story_without_universe")
          return
        end

        story = universe.stories.find_by(id: requested)
        if story
          story
        else
          @story_discarded << I18n.t("searches.discarded.story_outside_universe")
          nil
        end
      end
  end
end
