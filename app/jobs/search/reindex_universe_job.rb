# Re-indexes one universe's records after its slug changed.
#
# Every document under a universe stores a path containing that universe's slug,
# so a rename makes every one of them a dead link. Re-indexing the universe is
# the bounded repair; the alternative is leaving a universe whose search results
# all point at 404s until someone remembers a full reindex.
class Search::ReindexUniverseJob < ApplicationJob
  queue_as :default

  def perform(universe_id)
    universe = Universe.find_by(id: universe_id)
    return if universe.nil?

    summary = Search::Reindexer.new.call_for_universe(universe)
    Rails.logger.info { "[search] #{universe.name}: #{summary}" }
  end
end
