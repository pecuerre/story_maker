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
  #
  # A command's **title is the reader's own language**, and it is also what the
  # typed text is matched against — so someone who types «personajes» is matched
  # against «Personajes». That is the point: the thing on screen is the thing
  # searched. The `id` stays a value, because it is what the dropdown marks the
  # active option with and never appears to a reader.
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
          command("universe", "searches.commands.universe_overview", universe.name, universe_path(universe_slug: universe.slug)),
          command("stories", "searches.commands.stories", universe.name, universe_stories_path(universe_slug: universe.slug))
        ]
        pages + universe_pages + story_commands
      end

      def universe_pages
        [
          command("characters", "searches.commands.characters", universe.name, universe_characters_path(universe_slug: universe.slug)),
          command("locations", "searches.commands.locations", universe.name, universe_locations_path(universe_slug: universe.slug)),
          command("events", "searches.commands.events", universe.name, universe_events_path(universe_slug: universe.slug)),
          command("items", "searches.commands.items", universe.name, universe_items_path(universe_slug: universe.slug)),
          command("relations", "searches.commands.relations", universe.name, universe_relations_path(universe_slug: universe.slug)),
          command("ownerships", "searches.commands.ownerships", universe.name, universe_ownerships_path(universe_slug: universe.slug)),
          command("timeline", "searches.commands.timeline", universe.name, universe_timeline_path(universe_slug: universe.slug)),
          command("tags", "searches.commands.tags", universe.name, universe_tags_path(universe_slug: universe.slug))
        ]
      end

      def story_commands
        return [] if story.nil?

        [
          command("story", "searches.commands.story", universe.name,
            universe_story_path(universe_slug: universe.slug, id: story.id), name: story.name),
          command("sections", "searches.commands.sections", story.name,
            universe_story_sections_path(universe_slug: universe.slug, story_id: story.id)),
          command("scenes", "searches.commands.scenes", story.name,
            universe_story_scenes_path(universe_slug: universe.slug, story_id: story.id))
        ]
      end

      # The landing page's only destinations are the universes the visitor may
      # open, which is the same readable set a platform-wide search is filtered
      # to — so the two can never disagree about who exists.
      def universe_switchers
        Universe.visible_to(user).order(:name, :id).limit(MAX_UNIVERSES).map do |candidate|
          command("universe-#{candidate.id}", "searches.commands.universe",
            I18n.t("searches.commands.open_universe"), universe_path(universe_slug: candidate.slug),
            name: candidate.name)
        end
      end

      # `key` rather than a title, resolved here rather than stored, for the
      # reason every other constant in this application holds a key and not a
      # string: a title resolved at load time would be one language forever. The
      # subtitle beside it is data — a universe's or a story's own name — so it is
      # never translated, which is why the one command whose subtitle is chrome
      # ("Open universe") translates it at the call site.
      def command(id, key, subtitle, url, name: nil)
        Command.new(id: id, title: I18n.t(key, name: name), subtitle: subtitle, url: url)
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
