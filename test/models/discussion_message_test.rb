require "test_helper"

class DiscussionMessageTest < ActiveSupport::TestCase
  setup do
    @discussion = Discussion.create!(universe: universes(:universe_one), record: characters(:character_one))
  end

  test "a message names its thread, its author, and what was said" do
    message = DiscussionMessage.new(discussion: @discussion, user: users(:user_one), body: "Is she the heir?")

    assert message.save
    assert_equal @discussion, message.discussion
    assert_equal users(:user_one), message.user
  end

  test "requires a body" do
    message = DiscussionMessage.new(discussion: @discussion, user: users(:user_one), body: "  ")

    assert_not message.valid?
    assert_includes message.errors[:body], "can't be blank"
  end

  test "requires a thread and an author" do
    threadless = DiscussionMessage.new(user: users(:user_one), body: "Orphan")
    authorless = DiscussionMessage.new(discussion: @discussion, body: "Anonymous")

    assert_not threadless.valid?
    assert_includes threadless.errors[:discussion], "must exist"
    assert_not authorless.valid?
    assert_includes authorless.errors[:user], "must exist"
  end

  test "the database refuses a message with no body" do
    assert_not DiscussionMessage.columns_hash.fetch("body").null
    assert_raises ActiveRecord::NotNullViolation do
      DiscussionMessage.where(id: @discussion.messages.create!(user: users(:user_one), body: "Present").id)
        .update_all(body: nil)
    end
  end
end
