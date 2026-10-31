module StoryInterchange
  module Importers
    # Each chapter directory is one Section. The source has no chapter record,
    # so the directory name is its slug (`01-arrival`), the `#` heading in the
    # chapter's README is its display name when it carries one, and the slug
    # part titleized is the fallback. The number is the chapter's place, not part
    # of its name.
    #
    # The README's identity block — the prose before its first `##` heading — is
    # the Section's description, with references resolved to record names like
    # any other profile answer. A `##` subsection has no Section column, so it is
    # reported instead of silently dropped; the preview names the chapter and its
    # counts before the run.
    #
    # Chapters are flat, so every imported Section is top-level and its position
    # follows the sorted directory order within its Story. The chapter is read
    # before its scenes, so the Scenes slice can group them under this Section.
    class Sections < Importer
      slice label_key: "imports.slices.sections", count: :chapters

      class << self
        def records(report)
          report.chapters.map { |chapter| record_for(report, chapter) }
        end

        def reported(report)
          records(report).select(&:reported?)
        end

        private
          # The chapter is in the list whether or not it has a subsection: the
          # Section is written from the README's identity block, and the
          # subsections are what the slice leaves behind.
          def record_for(report, chapter)
            items = chapter.sections.map { |section| "#{chapter.slug}: #{section.heading}" }
            items.concat(unresolved_references(report, chapter))

            Importer::Record.new(
              name: chapter.name,
              slug: chapter.slug,
              sections: chapter.sections.size,
              words: WordCountable.words_in(chapter_body_text(chapter)),
              reported: items.any?,
              items: items
            )
          end

          # The whole README body, because the description is written and the
          # subsections are reported; the counts describe the record a reader
          # would otherwise have to open.
          def chapter_body_text(chapter)
            [ chapter.description.to_s, *chapter.sections.map(&:body) ].join("\n\n")
          end

          def unresolved_references(report, chapter)
            chapter.description.to_s.scan(Document::REFERENCE).flatten.map(&:strip).uniq.filter_map do |target|
              "#{chapter.slug}: [[#{target}]]" if unresolved?(report, target)
            end
          end
      end

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
            position: position,
            description: self.class.resolve_references(report, chapter.description).presence
          )
        end

        Outcome.new(label_key: label_key, created: created.size, records: self.class.records(report))
      end
    end
  end
end
