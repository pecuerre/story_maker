module Search
  # Runs a `Search::Query` against the engine and answers the two questions a
  # result list cannot answer for itself: *may* this reader see these records, and
  # *what are they called*.
  #
  # Authorization is a filter, not a post-filter. The engine is asked only for
  # documents whose universe the reader may read, using the same rule as
  # `Ability` — `Universe.visible_to` is the scope behind
  # `Universe#readable_by?`, which is what `can :read, Universe` asks — so a
  # private universe's records are never fetched and then hidden. A reader with
  # no readable universe gets an empty result rather than an unfiltered search.
  class Catalog
    # Enough to fill the dropdown without scrolling, and few enough that a
    # keystroke's answer stays quick.
    DROPDOWN_LIMIT = 8
    PAGE_LIMIT = 25
    # A filter list this long is beyond any plausible membership count. It is
    # logged rather than dropped, because the filter is the only thing keeping a
    # private universe's records out of a platform-wide answer.
    MAX_FILTERABLE_UNIVERSES = 1000

    def initialize(backend: Search.backend, user: Current.user)
      @backend = backend
      @user = user
    end

    # Raises `Search::Unavailable` when the engine cannot answer. A query too
    # short to be worth asking, or a reader with no readable universe, returns an
    # empty result set without calling the engine at all.
    def results(query, limit: PAGE_LIMIT, offset: 0)
      return Search::ResultSet.new unless query.searchable?
      return Search::ResultSet.new unless readable_scope?(query)

      found = @backend.search(text: query.text, filter: engine_filter(query), limit: limit, offset: offset)
      describe(found.hits, query)
      found
    end

    # The universes a platform-wide answer is allowed to reach. One query, per
    # request, whatever the number of results.
    def visible_universe_ids
      return @visible_universe_ids if defined?(@visible_universe_ids)

      ids = Universe.visible_to(@user).order(:id).pluck(:id)
      if ids.size > MAX_FILTERABLE_UNIVERSES
        Rails.logger.warn do
          "[search] #{ids.size} readable universes exceeds the #{MAX_FILTERABLE_UNIVERSES} a filter can carry"
        end
      end
      @visible_universe_ids = ids
    end

    private
      attr_reader :backend, :user

      # A universe or story boundary is already authorized: the shared
      # `authorize_universe_access` callback resolved and checked the universe,
      # and a story boundary is a story of that universe. Only the platform
      # boundary needs the readable set computed here.
      def readable_scope?(query)
        return true unless query.boundary == Scope::PLATFORM

        visible_universe_ids.any?
      end

      def engine_filter(query)
        clauses = [ boundary_clause(query) ]
        clauses << %(kind = "#{escape(query.kind)}") if query.kind
        clauses.compact.join(" AND ")
      end

      def boundary_clause(query)
        case query.boundary
        when Scope::STORY then "story_id = #{query.story.id}"
        when Scope::UNIVERSE then "universe_id = #{query.universe.id}"
        else "universe_id IN [#{visible_universe_ids.join(", ")}]"
        end
      end

      def escape(value)
        value.to_s.gsub(/["\\]/) { |character| "\\#{character}" }
      end

      # A hit stores ids, not names, so that renaming a universe or a story
      # cannot leave every record that mentions it showing a stale name — and
      # cannot require reindexing them. Two queries, whatever the page size.
      def describe(hits, query)
        return hits if hits.empty?

        universes = Universe.where(id: hits.filter_map(&:universe_id).uniq).pluck(:id, :name).to_h
        stories = Story.where(id: hits.filter_map(&:story_id).compact.uniq).pluck(:id, :name).to_h

        hits.each do |hit|
          context = [ stories[hit.story_id], universes[hit.universe_id] ].compact.uniq.join(" · ")
          hit.describe(context: context, query: query.text)
        end
      end
  end
end
