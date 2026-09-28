require "test_helper"

class SoftDeletableTest < ActiveSupport::TestCase
  test "a live record is not deleted and is visible to the default scope" do
    character = characters(:character_one)

    assert_not character.deleted?
    assert_equal character, Character.find(character.id)
    assert_includes Character.all, character
  end

  test "soft_delete marks the record and hides it from the default scope" do
    character = characters(:character_one)

    character.soft_delete

    assert character.deleted?
    assert_nil Character.find_by(id: character.id)
    assert_not_includes Character.all, character
  end

  test "soft_delete keeps the row so it can be restored" do
    character = characters(:character_one)

    assert_no_difference("Character.with_deleted.count") do
      character.soft_delete
    end

    assert_equal 1, Character.only_deleted.where(id: character.id).count
  end

  test "restore brings a soft-deleted record back" do
    character = characters(:character_one)
    character.soft_delete

    character.restore

    assert_not character.deleted?
    assert_equal character, Character.find(character.id)
    assert_includes Character.all, character
  end

  test "with_deleted and only_deleted scopes opt back in" do
    character = characters(:character_one)
    character.soft_delete

    assert_includes Character.with_deleted, character
    assert_includes Character.only_deleted, character
    assert_not_includes Character.all, character
  end

  test "soft_delete cascades to declared associations" do
    character = characters(:character_one)
    other = characters(:character_two)
    relation = Relation.create!(universe: character.universe, character1: character, character2: other)

    character.soft_delete

    assert relation.reload.deleted?, "the relation is soft-deleted with the character"
  end

  test "soft_delete cascades through a whole subtree" do
    universe = universes(:universe_one)
    story = stories(:story_one)
    scene = scenes(:scene_one)

    universe.soft_delete

    assert story.reload.deleted?
    assert scene.reload.deleted?
  end

  test "a soft-deleted parent hides its cascaded children from the default scope" do
    universe = universes(:universe_one)
    character = characters(:character_one)

    universe.soft_delete

    assert_nil Character.find_by(id: character.id)
    assert_nil Universe.find_by(id: universe.id)
  end

  test "soft-deleting a section ungroups its scenes without removing them" do
    section = sections(:section_one)
    scene = scenes(:scene_one)

    section.soft_delete

    assert section.reload.deleted?
    assert_nil scene.reload.section_id
    assert scene.reload.persisted?, "the scene is kept"
  end

  test "soft-deleting an event clears temporal references without destroying referrers" do
    event = events(:event_one)
    reference = Event.create!(universe: event.universe, title: "Reference", before_event: event)

    event.soft_delete

    assert event.reload.deleted?
    assert_nil reference.reload.before_event_id
    assert reference.reload.persisted?, "the referrer is kept"
  end

  test "soft-deleting a scene soft-deletes its elements and presence links" do
    scene = scenes(:scene_one)
    element = scene_elements(:narration_one)
    link = scene_characters(:scene_character_one)

    scene.soft_delete

    assert element.reload.deleted?
    assert link.reload.deleted?
  end

  test "a soft-deleted record can be re-created with the same unique key" do
    character = characters(:character_one)
    character.soft_delete

    replacement = Character.create!(universe: character.universe, name: "Replacement", slug: character.slug)

    assert replacement.persisted?
    assert_equal character.slug, replacement.slug
  end

  test "a soft-deleted presence link does not block re-adding the same record" do
    link = scene_characters(:scene_character_one)
    link.soft_delete

    readded = SceneCharacter.create!(scene: link.scene, character: link.character)

    assert readded.persisted?
  end
end
