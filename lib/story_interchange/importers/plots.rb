module StoryInterchange
  module Importers
    # A Plot is Story-owned, and the source's `## The question` section is the
    # description it lands with. Its remaining sections are not profile answers
    # and are reported, as are the frontmatter keys with no Plot column: `type`,
    # `status`, `owner_pov`, `opened_in`, and `backlog`.
    #
    # Scene assignments cannot arrive until the Scene slice exists, so a Plot is
    # written with no Scenes and the operator assigns them in the app.
    class Plots < Importer
      slice label_key: "imports.slices.plots",
        count: :plots,
        kind: :plot,
        profile: { "the question" => :description },
        reported_keys: %w[type status owner_pov opened_in backlog]

      def call
        write_entities(Plot)
      end

      private
        # A Plot names its Story instead of the Universe. The Stories slice ran
        # first, so the record the entity names already exists.
        def record_attributes(entity)
          { name: entity.name, slug: entity.slug, story: universe.stories.find_by!(slug: entity.story_slug) }
        end
    end
  end
end
