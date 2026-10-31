module StoryInterchange
  module Importers
    # A `tech/` file is an Item, not a new record kind. Its sections map to the
    # Item profile and its invented-by field becomes `origin`, with a `[[slug]]`
    # resolved to the name of the Faction or Character this run writes. The
    # current source keeps that field as the `Invented by` bullet under
    # `## Information`; the older `invented_by` frontmatter key is still read.
    #
    # `type`, `status`, and `backlog` have no Item column, so they are reported
    # along with the sections the app does not keep (Short summary, Information,
    # In the story, Open questions). The source is flat and an Item carries a
    # `parent_id`, but a filename says nothing about the hierarchy, so every
    # imported Item is top-level and the operator builds the tree in the app.
    class Items < Importer
      INFORMATION_HEADING = "information"
      ORIGIN_LABEL = /\Ainvented by\z/i

      slice label_key: "imports.slices.items",
        count: :items,
        kind: :item,
        profile: {
          "one line" => :what_it_does,
          "what it actually is" => :description,
          "how it is operated" => :how_it_is_used,
          "physical side effects" => :side_effects,
          "cannot" => :cannot,
          "costs" => :value,
          "constraints" => :constraints,
          "jargon" => :jargon,
          "history" => :history
        },
        reported_keys: %w[type status backlog]

      def call
        write_entities(Item)
      end

      private
        # The invented-by field is the one value that names a column. It is resolved
        # like a profile answer, so `[[wardens]]` reads as "The Wardens".
        def attributes_for(entity)
          super.merge(origin: origin_for(entity))
        end

        # The current source writes `- Invented by: …` under `## Information`.
        # The older frontmatter key wins when a file still carries both.
        def origin_for(entity)
          frontmatter = entity.frontmatter["invented_by"]
          return self.class.resolve_references(report, frontmatter) if frontmatter.present?

          section = entity.sections.find do |candidate|
            candidate.heading.to_s.downcase.squish == INFORMATION_HEADING
          end
          item = section && grouped_items(section.body).find { |label, _text| label.to_s.match?(ORIGIN_LABEL) }
          item && self.class.resolve_references(report, item.last)
        end
    end
  end
end
