# One Story's appearances as a grid: every Character with a row, every Scene with
# a column, and two layers that are never merged.
#
# - **Recorded presence** is the union `SceneParticipants` already owns — an
#   explicit `SceneCharacter` link or a Dialogue speaker. An Event reference is a
#   source for an Event's appearances, not for a Character row, so it is absent
#   here by design.
# - **Prose mention** is `StoryMentions`: a name written in an Element body. It
#   is a suggestion, not a fact, and the grid gives it a different mark.
#
# A Character gets a row when the Story records them present somewhere or names
# them in prose somewhere. A Character with neither is left out rather than
# printed as a blank row: a Universe holds records the current Story never uses,
# and a grid of blanks would bury the cast that matters. Both layers are read
# from live records, so a soft-deleted Scene, Element, or Character contributes
# nothing.
#
# The grid is read-only. It builds no forms, stores nothing, and never turns a
# mention into a presence link.
class AppearanceGrid
  EMPTY_SET = Set.new.freeze

  attr_reader :story, :scenes, :characters, :mentions

  def initialize(story)
    @story = story
    @scenes = story.scenes.reorder(:position, :id).to_a
    @mentions = StoryMentions.for(story)
    @presence_by_scene = SceneParticipants.character_ids_by_scene(@scenes)
      .transform_values(&:to_set)
    @characters = story.universe.characters
      .where(id: character_ids)
      .reorder(:name, :id)
      .to_a
  end

  def characters?
    characters.any?
  end

  def scenes?
    scenes.any?
  end

  def appears?(character, scene)
    @presence_by_scene.fetch(scene.id, EMPTY_SET).include?(character.id)
  end

  def mentioned?(character, scene)
    mentions.mentioned_in?(character, scene)
  end

  # The view still receives both answers through `appears?` and `mentioned?`;
  # this is the one place the pair becomes a single label or two marks.
  def state_for(character, scene)
    appears = appears?(character, scene)
    named = mentioned?(character, scene)
    return :both if appears && named
    return :present if appears
    return :mention if named

    :none
  end

  private
    def character_ids
      presence_ids = @presence_by_scene.values.flat_map(&:to_a)
      (presence_ids + mentions.character_ids).uniq
    end
end
