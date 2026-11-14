module StoryInterchange
  module Importers
    # Each chapter directory is one Section, and the chapter's `act` frontmatter
    # makes it a child of the act Section that groups it. The source has no
    # chapter record, so the directory name is its slug (`01-arrival`), and the
    # README's YAML frontmatter is its machine-readable record: `full_title` is
    # the display name, `summary` fills `short_summary`, and every other key is
    # carried whole in the description as YAML. The slug part titleized is the
    # name fallback. The number is the chapter's place, not part of its name.
    #
    # Everything after the README's frontmatter is documentation and is skipped,
    # so a subsection is never reported or imported.
    #
    # An act Section is a container the Source names only through its chapters.
    # It is written once per Story in the order its first chapter appears, at the
    # Story's top level, and a chapter without an `act` stays top-level too. The
    # chapter is read before its scenes, so the Scenes slice can group them under
    # this Section.
    #
    # Every chapter Section carries one `Chapter` Section Tag. The source has no
    # tag taxonomy of its own, but a chapter is the section kind it names per
    # record, so the run creates that tag once per Story instead of leaving the
    # imported chapters unlabeled. An act Section is a structural parent and
    # carries no tag.
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
        act_sections = {}
        top_positions = Hash.new(0)
        chapter_positions = Hash.new(0)
        chapter_tags = {}

        created = report.chapters.map do |chapter|
          story = universe.stories.find_by!(slug: chapter.story_slug)
          parent = act_section(story, chapter, act_sections, top_positions)
          position = chapter_position(story, parent, top_positions, chapter_positions)
          chapter_tag = chapter_tags[story.id] ||= SectionTag.create!(story: story, name: CHAPTER_TAG_NAME)

          Section.create!(
            story: story,
            parent: parent,
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

      private
        # The act Section that groups this chapter, created once per Story and
        # act name in first-chapter order. A chapter without an act has no parent
        # and stays top-level, as every chapter did before the source named acts.
        def act_section(story, chapter, act_sections, top_positions)
          name = chapter.act.to_s.strip
          return nil if name.blank?

          act_sections[[ story.id, name ]] ||= Section.create!(
            story: story,
            name: name,
            slug: name.parameterize,
            position: next_position(top_positions, story.id)
          )
        end

        # A Section's position orders it among its siblings. A chapter under an
        # act counts its own sequence, while an actless chapter shares the
        # Story's top-level sequence with the act Sections.
        def chapter_position(story, parent, top_positions, chapter_positions)
          return next_position(top_positions, story.id) if parent.nil?

          next_position(chapter_positions, [ story.id, parent.id ])
        end

        def next_position(positions, key)
          position = positions[key]
          positions[key] += 1
          position
        end
    end
  end
end
