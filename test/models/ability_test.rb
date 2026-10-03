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
      scene_tags(:scene_tag_one),
      scene_elements(:narration_one),
      scene_elements(:dialogue_one),
      scene_characters(:scene_character_one),
      scene_characters(:scene_character_two),
      scene_items(:scene_item_one),
      scene_locations(:scene_location_one),
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
    # Stands in for a Scene-owned component that is not in the registry yet. The
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

  test "an element and every presence link are authorized exactly as their scene is" do
    private_story = Story.create!(universe: @private_universe, name: "Private story")
    scene = private_story.scenes.create!(name: "Private scene")
    records = [
      scene.scene_elements.create!(name: "A beat"),
      scene.scene_characters.create!(character: @private_universe.characters.create!(name: "Somebody")),
      scene.scene_items.create!(item: @private_universe.items.create!(name: "A prop")),
      scene.scene_locations.create!(location: @private_universe.locations.create!(name: "A place"))
    ]

    non_member = Ability.new(@read_user)
    records.each do |record|
      assert_not non_member.can?(:read, record), record.class.name
      assert_not non_member.can?(:write, record), record.class.name
    end

    UniverseMembership.create!(universe: @private_universe, user: @read_user, access_level: :read)
    reader = Ability.new(@read_user)
    records.each do |record|
      assert reader.can?(:read, record), record.class.name
      assert_not reader.can?(:write, record), record.class.name
      assert_not reader.can?(:destroy, record), record.class.name
    end

    UniverseMembership.find_by!(universe: @private_universe, user: @read_user).update!(access_level: :write)
    writer = Ability.new(@read_user)
    records.each do |record|
      assert writer.can?(:write, record), record.class.name
      assert_not writer.can?(:admin, record), record.class.name
    end
  end

  test "every persisted model is content, or is authorized elsewhere, or is on the list" do
    # `CONTENT_CLASS_NAMES` is the registry CanCan builds its content rules from,
    # and a model missing from it has no rule at all, so every authorization check
    # against it is denied. That failure is silent — nothing crashes, a control
    # simply never renders — so the registry is inverted here: a new persisted
    # model fails this test until it is deliberately registered or deliberately
    # excused. An inclusion list cannot do that; an exclusion list can, because
    # the default becomes "you forgot".
    elsewhere = %w[ Universe UniverseMembership ]
    not_content = {
      "Session" => "one signed-in browser, never universe-scoped content",
      "User" => "the person, not something a universe contains",
      # A thread is authorized through the record it is about: the controller
      # resolves the record through `RecordTarget` inside the authorized universe
      # and asks `Ability` about *that*. Registering the thread itself would give
      # CanCan a rule whose answer could disagree with the record's, and a
      # polymorphic rule is exactly the class-level hole `RecordTarget` closes.
      "Discussion" => "authorized through the record it is about, never on its own",
      "DiscussionMessage" => "reachable only through its discussion's record scope",
      # A draft is one author's pending changes, not something the universe
      # publishes. Registering it as content would let the content rules answer
      # `read` for a guest in a public universe — exactly the wrong answer for
      # somebody else's unfinished work — so a draft is read as its owner's, inside
      # the universe the request has already authorized.
      "Draft" => "one author's pending changes, authorized through its owner and universe",
      "DraftChange" => "reachable only through its draft's owner and universe scope"
    }

    # Zeitwerk loads a model the first time something names it, so a model this
    # worker has not happened to touch yet is simply absent from `descendants` —
    # and this test would pass by not seeing the model it exists to catch. Every
    # name it reasons about is therefore loaded first. A name that does not
    # resolve at all raises here, which is the failure this test wants.
    (Ability::CONTENT_CLASS_NAMES + elsewhere + not_content.keys).each(&:constantize)

    persisted = ApplicationRecord.descendants.reject(&:abstract_class?).map do |model|
      model.name
    end.sort

    unregistered = persisted - Ability::CONTENT_CLASS_NAMES - elsewhere
    stale = not_content.keys - persisted
    unjustified = unregistered - not_content.keys

    assert_empty stale,
      "Models listed here as not content but no longer exist:\n  #{stale.join("\n  ")}"
    assert_empty unjustified,
      "Persisted models that are neither content, nor authorized elsewhere, nor " \
      "excused. Register the content ones in Ability::CONTENT_CLASS_NAMES and give " \
      "the rest a reason in this test:\n  #{unjustified.join("\n  ")}"
  end

  test "the content registry names only real content classes" do
    Ability::CONTENT_CLASS_NAMES.each do |name|
      model = name.constantize

      assert model < ApplicationRecord, name
      assert_not model.abstract_class?, name
      assert_equal name, model.name, "a nested class must be registered by its full name"
    end
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
