require "test_helper"

# The prose mention matcher. It answers one question — which Character was named
# at this offset — and the rules that keep an accidental substring from becoming
# a suggestion are pinned here.
class MentionIndexTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @character = @universe.characters.create!(name: "Mira")
  end

  def index
    MentionIndex.for(stories(:story_one))
  end

  test "a name matches case-insensitively and keeps the author's spelling" do
    match = index.matches("mira waits at the gate").sole

    assert_equal @character, match.character
    assert_equal "mira", match.text
    assert_equal 0, match.offset
    assert_equal 4, match.length
  end

  test "a match has to start and end on a word boundary" do
    assert_empty index.matches("Miranda waits")
    assert_empty index.matches("Amira waits")
    assert_equal 1, index.matches("Miranda, Mira waits").size
  end

  test "an apostrophe or hyphen after a name is a boundary" do
    assert_equal 1, index.matches("Mira's box").size
    assert_equal 1, index.matches("Mira-box").size
  end

  test "every comma- or newline-separated alias is a candidate" do
    @character.update!(aliases: "The Fox, Little Bird\nWanderer")

    matches = index.matches("The Fox meets Little Bird and Wanderer")

    assert_equal [ @character ] * 3, matches.map(&:character)
    assert_equal [ "The Fox", "Little Bird", "Wanderer" ], matches.map(&:text)
  end

  test "an alias repeated as the character's own name is still one owner" do
    @character.update!(aliases: "Mira, mira")

    assert_equal 1, index.matches("Mira waits").size
  end

  test "the longest candidate at a position wins" do
    jon = @universe.characters.create!(name: "Jon")
    jonas = @universe.characters.create!(name: "Jonas")

    matches = index.matches("Jonas leaves before Jon")

    assert_equal [ jonas, jon ], matches.map(&:character)
    assert_equal [ "Jonas", "Jon" ], matches.map(&:text)
  end

  test "a spelling shared by two characters is ambiguous and left out" do
    @character.update!(aliases: "Ari")
    other = @universe.characters.create!(name: "Ari")
    other.update!(aliases: "Ari")

    assert_empty index.matches("Ari waits")
    # The distinct names still work, so one ambiguous alias does not disable the
    # whole index.
    assert_equal 1, index.matches("Mira waits").size
  end

  test "a character is only looked for in the story's own universe" do
    universes(:universe_two).characters.create!(name: "Outsider")

    assert_empty index.matches("Outsider waits")
  end

  test "accents are part of the spelling rather than folded away" do
    @character.update!(name: "Sméagol")

    assert_equal 1, index.matches("Sméagol waits").size
    assert_empty index.matches("Smeagol waits")
  end

  test "an empty body and an index with no characters ask for no matches" do
    assert_empty index.matches(nil)
    assert_empty index.matches("")
    assert_empty MentionIndex.new([]).matches("Mira waits")
  end
end
