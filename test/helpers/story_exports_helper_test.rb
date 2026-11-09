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

  test "a non-character turn prints its slug tag as a speaker and keeps only the speech" do
    turn = SceneDialogueTurn.new(body: "registry-clerk: Your material came up with the last road lot.")

    assert_equal [ "Registry Clerk", "Your material came up with the last road lot." ],
      manuscript_turn_speaker_and_line(turn)
  end

  test "a non-character tag the author wrote as a name keeps its words" do
    turn = SceneDialogueTurn.new(body: "Tomás Nieves: That's the whole of it?")

    assert_equal [ "Tomás Nieves", "That's the whole of it?" ], manuscript_turn_speaker_and_line(turn)
  end

  test "only the first colon separates a non-character tag from the speech" do
    turn = SceneDialogueTurn.new(body: "registry-clerk: That's what was registered: nothing.")

    assert_equal [ "Registry Clerk", "That's what was registered: nothing." ],
      manuscript_turn_speaker_and_line(turn)
  end

  test "a non-character line with no tag keeps the label and prints whole" do
    turn = SceneDialogueTurn.new(body: "The gate is open.")

    assert_equal [ "Non-character speaker", "The gate is open." ], manuscript_turn_speaker_and_line(turn)
  end

  test "a character turn keeps its stored speaker and its whole line" do
    turn = SceneDialogueTurn.new(speaker: characters(:character_one), body: "registry-clerk: not a tag here")

    assert_equal [ "Character one", "registry-clerk: not a tag here" ], manuscript_turn_speaker_and_line(turn)
  end
end
