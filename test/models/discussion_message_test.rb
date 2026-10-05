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

  # Posting, which is a save and the conversation's notice as one write.
  test "posting a reply tells the thread it was posted in" do
    @discussion.messages.create!(user: users(:user_two), body: "Is she the heir?")

    assert_difference("Notification.count", 1) do
      assert @discussion.messages.new(user: users(:user_one), body: "Keep the letter.").post!
    end

    notification = users(:user_two).notifications.sole
    assert_equal "discussion_reply", notification.kind
    assert_equal @discussion.id, notification.payload["discussion_id"]
    assert_equal "Character one", notification.payload["record_name"]
  end

  test "posting into a thread nobody else has joined in tells nobody" do
    # The one recipient rule is the thread's other authors, so a first message in a new
    # thread has no readers to tell. It is not an error and it writes no row.
    assert_no_difference("Notification.count") do
      assert @discussion.messages.new(user: users(:user_one), body: "Somebody reading?").post!
    end
  end

  test "a refused post writes neither the message nor a notice" do
    @discussion.messages.create!(user: users(:user_two), body: "Is she the heir?")
    message = @discussion.messages.new(user: users(:user_one), body: "  ")

    assert_no_difference("Notification.count") do
      assert_no_difference("DiscussionMessage.count") do
        # It answers false rather than raising: an empty composer is an ordinary form
        # error the thread re-renders beside the field, not a crash.
        assert_not message.post!
      end
    end
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
