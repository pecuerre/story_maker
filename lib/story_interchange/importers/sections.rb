module StoryInterchange
  module Importers
    # Each chapter directory is one Section. The source has no chapter file, so
    # the directory name is the only chapter fact: the Section's slug is that
    # name (`01-arrival`) and its display name is the slug part titleized
    # (`Arrival`). The number is the chapter's place, not part of its name.
    #
    # Chapters are flat, so every imported Section is top-level and its position
    # follows the sorted directory order within its Story. The chapter is read
    # before its scenes, so the Scenes slice can group them under this Section.
    class Sections < Importer
      slice label_key: "imports.slices.sections", count: :chapters

      def call
        positions = Hash.new(0)

        created = report.chapters.map do |chapter|
          story = universe.stories.find_by!(slug: chapter.story_slug)
          position = positions[chapter.story_slug]
          positions[chapter.story_slug] += 1

          Section.create!(
            story: story,
            name: name_for(chapter.slug),
            slug: chapter.slug,
            position: position
          )
        end

        Outcome.new(label_key: label_key, created: created.size, skipped: [])
      end

      private
        # `01-arrival` names the chapter "Arrival". The number is positional
        # metadata that the slug keeps so a chapter's identity stays the
        # filename the source uses.
        def name_for(slug)
          slug.sub(/\A\d{2}-/, "").tr("-", " ").titleize
        end
    end
  end
end
