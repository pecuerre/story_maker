require "test_helper"

class DiscussionTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @character = characters(:character_one)
  end

  test "a thread is about one record of the universe that owns it" do
    discussion = Discussion.new(universe: @universe, record: @character)

    assert discussion.save
    assert_equal @character, discussion.record
    assert_equal @universe, discussion.universe
  end

  test "requires a universe" do
    discussion = Discussion.new(record: @character)

    assert_not discussion.valid?
    assert_includes discussion.errors[:universe], "must exist"
  end

  test "refuses a type that is not a registered content class" do
    # The registry is the gate, so a stored or submitted `record_type` is never
    # handed to `constantize`. That has to be a field error rather than a
    # NameError, and it must be the same refusal for a plausible-looking
    # non-content class as for a nonsense one.
    [ "Kernel", "ActiveRecord::Base", "NotAModel", "" ].each do |type|
      discussion = Discussion.new(universe: @universe, record_type: type, record_id: @character.id)

      assert_not discussion.valid?, type
      assert_includes discussion.errors[:record], "does not exist", type
    end
  end

  test "refuses an id that names nothing" do
    discussion = Discussion.new(universe: @universe, record_type: "Character", record_id: 0)

    assert_not discussion.valid?
    assert_includes discussion.errors[:record], "does not exist"
  end

  test "refuses a soft-deleted record" do
    deleted = Universe.create!(owner: users(:user_two), name: "Retired", slug: "retired")
    character = deleted.characters.create!(name: "Gone")
    discussion = Discussion.new(universe: deleted, record_type: "Character", record_id: character.id)
    character.soft_delete

    assert_not discussion.valid?
    assert_includes discussion.errors[:record], "does not exist"
  end

  test "refuses a record from another universe" do
    other = Universe.create!(owner: users(:user_two), name: "Other", slug: "other")
    discussion = Discussion.new(universe: other, record_type: "Character", record_id: @character.id)

    assert_not discussion.valid?
    # A different sentence from "does not exist": the record is there, and saying
    # otherwise would send the reader looking for a record that is not missing.
    assert_includes discussion.errors[:record], "must belong to the same universe"
    assert_no_difference("Discussion.count") { discussion.save }
  end

  test "refuses a record that reaches another universe through its story" do
    # A Section has no `universe_id` of its own: it reaches the universe through
    # its Story, so this is the case where the stored `universe_id` and the record
    # disagree while both look perfectly valid on their own.
    section = stories(:story_two).sections.create!(name: "Foreign section", slug: "foreign-section")
    discussion = Discussion.new(universe: @universe, record_type: "Section", record_id: section.id)

    assert_not discussion.valid?
    assert_includes discussion.errors[:record], "must belong to the same universe"
    assert_equal universes(:universe_two), UniverseScopeResolver.universe_for(section)
  end

  test "messages read oldest first and go with the thread" do
    discussion = Discussion.create!(universe: @universe, record: @character)
    first = discussion.messages.create!(user: users(:user_one), body: "First")
    second = discussion.messages.create!(user: users(:user_two), body: "Second")

    assert_equal [ first, second ], discussion.messages.reload.to_a

    assert_difference("DiscussionMessage.count", -2) do
      discussion.destroy
    end
  end

  test "the database allows only one thread per record" do
    Discussion.create!(universe: @universe, record: @character)

    duplicate = Discussion.new(universe: @universe, record: @character)

    assert_raises ActiveRecord::RecordNotUnique do
      duplicate.save!(validate: false)
    end
  end

  test "a destroyed universe leaves no thread behind" do
    discussion = Discussion.create!(universe: @universe, record: @character)
    discussion.messages.create!(user: users(:user_one), body: "A note")

    @universe.destroy

    # The contract is what is gone, not a number: `discussions` and
    # `discussion_messages` have no fixture files, and a table `fixtures :all`
    # does not own keeps whatever row a committed run left in it. Counting the
    # whole table therefore measured the test database's history rather than the
    # cascade, and one stray thread — the first one this suite did not write —
    # failed a passing cascade. The thread and its messages are named instead.
    assert_not Discussion.exists?(discussion.id)
    assert_not DiscussionMessage.exists?(discussion_id: discussion.id)
    # Reached by universe and by record, because the two `dependent: :destroy`
    # declarations are independent: the universe's and the record's own. A thread
    # left behind would be an orphan row nothing can reach.
    assert_empty Discussion.where(universe_id: @universe.id)
    assert_empty Discussion.where(record: @character)
  end
end
