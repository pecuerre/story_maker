require "test_helper"

class UserTest < ActiveSupport::TestCase
  # `users.name` and `users.email_address` are `null: false`. A model caller with no
  # validation for either sees `valid? == true` and then gets a NotNullViolation from
  # `save!`, which is a 500 in a loader or a console with no hint which column was wrong.
  test "a user without a name or an email address is refused before the database is asked" do
    nameless = User.new(email_address: "nameless@example.com", password: "password")
    assert_not nameless.valid?
    assert_includes nameless.errors.attribute_names, :name

    anonymous = User.new(name: "Anonymous", password: "password")
    assert_not anonymous.valid?
    assert_includes anonymous.errors.attribute_names, :email_address
  end

  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  # `universes` is a method rather than an association through memberships because the
  # owner is not a membership row. These two tests hold the union from both ends, since
  # either half implemented alone would be an answer that quietly drops the founder.
  test "universes are the ones you own plus the ones you hold a membership in" do
    person = User.create!(name: "Both", email_address: "both@example.com", password: "password")
    founded = Universe.create!(owner: person, name: "Founded", slug: "founded", private: true)
    joined = Universe.create!(owner: users(:user_two), name: "Joined", slug: "joined", private: true)
    UniverseMembership.create!(universe: joined, user: person, access_level: :write)

    assert_equal [ founded, joined ].sort_by(&:id), person.universes.sort_by(&:id)
    # A person who founded nothing and joined nothing is in nothing, rather than in the
    # public universes a reader may open but does not collaborate in.
    assert_empty User.create!(name: "Loner", email_address: "loner@example.com", password: "password").universes
  end

  test "a soft-deleted membership stops being one of your universes, and owning one never was" do
    person = User.create!(name: "Both", email_address: "both@example.com", password: "password")
    founded = Universe.create!(owner: person, name: "Founded", slug: "founded", private: true)
    joined = Universe.create!(owner: users(:user_two), name: "Joined", slug: "joined", private: true)
    UniverseMembership.create!(universe: joined, user: person, access_level: :write).soft_delete

    # There is no membership row to drop for the owned universe, which is exactly why the
    # ordinary association could not answer this and the method can.
    assert_equal [ founded ], person.universes.to_a
  end

  test "accessible universes are what you may open, which is not what you collaborate in" do
    person = User.create!(name: "Reader", email_address: "reader@example.com", password: "password")
    public_universe = Universe.create!(owner: users(:user_two), name: "Public", slug: "public")

    # A public universe is readable by every reader and has no membership row, so it is
    # accessible without being one of anybody's.
    assert_includes person.accessible_universes, public_universe
    assert_not_includes person.universes, public_universe
  end
end
