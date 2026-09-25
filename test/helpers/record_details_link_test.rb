require "test_helper"

# The Details link is shared by every list row and taxonomy node, so its label and
# accessible name are asserted once here instead of per page. The related-record
# count is a separate left-aligned pill, so it is asserted on its own helper.
class RecordDetailsLinkTest < ActionView::TestCase
  include ApplicationHelper

  test "the link names the record for assistive technology and carries no count" do
    character = characters(:character_one)
    html = record_details_link("/u/one/characters/#{character.id}", record: character)

    assert_includes html, "Details"
    assert_includes html, %(aria-label="Details for Character one")
    assert_not_includes html, "record-count"
  end

  test "a record without a name is labelled by its display string" do
    relation = Relation.new(character1: characters(:character_one), character2: characters(:character_two))
    html = record_details_link("/u/one/relations/1", record: relation)

    assert_includes html, "Details for Character one → Character two"
  end

  test "the count is a left-aligned pill next to the name, not part of the link" do
    badge = record_count_badge(3, "character")

    assert_includes badge, %(class="record-count")
    assert_includes badge, "(3 characters)"
  end

  test "a single record is counted in the singular" do
    assert_includes record_count_badge(1, "scene"), "(1 scene)"
  end

  test "a page with nothing to list yet renders no count" do
    assert_nil record_count_badge(nil, "character")
  end
end
