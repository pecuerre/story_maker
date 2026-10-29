require "yaml"

# A human-readable projection of one universe in the story-interchange shape.
#
# **This is not the backup.** The lossless copy is `UniverseBackup::DataDump`;
# this tree exists so a reader can open a character, a location, a plot, or a
# scene without a database, and so a future backup/import round trip has a
# starting point.
#
# The database does not store every field the interchange layout asks for
# (a Character's role, a Plot's type, a Scene's branch, a canon area, and so on),
# so this projection writes `— TBD` where the app has no answer and keeps the
# stored answer in the data dump. It is therefore deliberately not guaranteed to
# pass `StoryInterchange::Validator`; the archive README says why.
module UniverseBackup
  class ContentProjection
    ROOT = "content"

    attr_reader :universe

    def initialize(universe)
      @universe = universe
    end

    def files
      @files ||= begin
        projected = {}
        projected.merge!(canon_files)
        projected.merge!(character_files)
        projected.merge!(faction_files)
        projected.merge!(location_files)
        projected.merge!(item_files)
        projected.merge!(story_files)
        projected.merge!(empty_directories)
        projected.merge!(readme_files)
        projected
      end
    end

    private
      def base
        @base ||= "#{ROOT}/#{universe.slug}"
      end

      def canon_files
        rules = universe.canon_rules.order(:id).to_a
        {
          "#{base}/universe/canon/README.md" => canon_readme,
          "#{base}/universe/canon/rules.md" => canon_rules(rules)
        }
      end

      def canon_readme
        <<~MARKDOWN
          # Canon

          A projection from the application's Canon Rules. Rule ids are the
          application's database ids, not ids from another source repository.

          ## Areas

          | File | Area |
          |---|---|
          | `rules.md` | every rule |
        MARKDOWN
      end

      def canon_rules(rules)
        items = if rules.empty?
          "## Locked\n\n- No rules recorded.\n"
        else
          "## Locked\n\n" + rules.map { |rule| canon_item(rule) }.join("\n\n") + "\n"
        end

        "# Canon: rules\n\n#{items}"
      end

      def canon_item(rule)
        statement = indent(rule.statement.presence || "— TBD")
        lines = [ "- **K#{rule.id}.** #{statement}" ]
        lines << "  Source: #{indent(rule.source)}" if rule.source.present?
        lines << "  Story: #{rule.story.slug}" if rule.story
        lines.join("\n")
      end

      def character_files
        universe.characters.includes(:factions).order(:position, :id).to_h do |character|
          frontmatter = {
            "name" => character.name,
            "slug" => character.slug,
            "role" => "— TBD",
            "affiliation" => character.factions.map(&:slug).sort.join(", ").presence || "— TBD",
            "status" => "— TBD"
          }
          sections = {
            "At a glance" => character.at_a_glance,
            "Wants" => character.wants,
            "Needs" => character.needs,
            "Lies about (to themselves)" => character.lies_to_self,
            "Contradictions" => character.contradictions,
            "Under pressure they" => character.under_pressure_they,
            "Never" => character.never
          }
          [ "#{base}/universe/characters/#{character.slug}.md", document(frontmatter, character.name, sections) ]
        end
      end

      def faction_files
        universe.factions.order(:name).to_h do |faction|
          frontmatter = {
            "name" => faction.name,
            "slug" => faction.slug,
            "type" => "— TBD",
            "home" => "— TBD",
            "status" => "— TBD"
          }
          sections = {
            "Mission" => faction.mission,
            "Actually for" => faction.actual_aims,
            "Structure" => faction.structure,
            "Internal split" => faction.internal_divisions,
            "Resources" => faction.resources,
            "Would never" => faction.would_never,
            "Would absolutely" => faction.would_absolutely
          }
          [ "#{base}/universe/factions/#{faction.slug}.md", document(frontmatter, faction.name, sections) ]
        end
      end

      def location_files
        universe.locations.order(:position, :id).to_h do |location|
          frontmatter = {
            "name" => location.name,
            "slug" => location.slug,
            "type" => "— TBD",
            "controller" => "— TBD",
            "status" => "— TBD"
          }
          sections = {
            "What it is" => location.description,
            "Sensory" => bullets(
              "Sight" => location.sensory_sight,
              "Sound" => location.sensory_sound,
              "Smell" => location.sensory_smell,
              "Taste" => location.sensory_taste,
              "Touch / gravity" => location.sensory_touch
            ),
            "Layout" => bullets(
              "Structure" => location.layout_structure,
              "Key areas" => location.layout_key_areas,
              "Pathways" => location.layout_pathways,
              "Entrances and exits" => location.layout_entrances_exits,
              "Points of interest" => location.layout_points_of_interest
            ),
            "Why it matters" => location.significance,
            "Control and access" => bullets(
              "Controlled by" => location.access_controlled_by,
              "Granted how" => location.access_granted_how,
              "Security" => location.access_security,
              "Restrictions" => location.access_restrictions
            ),
            "History" => bullets(
              "Significant events" => location.history_significant_events,
              "Past occupants" => location.history_past_occupants,
              "Changes" => location.history_changes
            )
          }
          [ "#{base}/universe/locations/#{location.slug}.md", document(frontmatter, location.name, sections) ]
        end
      end

      def item_files
        universe.items.order(:position, :id).to_h do |item|
          frontmatter = {
            "name" => item.name,
            "slug" => item.slug,
            "type" => "— TBD",
            "invented_by" => "— TBD",
            "status" => "— TBD"
          }
          sections = {
            "One line" => item.what_it_does,
            "What it actually is" => item.description,
            "How it is operated" => item.how_it_is_used,
            "Physical side effects" => item.side_effects,
            "Cannot" => item.cannot,
            "Costs" => item.value,
            "Constraints" => item.constraints,
            "Jargon" => item.jargon,
            "History" => item.history
          }
          [ "#{base}/universe/tech/#{item.slug}.md", document(frontmatter, item.name, sections) ]
        end
      end

      def story_files
        files = { "#{base}/stories/README.md" => stories_readme }

        universe.stories.order(:name).each do |story|
          directory = "#{base}/stories/#{story.slug}"
          files["#{directory}/README.md"] = story_readme(story)
          files.merge!(chapter_files(story, directory))
          files.merge!(plot_files(story, directory))
        end

        files
      end

      def stories_readme
        rows = universe.stories.order(:name).map { |story| "| #{story.name} | `#{story.slug}/README.md` |" }
        <<~MARKDOWN
          # Stories

          | Story | Reading order |
          |---|---|
          #{rows.join("\n")}
        MARKDOWN
      end

      def story_readme(story)
        rows = story.scenes.order(:position, :id).includes(:section).map do |scene|
          "| #{scene.position + 1} | #{scene.name} | #{scene.section&.name || "Ungrouped"} | #{scene.status} |"
        end

        <<~MARKDOWN
          # #{story.name}

          Reading order projected from the application's Scene positions.

          ## Reading order

          | # | Scene | Section | Status |
          |---|---|---|---|
          #{rows.join("\n")}
        MARKDOWN
      end

      def chapter_files(story, story_directory)
        sections = story.sections.order(:position, :id).to_a
        scenes = story.scenes.order(:position, :id).includes(:section, :pov_character, scene_locations: :location).to_a
        groups = sections.map { |section| [ section, scenes.select { |scene| scene.section_id == section.id } ] }
        ungrouped = scenes.select { |scene| scene.section_id.nil? }
        groups << [ nil, ungrouped ] if ungrouped.any?

        files = {}
        groups.each_with_index do |(section, group_scenes), index|
          number = section ? index + 1 : 0
          chapter = format("%02d-%s", number, section&.slug || "ungrouped")
          directory = "#{story_directory}/chapters/#{chapter}"

          if group_scenes.empty?
            files["#{directory}/.gitkeep"] = ""
            next
          end

          group_scenes.each_with_index do |scene, scene_index|
            files["#{directory}/#{format("%02d", scene_index + 1)}-#{scene.slug}.md"] =
              scene_document(scene, chapter, scene_index + 1)
          end
        end

        files["#{story_directory}/chapters/.gitkeep"] = "" if files.empty?
        files
      end

      def scene_document(scene, chapter, sequence)
        location = scene.scene_locations.min_by(&:id)&.location
        frontmatter = {
          "id" => format("B-%03d", scene.id),
          "title" => scene.name,
          "chapter" => chapter,
          "sequence" => sequence,
          "pov" => scene.pov_character&.slug || "— TBD",
          "location" => location&.slug || "— TBD",
          "timeline" => scene.datetime&.iso8601 || "— TBD",
          "branch" => "— TBD",
          "status" => scene.status
        }
        prose = scene.scene_elements.order(:position, :id).pluck(:body).compact_blank.join("\n\n")
        document(frontmatter, scene.name, { "Prose" => prose })
      end

      def plot_files(story, story_directory)
        story.plots.order(:name).to_h do |plot|
          frontmatter = {
            "name" => plot.name,
            "slug" => plot.slug,
            "type" => "— TBD",
            "status" => "— TBD",
            "owner_pov" => "— TBD"
          }
          sections = { "The question" => plot.description }
          [ "#{story_directory}/plots/#{plot.slug}.md", document(frontmatter, plot.name, sections) ]
        end
      end

      def empty_directories
        %w[characters factions locations tech].to_h do |directory|
          [ "#{base}/universe/#{directory}/.gitkeep", "" ]
        end
      end

      def readme_files
        {
          "#{base}/README.md" => <<~MARKDOWN
            # #{universe.name}

            A human-readable projection of this universe in the story-interchange
            shape. It is not the backup. The lossless copy is `data/`.

            Fields the application does not store are written `— TBD`; the
            application's value, when it has one, is in the data dump. Photos,
            tags, routes, tropes, events, relations, ownerships, and discussions
            are not projected into this tree because the interchange layout has no
            place for them yet.

            This tree is not guaranteed to pass `StoryInterchange::Validator`:
            Scene branches and canon areas are two fields the application does not
            store at all.
          MARKDOWN
        }
      end

      def document(frontmatter, title, sections)
        parts = [ frontmatter(frontmatter), "# #{title}", "" ]

        sections.each do |heading, content|
          next if content.blank?

          parts << "## #{heading}" << "" << content.to_s.strip << ""
        end

        parts.join("\n").rstrip + "\n"
      end

      def frontmatter(values)
        body = values.compact.to_yaml.sub(/\A---\n/, "")
        "---\n#{body}---\n"
      end

      def bullets(values)
        values.filter_map { |label, value| "- #{label}: #{value}" if value.present? }.join("\n").presence
      end

      def indent(value)
        value.to_s.strip.gsub("\n", "\n  ")
      end
  end
end
