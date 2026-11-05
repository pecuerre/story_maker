module StoryInterchange
  module Importers
    # A Scene file becomes one Scene inside the Section its chapter directory
    # names. The chapter and its two-digit sequence are the path, so the Scene's
    # slug and flat position come from the directory and filename rather than
    # from frontmatter. `title` is the Scene's name, `pov` is the point-of-view
    # Character, `location` is a Location presence link, and the closing
    # `DRAFTING CONTRACT` note is the Scene's `drafting_contract`.
    #
    # The body alternates `## Narration` and `## Dialog` blocks, one Element
    # each in reading order. A Narration block's paragraphs are its Content. A
    # Dialog block's lines are turns: `@[[character:slug]] "line"` resolves to a
    # speaker and becomes a `SceneDialogueTurn`, while a bare `@slug` names a
    # speaker with no Character file. The block's resolvable speakers are the
    # Dialogue Element's roster, and an unregistered speaker's line is reported
    # rather than given a speaker the Universe does not have.
    #
    # `id`, `timeline`, and `branch` are source facts with no Scene column.
    # `id` is the backlog item the scene was written from, not a unique scene
    # key. `timeline` is deliberately author prose ("ninth day after the flare")
    # rather than a parseable date, so it is reported instead of guessed into
    # `datetime`.
    class Scenes < Importer
      slice label_key: "imports.slices.scenes",
        count: :scenes,
        kind: :scene

      # The two block kinds the source writes. A heading outside this map has no
      # Element target and is reported.
      BLOCK_KINDS = {
        "Narration" => SceneElement::NARRATION,
        "Dialog" => SceneElement::DIALOGUE
      }.freeze

      # The Scene facts the application has no column for.
      REPORTED_KEYS = %w[id timeline branch].freeze

      # One spoken line: `@[[character:slug]] "line"` or `@slug "line"`.
      DIALOGUE_LINE = /\A@(?<speaker>\[\[[^\[\]\n]+\]\]|[a-z0-9][a-z0-9-]*)[ \t]+"(?<body>.*)"[ \t]*\z/

      class << self
        # The nonblank spoken lines of one `## Dialog` block, in source order.
        # The preview and the write read the same parse.
        def dialogue_lines(body)
          body.to_s.each_line.filter_map do |line|
            match = DIALOGUE_LINE.match(line.strip)
            next unless match

            { speaker: match[:speaker], body: match[:body] }
          end
        end

        private
          # A Scene writes its block bodies and its drafting contract, so only a
          # block heading outside the source's two kinds is reported as a
          # section. The unstoreable frontmatter keys and the speakers with no
          # Character file are named too.
          def reported_entries(report, entity)
            entries = entity.sections.reject { |section| BLOCK_KINDS.key?(section.heading) }.map do |section|
              Importer::Note.new(:section, section.heading)
            end

            REPORTED_KEYS.each do |key|
              entries << Importer::Note.new(:frontmatter, key) if entity.frontmatter[key].present?
            end

            entries.concat(unregistered_speakers(entity))
            entries.concat(prose_references(report, entity))
          end

          # A bare `@slug` speaker has no Character record, so the line cannot
          # become a turn. One note per speaker, named as the source wrote it.
          def unregistered_speakers(entity)
            entity.sections.select { |section| BLOCK_KINDS[section.heading] == SceneElement::DIALOGUE }
              .flat_map { |section| dialogue_lines(section.body).map { |line| line[:speaker] } }
              .reject { |speaker| speaker.start_with?("[[") }
              .uniq
              .map { |speaker| Importer::Note.new(:speaker, speaker) }
          end

          # A `[[slug]]` this run cannot resolve stays exactly as written in the
          # prose, so the preview names it like an unmapped profile reference.
          def prose_references(report, entity)
            bodies = entity.sections.select { |section| BLOCK_KINDS.key?(section.heading) }.map(&:body)

            bodies.flat_map { |body| body.scan(Document::REFERENCE).flatten.map(&:strip) }
              .uniq
              .filter_map do |target|
                Importer::Note.new(:reference, "[[#{target}]]") if unresolved?(report, target)
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

        Outcome.new(label_key: label_key, created: created.size, records: self.class.records(report))
      end

      private
        # A blank or `— TBD` value means the Scene has not recorded one.
        TBD_PREFIX = "—"

        # The new scene format keeps no writing status in the source, so every
        # imported Scene starts in the vocabulary's default state.
        def scene_attributes(entity, story, position)
          {
            story: story,
            section: story.sections.find_by!(slug: entity.chapter_slug),
            position: position,
            name: entity.frontmatter["title"],
            slug: "#{entity.chapter_slug}-#{entity.slug}",
            status: Scene::DEFAULT_STATUS,
            pov_character: character_for(entity),
            drafting_contract: self.class.resolve_references(report, entity.drafting_contract)
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

        # One Element per `##` block, in source order. A block outside the two
        # known kinds has no Element target and was reported by the preview.
        def write_elements(scene, entity)
          position = 0

          entity.sections.each do |section|
            kind = BLOCK_KINDS[section.heading]
            next unless kind

            position = if kind == SceneElement::DIALOGUE
              write_dialogue(scene, section, position)
            else
              write_narration(scene, section, position)
            end
          end
        end

        def write_narration(scene, section, position)
          SceneElement.create!(
            scene: scene,
            kind: SceneElement::NARRATION,
            name: element_name(scene, position),
            body: self.class.resolve_references(report, section.body),
            position: position
          )
          position + 1
        end

        # A Dialogue Element is its ordered turns, one per line a registered
        # speaker says. A line by a speaker with no Character file cannot become
        # a turn and is reported by the preview. A block whose speakers are all
        # unregistered cannot be a Dialogue at all, so its lines are kept as
        # Narration prose instead of being lost.
        def write_dialogue(scene, section, position)
          lines = self.class.dialogue_lines(section.body)
          speakers = lines.filter_map { |line| registered_character(line[:speaker]) }.uniq

          if speakers.empty?
            SceneElement.create!(
              scene: scene,
              kind: SceneElement::NARRATION,
              name: element_name(scene, position),
              body: self.class.resolve_references(report, narration_fallback(lines)),
              position: position
            )
            return position + 1
          end

          element = SceneElement.create!(
            scene: scene,
            kind: SceneElement::DIALOGUE,
            name: element_name(scene, position),
            position: position
          )

          lines.each_with_index do |line, index|
            speaker = registered_character(line[:speaker])
            next if speaker.nil?

            SceneDialogueTurn.create!(
              scene_element: element,
              speaker: speaker,
              body: self.class.resolve_references(report, line[:body]),
              position: index
            )
          end

          position + 1
        end

        # `@[[character:slug]]` is the speaker form for a Character with a file.
        # A bare `@slug` deliberately names no record, so it is not resolved by
        # a matching Character slug.
        def registered_character(speaker)
          match = speaker.to_s.match(/\A\[\[character:(.+)\]\]\z/)
          match && universe.characters.find_by(slug: match[1])
        end

        # A dialog block the application cannot store as a Dialogue keeps its
        # spoken lines as prose, prefixed by the speaker the source gave.
        def narration_fallback(lines)
          lines.map { |line| "#{line[:speaker].delete_prefix("@")}: #{line[:body]}" }
            .join("\n\n")
        end

        # An Element's Title is required and the source records no block titles,
        # so the Scene's own title names the first block and later ones are
        # numbered.
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
