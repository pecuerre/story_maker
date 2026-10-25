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

  test "the search body includes the description and every profile answer" do
    # Search is the one reader that must not miss a profile field, and reading
    # the constant rather than a written list is what keeps a new column in it.
    item = Item.new(universe: universes(:universe_one), name: "The Gate Key",
      description: "A brass key", what_it_does: "Opens the sealed gate",
      jargon: "Gate-key")

    Item::PROFILE_FIELDS.each_with_index do |field, index|
      item.public_send("#{field}=", "answer #{index}")
    end

    body = item.search_description

    assert_includes body, "A brass key"
    Item::PROFILE_FIELDS.each_with_index do |_field, index|
      assert_includes body, "answer #{index}"
    end
    assert_not_includes body, "nil"
  end

  test "a blank profile is left out of the search body rather than joined as empty words" do
    item = Item.create!(universe: universes(:universe_one), name: "Empty Key", description: "Only a summary")

    assert_equal "Only a summary", item.search_description
  end
end
