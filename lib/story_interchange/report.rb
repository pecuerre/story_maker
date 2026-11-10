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

    # One canon item that the import can turn into a record. `id` is the ledger's
    # own `K`/`L`/`D`/`O` id; `slug` is that id lowercased, `name` is the item's
    # what-line (its first statement when it states none), `canon_type` is what
    # the id's prefix means, and `category` is the area file the item sits in.
    # `statement` is the item's whole text, the what-line and body together, and
    # `source` is empty for the current format; the older bold form still fills it
    # with the item's text and draws the statement from its first sentence.
    CanonItem = Data.define(:id, :slug, :name, :canon_type, :category, :statement, :source, :path, :line)

    # One parsed record: the frontmatter the validator checked, the slug its
    # filename fixes, and the body split into `##` sections so a slice maps
    # headings to profile answers without reading the file a second time.
    #
    # `story_slug` is nil for a Universe record and names the owning Story for a
    # Plot or a Scene. `chapter_slug` names the chapter directory a Scene's
    # identity and placement come from. `drafting_contract` is the scene's
    # closing `DRAFTING CONTRACT` note when it has one; both are nil elsewhere.
    #
    # A Scene's `slug` is its filename (`01-the-gate`), because the chapter and
    # the two-digit sequence are the path. Its story-wide address, the one a
    # `[[scene:slug]]` reference names and the imported Scene itself uses, is
    # `scene_slug`: the filename without that sequence (`the-gate`).
    Entity = Data.define(:kind, :slug, :name, :frontmatter, :sections, :introduction, :story_slug,
      :chapter_slug, :drafting_contract) do
      def scene_slug
        slug.to_s.sub(/\A\d{2}-/, "")
      end
    end

    # One chapter directory. A chapter has no record file, so its source facts
    # are the directory name, the Story that holds it, and the README's YAML
    # frontmatter: `title` names it, `summary` is the Section's short summary,
    # and every other key is carried in `description` as YAML. Everything after
    # the frontmatter is documentation and is skipped.
    Chapter = Data.define(:story_slug, :slug, :name, :short_summary, :description)

    attr_reader :universe_slug, :universe_name, :stories, :chapters, :counts, :issues,
      :canon_rules, :canon_questions

    def initialize
      @universe_slug = nil
      @universe_name = nil
      @stories = []
      @chapters = []
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

    # One chapter directory, in the source's sorted order. The order is the
    # Section position the import writes, and the README's frontmatter is what
    # the Sections slice writes.
    def add_chapter(story_slug:, slug:, name:, short_summary:, description:)
      @chapters << Chapter.new(story_slug: story_slug, slug: slug, name: name,
        short_summary: short_summary, description: description)
    end

    def count(kind)
      @counts[kind] += 1
    end

    # A K/L/D item: one rule the import writes.
    def add_canon_rule(item)
      @canon_rules << item
    end

    # The O subset of those items. An open question is written as a rule of type
    # `open`; this list is what the validator task and the preview can count
    # separately from the rules that answer a question.
    def add_canon_question(item)
      @canon_questions << item
    end

    def add_entity(entity)
      @entities << entity
    end

    # Every parsed record, or only those of one kind. A slice reads the kind it
    # writes, so it never depends on another slice having run first. A typed
    # lookup asks for its kind, so a Character and a Scene that share a slug can
    # never resolve to each other. A Scene is addressed by its story-wide
    # `scene_slug` (`the-gate`) as well as its filename (`01-the-gate`).
    def entities(kind = nil)
      kind ? @entities.select { |entity| entity.kind == kind } : @entities
    end

    def entity(slug, kind: nil)
      candidates = kind ? entities(kind) : @entities
      candidates.find do |entity|
        entity.slug == slug || (entity.kind == :scene && entity.scene_slug == slug)
      end
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
