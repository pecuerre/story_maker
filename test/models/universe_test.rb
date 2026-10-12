require "test_helper"

class UniverseTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
  end

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

  # `access_level_for` reads the membership table every time on purpose: a
  # membership write followed by a second question has to see the write, so a
  # caller may not be handed a remembered answer. The place that answers the same
  # question many times in one render is `ApplicationHelper`, and the request
  # test in `test/controllers/characters_controller_test.rb` holds that half.
  test "a membership change is visible to the next question about it" do
    private_universe = Universe.create!(owner: users(:user_one), name: "Private", slug: "private", private: true)
    reader = users(:user_two)

    assert_nil private_universe.access_level_for(reader)

    membership = UniverseMembership.create!(universe: private_universe, user: reader, access_level: :write)

    assert_equal "write", private_universe.access_level_for(reader)

    membership.update!(access_level: :read)

    assert_equal "read", private_universe.access_level_for(reader)

    membership.soft_delete

    assert_nil private_universe.access_level_for(reader)
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

  # The mutation budget, which an admin now sets from the universe form. What the
  # field can submit is what these hold: a positive number, a cleared field
  # (stored `NULL`, meaning no limit), and nothing else. The enforcement those
  # values drive is in `test/controllers/mutation_throttle_test.rb`.

  test "a universe is limited from creation, not from a settings visit" do
    universe = Universe.create!(owner: users(:user_one), name: "Default budget")

    assert_equal Universe::DEFAULT_MUTATION_LIMIT, universe.reload[:mutation_limit]
    assert_equal Universe::DEFAULT_MUTATION_LIMIT, universe.mutation_limit
    assert_not universe.mutations_unlimited?
  end

  test "a cleared limit is no limit at all, which is stored as NULL rather than a sentinel" do
    universe = universes(:universe_one).tap { |record| record.update!(mutation_limit: nil) }

    assert_nil universe.reload[:mutation_limit]
    assert universe.mutations_unlimited?
  end

  test "a configured limit is the number in force" do
    universe = universes(:universe_one).tap { |record| record.update!(mutation_limit: 5) }

    assert_equal 5, universe.reload.mutation_limit
    assert_not universe.mutations_unlimited?
  end

  test "zero is refused, because a universe nobody may write to is private" do
    universe = Universe.new(owner: users(:user_one), name: "Closed", mutation_limit: 0)

    assert_not universe.valid?
    assert_includes universe.errors[:mutation_limit], "must be greater than 0"
  end

  test "a limit that is not a whole number is refused" do
    universe = Universe.new(owner: users(:user_one), name: "Fractional", mutation_limit: 1.5)

    assert_not universe.valid?
    assert_includes universe.errors[:mutation_limit], "must be an integer"
  end

  test "the two readers answer the same row differently, which is why the form binds its own" do
    # `NULL` is the stored form of "no limit at all" and `mutations_unlimited?` says
    # so, while the number reader falls back to the default so that an incomplete
    # row is never the one unprotected state. They therefore disagree on exactly
    # the row that means unlimited. `MutationThrottle` asks the predicate before it
    # reads the number, and the universe form binds the stored value itself, because
    # Rails' own `number_field` binding asks this reader for a record that was read
    # rather than assigned.
    unlimited = Universe.new(mutation_limit: nil)

    assert unlimited.mutations_unlimited?
    assert_equal Universe::DEFAULT_MUTATION_LIMIT, unlimited.mutation_limit
  end

  # `members` is a method rather than `has_many :members, through: :memberships`
  # because the owner is not a membership row. These hold the union from this side, and
  # the two of them are what keeps `administrators` and `User#universes` honest about the
  # founder being in the answer.
  test "members are the owner plus everybody with a membership row" do
    writer = User.create!(name: "Writer", email_address: "writer-members@example.com", password: "password")
    UniverseMembership.create!(universe: @universe, user: writer, access_level: :write)
    owner = users(:user_one)

    # The owner is an admin with no membership row at all, so an association built from
    # memberships alone would leave out the one person every universe has.
    assert_empty @universe.memberships.where(user_id: owner)

    # That is only worth asserting because the owner *does* hold a row — the fixture's read
    # row in the other universe, named here so the empty result above is the row staying in
    # its own universe rather than a table with nothing in it to leak.
    assert_equal [ universes(:universe_two) ], owner.universe_memberships.map(&:universe)

    assert_equal [ owner, writer ].sort_by(&:id), @universe.members.sort_by(&:id)
  end

  test "a member's level does not decide who is a member, and the owner is always an administrator" do
    reader = User.create!(name: "Reader", email_address: "reader-members@example.com", password: "password")
    admin = User.create!(name: "Admin", email_address: "admin-members@example.com", password: "password")
    UniverseMembership.create!(universe: @universe, user: reader, access_level: :read)
    UniverseMembership.create!(universe: @universe, user: admin, access_level: :admin)

    assert_includes @universe.members, reader
    assert_equal [ users(:user_one), admin ].sort_by(&:id), @universe.administrators.sort_by(&:id)
  end

  test "a soft-deleted membership leaves the collaborators, and the owner never leaves" do
    member = User.create!(name: "Leaving", email_address: "leaving@example.com", password: "password")
    membership = UniverseMembership.create!(universe: @universe, user: member, access_level: :write)

    membership.soft_delete

    assert_equal [ users(:user_one) ], @universe.members.to_a
    assert_equal [ users(:user_one) ], @universe.administrators.to_a
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
