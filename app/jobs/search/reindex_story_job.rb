# Re-indexes one story's records after its slug changed.
#
# Every document below a story stores a path containing that story's slug, so a
# rename makes them dead links. This is `Search::ReindexUniverseJob`'s repair
# bounded to the story that changed, because a story rename must not rewrite an
# entire universe, and the records above it carry no part of that path.
class Search::ReindexStoryJob < ApplicationJob
  queue_as :default

  def perform(story_id)
    story = Story.find_by(id: story_id)
    return if story.nil?

    summary = Search::Reindexer.new.call_for_story(story)
    Rails.logger.info { "[search] #{story.name}: #{summary}" }
  end
end
