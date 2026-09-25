require "test_helper"

# The Details link is shared by every list row and taxonomy node, so its label,
# count, and accessible name are asserted once here instead of per page.
class RecordDetailsLinkTest < ActionView::TestCase
  include ApplicationHelper

  test "the link labels the count and names the record for assistive technology" do
    character = characters(:character_one)
    html = record_details_link("/u/one/characters/#{character.id}",
      record: character, count: 3, count_label: "character")

    assert_includes html, "Details"
    assert_includes html, "(3 characters)"
    assert_includes html, %(aria-label="Details for Character one (3 characters)")
  end

  test "a single record is counted in the singular" do
    html = record_details_link("/u/one/scenes/1", record: scenes(:scene_one), count: 1, count_label: "scene")

    assert_includes html, "(1 scene)"
  end

  test "the count is omitted when the destination has nothing to list yet" do
    character = characters(:character_one)
    html = record_details_link("/u/one/characters/#{character.id}", record: character)

    assert_includes html, "Details"
    assert_not_includes html, "details-link-count"
    assert_includes html, %(aria-label="Details for Character one")
  end

  test "a record without a name is labelled by its display string" do
    relation = Relation.new(character1: characters(:character_one), character2: characters(:character_two))
    html = record_details_link("/u/one/relations/1", record: relation)

    assert_includes html, "Details for Character one → Character two"
  end
end
