require "rubygems/package"
require "set"
require "stringio"
require "yaml"
require "zlib"

module StoryInterchange
  # Writes one Universe as a story-interchange source: a directory of Markdown
  # files the importer can read back.
  #
  # The source is the reverse of `StoryInterchange::Import`. It carries the
  # records the interchange layout has a place for — canon, Characters,
  # Factions, Locations, Items, Stories, Sections, Scenes, and Plots — in the
  # same `universe/` and `stories/` trees the validator checks. Writing the tree
  # is the whole job; `to_s` only packs those files into a `.tar.gz` whose root
  # directory is the Universe's slug, so extracting it gives the identity the
  # importer derives without a manifest.
  #
  # **The interchange is lossy by contract.** The layout has no home for tags,
  # Routes, tropes, relations, ownerships, Events, photos, aliases, Section
  # descriptions, or Scene parentheticals, so this export does not invent one.
  # It writes what the layout can carry and leaves the rest in the database; the
  # export page and `docs/features/exports.md` say which records do not travel.
  #
  # A Scene is written with at least one `## Narration` block, because that is
  # what the validator requires. Adjacent Elements of the same kind become one
  # block, because the layout alternates Narration and Dialog and has no
  # per-Element record; the prose survives, the Element boundary does not.
  #
  # The layout groups Scenes by Section, which cannot express a Story whose
  # narrative order interleaves Sections or ungrouped Scenes. Each Scene
  # therefore carries its story-wide `position`, numbered from the Story's own
  # order, so the import can restore the sequence the chapter directories would
  # otherwise reorder.
  #
  # The application scopes a slug to its own table, but a source needs one
  # namespace: a bare `[[slug]]` has to resolve without a type. The export
  # therefore allocates a unique slug to every record it writes and rewrites the
  # references that named a renamed one, rather than handing the importer a tree
  # it must refuse.
  class Export
    TBD = "— TBD"
    NARRATION = "Narration"
    DIALOGUE = "Dialog"
    UNGROUPED_TITLE = "Ungrouped"
    # A non-character turn stores its speaker tag in the line itself
    # (`registry-clerk: …`). The source speaks it as a bare `@slug`, which the
    # validator requires to be a lowercase hyphenated slug.
    NON_CHARACTER_TURN = /\A([A-Za-z][A-Za-z0-9 _-]*):\s*(.*)\z/m
    SLUG = /\A[a-z0-9][a-z0-9-]*\z/
    # The application scopes a slug to its own table, so two records of different
    # kinds — or two in one table — may share one. A source may not: a bare
    # `[[slug]]` must resolve without a type, so this export gives every record a
    # unique slug and rewrites the references that named the renamed ones. The
    # order is the order the export writes the files, and the order a bare
    # reference is looked up, so the record a bare reference already names is the
    # one that keeps its slug.
    REFERENCE_KINDS = {
      "character" => :character,
      "faction" => :faction,
      "location" => :location,
      "item" => :item,
      "tech" => :item,
      "plot" => :plot
    }.freeze
    # A typed reference is the only one the export has to rewrite: a bare
    # `[[slug]]` resolves to the first record with that slug, which is the one
    # the allocation above leaves holding it.
    TYPED_REFERENCE = /\A(?<prefix>[a-z]+):(?<slug>[^|\[\]\n]+)(?<type>\|type:[^\[\]\n]*)?\z/
    FENCED_CODE = /(```.*?```)/m
    REFERENCE = /\[\[([^\[\]\n]+)\]\]/

    attr_reader :universe, :generated_at

    def initialize(universe, generated_at: Time.current)
      @universe = universe
      @generated_at = generated_at
    end

    def files
      @files ||= begin
        projected = { "#{base}/README.md" => root_readme }
        projected.merge!(universe_files)
        projected.merge!(canon_files)
        projected.merge!(character_files)
        projected.merge!(faction_files)
        projected.merge!(location_files)
        projected.merge!(item_files)
        projected.merge!(story_files)
        projected.merge!(empty_directories)
        projected
      end
    end

    # One `.tar.gz` in memory. The archive is a read of the database and writes
    # nothing; the caller decides where the bytes go.
    def to_s
      io = StringIO.new
      gzip = Zlib::GzipWriter.new(io)
      tar = Gem::Package::TarWriter.new(gzip)

      files.each { |path, content| add_file(tar, path, content) }

      tar.close
      gzip.close unless gzip.closed?
      io.string
    end

    def filename
      "#{universe.slug}-story-interchange-#{generated_at.utc.strftime("%Y%m%d-%H%M%S")}.tar.gz"
    end

    private
      def base
        @base ||= universe.slug
      end

      def characters
        @characters ||= universe.characters.includes(:factions).order(:position, :id).to_a
      end

      def factions
        @factions ||= universe.factions.order(:name).to_a
      end

      def locations
        @locations ||= universe.locations.order(:position, :id).to_a
      end

      def items
        @items ||= universe.items.order(:position, :id).to_a
      end

      def stories
        @stories ||= universe.stories.order(:name, :id).to_a
      end

      def plots(story)
        @plots ||= {}
        @plots[story.id] ||= story.plots.order(:name, :id).to_a
      end

      def all_plots
        stories.flat_map { |story| plots(story) }
      end

      # The slug each record is written under, keyed by `[kind, id]`.
      def slug_map
        allocate_slugs unless @slug_map
        @slug_map
      end

      # The slug a reference to `kind`/`slug` in the database must be written as.
      # It is the first record of that kind with the slug, which is the one that
      # kept it; a second record with the same slug is ambiguous in a bare
      # reference and unresolvable in the source either way.
      def reference_slugs
        allocate_slugs unless @reference_slugs
        @reference_slugs
      end

      def allocate_slugs
        @slug_map = {}
        @reference_slugs = {}
        used = Set.new

        exported_slugs.each do |kind, record, slug|
          written = claim_slug(slug, kind, used)
          @slug_map[[ kind, record.id ]] = written
          @reference_slugs[[ kind, slug ]] ||= written
        end
      end

      def exported_slugs
        records = []
        characters.each { |record| records << [ :character, record, record.slug ] }
        factions.each { |record| records << [ :faction, record, record.slug ] }
        locations.each { |record| records << [ :location, record, record.slug ] }
        items.each { |record| records << [ :item, record, record.slug ] }
        all_plots.each { |record| records << [ :plot, record, record.slug ] }
        records
      end

      # The first record keeps the slug. A later one is suffixed with its kind,
      # then with a counter, until nothing else in the source holds it.
      def claim_slug(slug, kind, used)
        return slug if used.add?(slug)

        counter = 1
        loop do
          candidate = counter == 1 ? "#{slug}-#{kind}" : "#{slug}-#{kind}-#{counter}"
          return candidate if used.add?(candidate)

          counter += 1
        end
      end

      def slug_for(kind, record)
        slug_map.fetch([ kind, record.id ])
      end

      # A stored answer keeps its `[[kind:slug]]` references, so a renamed record
      # has to be renamed inside them too or the imported sentence would name a
      # record the source no longer has. A fenced block is an example, exactly as
      # it is for the validator's reference scanner.
      def rewrite_references(text)
        return text if text.blank?

        text.split(FENCED_CODE).map.with_index do |part, index|
          next part if index.odd?

          part.gsub(REFERENCE) { "[[#{rewrite_reference(Regexp.last_match(1))}]]" }
        end.join
      end

      def rewrite_reference(target)
        match = TYPED_REFERENCE.match(target)
        return target unless match

        kind = REFERENCE_KINDS[match[:prefix]]
        mapped = kind && reference_slugs[[ kind, match[:slug] ]]
        mapped ? "#{match[:prefix]}:#{mapped}#{match[:type]}" : target
      end

      def universe_files
        { "#{base}/universe/README.md" => universe_readme }
      end

      def universe_readme
        <<~MARKDOWN
          # #{universe.name}

          Exported from Universe Maker on #{generated_at.utc.iso8601}.

          This directory is a story-interchange source: `universe/` holds the
          records every Story shares, and `stories/` holds what each Story owns.
          It is read back by the platform import, which replaces the Universe of
          the same slug.
        MARKDOWN
      end

      def root_readme
        <<~MARKDOWN
          # #{universe.name}

          A story-interchange source exported from Universe Maker. Import the
          `#{base}/` directory, not the contents of this archive, so the
          importer derives the Universe's slug from the folder name.
        MARKDOWN
      end

      def canon_files
        rules = universe.canon_rules.order(:id).to_a
        ids = canon_ids(rules)
        groups = rules.group_by { |rule| canon_area(rule) }
        groups = { "rules" => [] } if groups.empty?

        areas = groups.to_h do |area, area_rules|
          [ "#{base}/universe/canon/#{area}.md", canon_area_document(area, area_rules, ids) ]
        end

        areas.merge("#{base}/universe/canon/README.md" => canon_readme(groups.keys))
      end

      # A canon id is the rule's slug when it is already a ledger id. A rule
      # written straight into the app has a name-derived slug, so it is numbered
      # from its database id under the prefix its canon type implies. A clash is
      # pushed to the next free number, because the ledger requires global ids.
      def canon_ids(rules)
        used = Set.new

        rules.to_h do |rule|
          prefix = canon_prefix(rule)
          id = ledger_id(rule, prefix)
          id = next_free_id(prefix, rule.id, used) unless id && !used.include?(id)
          used << id
          [ rule.id, id ]
        end
      end

      def ledger_id(rule, prefix)
        slug = rule.slug.to_s
        slug.upcase if slug.match?(/\A#{prefix.downcase}\d+\z/)
      end

      def next_free_id(prefix, number, used)
        number += 1 while used.include?("#{prefix}#{number}")
        "#{prefix}#{number}"
      end

      def canon_prefix(rule)
        { "locked" => "K", "rule" => "L", "consequence" => "D", "open" => "O" }
          .fetch(rule.canon_type.to_s, "K")
      end

      def canon_area(rule)
        rule.category.to_s.parameterize.presence || "rules"
      end

      def canon_readme(areas)
        index = areas.map { |area| "| `#{area}.md` | #{area} |" }.join("\n")

        <<~MARKDOWN
          # Canon

          The ledger rules and the index of its areas. Each area file holds the
          items the application stores for that category.

          ## Areas

          | File | Area |
          |---|---|
          #{index}
        MARKDOWN
      end

      # The three ledger sections in the order the source reads them. An open
      # question keeps its `O` prefix and sits under Open; a rule with no canon
      # type is written as a locked item.
      def canon_area_document(area, rules, ids)
        sections = [
          [ "Locked", rules.reject { |rule| %w[consequence open].include?(rule.canon_type) } ],
          [ "Derived consequences", rules.select { |rule| rule.canon_type == "consequence" } ],
          [ "Open", rules.select { |rule| rule.canon_type == "open" } ]
        ]

        body = sections.filter_map do |heading, items|
          next if items.empty?

          written = items.map { |rule| canon_item(rule, ids.fetch(rule.id)) }.join("\n\n")
          "## #{heading}\n\n#{written}"
        end.join("\n\n")

        body = "## Locked\n\n- No rules recorded.\n" if body.empty?
        "# Canon: #{area}\n\n#{body}\n"
      end

      def canon_item(rule, id)
        statement = indent(rewrite_references(rule.statement.to_s.strip).presence || TBD)
        "- #{id}. #{rule.name.to_s.squish}\n\n  #{statement}"
      end

      def character_files
        characters.to_h do |character|
          slug = slug_for(:character, character)
          frontmatter = {
            "name" => character.name,
            "slug" => slug,
            "affiliation" => affiliation(character)
          }
          frontmatter["pronouns"] = character.pronouns if character.pronouns.present?

          [ "#{base}/universe/characters/#{slug}.md",
            profile(frontmatter, character.name,
              rewrite_references(character.description), rewrite_references(character.summary)) ]
        end
      end

      # The importer splits the affiliation on `·`, and each typed link becomes
      # a Faction membership. A Character in no Faction still needs a non-blank
      # value, so it takes the same undecided marker the source uses.
      def affiliation(character)
        links = character.factions.sort_by(&:name).map { |faction| "[[faction:#{slug_for(:faction, faction)}]]" }
        links.any? ? links.join(" · ") : TBD
      end

      def faction_files
        factions.to_h do |faction|
          slug = slug_for(:faction, faction)
          frontmatter = { "name" => faction.name, "slug" => slug }
          [ "#{base}/universe/factions/#{slug}.md",
            profile(frontmatter, faction.name,
              rewrite_references(faction.description), rewrite_references(faction.summary)) ]
        end
      end

      def location_files
        locations.to_h do |location|
          slug = slug_for(:location, location)
          frontmatter = { "name" => location.name, "slug" => slug }
          [ "#{base}/universe/locations/#{slug}.md",
            profile(frontmatter, location.name,
              rewrite_references(location.description), rewrite_references(location.summary)) ]
        end
      end

      def item_files
        items.to_h do |item|
          slug = slug_for(:item, item)
          frontmatter = { "name" => item.name, "slug" => slug }
          [ "#{base}/universe/tech/#{slug}.md",
            profile(frontmatter, item.name,
              rewrite_references(item.description), rewrite_references(item.summary)) ]
        end
      end

      # The description is written before the summary so the importer sees the
      # description's own introduction where the source wrote it. A summary
      # section placed first would swallow that introduction.
      #
      # A Location and an Item have no summary column in the import, so their
      # summary survives as one more description section rather than as the
      # record's own answer. That is an interchange limit, not a lost sentence.
      def profile(frontmatter, title, description, summary)
        parts = [ frontmatter(frontmatter), "# #{title}", "" ]
        parts << description.to_s.strip << "" if description.present?
        parts << "## Short summary" << "" << summary.to_s.strip << "" if summary.present?
        parts.join("\n").rstrip + "\n"
      end

      def story_files
        files = { "#{base}/stories/README.md" => stories_readme }

        stories.each do |story|
          directory = "#{base}/stories/#{story.slug}"
          files["#{directory}/README.md"] = story_readme(story)
          files.merge!(chapter_files(story, directory))
          files.merge!(plot_files(story, directory))
        end

        files
      end

      def stories_readme
        rows = stories.map { |story| "| #{story.name} | `#{story.slug}/README.md` |" }
        <<~MARKDOWN
          # Stories

          | Story | Reading order |
          |---|---|
          #{rows.join("\n")}
        MARKDOWN
      end

      def story_readme(story)
        <<~MARKDOWN
          # #{story.name}

          #{story.description.to_s.strip}
        MARKDOWN
      end

      def chapter_files(story, story_directory)
        sections = story.sections.order(:position, :id).to_a
        scenes = story.scenes.order(:position, :id)
          .includes(:pov_character, scene_locations: :location, plots: :story,
            scene_elements: { scene_dialogue_turns: :speaker })
          .to_a

        files = {}
        section_ids = sections.map(&:id)
        groups = sections.map { |section| [ section, scenes.select { |scene| scene.section_id == section.id } ] }
        ungrouped = scenes.reject { |scene| section_ids.include?(scene.section_id) }
        # `scenes` is already in narrative order, so the index is the Story's own
        # position. It is written explicitly because the chapter directories group
        # by Section and would otherwise be the import's only order.
        positions = scenes.each_with_index.to_h { |scene, index| [ scene.id, index ] }
        # A Scene's filename is its story-wide address. The application does not
        # keep that address unique within a Story, so a duplicate would make the
        # validator refuse the source; the first Scene keeps it and the later one
        # is suffixed, the same way a record slug collision is.
        addresses = unique_scene_addresses(scenes)

        groups.each_with_index do |(section, group_scenes), index|
          directory = format("%02d-%s", index + 1, section.slug)
          files.merge!(chapter(story_directory, directory, section.name, section.short_summary,
            group_scenes, positions, addresses))
        end

        if ungrouped.any?
          directory = "#{format("%02d", sections.size + 1)}-ungrouped"
          files.merge!(chapter(story_directory, directory, UNGROUPED_TITLE, nil, ungrouped, positions,
            addresses))
        end

        files["#{story_directory}/chapters/.gitkeep"] = "" if files.empty?
        files
      end

      # The Scene a bare `[[scene:slug]]` already names is the first one with that
      # slug, because that is the record the application resolves the reference
      # to; the later Scene takes the suffix and no stored reference changes
      # meaning.
      def unique_scene_addresses(scenes)
        used = Set.new

        scenes.to_h { |scene| [ scene.id, claim_slug(scene.slug, :scene, used) ] }
      end

      def chapter(story_directory, directory, title, summary, scenes, positions, addresses)
        base_directory = "#{story_directory}/chapters/#{directory}"
        files = { "#{base_directory}/README.md" => chapter_readme(title, summary) }

        scenes.each_with_index do |scene, index|
          path = "#{base_directory}/#{format("%02d", index + 1)}-#{addresses.fetch(scene.id)}.md"
          files[path] = scene_document(scene, positions.fetch(scene.id))
        end

        files
      end

      def chapter_readme(title, summary)
        frontmatter = { "title" => title }
        frontmatter["summary"] = summary if summary.present?

        "#{frontmatter(frontmatter)}# #{title}\n\nA chapter of this Story. The Scenes below it are its Section.\n"
      end

      def scene_document(scene, position)
        moment = scene.datetime&.utc&.strftime("%Y-%m-%d %H:%M")
        character = scene.pov_character
        location = scene_location(scene)
        plot = scene.plots.min_by(&:id)
        frontmatter = {
          "id" => format("B-%03d", scene.id % 1000),
          "position" => position,
          "title" => scene.name,
          "pov" => character ? slug_for(:character, character) : TBD,
          "location" => location ? slug_for(:location, location) : TBD,
          "timeline" => moment || TBD,
          "branch" => "main"
        }
        frontmatter["moment"] = moment if moment
        frontmatter["plot"] = slug_for(:plot, plot) if plot

        parts = [ frontmatter(frontmatter), "# #{scene.name}", "" ]
        scene_blocks(scene).each do |heading, body|
          parts << "## #{heading}" << "" << body.to_s.strip << ""
        end

        parts.join("\n").rstrip + "\n"
      end

      def scene_location(scene)
        scene.scene_locations.min_by(&:id)&.location
      end

      # The source alternates and never puts two blocks of the same kind side by
      # side, so adjacent Elements merge and a leading Dialogue gets an empty
      # Narration before it. The prose is kept in order; the app's Element
      # boundary and its block titles are not part of the interchange.
      def scene_blocks(scene)
        blocks = []

        scene.scene_elements.sort_by { |element| [ element.position, element.id ] }.each do |element|
          heading, body = export_block(element)
          separator = heading == DIALOGUE ? "\n" : "\n\n"

          if blocks.last && blocks.last[0] == heading
            blocks.last[1] = [ blocks.last[1], body ].reject(&:blank?).join(separator)
          else
            blocks << [ heading, body.to_s ]
          end
        end

        blocks.unshift([ NARRATION, "" ]) if blocks.empty? || blocks.first[0] == DIALOGUE
        blocks
      end

      # A Dialogue with turns exports its turns. A Dialogue with no turns keeps
      # its block body as Narration instead, because a title-only or older block
      # has nothing the Dialog grammar can read.
      def export_block(element)
        if element.kind == SceneElement::DIALOGUE && element.scene_dialogue_turns.any?
          [ DIALOGUE, dialogue_lines(element).join("\n") ]
        else
          [ NARRATION, rewrite_references(element.body.to_s.strip) ]
        end
      end

      def dialogue_lines(element)
        element.scene_dialogue_turns.sort_by { |turn| [ turn.position, turn.id ] }.map do |turn|
          if turn.speaker
            "@[[character:#{slug_for(:character, turn.speaker)}]] #{quote(rewrite_references(turn.body))}"
          else
            tag, body = non_character_turn(turn.body)
            "@#{tag} #{quote(rewrite_references(body))}"
          end
        end
      end

      # The stored non-character body is `tag: line`. The bare speaker is the
      # tag turned into a slug the grammar accepts; a body without one speaks as
      # `speaker`, which the manuscript already labels as a non-character voice.
      def non_character_turn(body)
        match = NON_CHARACTER_TURN.match(body.to_s)
        return [ "speaker", body.to_s ] unless match

        tag = match[1].parameterize
        tag = "speaker" unless tag.match?(SLUG)
        [ tag, match[2] ]
      end

      def quote(text)
        %("#{text.to_s.gsub(/\s+/, " ").strip}")
      end

      def plot_files(story, story_directory)
        plots(story).to_h do |plot|
          slug = slug_for(:plot, plot)
          frontmatter = { "name" => plot.name, "slug" => slug }
          [ "#{story_directory}/plots/#{slug}.md",
            profile(frontmatter, plot.name,
              rewrite_references(plot.description), rewrite_references(plot.short_summary)) ]
        end
      end

      # The validator requires every entity directory, and a tar only carries a
      # directory when it holds a file. The dotfile is ignored by the reader, so
      # an empty directory survives the archive without becoming a record.
      def empty_directories
        %w[characters factions locations tech].to_h do |directory|
          [ "#{base}/universe/#{directory}/.gitkeep", "" ]
        end
      end

      def frontmatter(values)
        body = values.compact.to_yaml.sub(/\A---\n/, "")
        "---\n#{body}---\n"
      end

      def indent(value)
        value.to_s.strip.gsub("\n", "\n  ")
      end

      def add_file(tar, path, content)
        bytes = content.to_s
        tar.add_file_simple(path, 0o644, bytes.bytesize) do |io|
          io.write(bytes)
        end
      end
  end
end
