require "test_helper"

class ItemTest < ActiveSupport::TestCase
  test "requires a name" do
    item = Item.new(universe: universes(:universe_one), item_tags: [ item_tags(:item_tag_one) ])

    assert_not item.valid?
    assert_includes item.errors[:name], "can't be blank"
  end
end
