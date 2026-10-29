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
  class Document
    FRONTMATTER = /\A---[ \t]*\r?\n(.*?)\r?\n---[ \t]*(?:\r?\n|\z)/m
    REFERENCE = /\[\[([^\[\]\n]+)\]\]/

    Reference = Data.define(:target, :line)

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

    private
      def parse
        if (match = FRONTMATTER.match(@raw))
          @frontmatter = YAML.safe_load(match[1], permitted_classes: [ Date, Time ], aliases: true)
          @body = match.post_match
          @parse_error = "frontmatter must be a mapping" unless @frontmatter.is_a?(Hash)
        else
          @frontmatter = nil
          @body = @raw
          @parse_error = "missing YAML frontmatter"
        end
      rescue Psych::Exception => error
        @frontmatter = nil
        @body = @raw
        @parse_error = "frontmatter is not valid YAML: #{error.message}"
      end

      def scan_references
        mask_code(@raw).each_line.with_index(1).flat_map do |line, number|
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
  end
end
