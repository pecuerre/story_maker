require "test_helper"

class SceneTest < ActiveSupport::TestCase
  setup do
    @story = stories(:story_one)
  end

  test "can be found by its normalized fixture slug" do
    scene = scenes(:scene_one)

    assert_equal "scene-one", scene.slug
    assert_equal scene, Scene.scene_one
  end

  test "requires a story" do
    scene = Scene.new(name: "Orphan")

    assert_not scene.valid?
    assert_includes scene.errors[:story], "must exist"
  end

  test "requires a title" do
    scene = Scene.new(story: @story, name: "")

    assert_not scene.valid?
    assert_includes scene.errors[:name], "can't be blank"
  end

  test "a title-only scene is valid" do
    assert Scene.create!(story: @story, name: "Unfinished scene")
  end

  test "resolves its universe through its story" do
    assert_equal universes(:universe_one), scenes(:scene_one).universe
    assert_nil Scene.new(name: "Orphan").universe
  end

  test "positions are independent flat integers without an ordering parent" do
    assert_not Scene.column_names.include?("parent_id")
    assert_equal [ 0, 1, 2 ], @story.scenes.reorder(:position, :id).pluck(:position)
  end

  test "a story owns and cascades its scenes" do
    assert_includes @story.scenes, scenes(:scene_one)
    assert_not_includes stories(:story_alt).scenes, scenes(:scene_one)

    assert_difference("Scene.count", -1) do
      stories(:story_alt).destroy!
    end
  end

  test "scenes are only reachable through their own universe" do
    assert_equal [ scenes(:scene_one), scenes(:scene_two), scenes(:scene_three) ],
      universes(:universe_one).scenes.where(story: stories(:story_one)).reorder(:position, :id).to_a
    assert_empty universes(:universe_two).scenes
  end

  test "references an optional same-story section and same-universe event" do
    scene = scenes(:scene_one)

    assert_equal sections(:section_one), scene.section
    assert_equal events(:event_one), scene.event
    assert_equal Time.utc(2026, 9, 11, 9), scene.datetime
  end

  test "the event link and the in-world datetime are independent" do
    # An event-only scene and a datetime-only scene are both valid, and setting
    # one never clears the other.
    event_only = @story.scenes.create!(name: "Event only", event: events(:event_two))
    time_only = @story.scenes.create!(name: "Time only", datetime: Time.utc(2019, 5, 4, 20, 15))

    assert_nil event_only.datetime
    assert_nil time_only.event

    event_only.update!(datetime: Time.utc(2019, 5, 4, 20, 15))
    assert_equal events(:event_two), event_only.reload.event
  end

  test "several scenes may reference the same event" do
    scenes(:scene_three).update!(event: events(:event_one))

    assert_equal [ events(:event_one), events(:event_one) ],
      [ scenes(:scene_one).reload.event, scenes(:scene_three).reload.event ]
  end

  test "a title-only scene stays valid without any reference" do
    scene = @story.scenes.create!(name: "Bare scene")

    assert_nil scene.section
    assert_nil scene.event
    assert_nil scene.datetime
  end

  test "rejects a section from another story" do
    scene = Scene.new(story: @story, name: "Wrong section", section: sections(:section_alt))

    assert_not scene.valid?
    assert_includes scene.errors[:section], "must belong to the same story"
  end

  test "rejects an event from another universe" do
    scene = Scene.new(story: @story, name: "Wrong event", event: events(:event_other_universe))

    assert_not scene.valid?
    assert_includes scene.errors[:event], "must belong to the story's universe"
  end

  test "rejects an unknown optional reference instead of raising a foreign key error" do
    scene = Scene.new(story: @story, name: "Broken references", section_id: 0, event_id: 0)

    assert_not scene.valid?
    assert_includes scene.errors[:section], "must exist"
    assert_includes scene.errors[:event], "must exist"
  end

  test "rejects an unparseable in-world datetime instead of silently dropping it" do
    scene = Scene.new(story: @story, name: "Bad time", datetime: "not-a-datetime")

    assert_not scene.valid?
    assert_includes scene.errors[:datetime], "is not a valid date and time"
  end

  test "accepts a minute-precision datetime-local string" do
    scene = Scene.create!(story: @story, name: "Local time", datetime: "2019-11-05T21:00")

    assert_equal Time.utc(2019, 11, 5, 21), scene.datetime
  end

  test "a blank datetime clears the in-world time" do
    scene = scenes(:scene_three)

    assert scene.datetime.present?
    scene.update!(datetime: "")

    assert_nil scene.reload.datetime
  end

  test "deleting a section only ungroups its scenes and keeps their order" do
    scene = scenes(:scene_one)
    original_positions = @story.scenes.reorder(:position, :id).pluck(:position)

    sections(:section_one).destroy!

    assert_nil scene.reload.section
    assert_equal original_positions, @story.scenes.reorder(:position, :id).pluck(:position)
  end

  test "deleting an event only clears scene references and keeps its scenes" do
    scene = scenes(:scene_one)

    assert_difference("Scene.count", 0) do
      events(:event_one).destroy!
    end

    assert_nil scene.reload.event
    assert_equal Time.utc(2026, 9, 11, 9), scene.datetime
  end
end
