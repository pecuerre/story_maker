require "test_helper"

class ContextualInspectorHelperTest < ActionView::TestCase
  include ContextualInspectorHelper

  setup do
    @controller = Struct.new(:controller_name).new("characters")
    Current.universe = universes(:universe_one)
    Current.story = nil
  end

  teardown do
    Current.story = nil
    Current.universe = nil
  end

  test "rows nothing when no story and no selected record" do
    assert_empty contextual_inspector_rows
  end

  test "a story page yields sections and scenes counts" do
    Current.story = stories(:story_one)
    @story = stories(:story_one)

    rows = contextual_inspector_rows

    assert_equal [
      [ t("inspector.sections"), 2 ],
      [ t("inspector.scenes"), 3 ]
    ], rows
  end

  test "a character details page yields relations and ownerships counts" do
    @character = characters(:character_one)

    rows = contextual_inspector_rows

    assert_equal [
      [ t("inspector.relations"), 1 ],
      [ t("inspector.ownerships"), 1 ]
    ], rows
  end

  test "rows are capped at five" do
    Current.story = stories(:story_one)
    @character = characters(:character_one)

    rows = contextual_inspector_rows

    assert_operator rows.size, :<=, 5
  end
end
