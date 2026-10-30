require "yaml"

# A human-readable projection of one universe in the story-interchange shape.
#
# **This is not the backup.** The lossless copy is `UniverseBackup::DataDump`;
# this tree exists so a reader can open a character, a location, a plot, or a
# scene without a database, and so a future backup/import round trip has a
# starting point.
#
# The database does not store every field the interchange layout asks for
# (a Character's role, a Plot's type, a Scene's branch, and so on), so this
# projection writes `— TBD` where the app has no answer and keeps the stored
# answer in the data dump. It is therefore deliberately not guaranteed to pass
# `StoryInterchange::Validator`; the archive README says why.
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

      # One file per category, named after the category, because the story
      # interchange stores one area per file. A rule with no category lands in
      # `rules.md`, and a category is parameterized so a hand-typed one cannot
      # write outside the canon directory.
      def canon_files
        groups = universe.canon_rules.order(:id).to_a.group_by { |rule| canon_area(rule) }
        groups = { "rules" => [] } if groups.empty?

        areas = groups.to_h do |area, rules|
          [ "#{base}/universe/canon/#{area}.md", canon_area_document(area, rules) ]
        end

        areas.merge("#{base}/universe/canon/README.md" => canon_readme(groups.keys))
      end

      def canon_readme(areas)
        index = areas.map { |area| "| `#{area}.md` | #{area} |" }.join("\n")

        <<~MARKDOWN
          # Canon

          A projection from the application's Canon Rules. An item id is the
          rule's slug when it is a ledger id, and its database id otherwise, not
          an id from another source repository.

          ## Areas

          | File | Area |
          |---|---|
          #{index}
        MARKDOWN
      end

      def canon_area_document(area, rules)
        body = if rules.empty?
          "## Locked\n\n- No rules recorded.\n"
        else
          canon_sections(rules).filter_map do |heading, items|
            next if items.empty?

            "## #{heading}\n\n#{items.map { |rule| canon_item(rule) }.join("\n\n")}"
          end.join("\n\n") + "\n"
        end

        "# Canon: #{area}\n\n#{body}"
      end

      # The ledger knows three section headings: Locked (which holds both a
      # locked fact and a rule of the mechanism), Derived consequences, and Open.
      def canon_sections(rules)
        [
          [ "Locked", rules.reject { |rule| %w[ consequence open ].include?(rule.canon_type) } ],
          [ "Derived consequences", rules.select { |rule| rule.canon_type == "consequence" } ],
          [ "Open", rules.select { |rule| rule.canon_type == "open" } ]
        ]
      end

      def canon_item(rule)
        statement = indent(rule.statement.presence || "— TBD")
        title = rule.name.presence
        # The title is only written when it says something the statement does
        # not; an untitled rule is the `**K16.**` form the ledger already uses.
        line = if title.present? && title != rule.statement
          "- **#{canon_item_id(rule)} — #{indent(title)}.** #{statement}"
        else
          "- **#{canon_item_id(rule)}.** #{statement}"
        end
        lines = [ line ]
        lines << "  Source: #{indent(rule.source)}" if rule.source.present?
        lines << "  Story: #{rule.story.slug}" if rule.story
        lines.join("\n")
      end

      # A stored slug is already a ledger id when its prefix matches the rule's
      # type; otherwise the projection falls back to the database id under the
      # prefix the type implies, because the numeric id is the only stable key a
      # hand-written rule has.
      def canon_item_id(rule)
        prefix = { "locked" => "K", "rule" => "L", "consequence" => "D", "open" => "O" }
          .fetch(rule.canon_type.to_s, "K")
        slug = rule.slug.to_s

        return slug.upcase if slug.match?(/\A#{prefix.downcase}(?:-[a-z0-9]+)?\d+\z/)

        "#{prefix}#{rule.id}"
      end

      def canon_area(rule)
        rule.category.to_s.parameterize.presence || "rules"
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
          sections = { "At a glance" => character.summary }
            .merge(description_sections(character.description))
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

      # A Character's description is Markdown that already carries its own `##`
      # sections. The projection keeps those headings so the readable tree reads
      # like the source; prose before the first heading becomes a `Description`
      # section rather than being dropped.
      def description_sections(description)
        text = description.to_s.strip
        return {} if text.blank?

        sections = {}
        chunks = text.split(/^##[ \t]+/)
        sections["Description"] = chunks.shift.strip if chunks.any? && chunks.first.present?

        chunks.each do |chunk|
          heading, body = chunk.split(/\r?\n/, 2)
          sections[heading.strip] = body.to_s.strip
        end

        sections
      end

      def bullets(values)
        values.filter_map { |label, value| "- #{label}: #{value}" if value.present? }.join("\n").presence
      end

      def indent(value)
        value.to_s.strip.gsub("\n", "\n  ")
      end
  end
end
