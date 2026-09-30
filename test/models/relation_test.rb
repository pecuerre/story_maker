require "test_helper"

class RelationTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @character = characters(:character_one)
    @relation_tag = RelationTag.new(universe: @universe, name: "Child of")
  end

  test "requires both characters" do
    relation = Relation.new(universe: @universe)

    assert_not relation.valid?
    assert_includes relation.errors[:character1], "can't be blank"
    assert_includes relation.errors[:character2], "can't be blank"
  end

  test "allows a relation without tags, even with a blank name" do
    other = characters(:character_two)
    relation = Relation.create!(universe: @universe, character1: @character, character2: other, name: "")

    assert_empty relation.relation_tags
    assert_equal "#{@character.slug}-#{other.slug}", relation.slug
  end

  test "derives a composite slug when name is omitted" do
    other = characters(:character_two)
    relation = Relation.create!(universe: @universe, character1: @character, character2: other)

    assert_equal "#{@character.slug}-#{other.slug}", relation.slug
  end

  test "includes the relation tag in an automatically generated slug" do
    other = characters(:character_two)
    @relation_tag.save!
    relation = Relation.create!(
      universe: @universe,
      character1: @character,
      character2: other,
      relation_tags: [ @relation_tag ]
    )

    assert_equal "#{@character.slug}-#{@relation_tag.slug}-#{other.slug}", relation.slug
  end

  test "falls back to the composite slug when the name cannot be slugified" do
    other = characters(:character_two)
    relation = Relation.create!(universe: @universe, character1: @character, character2: other, name: "!!!")

    assert_equal "#{@character.slug}-#{other.slug}", relation.slug
  end

  test "allows repeated relations between the same characters" do
    @relation_tag.save!
    attributes = { universe: @universe, character1: @character, character2: characters(:character_two), relation_tags: [ @relation_tag ] }

    assert Relation.create!(attributes)
    assert Relation.create!(attributes)
  end

  test "display_string falls back to its two endpoints because the name is optional" do
    other = characters(:character_two)
    relation = Relation.create!(universe: @universe, character1: @character, character2: other)

    assert_equal "#{@character.name} → #{other.name}", relation.display_string

    relation.update!(name: "Sworn oath")
    assert_equal "Sworn oath", relation.display_string
  end

  test "a blank name is stored as no name rather than an empty string" do
    other = characters(:character_two)
    relation = Relation.create!(universe: @universe, character1: @character, character2: other, name: "  ")

    assert_nil relation.reload.name
  end

  test "a name that cannot be slugified is stored, because the name is not the address" do
    other = characters(:character_two)
    relation = Relation.create!(universe: @universe, character1: @character, character2: other, name: "!!!")
    composite = relation.slug

    # `HasSlug` resolves an unslugifiable name to a random hex, which would leave
    # the record with a name it can display and an address nothing else predicts.
    relation.update!(name: "???")

    assert_equal "???", relation.reload.name
    assert_equal composite, relation.slug

    # Renaming to a name that *does* slugify still renames.
    relation.update!(name: "Sworn oath")

    assert_equal "sworn-oath", relation.reload.slug
  end

  test "clearing a name keeps the slug the record already had" do
    other = characters(:character_two)
    relation = Relation.create!(universe: @universe, character1: @character, character2: other, name: "Sworn oath")
    assert_equal "sworn-oath", relation.slug

    relation.update!(name: "")

    # The name goes, the address stays, and the endpoints become the label again.
    assert_nil relation.reload.name
    assert_equal "sworn-oath", relation.slug
    assert_equal "#{@character.name} → #{other.name}", relation.display_string
  end

  test "renaming a relation still renames its slug" do
    other = characters(:character_two)
    relation = Relation.create!(universe: @universe, character1: @character, character2: other, name: "Sworn oath")

    relation.update!(name: "Blood tie")

    assert_equal "blood-tie", relation.reload.slug
  end
end
