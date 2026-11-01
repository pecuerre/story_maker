require "test_helper"

class ItemTest < ActiveSupport::TestCase
  test "requires a name" do
    item = Item.new(universe: universes(:universe_one), item_tags: [ item_tags(:item_tag_one) ])

    assert_not item.valid?
    assert_includes item.errors[:name], "can't be blank"
  end

  test "allows an item without tags" do
    assert Item.create!(universe: universes(:universe_one), name: "Untagged")
  end

  test "the search body is the description" do
    item = Item.new(universe: universes(:universe_one), name: "The Gate Key",
      description: "## What it does\n\nA brass key that opens the sealed gate.")

    assert_equal item.description, item.search_description
  end

  test "a blank description is left out of the search body rather than joined as empty words" do
    item = Item.create!(universe: universes(:universe_one), name: "Empty Key")

    assert_nil item.search_description
  end
end
