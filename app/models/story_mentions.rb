# The prose mentions of one Story, grouped by Scene and Character.
#
# `MentionIndex` answers *who is named at this offset*. This class is the
# Story-scoped read built on it: it loads the Story's Scenes and their Element
# bodies once and answers the two questions the mention surfaces ask.
#
# - `entries_for(character)` is the Character details page's suggestion list:
#   the Scenes where that Character's name is written, in narrative order, with
#   the Elements that named them.
# - `mentioned_in?(character, scene)` is the heatmap's second layer: whether a
#   name is written in a Scene, independent of whether the Character is
#   recorded as present there.
#
# **The grouping never adds an appearance.** A mention is a suggestion, so this
# object is deliberately not merged into `SceneAppearances` or
# `SceneParticipants`; the callers that show both keep them visually and
# semantically distinct. It writes nothing, and it reads only live Scenes and
# live Elements, so a soft-deleted Scene or Element contributes no mention.
class StoryMentions
  # One name occurrence in one Element. `text` is the spelling the author wrote,
  # which may be an alias, while `character` is the record it belongs to.
  Mention = Struct.new(:character, :scene, :element, :text, :offset, :length, keyword_init: true)

  # One Scene and every mention of one Character in it. `elements` and `names`
  # are derived here so the view never has to group the same rows twice.
  Entry = Struct.new(:character, :scene, :mentions, keyword_init: true) do
    def count
      mentions.size
    end

    def elements
      mentions.map(&:element).uniq
    end

    # The spellings that produced these mentions, deduplicated in reading order.
    # A row can say "written as Strider" when the author used an alias.
    def names
      mentions.map(&:text).uniq
    end
  end

  attr_reader :story, :index

  def self.for(story)
    new(story)
  end

  def initialize(story)
    @story = story
    @index = MentionIndex.for(story)
    @mentions_by_character = Hash.new { |hash, key| hash[key] = [] }
    @mentions_by_scene = Hash.new { |hash, key| hash[key] = [] }
    @scene_ids_by_character = Hash.new { |hash, key| hash[key] = Set.new }
    scan
  end

  # Scenes where the Character is named, in narrative order, each with the
  # Element rows that name them. A Character with no mentions has no entries
  # rather than an empty entry.
  def entries_for(character)
    return [] if character.nil?

    @mentions_by_character[character.id]
      .group_by(&:scene)
      .map { |scene, mentions| Entry.new(character: character, scene: scene, mentions: mentions) }
  end

  def scenes_for(character)
    entries_for(character).map(&:scene)
  end

  # The cheap read for a grid: one set membership test instead of building an
  # Entry for every cell.
  def mentioned_in?(character, scene)
    @scene_ids_by_character[character.id].include?(scene.id)
  end

  # Every mention in one Scene, for a page that highlights prose in place. The
  # order is the Scene's Element order, then reading order inside the body.
  def mentions_in(scene)
    @mentions_by_scene[scene.id]
  end

  # The Character ids that have at least one mention. The appearance grid uses
  # this to add a row for a Character who is named but never recorded present.
  def character_ids
    @mentions_by_character.keys
  end

  def any?
    @mentions_by_scene.any?
  end

  private
    def scan
      story.scenes.reorder(:position, :id).includes(:scene_elements).each do |scene|
        scene.scene_elements.sort_by { |element| [ element.position, element.id ] }.each do |element|
          index.matches(element.body).each do |match|
            mention = Mention.new(
              character: match.character,
              scene: scene,
              element: element,
              text: match.text,
              offset: match.offset,
              length: match.length
            )
            @mentions_by_character[mention.character.id] << mention
            @mentions_by_scene[scene.id] << mention
            @scene_ids_by_character[mention.character.id] << scene.id
          end
        end
      end
    end
end
