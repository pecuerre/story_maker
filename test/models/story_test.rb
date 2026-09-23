require "test_helper"

class StoryTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
  end

  test "requires a name" do
    story = Story.new(universe: @universe)

    assert_not story.valid?
    assert_includes story.errors[:name], "can't be blank"
  end

  test "derives its slug from the name" do
    story = Story.create!(universe: @universe, name: "A Song of Ice and Fire")

    assert_equal "a-song-of-ice-and-fire", story.slug
  end

  test "rejects a duplicate name within the same universe" do
    story = Story.new(universe: @universe, name: stories(:story_one).name)

    assert_not story.valid?
    assert_includes story.errors[:name], "has already been taken"
  end

  test "allows the same name in another universe" do
    story = Story.new(universe: universes(:universe_two), name: stories(:story_one).name)

    assert story.valid?
  end

  test "keeps stories of one universe apart from stories of another" do
    assert_equal [ "spin-off", "story-one" ],
      @universe.stories.pluck(:slug).sort
    assert_includes universes(:universe_two).stories.pluck(:slug), "story-two"
  end

  test "destroying a story destroys its sections" do
    story = stories(:story_one)

    assert_difference("Section.count", -2) do
      story.destroy!
    end
  end

  test "destroying a story destroys its section tags" do
    story = stories(:story_one)

    assert_difference("SectionTag.count", -2) do
      story.destroy!
    end
  end
end
