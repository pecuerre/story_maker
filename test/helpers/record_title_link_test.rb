require "test_helper"

# The linked name is shared by every flat list row, so its shape is asserted once
# here. It is deliberately not the row's Details action: both links point at the
# same page, and their accessible names have to stay distinct.
class RecordTitleLinkTest < ActionView::TestCase
  include ApplicationHelper

  test "the link's accessible name is its visible record name" do
    character = characters(:character_one)
    html = record_title_link("/u/one/characters/#{character.id}", record: character)

    assert_includes html, %(class="entity-title entity-title-link")
    assert_includes html, ">Character one</a>"
    assert_not_includes html, "aria-label"
  end

  test "a caller can pass the label its row already composes" do
    relation = Relation.new(character1: characters(:character_one), character2: characters(:character_two))
    html = record_title_link("/u/one/relations/1", record: relation, label: "A — allies → B")

    assert_includes html, ">A — allies → B</a>"
  end
end
