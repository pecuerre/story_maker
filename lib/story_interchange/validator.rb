require "pathname"
require "set"

module StoryInterchange
  # Checks one source directory against the interchange layout and returns a
  # `Report`. It reads files only; no record is created, changed, or deleted.
  #
  # The checks are the contract in [the feature
  # document](../../docs/features/story_interchange.md): the identity a source
  # carries without a manifest, the required frontmatter for each record kind,
  # unique frozen slugs, the canon ledger's stable ids, scene numbering and
  # branch syntax, and every `[[...]]` reference.
  class Validator
    SLUG = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/
    CHAPTER_DIRECTORY = /\A\d{2}-.+\z/
    SCENE_FILE = /\A(\d{2})-(.+)\.md\z/
    SCENE_ID = /\AB-\d{3}\z/
    SCENE_BRANCH = /\A(?:main|fork of [A-Za-z0-9-]+-\d{2})\z/
    SCENE_STATUSES = %w[draft revised final].freeze
    # A definition is a bold id followed by a period or an em dash. Bold ids in
    # ordinary prose (`**K43's signature**`, `**D8 expires**`) are references,
    # not definitions. `marker` holds what follows the id inside the bold run —
    # the period, or an em dash and the item's heading — and `text` holds the
    # prose after the bold run, which is what the statement is drawn from.
    # A canon item opens with its bold id and then either a full stop or a short
    # title after a dash: `**K16.**`, `**L2 — Trigger.**`, `**D8.**`. Any of the
    # three dash characters the author may type separates the title, because the
    # source is prose and the separator is not a fact the application should
    # refuse to read.
    CANON_ITEM = /\A\s*(?:-\s+)?\*\*(?<id>K\d+|L\d+|D\d+|O(?:-[A-Z0-9]+)?\d+)(?<marker>\.|\s+[-–—][^*]*)\*\*(?<text>[^\n]*)\r?\n?\z/
    CANON_HEADING = /\A##\s+(.+?)\s*\z/
    # What an id's prefix means, which is the canon type the record stores.
    CANON_TYPES = { "K" => "locked", "L" => "rule", "D" => "consequence", "O" => "open" }.freeze
    # The source may cite a canon item as `[[rule:ID]]` or, in the current
    # character files, as `[[canon:ID]]`; both name the same locked or open id.
    RULE_REFERENCE = /\A(?:rule|canon):(.+)\z/
    SCENE_REFERENCE = /\Ascene:(.+)\z/
    # A typed entity reference: `[[character:ada]]`, `[[location:keep]]`. The
    # prefix says what the record must be, so a link cannot silently point at a
    # different kind that happens to share a slug.
    TYPED_REFERENCE = /\A(?<kind>[a-z]+):(?<slug>.+)\z/
    KIND_FOR_PREFIX = {
      "character" => :character,
      "faction" => :faction,
      "location" => :location,
      "item" => :item,
      "tech" => :item,
      "plot" => :plot
    }.freeze
    BACKLOG_REFERENCE = /\AB-\d{3}\z/
    PLACEHOLDER_REFERENCES = %w[slug].freeze

    ENTITY_KINDS = {
      "characters" => {
        directory: "characters",
        kind: :character,
        count: :characters,
        label: "character",
        # The current character file keeps only the three identity fields in
        # frontmatter and moves role, status, and first appearance into the
        # `## Information` body. The older keys are still accepted.
        required: %w[name slug affiliation],
        optional: %w[role status first_appears backlog]
      },
      "factions" => {
        directory: "factions",
        kind: :faction,
        count: :factions,
        label: "faction",
        required: %w[name slug type home status],
        optional: %w[backlog]
      },
      "locations" => {
        directory: "locations",
        kind: :location,
        count: :locations,
        label: "location",
        required: %w[name slug type controller status],
        optional: %w[backlog]
      },
      "tech" => {
        directory: "tech",
        kind: :item,
        count: :items,
        label: "item",
        required: %w[name slug type invented_by status],
        optional: %w[backlog]
      }
    }.freeze

    PLOT_REQUIRED = %w[name slug type status owner_pov].freeze
    PLOT_OPTIONAL = %w[opened_in backlog].freeze
    SCENE_REQUIRED = %w[id title chapter sequence pov location timeline branch status].freeze
    SCENE_OPTIONAL = %w[depends_on].freeze

    # Everything directly under `universe/` that the interchange reads. A
    # `README.md` is documentation at any depth, and `inspirations.md` is
    # authoring guidance with no record behind it, so it is reported rather than
    # silently ignored.
    UNIVERSE_ENTRIES = %w[README.md canon characters factions locations tech].freeze

    Entry = Data.define(:document, :kind, :story_slug, :chapter_slug)

    def initialize(path)
      @root = File.expand_path(path)
      @report = Report.new
      @entries = []
      @slugs = {}
      @slug_kinds = {}
      @character_slugs = Set.new
      @location_slugs = Set.new
      @canon_ids = {}
      @scene_keys = Set.new
    end

    def call
      unless File.directory?(@root)
        @report.error(path: @root, message: "source directory does not exist")
        return @report
      end

      read_identity
      return @report unless check_layout

      check_universe_entries
      read_canon
      read_entities
      read_stories
      check_references
      @report
    end

    private
      def read_identity
        name = File.basename(@root).delete_suffix(".git")
        slug = name.parameterize

        if slug.blank?
          @report.error(path: File.basename(@root), message: "source directory name must contain a letter or digit")
          return
        end

        @report.universe_slug = slug
        @report.universe_name = universe_name || slug.titleize
      end

      # The directory name is the Universe's address; `universe/README.md` opens
      # with the name a reader knows it by (`# Meridian`). The heading is the
      # display name when it exists, and the titleized slug is the fallback.
      def universe_name
        readme = File.join(@root, "universe", "README.md")
        return nil unless File.file?(readme)

        Document.load(readme, root: @root).title.to_s.strip.presence
      end

      def check_layout
        @universe = File.join(@root, "universe")
        @stories_directory = File.join(@root, "stories")
        valid = true

        [ @universe, @stories_directory ].each do |directory|
          next if File.directory?(directory)

          @report.error(path: relative(directory), message: "missing #{relative(directory)}/ directory")
          valid = false
        end

        if File.directory?(@universe)
          canon = File.join(@universe, "canon")
          unless File.directory?(canon)
            @report.error(path: relative(canon), message: "missing universe/canon/ directory")
            valid = false
          end

          ENTITY_KINDS.each_value do |config|
            directory = File.join(@universe, config[:directory])
            next if File.directory?(directory)

            @report.error(path: relative(directory), message: "missing universe/#{config[:directory]}/ directory")
            valid = false
          end

          readme = File.join(canon, "README.md")
          unless File.file?(readme)
            @report.error(path: relative(readme), message: "universe/canon/README.md is required")
            valid = false
          end
        end

        valid
      end

      # A file directly under `universe/` that is neither the README nor an
      # entity directory has no record kind in the application. The source may
      # legitimately carry one (`inspirations.md`), so it is a warning and the
      # preview names it instead of the import reading it as content.
      def check_universe_entries
        Dir.children(@universe).sort.each do |child|
          next if child.start_with?(".")
          next if UNIVERSE_ENTRIES.include?(child)

          path = File.join(@universe, child)
          @report.warning(path: relative(path),
            message: "unexpected entry in universe/; only README.md, canon/, and the entity directories are read")
        end
      rescue SystemCallError
        nil
      end

      def read_canon
        directory = File.join(@universe, "canon")
        markdown_files(directory, include_readme: true).each do |file|
          # The ledger README states the rules and indexes the areas. It is
          # documentation: required, but not an entity and not a reference
          # source.
          next if File.basename(file) == "README.md"

          document = document_for(file)
          @entries << Entry.new(document: document, kind: :canon, story_slug: nil, chapter_slug: nil)
          read_canon_area(document)
        end
      end

      def read_canon_area(document)
        section = nil
        item = nil
        lines = []

        document.content.each_line.with_index(1) do |line, number|
          if (match = CANON_HEADING.match(line))
            register_canon_item(item, lines, document, section) if item
            item = nil
            lines = []
            section = canon_section(match[1])
          elsif (match = CANON_ITEM.match(line))
            register_canon_item(item, lines, document, section) if item
            item = { id: match[:id], line: number, match: match }
            lines = [ line ]
          elsif item
            # Everything between this item's bold id and the next item or heading
            # is the item's own text. Keeping it whole is what lets the statement
            # be a real first sentence and the source passage be the passage,
            # rather than only the line the id happens to start on.
            lines << line
          end
        end

        register_canon_item(item, lines, document, section) if item
      end

      def canon_section(heading)
        text = heading.downcase
        if text.include?("open")
          :open
        elsif text.include?("locked") || text.include?("derived")
          :rule
        else
          :other
        end
      end

      # Finalizes the item that just ended. The lines include the item's own bold
      # id line, so the text is the passage as the author wrote it.
      def register_canon_item(item, lines, document, section)
        text = lines.join.strip
        register_canon_id(item[:id], document, item[:line], section, item[:match], text)
      end

      def register_canon_id(id, document, line_number, section, match, text)
        if @canon_ids.key?(id)
          error(document, line_number, "canon id #{id} is already defined in #{@canon_ids[id].relative_path}")
          return
        end

        @canon_ids[id] = document
        question = id.start_with?("O")
        # Every item becomes a rule, an open question included: the type is what
        # keeps the question distinguishable in the workspace. The question count
        # remains a subset the validator task and the preview can name.
        @report.count(:canon_rules)
        @report.count(:canon_questions) if question
        add_canon_item(id, document, line_number, match, text, question)

        if section == :open && !question
          warning(document, line_number, "canon id #{id} is a locked rule but sits under Open")
        elsif section == :rule && question
          warning(document, line_number, "canon id #{id} is an open question but sits under Locked")
        elsif section.nil? || section == :other
          warning(document, line_number, "canon id #{id} is outside a Locked, Derived, or Open section")
        end
      end

      # Hands the parsed item to the report so an import slice can write it. The
      # validator stays the one place that reads `universe/canon/`, rather than
      # the importer parsing the same files a second way.
      def add_canon_item(id, document, line_number, match, text, question)
        statement = canon_statement(match, text)
        item = Report::CanonItem.new(
          id: id,
          slug: id.downcase,
          name: canon_name(match, statement),
          canon_type: CANON_TYPES.fetch(id[0]),
          category: canon_category(document),
          statement: statement,
          source: canon_source(text),
          path: document.relative_path,
          line: line_number
        )

        @report.add_canon_rule(item)
        @report.add_canon_question(item) if question
      end

      # The item's own title when it states one (`**L2 — Trigger.**` names
      # `Trigger`), otherwise the statement, because a rule's name is required and
      # `**K16.**` states nothing but the rule itself.
      def canon_name(match, statement)
        canon_title(match).presence || statement
      end

      # The area file an item sits in, without the extension, which is the rule's
      # category. The ledger README is not an area and never reaches this method.
      def canon_category(document)
        File.basename(document.relative_path, ".md")
      end

      # The first sentence of the item's prose, or its title when the item has no
      # prose after the id. The prose is the whole item, not only its opening
      # line, so a sentence may span the line breaks the author used. Markdown and
      # source-file paths are presentation, not the rule, so they are cleaned off
      # before the sentence boundary is drawn: a period that closes bold text sits
      # beside `*`, not whitespace, until the markers are gone. A leading
      # amendment note is kept in the source and skipped here, so the statement
      # is the rule rather than a citation of what changed around it.
      def canon_statement(match, text)
        prose = strip_leading_canon_note(canon_clean(text_after_canon_id(text)))
        statement = first_sentence(prose).squish
        return statement if statement.present?

        canon_title(match).presence || canon_clean(match[0]).squish
      end

      # `*(Amended by K27.)*`, `(Author direction — K67: …)`, or a similar note at
      # the start of an item. It stays in `source`; it is not the rule.
      LEADING_CANON_NOTE = /\A\s*\((?=[^)]*(?:amend|author|stated|canon\b|K\d+|L\d+|D\d+|O-[A-Z0-9]+|rule:))[^)]*\)\s*/i

      def strip_leading_canon_note(prose)
        without_note = prose.sub(LEADING_CANON_NOTE, "")
        without_note.presence || prose
      end

      # The opening `**K16.**` or `**L2 — Trigger.**`, and nothing after it.
      def text_after_canon_id(text)
        text.sub(/\A\s*(?:-\s+)?\*\*[A-Z0-9-]+.*?\*\*/, "").strip
      end

      # A title's citation tail belongs in the body, not in the name: an
      # amendment such as `(Amended by K27)` or a `rule:L3` reference is removed
      # here, while `canon_source` keeps the item's original text whole.
      def canon_title(match)
        raw = match[:marker].to_s.sub(/\A\s*[-–—]\s*/, "").sub(/\.\z/, "").strip
        return "" if raw.blank?

        canon_clean(raw)
          .gsub(/\s*\([^()]*?(?:amended|rule:|K\d+|L\d+|D\d+|O-[A-Z0-9]+)[^()]*\)/i, "")
          .gsub(/\s*\[{0,2}rule:[^\]\s]+\]{0,2}/i, "")
          .sub(/\s*[-–—]\s*(?:amended|see)\b.*\z/i, "")
          .strip
      end

      def first_sentence(text)
        text[/\A.*?[.!?](?=\s|\z)/m]&.strip || text
      end

      # What an item is stored as: its own text, with the Markdown the app cannot
      # render and the source tree's file paths taken out. Paragraph breaks stay,
      # because they are the author's, and rule references stay as written.
      def canon_source(text)
        canon_clean(text)
      end

      MARKDOWN_LINK = /\[([^\]\n]+)\]\([^)\n]+\)/
      INLINE_CODE = /`+([^`\n]*)`+/
      SOURCE_FILE_REFERENCE = %r{(?<![\w/])(?:[\w.-]+/)*[\w.-]+\.md\b}
      TABLE_RULE = /\A\|?[\s:|-]+\|?\z/

      # What an item is stored as: its own text, with the Markdown the app cannot
      # render and the source tree's file paths taken out. Paragraph breaks stay,
      # because they are the author's, and rule references stay as written. A
      # table keeps its cells as one readable line and loses the pipes and the
      # rule beneath its header; a list keeps its text and loses the marker.
      def canon_clean(text)
        text.to_s
          .gsub(MARKDOWN_LINK, '\1')
          .gsub(INLINE_CODE, '\1')
          .gsub(SOURCE_FILE_REFERENCE, "")
          .gsub(/~~/, "")
          .gsub(/\*\*|__/, "")
          .gsub(/\*/, "")
          .lines.map { |line| canon_clean_line(line) }.join("\n")
          .gsub(/\n{3,}/, "\n\n")
          .strip
      end

      def canon_clean_line(line)
        line = line.gsub(/[ \t]+/, " ").strip
        return "" if line.include?("|") && TABLE_RULE.match?(line)

        if line.start_with?("|")
          return line.sub(/\A\|/, "").sub(/\|\z/, "").split("|").map(&:strip).reject(&:blank?).join(" · ")
        end

        line.sub(/\A#+\s+/, "")
          .sub(/\A>\s+/, "")
          .sub(/\A[-+]\s+/, "")
      end

      def read_entities
        ENTITY_KINDS.each_value do |config|
          directory = File.join(@universe, config[:directory])
          next unless File.directory?(directory)

          markdown_files(directory).each do |file|
            document = document_for(file)
            @entries << Entry.new(document: document, kind: config[:kind], story_slug: nil, chapter_slug: nil)
            @report.count(config[:count])
            frontmatter = validate_frontmatter(document,
              kind: config[:kind],
              required: config[:required],
              optional: config[:optional],
              label: config[:label],
              slug_from_filename: true)
            register_entity(document, config[:kind], frontmatter) if frontmatter
          end
        end
      end

      def read_stories
        stories = directories(@stories_directory)
        if stories.empty?
          @report.error(path: relative(@stories_directory), message: "stories/ must contain at least one story directory")
          return
        end

        stories.each { |directory| read_story(directory) }
      end

      def read_story(directory)
        slug = File.basename(directory)
        unless slug.match?(SLUG)
          @report.error(path: relative(directory), message: "story directory name must be a lowercase hyphenated slug")
          return
        end

        @report.count(:stories)
        read_story_readme(directory, slug)
        read_story_records(directory, slug)
      end

      def read_story_readme(directory, slug)
        path = File.join(directory, "README.md")

        unless File.file?(path)
          @report.add_story(slug: slug, name: slug.titleize)
          @report.error(path: relative(directory), message: "story #{slug} is missing README.md")
          return
        end

        document = document_for(path)

        if blank?(document.title)
          @report.add_story(slug: slug, name: slug.titleize)
          @report.error(path: relative(path), message: "story README needs a `# Story name` heading")
        else
          @report.add_story(slug: slug, name: document.title.strip)
        end
      end

      def read_story_records(directory, slug)
        Dir.children(directory).sort.each do |child|
          next if child == "README.md"
          next if child.start_with?(".")

          path = File.join(directory, child)
          case child
          when "chapters", "plots"
            if File.directory?(path)
              child == "chapters" ? read_chapters(path, slug) : read_plots(path, slug)
            else
              @report.warning(path: relative(path), message: "#{child} in story #{slug} must be a directory")
            end
          else
            @report.warning(path: relative(path),
              message: "unexpected entry in story #{slug}; only README.md, chapters/, and plots/ belong here")
          end
        end
      end

      def read_plots(directory, slug)
        markdown_files(directory).each do |file|
          document = document_for(file)
          @entries << Entry.new(document: document, kind: :plot, story_slug: slug, chapter_slug: nil)
          @report.count(:plots)
          frontmatter = validate_frontmatter(document,
            kind: :plot,
            required: PLOT_REQUIRED,
            optional: PLOT_OPTIONAL,
            label: "plot",
            slug_from_filename: true)
          register_entity(document, :plot, frontmatter, story_slug: slug) if frontmatter
        end
      end

      def read_chapters(directory, story_slug)
        directories(directory).each do |chapter_directory|
          chapter = File.basename(chapter_directory)
          unless chapter.match?(CHAPTER_DIRECTORY)
            @report.error(path: relative(chapter_directory), message: "chapter directory must be named NN-slug")
            next
          end

          @report.count(:chapters)
          @report.add_chapter(story_slug: story_slug, slug: chapter, name: chapter_name(chapter_directory, chapter))
          markdown_files(chapter_directory).each do |file|
            read_scene(file, story_slug, chapter)
          end
        end
      end

      # A chapter directory may carry a README whose `#` heading names the
      # chapter for a human: `# Chapter 06 — The Meeting`. The heading supplies
      # the Section's display name when it names one, and the directory's own
      # slug part is the fallback so a chapter without a README still has a name.
      def chapter_name(directory, slug)
        readme = File.join(directory, "README.md")
        heading = File.file?(readme) ? Document.load(readme, root: @root).title.to_s.strip : ""
        heading = heading.sub(/\Achapter\s+\d{2}\s*[—–:-]\s*/i, "").strip
        heading.presence || slug.sub(/\A\d{2}-/, "").tr("-", " ").titleize
      end

      def read_scene(file, story_slug, chapter)
        match = SCENE_FILE.match(File.basename(file))
        unless match
          @report.error(path: relative(file), message: "scene filename must be NN-slug.md")
          return
        end

        sequence = match[1]
        document = document_for(file)
        @entries << Entry.new(document: document, kind: :scene, story_slug: story_slug, chapter_slug: chapter)
        @report.count(:scenes)

        frontmatter = validate_frontmatter(document,
          kind: :scene,
          required: SCENE_REQUIRED,
          optional: SCENE_OPTIONAL,
          label: "scene",
          slug_from_filename: false)
        return unless frontmatter

        register_entity(document, :scene, frontmatter, story_slug: story_slug, name: frontmatter["title"])
        check_scene(document, frontmatter, story_slug, chapter, sequence)
      end

      def check_scene(document, frontmatter, story_slug, chapter, sequence)
        if frontmatter["chapter"].is_a?(String) && frontmatter["chapter"] != chapter
          error(document, 1, "scene chapter `#{frontmatter["chapter"]}` must match its directory `#{chapter}`")
        end

        unless frontmatter["sequence"].to_s.rjust(2, "0") == sequence
          error(document, 1, "scene sequence `#{frontmatter["sequence"]}` must match filename prefix `#{sequence}`")
        end

        id = frontmatter["id"]
        error(document, 1, "scene id `#{id}` must be B-### (three digits)") unless id.is_a?(String) && id.match?(SCENE_ID)

        status = frontmatter["status"]
        unless SCENE_STATUSES.include?(status)
          error(document, 1, "scene status `#{status}` must be one of #{SCENE_STATUSES.join(", ")}")
        end

        branch = frontmatter["branch"]
        unless branch.is_a?(String) && branch.match?(SCENE_BRANCH)
          error(document, 1, "scene branch `#{branch}` must be `main` or `fork of <Holder>-<NN>`")
        end

        check_named_slug(document, frontmatter["pov"], @character_slugs, "point of view")
        check_named_slug(document, frontmatter["location"], @location_slugs, "location")
        check_depends_on(document, frontmatter["depends_on"])
        @scene_keys << [ story_slug, chapter, File.basename(document.path, ".md") ]
      end

      def check_named_slug(document, value, allowed, label)
        return if blank?(value) || value.to_s.strip.start_with?("—")

        unless value.is_a?(String) && allowed.include?(value)
          error(document, 1, "scene #{label} `#{value}` does not name a record in the source")
        end
      end

      def check_depends_on(document, value)
        return if blank?(value)
        return if value.is_a?(Array) && value.all? { |item| item.is_a?(String) && item.match?(BACKLOG_REFERENCE) }

        error(document, 1, "depends_on must be a list of B-### ids")
      end

      def validate_frontmatter(document, kind:, required:, optional:, label:, slug_from_filename:)
        if document.parse_error
          error(document, 1, "#{label}: #{document.parse_error}")
          return nil
        end

        frontmatter = document.frontmatter
        keys = frontmatter.keys.map(&:to_s)

        (required - keys).each do |key|
          error(document, 1, "#{label}: missing required frontmatter key `#{key}`")
        end

        (required & keys).each do |key|
          error(document, 1, "#{label}: required frontmatter key `#{key}` is blank") if blank?(frontmatter[key])
        end

        (keys - required - optional).each do |key|
          warning(document, 1, "#{label}: unknown frontmatter key `#{key}`")
        end

        if slug_from_filename
          slug = frontmatter["slug"]
          if slug.is_a?(String)
            expected = File.basename(document.path, ".md")
            error(document, 1, "#{label}: slug `#{slug}` must match the filename `#{expected}.md`") unless slug == expected
            error(document, 1, "#{label}: slug `#{slug}` is not a lowercase hyphenated slug") unless slug.match?(SLUG)
            register_slug(slug, document, kind)
          end
        end

        frontmatter
      end

      def register_slug(slug, document, kind)
        if @slugs.key?(slug)
          error(document, 1, "duplicate record slug `#{slug}` (also #{@slugs[slug].relative_path})")
        else
          @slugs[slug] = document
          @slug_kinds[slug] = kind
        end

        @character_slugs << slug if kind == :character
        @location_slugs << slug if kind == :location
      end

      # Hands the parsed record to the report so an import slice writes it. The
      # filename is the identity (the contract requires the frontmatter slug to
      # match it), and the body is split once here rather than by every slice.
      def register_entity(document, kind, frontmatter, story_slug: nil, name: nil)
        @report.add_entity(Report::Entity.new(
          kind: kind,
          slug: File.basename(document.path, ".md"),
          name: (name || frontmatter["name"]).to_s,
          frontmatter: frontmatter,
          sections: document.sections,
          introduction: document.introduction,
          story_slug: story_slug
        ))
      end

      def check_references
        @entries.each do |entry|
          entry.document.references.each do |reference|
            check_reference(entry, reference)
          end
        end
      end

      def check_reference(entry, reference)
        target = reference.target

        if PLACEHOLDER_REFERENCES.include?(target)
          nil
        elsif target.match?(BACKLOG_REFERENCE)
          nil
        elsif (match = target.match(RULE_REFERENCE))
          unless @canon_ids.key?(match[1])
            error(entry.document, reference.line, "unknown canon rule `#{match[1]}`")
          end
        elsif (match = target.match(SCENE_REFERENCE))
          unless entry.kind == :scene && @scene_keys.include?([ entry.story_slug, entry.chapter_slug, match[1] ])
            error(entry.document, reference.line, "unknown scene `#{match[1]}` in this chapter")
          end
        elsif (match = target.match(TYPED_REFERENCE)) && KIND_FOR_PREFIX.key?(match[:kind])
          check_typed_reference(entry, reference, KIND_FOR_PREFIX[match[:kind]], match[:slug])
        elsif target.match?(SLUG)
          unless @slugs.key?(target)
            error(entry.document, reference.line, "unknown record slug `#{target}`")
          end
        else
          error(entry.document, reference.line, "unknown reference form `[[#{target}]]`")
        end
      end

      # A typed reference must name a record of the kind its prefix declares.
      # `[[location:ada]]` is an error even though `ada` exists, because the
      # author asked for a Location and the page would have to break that promise.
      def check_typed_reference(entry, reference, kind, slug)
        unless slug.match?(SLUG) && @slugs.key?(slug)
          error(entry.document, reference.line, "unknown record slug `#{slug}`")
          return
        end

        return if @slug_kinds[slug] == kind

        error(entry.document, reference.line,
          "reference `[[#{reference.target}]]` names a #{@slug_kinds[slug]}, not a #{kind}")
      end

      def document_for(path)
        Document.load(path, root: @root)
      end

      # Only `.md` files are read. `README.md` is documentation at every depth —
      # the directory's own guide, never a record — so it is skipped unless the
      # caller is the canon ledger, which asks for it by name.
      def markdown_files(directory, include_readme: false)
        return [] unless File.directory?(directory)

        Dir.children(directory).sort.filter_map do |child|
          next if child.start_with?(".")
          next if child == "README.md" && !include_readme
          next unless child.end_with?(".md")

          path = File.join(directory, child)
          path if File.file?(path)
        end
      end

      def directories(directory)
        return [] unless File.directory?(directory)

        Dir.children(directory).sort.filter_map do |child|
          next if child.start_with?(".")

          path = File.join(directory, child)
          path if File.directory?(path)
        end
      end

      def relative(path)
        Pathname.new(path).relative_path_from(Pathname.new(@root)).to_s
      rescue ArgumentError
        path
      end

      def error(document, line, message)
        @report.error(path: document.relative_path, line: line, message: message)
      end

      def warning(document, line, message)
        @report.warning(path: document.relative_path, line: line, message: message)
      end

      def blank?(value)
        value.nil? || (value.respond_to?(:empty?) && value.empty?) ||
          (value.is_a?(String) && value.strip.empty?)
      end
  end
end
