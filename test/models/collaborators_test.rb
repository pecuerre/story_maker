require "test_helper"

# The query object behind the Collaborators page. The request suite owns what the page
# shows; this file owns the one arithmetic rule the page does not explain: a row's
# share is its whole-number percentage of every change remembered in the universe, and
# the set is a partition of 100 rather than independent roundings.
class CollaboratorsTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @owner = users(:user_one)
    @author = users(:user_two)
  end

  test "a share is the entry's whole-number percentage of every remembered change" do
    closed_draft(3, by: @author)
    closed_draft(1, by: @owner)

    entries = Collaborators.for(@universe).all

    assert_equal [ @author, @owner ], entries.map(&:user)
    assert_equal [ 75, 25 ], entries.map(&:percent)
  end

  test "the shares add up to 100 when the split does not divide evenly" do
    third = User.create!(name: "User Three", email_address: "three@example.com", password: "password")
    closed_draft(1, by: @author)
    closed_draft(1, by: @owner)
    closed_draft(1, by: third)

    percents = Collaborators.for(@universe).all.map(&:percent)

    # Three equal authors compute as 33.33% each. Independent rounding would print
    # 33/33/33 and leave a point unaccounted for; the largest remainder takes it, and
    # the tie falls to the list's own order (User One, User Three, User Two).
    assert_equal 100, percents.sum
    assert_equal [ 34, 33, 33 ], percents
  end

  test "a universe whose closed drafts remember nothing gives every share zero" do
    Draft.create!(user: @author, universe: @universe, status: "applied", closed_at: Time.current)

    entries = Collaborators.for(@universe).all

    assert_equal [ 0 ], entries.map(&:percent)
  end

  private
    def closed_draft(count, by:)
      draft = Draft.create!(user: by, universe: @universe, status: "applied",
        closed_at: Time.current, applied_count: count)
      count.times do |index|
        draft.draft_changes.create!(action: "create", record_type: "Character",
          payload: { "name" => "Created #{index}" })
      end
      draft
    end
end
