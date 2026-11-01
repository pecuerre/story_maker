module StoryInterchange
  module Importers
    # A `tech/` file is an Item, not a new record kind. It keeps only the fields
    # its record has columns for: a name, its place in the hierarchy, and one
    # Markdown description carrying every `##` section the source wrote, in
    # source order.
    #
    # The current file keeps only `name` and `slug` in frontmatter; `type`,
    # `invented_by`, `status`, and `backlog` are body data under `## Information`,
    # so they stay in the description. An older file that still carries them in
    # frontmatter has them reported.
    #
    # The description is stored as written so the app can render its headings,
    # lists, and `[[kind:slug]]` links at read time. That is the one profile
    # answer this slice deliberately does **not** resolve into plain names: a
    # link is the meaning, not decoration.
    #
    # The source is flat and an Item carries a `parent_id`, but a filename says
    # nothing about the hierarchy, so every imported Item is top-level and the
    # operator builds the tree in the app.
    class Items < Importer
      slice label_key: "imports.slices.items",
        count: :items,
        kind: :item,
        reported_keys: %w[type invented_by status backlog]

      # Nothing in the body is left behind: the identity block and every section
      # land in the description. Only the frontmatter keys with no column are
      # reported.
      class << self
        private
          def reported_entries(_report, entity)
            reported_keys.filter_map do |key|
              Importer::Note.new(:frontmatter, key) if entity.frontmatter[key].present?
            end
          end
      end

      def call
        write_entities(Item)
      end

      private
        def attributes_for(entity)
          record_attributes(entity).merge(description: description_for(entity))
        end

        # The source's identity block, then every `##` section, in source order.
        # References stay in their source form so the details page can turn each
        # one into a link to the record it names.
        def description_for(entity)
          parts = []
          parts << entity.introduction if entity.introduction.present?

          entity.sections.each do |section|
            parts << "## #{section.heading}\n\n#{section.body}"
          end

          parts.join("\n\n").presence
        end
    end
  end
end
