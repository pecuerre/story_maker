require "test_helper"

class UniverseTest < ActiveSupport::TestCase
  test "requires a name" do
    universe = Universe.new(owner: users(:user_one))

    assert_not universe.valid?
    assert_includes universe.errors[:name], "can't be blank"
  end

  test "requires an explicit boolean visibility flag" do
    universe = Universe.new(owner: users(:user_one), name: "Ambiguous", private: nil)

    assert_not universe.valid?
    assert_includes universe.errors[:private], "is not included in the list"
  end

  test "a duplicate name that derives a taken address is a field error" do
    # `HasSlug` derives the address from the name and the address is global, so
    # two universes whose names slugify alike collide. The database's partial
    # unique index used to raise `ActiveRecord::RecordNotUnique` here instead.
    Universe.create!(owner: users(:user_one), name: "Shared name")

    duplicate = Universe.new(owner: users(:user_one), name: "Shared name")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:slug], "has already been taken"
    assert_no_difference("Universe.count") { duplicate.save }
  end

  test "an explicit address can disambiguate a duplicate name" do
    Universe.create!(owner: users(:user_one), name: "Shared name")

    disambiguated = Universe.new(owner: users(:user_one), name: "Shared name", slug: "shared-name-two")

    assert disambiguated.save
    assert_equal "shared-name-two", disambiguated.slug
  end

  test "a rename into a taken address is a field error and keeps the old address" do
    Universe.create!(owner: users(:user_one), name: "Taken", slug: "taken")
    universe = Universe.create!(owner: users(:user_one), name: "Movable", slug: "movable")

    assert_not universe.update(name: "Taken")
    assert_includes universe.errors[:slug], "has already been taken"
    assert_equal "movable", universe.reload.slug
  end

  test "an unrelated save does not republish the universe under a new address" do
    universe = Universe.create!(owner: users(:user_one), name: "Movable", slug: "movable")

    assert universe.update(private: true)

    assert_equal "movable", universe.reload.slug
  end

  test "a soft-deleted universe releases its address" do
    universe = Universe.create!(owner: users(:user_one), name: "Retired", slug: "retired")
    universe.soft_delete

    reused = Universe.new(owner: users(:user_one), name: "Retired", slug: "retired")

    assert reused.save
    assert_equal "retired", reused.slug
  end

  test "defaults visibility to public" do
    universe = Universe.create!(owner: users(:user_one), name: "Default visibility")

    assert_equal false, universe.reload[:private]
  end

  test "database rejects null visibility flags" do
    universe = universes(:universe_one)

    assert_not Universe.columns_hash.fetch("private").null
    assert_raises ActiveRecord::NotNullViolation do
      Universe.where(id: universe.id).update_all(private: nil)
    end
    assert_equal false, universe.reload[:private]
  end

  test "ambiguous visibility fails closed" do
    universe = Universe.new(owner: users(:user_one), name: "Ambiguous", private: nil)

    assert_not universe.public?
    assert_nil universe.access_level_for(users(:user_two))
    assert_not universe.readable_by?(users(:user_two))
    assert_not universe.writable_by?(users(:user_two))
  end

  test "visible_to includes explicit private memberships" do
    private_universe = Universe.create!(owner: users(:user_one), name: "Private", slug: "private", private: true)
    UniverseMembership.create!(universe: private_universe, user: users(:user_two), access_level: :read)

    assert_includes Universe.visible_to(users(:user_two)), private_universe
    assert_not_includes Universe.visible_to(User.new), private_universe
  end

  test "access levels are inherited by all universe components" do
    private_universe = Universe.create!(owner: users(:user_one), name: "Private", slug: "private", private: true)
    story = Story.create!(universe: private_universe, name: "Story")
    UniverseMembership.create!(universe: private_universe, user: users(:user_two), access_level: :read)

    assert private_universe.readable_by?(users(:user_two))
    assert_not private_universe.writable_by?(users(:user_two))
    assert_equal private_universe, story.universe
    assert Ability.new(users(:user_two)).can?(:read, story)
    assert_not Ability.new(users(:user_two)).can?(:write, story)
  end

  test "defaults the collaboration mode to direct" do
    universe = Universe.create!(owner: users(:user_one), name: "Default collaboration")

    assert_equal "direct", universe.reload[:collaboration_mode]
    assert universe.direct?
    assert_not universe.draft_based?
  end

  test "rejects a collaboration mode the application has no behaviour for" do
    universe = Universe.new(owner: users(:user_one), name: "Unknown mode", collaboration_mode: "consensus")

    assert_not universe.valid?
    assert_includes universe.errors[:collaboration_mode], "is not included in the list"
  end

  test "database rejects a null collaboration mode" do
    universe = universes(:universe_one)

    assert_not Universe.columns_hash.fetch("collaboration_mode").null
    assert_raises ActiveRecord::NotNullViolation do
      Universe.where(id: universe.id).update_all(collaboration_mode: nil)
    end
    assert_equal "direct", universe.reload[:collaboration_mode]
  end

  test "each collaboration mode is asked about through its own predicate" do
    assert_equal %w[direct wikipedia github], Universe::COLLABORATION_MODES

    direct = Universe.new(collaboration_mode: "direct")
    wikipedia = Universe.new(collaboration_mode: "wikipedia")
    github = Universe.new(collaboration_mode: "github")

    assert direct.direct?
    assert wikipedia.wikipedia?
    assert github.github?

    assert_not direct.wikipedia?
    assert_not direct.github?
    assert_not wikipedia.direct?
    assert_not wikipedia.github?
    assert_not github.direct?
    assert_not github.wikipedia?

    assert_not direct.draft_based?
    assert wikipedia.draft_based?
    assert github.draft_based?
  end

  test "an unrecognized collaboration mode is treated as draft-based" do
    # The column is NOT NULL and validated, so this only happens through a raw
    # write. It is worth pinning because the answer decides whether a change is
    # written straight through: holding one for an author to look at is
    # recoverable, writing one that was never meant to be is not.
    universe = Universe.create!(owner: users(:user_one), name: "Future mode", collaboration_mode: "wikipedia")
    Universe.where(id: universe.id).update_all(collaboration_mode: "gitlab")

    assert universe.reload.draft_based?
    assert_not universe.direct?
  end

  test "writable and administrated scopes match instance policy" do
    private_universe = Universe.create!(owner: users(:user_one), name: "Private", slug: "private", private: true)
    writer = User.create!(name: "Writer", email_address: "writer-scope@example.com", password: "password")
    admin = User.create!(name: "Admin", email_address: "admin-scope@example.com", password: "password")
    UniverseMembership.create!(universe: private_universe, user: writer, access_level: :write)
    UniverseMembership.create!(universe: private_universe, user: admin, access_level: :admin)

    assert_includes Universe.writable_by(writer), private_universe
    assert_not_includes Universe.administrated_by(writer), private_universe
    assert_includes Universe.administrated_by(admin), private_universe
    assert_includes Universe.writable_by(users(:user_one)), private_universe
  end
end
