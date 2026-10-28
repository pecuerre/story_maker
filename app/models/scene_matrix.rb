# One Story's Scenes as a matrix: every Scene in narrative order as a row, and
# one column for each fact the Story already stores about it.
#
# The matrix is a read. It builds no form, stores no result, and never reorders
# or renumbers anything: `Scene#position` is still the only order, so the rows
# are the same sequence the Scenes list shows. Section grouping is one column,
# not a second grouping of the table, because grouping never changes the order.
#
# Every read is grouped. The rows arrive in one query with their Section, point
# of view, Scene Tags, and Event links preloaded; the Element count and the
# participant count are one grouped query each; and the prose total is the
# Story's existing `WordCounts`. A Story of hundreds of Scenes therefore costs
# the same number of queries as a short one.
#
# Presence is read through `SceneParticipants`, so the participant count is the
# union the Characters tab, the Scenes list, and the Appearance grid report. A
# Character who both participates and speaks is counted once.
class SceneMatrix
  attr_reader :story, :scenes

  def initialize(story)
    @story = story
    @scenes = story.scenes
      .includes(:section, :pov_character, :scene_tags, scene_events: :event)
      .reorder(:position, :id)
      .to_a
    @element_counts = SceneElement.where(scene_id: @scenes.map(&:id)).group(:scene_id).count
    @participant_counts = SceneParticipants.counts_by_scene(@scenes)
    @word_counts = WordCounts.for_story(story)
  end

  def scenes?
    scenes.any?
  end

  def element_count_for(scene)
    @element_counts.fetch(scene.id, 0)
  end

  def word_count_for(scene)
    @word_counts.for_scene(scene)
  end

  def participant_count_for(scene)
    @participant_counts.fetch(scene.id, 0)
  end
end
