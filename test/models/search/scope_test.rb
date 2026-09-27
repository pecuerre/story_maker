require "test_helper"

# The scope dropdown: what a search is allowed to look at, and what happens when
# it is asked for a boundary that does not exist.
class Search::ScopeTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
  end

  test "a universe page defaults to this universe and a landing page to the platform" do
    assert_equal "universe", Search::Scope.default_for(@universe)
    assert_equal "platform", Search::Scope.default_for(nil)
  end

  test "no scope means the default for the page it is on" do
    assert_equal "universe", Search::Scope.new(nil, universe: @universe).value
    assert_equal "platform", Search::Scope.new(nil, universe: nil).value
  end

  test "a boundary option resolves to the boundary it names" do
    assert_equal "platform", Search::Scope.new("platform", universe: @universe, story: @story).boundary
    assert_equal "universe", Search::Scope.new("universe", universe: @universe, story: @story).boundary
    assert_equal "story", Search::Scope.new("story", universe: @universe, story: @story).boundary
  end

  test "a kind option inherits the page's boundary" do
    inside = Search::Scope.new("characters", universe: @universe)
    assert_equal "universe", inside.boundary
    assert_equal "character", inside.kind

    outside = Search::Scope.new("characters", universe: nil)
    assert_equal "platform", outside.boundary
    assert_equal "character", outside.kind
  end

  test "asking for this story without a story widens the search and says so" do
    scope = Search::Scope.new("story", universe: @universe, story: nil)

    assert_equal "universe", scope.boundary
    assert_equal [ "The story search was widened to this universe because no story is selected." ],
      scope.discarded
  end

  test "asking for this universe on the landing page widens to the platform and says so" do
    scope = Search::Scope.new("universe", universe: nil, story: nil)

    assert_equal "platform", scope.boundary
    assert_empty scope.discarded, "widening to the platform is what a landing page search already is"
  end

  test "an unknown scope falls back to the default and reports itself" do
    scope = Search::Scope.new("planets", universe: @universe)

    assert_equal "universe", scope.value
    assert_equal "universe", scope.boundary
    assert_equal [ "“planets” is not a search scope, so the default scope was used." ], scope.discarded
  end

  test "a control shows the scope that was really searched, never an unhonourable one" do
    widened = Search::Scope.new("story", universe: @universe, story: nil)
    assert_equal "story", widened.value, "the request keeps what was asked for"
    assert_equal "universe", widened.display_value, "the control shows what was searched"

    honoured = Search::Scope.new("story", universe: @universe, story: @story)
    assert_equal "story", honoured.display_value

    # A kind option is available everywhere, so it is never replaced.
    assert_equal "characters", Search::Scope.new("characters", universe: nil).display_value
  end

  test "commands belong to a boundary search, not to a narrowed one" do
    assert Search::Scope.new("platform", universe: @universe).commands?
    assert Search::Scope.new("universe", universe: @universe).commands?
    assert Search::Scope.new("story", universe: @universe, story: @story).commands?
    assert_not Search::Scope.new("characters", universe: @universe).commands?
    assert_not Search::Scope.new("tags", universe: @universe).commands?
  end

  test "an option is unavailable only when the page cannot honour it" do
    universe_option = Search::Scope.option_for("universe")
    story_option = Search::Scope.option_for("story")
    characters_option = Search::Scope.option_for("characters")

    assert_not Search::Scope.available?(universe_option, universe: nil, story: @story)
    assert Search::Scope.available?(universe_option, universe: @universe, story: nil)

    assert_not Search::Scope.available?(story_option, universe: @universe, story: nil)
    assert Search::Scope.available?(story_option, universe: @universe, story: @story)

    # A kind option has no boundary of its own, so the page can always honour it.
    assert Search::Scope.available?(characters_option, universe: nil, story: nil)
  end

  test "every option has a label and every kind a label of its own" do
    Search::Scope::OPTIONS.each do |option|
      assert option.label.present?, "#{option.value} has no label"
      assert_includes Search::Kinds::LABELS.keys, option.kind if option.kind
    end

    assert_equal "Character tag", Search::Kinds.label_for("tag", "Character")
    assert_equal "Tag", Search::Kinds.label_for("tag")
    assert_equal "Scene element", Search::Kinds.label_for("scene_element")
  end

  test "the option list is the dropdown, and the boundary options come first" do
    assert_equal %w[platform universe story], Search::Scope::OPTIONS.first(3).map(&:value)
    assert_equal Search::Scope::OPTIONS.size, Search::Scope::VALUES.uniq.size
  end
end
