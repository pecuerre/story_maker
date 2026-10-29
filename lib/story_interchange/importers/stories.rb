module StoryInterchange
  module Importers
    # Stories come first among the story-owned records, because a Plot needs the
    # Story it belongs to. One Story per directory: the directory name is its
    # slug and its README's `#` heading is its name.
    #
    # The README's prose and its reading-order table are presentation, not data:
    # the table is regenerated for a human and the introduction has no Story
    # column to fill, so neither is written.
    class Stories < Importer
      slice label_key: "imports.slices.stories", count: :stories

      def call
        created = report.stories.map do |story|
          Story.create!(universe: universe, slug: story[:slug], name: story[:name])
        end

        Outcome.new(label_key: label_key, created: created.size, skipped: [])
      end
    end
  end
end
