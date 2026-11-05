module StoryInterchange
  module Importers
    # A Plot keeps the two things its record has columns for: a short summary
    # from `Short summary`, and one Markdown description carrying the identity
    # block and every other `##` section the source wrote, in source order.
    #
    # The current plot file keeps only `name` and `slug` in frontmatter; type,
    # status, owner POV, the opening scene, and the backlog item are body data
    # under `## Information`, so they stay in the description. The older
    # frontmatter keys are still accepted and reported by name.
    #
    # The description is stored as written so the app can render its headings,
    # lists, and `[[kind:slug]]` links at read time. The short summary is the one
    # answer resolved to plain names, because it is a list row rather than a
    # page.
    #
    # Scene assignments cannot arrive until the Scene slice exists, so a Plot is
    # written with no Scenes and the operator assigns them in the app.
    class Plots < Importer
      SHORT_SUMMARY_HEADING = "short summary"

      slice label_key: "imports.slices.plots",
        count: :plots,
        kind: :plot,
        reported_keys: %w[type status owner_pov opened_in backlog]

      # Every body section lands in the description except the short summary, so
      # only the frontmatter keys with no Plot column are reported.
      class << self
        private
          def reported_entries(_report, entity)
            reported_keys.filter_map do |key|
              Importer::Note.new(:frontmatter, key) if entity.frontmatter[key].present?
            end
          end
      end

      def call
        write_entities(Plot)
      end

      private
        def attributes_for(entity)
          record_attributes(entity).merge(
            short_summary: summary_for(entity),
            description: description_for(entity)
          )
        end

        # A Plot names its Story instead of the Universe. The Stories slice ran
        # first, so the record the entity names already exists.
        def record_attributes(entity)
          { name: entity.name, slug: entity.slug, story: universe.stories.find_by!(slug: entity.story_slug) }
        end

        def summary_for(entity)
          section = summary_section(entity)
          section && self.class.resolve_references(report, section.body)
        end

        # The source's identity block, then every `##` section except the short
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

        def summary_section(entity)
          entity.sections.find { |section| section.heading.to_s.downcase.squish == SHORT_SUMMARY_HEADING }
        end
    end
  end
end
