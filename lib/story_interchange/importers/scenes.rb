module StoryInterchange
  module Importers
    # A Scene file becomes one Scene inside the Section its chapter directory
    # names. The frontmatter that has an application column is written: `title`
    # is the Scene's name, `chapter` groups it under that Section, `sequence`
    # and the chapter order decide its place in the Story's flat sequence,
    # `pov` is the point-of-view Character, `location` is a Location presence
    # link, and `status` is the writing status.
    #
    # The body is manuscript prose. It opens with the Scene's own `##` title
    # heading, which names the record rather than being a section; any further
    # `##` heading is reported, because the Scene contract has no sections. HTML
    # comments are drafting notes and never reach stored prose.
    #
    # The source has no per-block marker, so every blank-line-separated
    # paragraph becomes one Narration Element: the first carries the Scene's
    # title and each later one is numbered, because an Element requires a Title
    # and the source records no block titles. Nothing is split into Dialogue,
    # because the source records no speaker or line — dialogue attribution is
    # preserved only where the source states it.
    #
    # `id`, `timeline`, `branch`, and `depends_on` are source facts with no
    # Scene column. `timeline` is deliberately author prose ("ninth day after
    # the flare") rather than a parseable date, so it is reported instead of
    # guessed into `datetime`.
    class Scenes < Importer
      slice label_key: "imports.slices.scenes",
        count: :scenes,
        kind: :scene,
        reported_keys: %w[id timeline branch depends_on]

      class << self
        private
          # A Scene's introduction is the manuscript prose this slice writes as
          # Elements, so it is not reported; its `##` sections are.
          def reported_entries(report, entity)
            entries = []

            entity.sections.each do |section|
              entries << "#{entity.slug}: #{section.heading}"
            end

            reported_keys.each do |key|
              entries << "#{entity.slug}: #{key}" if entity.frontmatter[key].present?
            end

            entries.concat(prose_references(report, entity))
          end

          # A `[[slug]]` this run cannot resolve stays exactly as written in the
          # prose, so the preview names it like an unmapped profile reference.
          def prose_references(report, entity)
            entity.introduction.scan(Document::REFERENCE).flatten.map(&:strip).uniq.filter_map do |target|
              "#{entity.slug}: [[#{target}]]" if unresolved?(report, target)
            end
          end
      end

      def call
        positions = Hash.new(0)

        created = report.entities(:scene).map do |entity|
          story = universe.stories.find_by!(slug: entity.story_slug)
          position = positions[story.id]
          positions[story.id] += 1

          scene = Scene.create!(scene_attributes(entity, story, position))
          link_location(scene, entity)
          write_elements(scene, entity)
          scene
        end

        Outcome.new(label_key: label_key, created: created.size, skipped: self.class.reported(report))
      end

      private
        # A blank or `— TBD` value means the Scene has not recorded one.
        TBD_PREFIX = "—"

        def scene_attributes(entity, story, position)
          {
            story: story,
            section: story.sections.find_by!(slug: entity.frontmatter["chapter"]),
            position: position,
            name: entity.frontmatter["title"],
            slug: "#{entity.frontmatter["chapter"]}-#{entity.slug}",
            status: entity.frontmatter["status"],
            pov_character: character_for(entity)
          }
        end

        def character_for(entity)
          slug = named_slug(entity.frontmatter["pov"])
          slug && universe.characters.find_by!(slug: slug)
        end

        # The source's `location` is the place the Scene happens in, which the
        # application keeps as an explicit Location presence link with no role.
        def link_location(scene, entity)
          slug = named_slug(entity.frontmatter["location"])
          return if slug.nil?

          SceneLocation.create!(scene: scene, location: universe.locations.find_by!(slug: slug))
        end

        def write_elements(scene, entity)
          paragraphs(entity.introduction).each_with_index do |paragraph, index|
            SceneElement.create!(
              scene: scene,
              kind: SceneElement::NARRATION,
              name: element_name(scene, index),
              body: self.class.resolve_references(report, paragraph),
              position: index
            )
          end
        end

        # One block per blank-line-separated paragraph, kept as written.
        def paragraphs(text)
          text.to_s.split(/\n[ \t]*\n/).map(&:strip).reject(&:empty?)
        end

        # An Element's Title is required and the prose carries none, so the
        # Scene's own title names the first block and later ones are numbered.
        def element_name(scene, index)
          index.zero? ? scene.name : "#{scene.name} (#{index + 1})"
        end

        def named_slug(value)
          text = value.to_s.strip
          return nil if text.empty? || text.start_with?(TBD_PREFIX)

          text
        end
    end
  end
end
