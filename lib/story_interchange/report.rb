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

    attr_reader :universe_slug, :universe_name, :stories, :counts, :issues

    def initialize
      @universe_slug = nil
      @universe_name = nil
      @stories = []
      @counts = Hash.new(0)
      @issues = []
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
