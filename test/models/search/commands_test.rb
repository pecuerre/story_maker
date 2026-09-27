require "test_helper"

# Navigation commands: the pages a reader can jump to from the same box that
# finds records. They follow the search's boundary, and they are built from what
# this reader can reach rather than from an index.
class Search::CommandsTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
  end

  test "a universe's own pages are offered from inside it" do
    commands = Search::Commands.new(text: "chara", universe: @universe, user: users(:user_one)).to_a

    assert_equal [ "Characters" ], commands.map(&:title)
    assert_equal universe_characters_path(universe_slug: @universe.slug), commands.first.url
  end

  test "the story workspace is offered only when a story is selected" do
    without = Search::Commands.new(text: "scenes", universe: @universe, user: users(:user_one)).to_a
    with = Search::Commands.new(text: "scenes", universe: @universe, story: @story, user: users(:user_one)).to_a

    assert_empty without
    assert_equal [ "Scenes" ], with.map(&:title)
    assert_equal universe_story_scenes_path(universe_slug: @universe.slug, story_id: @story.id), with.first.url
  end

  test "a command outside the universe is not offered" do
    commands = Search::Commands.new(text: "hobbit", universe: @universe, user: users(:user_one)).to_a

    assert_empty commands
  end

  test "the landing page offers every universe the visitor may open" do
    private_universe = Universe.create!(owner: users(:user_two), name: "Hidden", private: true)
    commands = Search::Commands.new(text: "universe", universe: nil, user: users(:user_one)).to_a

    assert_includes commands.map(&:title), "Universe: Universe one"
    # Universe two is public, so it is readable by anyone who asks.
    assert_includes commands.map(&:title), "Universe: Universe two"
    assert_not_includes commands.map(&:title), "Universe: #{private_universe.name}"
  end

  test "a guest is offered only the public universes" do
    private_universe = Universe.create!(owner: users(:user_two), name: "Hidden", private: true)
    commands = Search::Commands.new(text: "hidden", universe: nil, user: nil).to_a

    assert_empty commands
    assert_not_includes commands.map(&:title), "Universe: #{private_universe.name}"
  end

  test "a member of a private universe is offered it" do
    private_universe = Universe.create!(owner: users(:user_two), name: "Hidden", private: true)
    UniverseMembership.create!(universe: private_universe, user: users(:user_one), access_level: :read)

    commands = Search::Commands.new(text: "hidden", universe: nil, user: users(:user_one)).to_a

    assert_equal [ "Universe: Hidden" ], commands.map(&:title)
  end

  test "a label that starts with the text is a better match than one that only contains it" do
    commands = Search::Commands.new(text: "loc", universe: @universe, user: users(:user_one)).to_a

    # "Locations" starts with the text; nothing else here does.
    assert_equal [ "Locations" ], commands.map(&:title)
  end

  test "a word inside a label still matches" do
    commands = Search::Commands.new(text: "items", universe: @universe, user: users(:user_one)).to_a

    assert_equal [ "Items" ], commands.map(&:title)
  end

  test "an empty text offers nothing" do
    assert_empty Search::Commands.new(text: "  ", universe: @universe, user: users(:user_one)).to_a
    assert_not Search::Commands.new(text: "", universe: @universe, user: users(:user_one)).any?
  end

  test "the list is capped so the dropdown stays a search result" do
    10.times { |index| Story.create!(universe: @universe, name: "Story #{index}") }
    commands = Search::Commands.new(text: "story", universe: @universe, user: users(:user_one)).to_a

    assert_operator commands.size, :<=, Search::Commands::MAX_MATCHES
  end

  test "a command carries an id, so a reader can be told which one is active" do
    commands = Search::Commands.new(text: "timeline", universe: @universe, user: users(:user_one)).to_a

    assert_equal "timeline", commands.first.id
    assert_equal @universe.name, commands.first.subtitle
    assert_equal({ id: "timeline", title: "Timeline", subtitle: @universe.name,
      url: universe_timeline_path(universe_slug: @universe.slug) }, commands.first.as_json)
  end
end
