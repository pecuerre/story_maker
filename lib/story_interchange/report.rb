module StoryInterchange
  # The result of one validation run: the identity read from the source, the
  # record counts a later import preview needs, and every error and warning.
  #
  # Errors block an import; warnings name something the author should review but
  # do not, because the layout allows a source to carry more than the app knows.
  class Report
    Issue = Data.define(:severity, :path, :line, :message) do
      def error?
        severity == :error
      end

      def warning?
        severity == :warning
      end

      def to_s
        "#{path}:#{line}: #{message}"
      end
    end

    # One canon item that the import can turn into a record. `statement` is the
    # item's first sentence, or its heading text when the item has no body, and
    # `source` is the item's own text plus the area it came from. A question has
    # no source because it never becomes a rule.
    CanonItem = Data.define(:id, :statement, :source, :path, :line)

    # One parsed record: the frontmatter the validator checked, the slug its
    # filename fixes, and the body split into `##` sections so a slice maps
    # headings to profile answers without reading the file a second time.
    #
    # `story_slug` is nil for a Universe record and names the owning Story for a
    # Plot, whose directory is what scopes it.
    Entity = Data.define(:kind, :slug, :name, :frontmatter, :sections, :introduction, :story_slug)

    attr_reader :universe_slug, :universe_name, :stories, :counts, :issues,
      :canon_rules, :canon_questions

    def initialize
      @universe_slug = nil
      @universe_name = nil
      @stories = []
      @counts = Hash.new(0)
      @issues = []
      @canon_rules = []
      @canon_questions = []
      @entities = []
    end

    def universe_slug=(value)
      @universe_slug = value
    end

    def universe_name=(value)
      @universe_name = value
    end

    def add_story(slug:, name:)
      @stories << { slug: slug, name: name }
    end

    def count(kind)
      @counts[kind] += 1
    end

    # A K/L/D item: one rule the import writes.
    def add_canon_rule(item)
      @canon_rules << item
    end

    # An O item: reported to the operator and never written, because an open
    # question is not a rule the prose must obey.
    def add_canon_question(item)
      @canon_questions << item
    end

    def add_entity(entity)
      @entities << entity
    end

    # Every parsed record, or only those of one kind. A slice reads the kind it
    # writes, so it never depends on another slice having run first.
    def entities(kind = nil)
      kind ? @entities.select { |entity| entity.kind == kind } : @entities
    end

    def entity(slug)
      @entities.find { |entity| entity.slug == slug }
    end

    def error(path:, message:, line: 1)
      @issues << Issue.new(severity: :error, path: path, line: line, message: message)
    end

    def warning(path:, message:, line: 1)
      @issues << Issue.new(severity: :warning, path: path, line: line, message: message)
    end

    def errors
      @issues.select(&:error?)
    end

    def warnings
      @issues.select(&:warning?)
    end

    def valid?
      errors.empty?
    end
  end
end
