# Re-indexes one scene's records after its slug changed.
#
# A scene's own document is rewritten by the save that renamed it. What is left
# stale is everything stored *below* it: an Element's hit opens its Scene, so a
# scene rename makes every Element document below it a dead link.
class Search::ReindexSceneJob < ApplicationJob
  queue_as :default

  def perform(scene_id)
    scene = Scene.find_by(id: scene_id)
    return if scene.nil?

    summary = Search::Reindexer.new.call_for_scene(scene)
    Rails.logger.info { "[search] #{scene.name}: #{summary}" }
  end
end
