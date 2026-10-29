require "date"
require "pathname"
require "yaml"

module StoryInterchange
  # One Markdown file in a source tree, read as an optional YAML frontmatter
  # block plus a Markdown body.
  #
  # Parsing is deliberately forgiving: a bad or missing block is recorded as
  # `parse_error` and the validator decides whether that is an error (an entity
  # file) or expected (a README or a canon area file). References are scanned
  # from the raw text, so a `[[slug]]` in frontmatter is checked too. Fenced code
  # blocks are masked out first because they are examples; inline code is not,
  # because the real source writes its rule references as `[[rule:L1]]`.
  #
  # An HTML comment is a drafting note for a human, not prose, so it is masked
  # out of the body and out of the reference scan. Masking replaces the comment
  # with spaces and keeps its line breaks, so a reported line number still points
  # at the file the author sees.
  class Document
    FRONTMATTER = /\A---[ \t]*\r?\n(.*?)\r?\n---[ \t]*(?:\r?\n|\z)/m
    REFERENCE = /\[\[([^\[\]\n]+)\]\]/
    SECTION = /^##[ \t]+(.+?)[ \t]*$/
    COMMENT = /<!--.*?-->/m
    # The heading a body opens with: the `#` name of a profile, the `##` title
    # of a Scene. It names the record, so it is not part of the prose.
    TITLE_HEADING = /\A\s*[#]{1,6}[ \t]+[^\n]*\r?\n?/

    Reference = Data.define(:target, :line)
    # One `##` section of the body, with its heading as the source wrote it. The
    # body is kept verbatim (minus the surrounding blank lines) because a
    # profile answer is author prose, not something the import may reformat.
    Section = Data.define(:heading, :body)

    attr_reader :path, :root, :frontmatter, :body, :raw, :parse_error

    def self.load(path, root:)
      new(path, root:)
    end

    def initialize(path, root:)
      @path = path
      @root = root
      @raw = File.read(path, encoding: "UTF-8")
      parse
    rescue SystemCallError, ArgumentError => error
      @raw = ""
      @body = ""
      @frontmatter = nil
      @parse_error = "could not be read: #{error.message}"
    end

    def relative_path
      Pathname.new(path).relative_path_from(Pathname.new(root)).to_s
    end

    def title
      body.to_s[/^#[ \t]+(.+?)[ \t]*$/, 1]
    end

    def references
      @references ||= scan_references
    end

    # The file with its HTML comments masked to spaces, line breaks preserved.
    # The canon reader walks this rather than `raw`, so a commented-out example
    # is never parsed as an item.
    def content
      @content ||= mask_comments(@raw)
    end

    # The `##` sections in source order, after the opening heading. A `###`
    # subheading stays part of the section it is written under, because the
    # profile answer owns the whole block.
    def sections
      @sections ||= begin
        collected = []
        current = nil

        text_after_title.each_line do |line|
          if (match = SECTION.match(line))
            current = [ match[1], +"" ]
            collected << current
          elsif current
            current[1] << line
          end
        end

        collected.map { |heading, text| Section.new(heading: heading, body: text.strip) }
      end
    end

    # The prose between the opening heading and the first `##` section. The
    # source puts the author's identity block there. A Scene opens with its own
    # `##` title heading and carries the whole manuscript here, because the
    # Scene contract has no sections.
    def introduction
      @introduction ||= begin
        text = text_after_title
        match = SECTION.match(text)
        (match ? text[0...match.begin(0)] : text).strip
      end
    end

    private
      def parse
        if (match = FRONTMATTER.match(@raw))
          @frontmatter = YAML.safe_load(match[1], permitted_classes: [ Date, Time ], aliases: true)
          @body = mask_comments(match.post_match)
          @parse_error = "frontmatter must be a mapping" unless @frontmatter.is_a?(Hash)
        else
          @frontmatter = nil
          @body = mask_comments(@raw)
          @parse_error = "missing YAML frontmatter"
        end
      rescue Psych::Exception => error
        @frontmatter = nil
        @body = mask_comments(@raw)
        @parse_error = "frontmatter is not valid YAML: #{error.message}"
      end

      def text_after_title
        @text_after_title ||= body.to_s.sub(TITLE_HEADING, "")
      end

      def scan_references
        mask_code(content).each_line.with_index(1).flat_map do |line, number|
          line.scan(REFERENCE).flatten.map do |target|
            Reference.new(target: target.strip, line: number)
          end
        end
      end

      # Preserve every character position and line break; only make the fenced
      # example invisible to the reference scanner.
      def mask_code(text)
        text.gsub(/```.*?```/m) { |block| block.gsub(/[^\n]/, " ") }
      end

      # The same masking for a human drafting note: its text never reaches stored
      # prose, and a `[[slug]]` written inside it is an example rather than a
      # reference.
      def mask_comments(text)
        text.gsub(COMMENT) { |comment| comment.gsub(/[^\n]/, " ") }
      end
  end
end
