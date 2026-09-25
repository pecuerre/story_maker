require "test_helper"

class AbilityTest < ActiveSupport::TestCase
  setup do
    @public_universe = universes(:universe_one)
    @private_universe = Universe.create!(owner: users(:user_one), name: "Private", slug: "private", private: true)
    @read_user = users(:user_two)
    @write_user = User.create!(name: "Writer", email_address: "writer@example.com", password: "password")
    @admin_user = User.create!(name: "Admin", email_address: "admin@example.com", password: "password")
  end

  test "guests can read public content but cannot write" do
    ability = Ability.new(nil)

    assert ability.can?(:read, @public_universe)
    assert ability.can?(:read, stories(:story_one))
    assert_not ability.can?(:write, @public_universe)
    assert_not ability.can?(:write, stories(:story_one))
    assert_not ability.can?(:create, Universe)
  end

  test "signed-in users can contribute to public universes" do
    ability = Ability.new(@read_user)

    assert ability.can?(:read, @public_universe)
    assert ability.can?(:write, @public_universe)
    assert ability.can?(:write, stories(:story_one))
    assert_not ability.can?(:admin, @public_universe)
  end

  test "private access follows membership level" do
    private_story = Story.create!(universe: @private_universe, name: "Private story")
    non_member_ability = Ability.new(@read_user)
    assert_not non_member_ability.can?(:read, @private_universe)
    assert_not non_member_ability.can?(:read, private_story)

    UniverseMembership.create!(universe: @private_universe, user: @read_user, access_level: :read)
    read_ability = Ability.new(@read_user)

    assert read_ability.can?(:read, @private_universe)
    assert_not read_ability.can?(:write, @private_universe)
    assert_not read_ability.can?(:admin, @private_universe)

    UniverseMembership.create!(universe: @private_universe, user: @write_user, access_level: :write)
    write_ability = Ability.new(@write_user)

    assert write_ability.can?(:read, @private_universe)
    assert write_ability.can?(:write, @private_universe)
    assert_not write_ability.can?(:admin, @private_universe)

    UniverseMembership.create!(universe: @private_universe, user: @admin_user, access_level: :admin)
    admin_ability = Ability.new(@admin_user)

    assert admin_ability.can?(:admin, @private_universe)
    assert admin_ability.can?(:manage, @private_universe)
    assert admin_ability.can?(:admin, private_story)
    assert admin_ability.can?(:manage, UniverseMembership.new(universe: @private_universe, user: @admin_user))
  end

  test "the owner is always an administrator" do
    ability = Ability.new(users(:user_one))

    assert ability.can?(:admin, @public_universe)
    assert ability.can?(:manage, @public_universe)
    assert_equal "admin", ability.access_level_for(@public_universe)
  end

  test "read and write checks cover every universe and story component" do
    relation = Relation.create!(universe: @public_universe, character1: characters(:character_one), character2: characters(:character_two))
    ownership = Ownership.create!(universe: @public_universe, character: characters(:character_one), item: items(:item_one))
    relation_tag = RelationTag.create!(universe: @public_universe, name: "Relation type")
    ownership_tag = OwnershipTag.create!(universe: @public_universe, name: "Ownership type")
    records = [
      stories(:story_one),
      sections(:section_one),
      section_tags(:section_tag_one),
      scenes(:scene_one),
      characters(:character_one),
      character_tags(:character_tag_one),
      locations(:location_one),
      location_tags(:location_tag_one),
      items(:item_one),
      item_tags(:item_tag_one),
      events(:event_one),
      event_tags(:event_tag_one),
      relation,
      relation_tag,
      ownership,
      ownership_tag
    ]

    reader = Ability.new(@read_user)
    records.each do |record|
      assert reader.can?(:read, record), record.class.name
      assert reader.can?(:write, record), record.class.name
    end
  end

  test "a scene-owned record resolves its universe through its scene" do
    private_story = Story.create!(universe: @private_universe, name: "Private story")
    scene = private_story.scenes.create!(name: "Private scene")
    # Stands in for the Scene-owned component models added in later slices. The
    # class must also be registered in CONTENT_CLASS_NAMES for CanCan to match
    # it; what is proven here is that the Ability resolves its Universe through
    # Scene, the same way the shared view helper does.
    scene_owned = Struct.new(:scene).new(scene)

    assert_equal @private_universe, Ability.new(@read_user).send(:universe_for, scene_owned)
    assert_equal @private_universe, Ability.new(@read_user).send(:universe_for, scene)

    UniverseMembership.create!(universe: @private_universe, user: @read_user, access_level: :write)
    write_ability = Ability.new(@read_user)
    assert write_ability.can?(:write, scene)
    assert_equal @private_universe, write_ability.send(:universe_for, scene_owned)
  end

  test "a scene resolves its universe through its story" do
    private_story = Story.create!(universe: @private_universe, name: "Private story")
    scene = private_story.scenes.create!(name: "Private scene")

    non_member_ability = Ability.new(@read_user)
    assert_not non_member_ability.can?(:read, scene)
    assert_not non_member_ability.can?(:write, scene)

    UniverseMembership.create!(universe: @private_universe, user: @read_user, access_level: :read)
    read_ability = Ability.new(@read_user)
    assert read_ability.can?(:read, scene)
    assert_not read_ability.can?(:write, scene)
    assert_not read_ability.can?(:destroy, scene)

    UniverseMembership.find_by!(universe: @private_universe, user: @read_user).update!(access_level: :admin)
    admin_ability = Ability.new(@read_user)
    assert admin_ability.can?(:admin, scene)
    assert admin_ability.can?(:manage, scene)

    guest_ability = Ability.new(nil)
    assert guest_ability.can?(:read, scenes(:scene_one))
    assert_not guest_ability.can?(:write, scenes(:scene_one))
  end
end
