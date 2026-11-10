module StoryInterchange
  module Importers
    # Each chapter directory is one Section. The source has no chapter record,
    # so the directory name is its slug (`01-arrival`), and the README's YAML
    # frontmatter is its machine-readable record: `title` is the display name,
    # `summary` fills `short_summary`, and every other key is carried whole in
    # the description as YAML. The slug part titleized is the name fallback. The
    # number is the chapter's place, not part of its name.
    #
    # Everything after the README's frontmatter is documentation and is skipped,
    # so a subsection is never reported or imported.
    #
    # Chapters are flat, so every imported Section is top-level and its position
    # follows the sorted directory order within its Story. The chapter is read
    # before its scenes, so the Scenes slice can group them under this Section.
    #
    # Every chapter Section carries one `Chapter` Section Tag. The source has no
    # tag taxonomy of its own, but a chapter is the one section kind it names, so
    # the run creates that tag once per Story instead of leaving the imported
    # chapters unlabeled.
    class Sections < Importer
      slice label_key: "imports.slices.sections", count: :chapters

      CHAPTER_TAG_NAME = "Chapter"

      class << self
        def records(report)
          report.chapters.map { |chapter| record_for(report, chapter) }
        end

        def reported(report)
          records(report).select(&:reported?)
        end

        private
          # The Section is written from the README's frontmatter, so the only
          # thing it can leave behind is a reference in that metadata that names
          # no record this run writes.
          def record_for(report, chapter)
            Importer::Record.new(
              name: chapter.name,
              slug: chapter.slug,
              notes: unresolved_references(report, chapter)
            )
          end

          def unresolved_references(report, chapter)
            chapter.description.to_s.scan(Document::REFERENCE).flatten.map(&:strip).uniq.filter_map do |target|
              Importer::Note.new(:reference, "[[#{target}]]") if unresolved?(report, target)
            end
          end
      end

      def call
        positions = Hash.new(0)
        chapter_tags = {}

        created = report.chapters.map do |chapter|
          story = universe.stories.find_by!(slug: chapter.story_slug)
          chapter_tag = chapter_tags[story.id] ||= SectionTag.create!(story: story, name: CHAPTER_TAG_NAME)
          position = positions[chapter.story_slug]
          positions[chapter.story_slug] += 1

          Section.create!(
            story: story,
            name: chapter.name,
            slug: chapter.slug,
            position: position,
            short_summary: self.class.resolve_references(report, chapter.short_summary).presence,
            description: self.class.resolve_references(report, chapter.description).presence,
            section_tags: [ chapter_tag ]
          )
        end

        Outcome.new(label_key: label_key, created: created.size, records: self.class.records(report))
      end
    end
  end
end
