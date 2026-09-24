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
