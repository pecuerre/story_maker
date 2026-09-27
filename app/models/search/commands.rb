module Search
  # The navigation half of the search box: the pages a reader can jump to from
  # the same box that finds records.
  #
  # Commands are built from the database on each request rather than indexed,
  # because they are derived from what *this* reader can reach right now — the
  # universes they may open, and the pages and stories of the universe in front of
  # them. An index would answer a question nobody asked and would be wrong
  # whenever access changed.
  #
  # Commands follow the search's boundary: on the landing page they are the
  # universes the visitor may open, and inside a universe they are that
  # universe's own pages and stories. Mixing the two would offer "switch
  # universe" in the middle of a story search.
  class Commands
    include Rails.application.routes.url_helpers

    # A dropdown that lists a dozen destinations is a menu, not a search result.
    MAX_MATCHES = 6
    # A reader belongs to a handful of universes. Capping the list keeps the
    # dropdown quick and keeps a large membership from turning a keystroke into a
    # thousand-row query.
    MAX_UNIVERSES = 8
    # An exact start of the label is the strongest signal, a word start next, and
    # a substring last. The scores are only ever compared with each other.
    PREFIX_SCORE = 0
    WORD_START_SCORE = 1
    CONTAINS_SCORE = 2

    Command = Data.define(:id, :title, :subtitle, :url) do
      def as_json(*)
        { id: id, title: title, subtitle: subtitle, url: url }
      end
    end

    attr_reader :text, :universe, :story

    def initialize(text:, universe: nil, story: nil, user: nil)
      @text = text.to_s.strip
      @universe = universe
      @story = story
      @user = user
    end

    def to_a
      needle = text.downcase
      return [] if needle.blank?

      candidates.filter_map { |command| match(command, needle) }
        .sort_by { |score, title, _| [ score, title ] }
        .first(MAX_MATCHES)
        .map(&:last)
    end

    def any?
      to_a.any?
    end

    private
      attr_reader :user

      def candidates
        @candidates ||= universe ? universe_candidates : universe_switchers
      end

      # Inside a universe, every destination already belongs to the boundary the
      # search is using, so the commands stay inside it.
      def universe_candidates
        pages = [
          command("universe", "Universe overview", universe.name, universe_path(universe_slug: universe.slug)),
          command("stories", "All stories", universe.name, universe_stories_path(universe_slug: universe.slug))
        ]
        pages + universe_pages + story_commands
      end

      def universe_pages
        [
          command("characters", "Characters", universe.name, universe_characters_path(universe_slug: universe.slug)),
          command("locations", "Locations", universe.name, universe_locations_path(universe_slug: universe.slug)),
          command("events", "Events", universe.name, universe_events_path(universe_slug: universe.slug)),
          command("items", "Items", universe.name, universe_items_path(universe_slug: universe.slug)),
          command("relations", "Relations", universe.name, universe_relations_path(universe_slug: universe.slug)),
          command("ownerships", "Ownerships", universe.name, universe_ownerships_path(universe_slug: universe.slug)),
          command("timeline", "Timeline", universe.name, universe_timeline_path(universe_slug: universe.slug)),
          command("tags", "Tags", universe.name, universe_tags_path(universe_slug: universe.slug))
        ]
      end

      def story_commands
        return [] if story.nil?

        [
          command("story", "Story: #{story.name}", universe.name,
            universe_story_path(universe_slug: universe.slug, id: story.id)),
          command("sections", "Sections", story.name,
            universe_story_sections_path(universe_slug: universe.slug, story_id: story.id)),
          command("scenes", "Scenes", story.name,
            universe_story_scenes_path(universe_slug: universe.slug, story_id: story.id))
        ]
      end

      # The landing page's only destinations are the universes the visitor may
      # open, which is the same readable set a platform-wide search is filtered
      # to — so the two can never disagree about who exists.
      def universe_switchers
        Universe.visible_to(user).order(:name, :id).limit(MAX_UNIVERSES).map do |candidate|
          command("universe-#{candidate.id}", "Universe: #{candidate.name}", "Open universe",
            universe_path(universe_slug: candidate.slug))
        end
      end

      def command(id, title, subtitle, url)
        Command.new(id: id, title: title, subtitle: subtitle, url: url)
      end

      def match(command, needle)
        label = command.title.downcase
        score = if label.start_with?(needle)
          PREFIX_SCORE
        elsif label.match?(/(?:\A|\s)#{Regexp.escape(needle)}/)
          WORD_START_SCORE
        elsif label.include?(needle)
          CONTAINS_SCORE
        end

        [ score, command.title, command ] if score
      end
  end
end
