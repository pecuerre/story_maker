module Search
  # A page of hits and how many the engine thinks exist in total, so a page can
  # say "12 of 40 matches" instead of implying that a short list is everything.
  class ResultSet
    attr_reader :hits, :total, :took_ms

    def initialize(hits: [], total: nil, took_ms: nil)
      @hits = hits
      @total = total.nil? ? hits.size : total
      @took_ms = took_ms
    end

    def any?
      hits.any?
    end

    def empty?
      hits.empty?
    end

    def size
      hits.size
    end
  end
end
