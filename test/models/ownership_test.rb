require "test_helper"

class OwnershipTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @ownership_tag = OwnershipTag.create!(universe: @universe, name: "Owns")
  end

  test "requires an item and a character" do
    ownership = Ownership.new(universe: @universe)

    assert_not ownership.valid?
    assert_includes ownership.errors[:item], "can't be blank"
    assert_includes ownership.errors[:character], "can't be blank"
  end

  test "allows an ownership without tags, even with a blank name" do
    ownership = Ownership.create!(
      universe: @universe,
      item: items(:item_one),
      character: characters(:character_one),
      name: ""
    )

    assert_empty ownership.ownership_tags
    assert_equal "#{characters(:character_one).slug}-#{items(:item_one).slug}", ownership.slug
  end

  test "derives a composite slug when name is omitted" do
    ownership = Ownership.create!(
      universe: @universe,
      item: items(:item_one),
      character: characters(:character_one)
    )

    assert_equal "#{characters(:character_one).slug}-#{items(:item_one).slug}", ownership.slug
  end

  test "includes the ownership tag in an automatically generated slug" do
    ownership = Ownership.create!(
      universe: @universe,
      item: items(:item_one),
      character: characters(:character_one),
      ownership_tags: [ @ownership_tag ]
    )

    assert_equal(
      "#{characters(:character_one).slug}-#{@ownership_tag.slug}-#{items(:item_one).slug}",
      ownership.slug
    )
  end

  test "falls back to the composite slug when the name cannot be slugified" do
    ownership = Ownership.create!(
      universe: @universe,
      item: items(:item_one),
      character: characters(:character_one),
      name: "!!!"
    )

    assert_equal "#{characters(:character_one).slug}-#{items(:item_one).slug}", ownership.slug
  end

  test "rejects associated records from another universe" do
    ownership = Ownership.new(
      universe: @universe,
      item: items(:item_one),
      character: characters(:character_one),
      ownership_tags: [ OwnershipTag.create!(universe: universes(:universe_two), name: "Owns") ]
    )

    assert_not ownership.valid?
    assert_includes ownership.errors[:ownership_tags], "must belong to the same universe"
  end

  test "allows repeated ownerships" do
    attributes = {
      universe: @universe,
      item: items(:item_one),
      character: characters(:character_one),
      ownership_tags: [ @ownership_tag ]
    }

    assert Ownership.create!(attributes)
    assert Ownership.create!(attributes)
  end

  test "display_string falls back to its two endpoints because the name is optional" do
    item = items(:item_one)
    character = characters(:character_one)
    ownership = Ownership.create!(universe: @universe, character: character, item: item)

    assert_equal "#{character.name} owns #{item.name}", ownership.display_string

    ownership.update!(name: "Heirloom")
    assert_equal "Heirloom", ownership.display_string
  end

  # An Ownership is the one model whose stored label is a sentence, so it is the
  # one model where the two forms can differ. `display_string` is what a search
  # document keeps and one index serves every reader, so it is the default
  # locale's whatever the request is; `display_label` is what a view reads.
  test "the stored label is the default locale's, whatever the request asks for" do
    ownership = Ownership.create!(universe: @universe, character: characters(:character_one),
      item: items(:item_one))

    I18n.with_locale(:es) do
      assert_equal "#{ownership.character.name} owns #{ownership.item.name}", ownership.display_string
      assert_equal "#{ownership.character.name} posee #{ownership.item.name}", ownership.display_label
    end
  end

  test "an ownership's own name is the author's and is never translated" do
    ownership = Ownership.create!(universe: @universe, character: characters(:character_one),
      item: items(:item_one), name: "Heirloom")

    I18n.with_locale(:es) do
      assert_equal "Heirloom", ownership.display_label
      assert_equal "Heirloom", ownership.display_string
    end
  end

  test "a blank name is stored as no name rather than an empty string" do
    ownership = Ownership.create!(universe: @universe, item: items(:item_one),
      character: characters(:character_one), name: "  ")

    assert_nil ownership.reload.name
  end

  test "clearing a name keeps the slug the record already had" do
    item = items(:item_one)
    character = characters(:character_one)
    ownership = Ownership.create!(universe: @universe, item: item, character: character, name: "Heirloom")
    assert_equal "heirloom", ownership.slug

    ownership.update!(name: "")

    # The name goes, the address stays, and the endpoints become the label again.
    assert_nil ownership.reload.name
    assert_equal "heirloom", ownership.slug
    assert_equal "#{character.name} owns #{item.name}", ownership.display_string
  end

  test "renaming an ownership still renames its slug" do
    ownership = Ownership.create!(universe: @universe, item: items(:item_one),
      character: characters(:character_one), name: "Heirloom")

    ownership.update!(name: "Family sword")

    assert_equal "family-sword", ownership.reload.slug
  end
end
