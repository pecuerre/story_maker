module Search
  # One search result as the rest of the application sees it: a value object, not
  # the engine's own hash.
  #
  # A hit stores the *identifiers* of its universe and story rather than their
  # names. A rename therefore needs no reindex of every record that merely
  # mentions the universe, and a stale index can never show an old name: the
  # catalog resolves the context of each hit, in two queries, at read time.
  class Hit
    ATTRIBUTES = %i[ id kind taxonomy universe_id story_id title body url updated_at ].freeze
    # Long enough to place a result at a glance, short enough that a paragraph
    # of prose does not become the answer.
    SNIPPET_LENGTH = 160
    SNIPPET_GAP = 24

    attr_reader :id, :kind, :taxonomy, :universe_id, :story_id, :title, :body, :url, :updated_at
    # Display-only, and deliberately not stored in the index: the context names and
    # the excerpt depend on the request, not on the record.
    attr_accessor :subtitle, :snippet

    def initialize(attributes = {})
      ATTRIBUTES.each { |attribute| instance_variable_set(:"@#{attribute}", attributes[attribute]) }
      @subtitle = attributes[:subtitle]
      @snippet = attributes[:snippet]
    end

    # The engine answers with string keys and may add fields of its own. Only
    # the declared attributes are read, so an extra field in the index cannot
    # change the contract this object exposes.
    def self.from_engine(hit)
      new(hit.to_h.symbolize_keys.slice(*ATTRIBUTES))
    end

    def kind_label
      Kinds.label_for(kind, taxonomy)
    end

    # Fills in what only this request knows. `Search::Catalog` calls this once per
    # hit, having already batch-loaded the universe and story names.
    def describe(context:, query: nil)
      self.subtitle = context
      self.snippet = excerpt(query)
      self
    end

    def as_json(*)
      {
        id: id,
        kind: kind,
        kind_label: kind_label,
        taxonomy: taxonomy,
        title: title,
        subtitle: subtitle,
        snippet: snippet,
        url: url
      }
    end

    private
      # A plain-text excerpt, never markup: a snippet is the one place an
      # author's prose is shown back to them, and the results are rendered as
      # text. The window is centred on the first match, so the reader sees why
      # the record was returned instead of always its opening words.
      def excerpt(query)
        source = body.to_s.squish
        return if source.blank?

        window = [ SNIPPET_LENGTH, source.length ].min
        index = match_index(source, query)
        start = index ? [ index - SNIPPET_GAP, 0 ].max : 0
        excerpt = source[start, window].to_s.strip
        return excerpt unless index

        index.zero? ? excerpt : "…#{excerpt}"
      end

      def match_index(source, query)
        needle = query.to_s.strip.downcase
        return if needle.blank?

        source.downcase.index(needle)
      end
  end
end
