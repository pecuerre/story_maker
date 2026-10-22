module InvalidatesUniverseSummary
  extend ActiveSupport::Concern

  # `Universe#summary_counts` counts this model's table and caches the result,
  # so anything that can change a counted figure expires the summary of this
  # record's universe — and of the previous universe when a record moves
  # between them. The same rule `InvalidatesMenuCounts` applies to the sidebar
  # menu counts; the two caches are independent entries and both expire here.
  included do
    before_update :track_universe_summary_move, if: :will_save_change_to_universe_id?
    after_commit :expire_universe_summary_counts, on: %i[ create destroy update ]
  end

  private

    def track_universe_summary_move
      @universe_summary_previous_universe_id = universe_id_was
    end

    def expire_universe_summary_counts
      [ universe_id, @universe_summary_previous_universe_id ].compact.uniq.each do |universe_id|
        MenuCountCache.expire(:universe_summary, universe_id)
      end
    ensure
      @universe_summary_previous_universe_id = nil
    end
end
