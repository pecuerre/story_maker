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
    # each in reading order. A Narration block's paragraphs are its Content.
    # A Dialog block's lines are turns. `@[[character:slug]] "line"` names a
    # Character speaker; a bare `@slug "line"` names a speaker with no Character
    # file, which becomes a non-character turn whose body carries the tag
    # (`slug: line`). Every turn is stored, so the block's speakers are the cast.
    # An unresolvable typed Character link is refused by the validator before the
    # import runs, so it is not silently rewritten.
    #
    # `id`, `timeline`, and `branch` are source facts with no Scene column.
    # `id` is the backlog item the scene was written from, not a unique scene
    # key. `timeline` is deliberately author prose ("ninth day after the flare")
    # so it is reported. `moment` is its parseable twin: a concrete date or
    # clock time sets the Scene's own `datetime`, while a relation to another
    # scene is left to the Events slice, which writes the Event and its
    # temporal link.
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

      class << self
        # The turns of one `## Dialog` block, in source order. A quoted line may
        # wrap across physical lines; `SceneDialogue` joins it into one turn.
        # The preview and the write read the same parse.
        def dialogue_lines(body)
          SceneDialogue.parse(body).turns.map do |turn|
            { speaker: turn.speaker, body: turn.body }
          end
        end

        private
          # A Scene writes its block bodies and its drafting contract, so only a
          # block heading outside the source's two kinds is reported as a
          # section. The unstoreable frontmatter keys are named too.
          def reported_entries(report, entity)
            entries = entity.sections.reject { |section| BLOCK_KINDS.key?(section.heading) }.map do |section|
              Importer::Note.new(:section, section.heading)
            end

            REPORTED_KEYS.each do |key|
              entries << Importer::Note.new(:frontmatter, key) if entity.frontmatter[key].present?
            end

            entries.concat(prose_references(report, entity))
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
            datetime: Moment.parse(entity.frontmatter["moment"]).datetime,
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

        # A Dialogue Element is its ordered turns. A line with a resolvable
        # `@[[character:slug]]` names that Character; a bare `@slug` line has no
        # Character record, so it becomes a non-character turn whose body keeps
        # the speaker tag (`slug: line`). Every source line is stored, so the
        # block's speakers are the Dialogue's cast.
        def write_dialogue(scene, section, position)
          lines = self.class.dialogue_lines(section.body)

          element = SceneElement.create!(
            scene: scene,
            kind: SceneElement::DIALOGUE,
            name: element_name(scene, position),
            position: position
          )

          lines.each_with_index do |line, index|
            speaker = registered_character(line[:speaker])

            SceneDialogueTurn.create!(
              scene_element: element,
              speaker: speaker,
              body: self.class.resolve_references(report, turn_body(line, speaker)),
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

        # A non-character turn keeps the source's speaker tag in the line itself,
        # so an exported or re-read dialogue still says who spoke.
        def turn_body(line, speaker)
          return line[:body] if speaker

          "#{line[:speaker].delete_prefix('@')}: #{line[:body]}"
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
