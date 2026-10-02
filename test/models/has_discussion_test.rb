require "test_helper"

class HasDiscussionTest < ActiveSupport::TestCase
  DISCUSSIBLE = %w[
    Story Section SectionTag Scene SceneTag SceneElement SceneCharacter SceneItem SceneLocation
    Character CharacterTag Location LocationTag Item ItemTag Event EventTag Relation RelationTag
    Ownership OwnershipTag
  ].freeze

  test "every content and tag model carries exactly one thread, destroyed with its record" do
    DISCUSSIBLE.each do |name|
      association = name.constantize.reflect_on_association(:discussion)

      assert association, "#{name} has no discussion association"
      assert_equal :record, association.options[:as], name
      assert_equal :destroy, association.options[:dependent], name
    end
  end

  test "the list is every registered content class except Photo, which has no page of its own" do
    assert_equal Ability::CONTENT_CLASS_NAMES.sort, (DISCUSSIBLE + [ "Photo" ]).sort,
      "a newly registered content class must be decided here, not inherit the list"
    assert_nil Photo.reflect_on_association(:discussion)
  end

  test "find_or_create_discussion is the same thread every time" do
    character = characters(:character_one)

    first = character.find_or_create_discussion
    second = character.find_or_create_discussion

    assert_same first, second
    assert_equal 1, Discussion.count
    assert_equal universes(:universe_one), first.universe
  end

  test "the thread is stamped with the record's own universe, however deep the record sits" do
    {
      characters(:character_one) => universes(:universe_one),
      sections(:section_one) => universes(:universe_one),
      scenes(:scene_one) => universes(:universe_one),
      scene_elements(:narration_one) => universes(:universe_one),
      scene_characters(:scene_character_one) => universes(:universe_one),
      stories(:story_two) => universes(:universe_two)
    }.each do |record, universe|
      discussion = record.find_or_create_discussion

      assert_equal universe, discussion.universe, record.class.name
      assert_equal record, discussion.record, record.class.name
    end
  end

  test "losing the create race returns the thread that won" do
    character = characters(:character_one)
    # What the unique pair index does to a second simultaneous **Discuss** press:
    # the insert is refused and the row that already exists is read back, rather
    # than a 500 and two threads on one record.
    Discussion.create!(universe: universes(:universe_one), record: character)
    character.reload

    assert_nothing_raised do
      assert_equal Discussion.find_by!(record: character), character.find_or_create_discussion
    end
    assert_equal 1, Discussion.count
  end

  test "a hard-deleted record takes its thread and its messages with it" do
    character = Universe.create!(owner: users(:user_two), name: "Disposable", slug: "disposable")
      .characters.create!(name: "Temporary")
    character.find_or_create_discussion.messages.create!(user: users(:user_two), body: "Soon gone")

    assert_difference([ "Discussion.count", "DiscussionMessage.count" ], -1) do
      character.destroy
    end
  end

  test "deleting the record a presence link hangs from takes the link's thread with it" do
    # The reason `Character`, `Item`, and `Location` destroy their presence links
    # rather than removing them with `delete_all`: `delete_all` skips callbacks, so
    # the link row would go and its thread would stay behind pointing at nothing.
    universe = Universe.create!(owner: users(:user_two), name: "Disposable", slug: "disposable")
    scene = universe.stories.create!(name: "Disposable story", slug: "disposable-story").scenes.create!(name: "A scene")
    character = universe.characters.create!(name: "Temporary")
    link = character.scene_characters.create!(scene: scene)
    link.find_or_create_discussion

    assert_difference([ "Discussion.count", "SceneCharacter.count" ], -1) do
      character.destroy
    end
  end

  test "a soft-deleted record keeps its thread, and the thread is unreachable meanwhile" do
    universe = Universe.create!(owner: users(:user_two), name: "Retired", slug: "retired")
    character = universe.characters.create!(name: "Gone")
    discussion = character.find_or_create_discussion
    character.soft_delete

    assert_equal discussion, Character.with_deleted.find(character.id).find_or_create_discussion
    assert_nil RecordTarget.find(record_type: "Character", record_id: character.id),
      "a soft-deleted record must not resolve, so its thread cannot be read through it"
    assert_raises ActiveRecord::RecordNotFound do
      RecordTarget.find!(record_type: "Character", record_id: character.id, within: universe)
    end
  end
end
