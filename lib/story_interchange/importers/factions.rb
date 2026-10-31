module StoryInterchange
  module Importers
    # A Faction keeps the two things its record has columns for: a short summary
    # from `Short summary`, and one Markdown description carrying every other
    # `##` section the source wrote, in source order.
    #
    # The current file keeps only `name` and `slug` in frontmatter; `type`,
    # `home`, `status`, and `backlog` are body data under `## Information`, so
    # they stay in the description. `Mission` is the older summary heading and
    # is still read when a file has no `Short summary`; when both are present,
    # `Short summary` is the summary and `Mission` is one more section in the
    # description.
    #
    # The description is stored as written so the app can render its headings,
    # lists, and `[[kind:slug]]` links at read time. That is the one profile
    # answer this slice deliberately does **not** resolve into plain names: a
    # link is the meaning, not decoration.
    #
    # `type`, `home`, `status`, and `backlog` have no Faction column and are
    # reported when an older file still carries them in frontmatter.
    class Factions < Importer
      SHORT_SUMMARY_HEADING = "short summary"
      LEGACY_SUMMARY_HEADING = "mission"

      slice label_key: "imports.slices.factions",
        count: :factions,
        kind: :faction,
        reported_keys: %w[type home status backlog]

      # Nothing in the body is left behind: the identity block and every section
      # land in the description, except the summary. Only the frontmatter keys
      # with no column are reported.
      class << self
        private
          def reported_entries(_report, entity)
            reported_keys.filter_map do |key|
              Importer::Note.new(:frontmatter, key) if entity.frontmatter[key].present?
            end
          end
      end

      def call
        write_entities(Faction)
      end

      private
        def attributes_for(entity)
          record_attributes(entity).merge(
            summary: summary_for(entity),
            description: description_for(entity)
          )
        end

        def summary_for(entity)
          section = summary_section(entity)
          section && self.class.resolve_references(report, section.body)
        end

        # The source's identity block, then every `##` section except the
        # summary's. References stay in their source form so the details page can
        # turn each one into a link to the record it names.
        def description_for(entity)
          summary = summary_section(entity)
          parts = []
          parts << entity.introduction if entity.introduction.present?

          entity.sections.each do |section|
            next if section.equal?(summary)

            parts << "## #{section.heading}\n\n#{section.body}"
          end

          parts.join("\n\n").presence
        end

        # `Short summary` is the current heading. `Mission` was the summary
        # before the faction format split the two, so it is the fallback only
        # when the file carries no `Short summary`.
        def summary_section(entity)
          entity.sections.find { |section| normalized_heading(section.heading) == SHORT_SUMMARY_HEADING } ||
            entity.sections.find { |section| normalized_heading(section.heading) == LEGACY_SUMMARY_HEADING }
        end

        def normalized_heading(heading)
          heading.to_s.downcase.squish
        end
    end
  end
end
