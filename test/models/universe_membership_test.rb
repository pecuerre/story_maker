require "test_helper"

class UniverseMembershipTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @user = users(:user_two)
  end

  test "defaults to read access" do
    membership = UniverseMembership.new(universe: @universe, user: @user)

    assert_equal "read", membership.access_level
    assert membership.valid?
  end

  test "levels are ordered" do
    read = UniverseMembership.new(universe: @universe, user: @user, access_level: :read)
    write = UniverseMembership.new(universe: @universe, user: @user, access_level: :write)
    admin = UniverseMembership.new(universe: @universe, user: @user, access_level: :admin)

    assert read.readable?
    assert_not read.writable?
    assert write.writable?
    assert_not write.administrable?
    assert admin.administrable?
  end

  test "a user can have only one membership per universe" do
    UniverseMembership.create!(universe: @universe, user: @user, access_level: :read)
    duplicate = UniverseMembership.new(universe: @universe, user: @user, access_level: :write)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end

  test "the owner cannot be added as a separate membership" do
    membership = UniverseMembership.new(universe: @universe, user: users(:user_one), access_level: :read)

    assert_not membership.valid?
    assert_includes membership.errors[:user], "is the universe owner and already has admin access"
  end
end
