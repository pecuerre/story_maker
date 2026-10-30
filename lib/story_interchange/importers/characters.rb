module StoryInterchange
  module Importers
    # A Character keeps the two things its record has columns for: a short
    # summary from `Short summary`, and one Markdown description carrying every
    # other `##` section the source wrote, in source order.
    #
    # The current file keeps only `name`, `slug`, and `affiliation` in
    # frontmatter; role, status, age, occupation, and first appearance are body
    # data under `## Information`, so they stay in the description. `At a glance`
    # is the older summary heading and is still read.
    #
    # The description is stored as written so the app can render its headings,
    # emphasis, lists, and `[[kind:slug]]` links at read time. That is the one
    # profile answer this slice deliberately does **not** resolve into plain
    # names: a link is the meaning, not decoration.
    #
    # `role`, `affiliation`, `status`, `first_appears`, and `backlog` have no
    # Character column and are reported when they appear in frontmatter.
    # `affiliation` never becomes Faction membership here: it is free text in the
    # real source and may name a Faction, another record, or prose, so the
    # operator assigns membership in the app.
    class Characters < Importer
      SUMMARY_HEADINGS = [ "short summary", "at a glance" ].freeze

      slice label_key: "imports.slices.characters",
        count: :characters,
        kind: :character,
        reported_keys: %w[role affiliation status first_appears backlog]

      # Nothing in the body is left behind: the identity block and every section
      # land in the description, except the summary. Only the frontmatter keys
      # with no column are reported.
      def self.reported(report)
        report.entities(:character).flat_map do |entity|
          reported_keys.filter_map do |key|
            "#{entity.slug}: #{key}" if entity.frontmatter[key].present?
          end
        end
      end

      def call
        write_entities(Character)
      end

      private
        def attributes_for(entity)
          record_attributes(entity).merge(
            summary: summary_for(entity),
            description: description_for(entity)
          )
        end

        def summary_for(entity)
          section = entity.sections.find { |candidate| SUMMARY_HEADINGS.include?(normalized_heading(candidate.heading)) }
          section && self.class.resolve_references(report, section.body)
        end

        # The source's identity block, then every `##` section except the
        # summary's. References stay in their source form so the details page can
        # turn each one into a link to the record it names.
        def description_for(entity)
          parts = []
          parts << entity.introduction if entity.introduction.present?

          entity.sections.each do |section|
            next if SUMMARY_HEADINGS.include?(normalized_heading(section.heading))

            parts << "## #{section.heading}\n\n#{section.body}"
          end

          parts.join("\n\n").presence
        end

        def normalized_heading(heading)
          heading.to_s.downcase.squish
        end
    end
  end
end
