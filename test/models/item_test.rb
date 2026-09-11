require "test_helper"

class ItemTest < ActiveSupport::TestCase
  test "requires a name" do
    item = Item.new(story: stories(:story_one), item_types: [ item_types(:item_type_one) ])

    assert_not item.valid?
    assert_includes item.errors[:name], "can't be blank"
  end
end
