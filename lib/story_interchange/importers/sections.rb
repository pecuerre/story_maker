module StoryInterchange
  module Importers
    # Each chapter directory is one Section. The source has no chapter record,
    # so the directory name is its slug (`01-arrival`), the `#` heading in the
    # chapter's README is its display name when it carries one, and the slug
    # part titleized is the fallback. The number is the chapter's place, not part
    # of its name.
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
            name: chapter.name,
            slug: chapter.slug,
            position: position
          )
        end

        Outcome.new(label_key: label_key, created: created.size, skipped: [])
      end
    end
  end
end
