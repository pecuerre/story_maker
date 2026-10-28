require "test_helper"

# The Story-scoped mention read. It is the second layer the appearance heatmap
# and the Character details page both consume, so it has to keep narrative order,
# story scope, and the difference between a mention and an appearance.
class StoryMentionsTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    @character = @universe.characters.create!(name: "Mira", aliases: "The Fox")
  end

  def add_element(scene, body, name: "Mira block", position: 0)
    scene.scene_elements.create!(name: name, kind: "narration", body: body, position: position)
  end

  test "entries group mentions by scene in narrative order" do
    later = @story.scenes.create!(name: "Later scene", position: 3)
    add_element(scenes(:scene_two), "Mira waits.")
    add_element(later, "The Fox watches.")

    entries = StoryMentions.for(@story).entries_for(@character)

    assert_equal [ scenes(:scene_two), later ], entries.map(&:scene)
    assert_equal [ "Mira" ], entries.first.names
    assert_equal [ "The Fox" ], entries.last.names
  end

  test "one scene with several elements is one entry" do
    scene = scenes(:scene_two)
    add_element(scene, "Mira waits.", name: "First", position: 0)
    add_element(scene, "Mira again.", name: "Second", position: 1)

    entry = StoryMentions.for(@story).entries_for(@character).sole

    assert_equal 2, entry.count
    assert_equal [ "First", "Second" ], entry.elements.map(&:name)
    assert_equal [ "Mira" ], entry.names
  end

  test "a mention is not an appearance" do
    add_element(scenes(:scene_two), "Mira waits.")

    mentions = StoryMentions.for(@story)

    assert mentions.mentioned_in?(@character, scenes(:scene_two))
    assert_not mentions.mentioned_in?(@character, scenes(:scene_one))
    assert_empty SceneAppearances.for(@character, story: @story).entries
  end

  test "mentions stay inside the story that was read" do
    add_element(scenes(:scene_alt), "Mira waits in the spin-off.")

    assert_empty StoryMentions.for(@story).entries_for(@character)
    assert_equal 1, StoryMentions.for(stories(:story_alt)).entries_for(@character).count
  end

  test "a soft-deleted element contributes no mention" do
    element = add_element(scenes(:scene_two), "Mira waits.")
    element.soft_delete

    assert_empty StoryMentions.for(@story).entries_for(@character)
  end

  test "a soft-deleted scene contributes no mention" do
    add_element(scenes(:scene_two), "Mira waits.")
    scenes(:scene_two).soft_delete

    assert_empty StoryMentions.for(@story).entries_for(@character)
  end

  test "a character with no mention has no entries and no scene ids" do
    mentions = StoryMentions.for(@story)

    assert_empty mentions.entries_for(characters(:character_one))
    assert_empty mentions.scenes_for(characters(:character_one))
    refute mentions.any?
  end

  test "mentions_in reads the scene's own rows in element order" do
    scene = scenes(:scene_two)
    add_element(scene, "Mira waits.", name: "First", position: 0)
    add_element(scene, "Mira again.", name: "Second", position: 1)

    mentions = StoryMentions.for(@story).mentions_in(scene)

    assert_equal [ "First", "Second" ], mentions.map { |mention| mention.element.name }
    assert_equal [ @character, @character ], mentions.map(&:character)
  end
end
