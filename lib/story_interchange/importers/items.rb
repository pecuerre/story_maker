module StoryInterchange
  module Importers
    # A `tech/` file is an Item, not a new record kind. Its sections map to the
    # Item profile and its `invented_by` frontmatter becomes `origin`, with a
    # `[[slug]]` resolved to the name of the Faction or Character this run
    # writes.
    #
    # `type`, `status`, and `backlog` have no Item column, so they are reported
    # along with the sections the app does not keep (In the story, Open
    # questions). The source is flat and an Item carries a `parent_id`, but a
    # filename says nothing about the hierarchy, so every imported Item is
    # top-level and the operator builds the tree in the app.
    class Items < Importer
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
        # `invented_by` is the one frontmatter key that names a column. It is
        # resolved like a profile answer, so `[[wardens]]` reads as "The Wardens".
        def attributes_for(entity)
          super.merge(origin: self.class.resolve_references(report, entity.frontmatter["invented_by"]))
        end
    end
  end
end
