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
    # Plot Scene assignments come from the Scene side: every scene's optional
    # `plot` frontmatter names the thread it dramatises. This slice runs after
    # Scenes, so it assigns those Scenes once every Plot exists. The source's
    # `## Progression` rows are the human view of the same join and stay in the
    # description rather than being read a second way.
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
        plots = report.entities(:plot).map do |entity|
          Plot.create!(**attributes_for(entity))
        end

        plots.each { |plot| assign_scenes(plot) }

        Outcome.new(label_key: label_key, created: plots.size, records: self.class.records(report))
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

        # The Scenes that name this thread in their own `plot` frontmatter. The
        # validator already refused a `plot` that names no thread in the Story,
        # so every assignment has a Scene record; a Scene that names no thread is
        # simply absent. `scenes=` keeps the model's same-Story and uniqueness
        # checks as the one place the join is validated.
        def assign_scenes(plot)
          story = plot.story
          slugs = report.entities(:scene).filter_map do |entity|
            next unless entity.story_slug == story.slug
            next unless entity.frontmatter["plot"].to_s.strip == plot.slug

            entity.scene_slug
          end
          return if slugs.empty?

          plot.scenes = story.scenes.where(slug: slugs).to_a
        end
    end
  end
end
