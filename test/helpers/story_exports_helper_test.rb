require "test_helper"

class StoryExportsHelperTest < ActionView::TestCase
  include StoryExportsHelper
  include ScenesHelper

  test "the section and scene headings stay inside six levels" do
    assert_equal "h2", manuscript_section_heading(0)
    assert_equal "h3", manuscript_section_heading(1)
    assert_equal "h6", manuscript_section_heading(4)
    assert_equal "h6", manuscript_section_heading(9)

    assert_equal "h3", manuscript_scene_heading(0)
    assert_equal "h4", manuscript_scene_heading(1)
    assert_equal "h6", manuscript_scene_heading(9)
  end

  test "scene notes list the stored participants with their roles" do
    rows = manuscript_scene_notes(scenes(:scene_one))

    assert_equal [ "In-world time", "Characters", "Items", "Locations", "Events depicted" ],
      rows.map { |row| row[:label] }
    assert_equal "2026-09-11 09:00", rows.first[:text]

    characters = rows.find { |row| row[:label] == "Characters" }
    assert_equal [ [ "Character one", "setting" ], [ "Character two", nil ] ], characters[:entries]

    items = rows.find { |row| row[:label] == "Items" }
    assert_equal [ [ "Item one", "carries" ], [ "Item two", nil ] ], items[:entries]

    events = rows.find { |row| row[:label] == "Events depicted" }
    assert_equal [ [ events(:event_one).display_label, nil ] ], events[:entries]
  end

  test "a point of view is the first note when one is recorded" do
    scenes(:scene_one).update!(pov_character: characters(:character_one))

    rows = manuscript_scene_notes(scenes(:scene_one))

    assert_equal "Point of view", rows.first[:label]
    assert_equal "Character one", rows.first[:text]
  end

  test "a scene with nothing recorded produces no note rows" do
    scene = stories(:story_one).scenes.create!(name: "Bare scene")

    assert_empty manuscript_scene_notes(scene)
  end
end
