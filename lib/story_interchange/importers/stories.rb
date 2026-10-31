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

      class << self
        # A Story has no profile, so nothing is left behind and only its name is
        # listed.
        def records(report)
          report.stories.map do |story|
            Importer::Record.new(
              name: story[:name],
              slug: story[:slug],
              notes: []
            )
          end
        end
      end

      def call
        created = report.stories.map do |story|
          Story.create!(universe: universe, slug: story[:slug], name: story[:name])
        end

        Outcome.new(label_key: label_key, created: created.size, records: [])
      end
    end
  end
end
