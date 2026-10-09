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

  # Rendering, which is the one thing on this model that turns stored markdown into
  # HTML somebody else will read.
  #
  # It had no coverage here when it was written: the thread's own test caught the
  # paragraph wrapper and the block newline it leaves behind by asserting the exact
  # text of a rendered message, and that assertion was the whole guard. It is kept —
  # it is the reason the wrapper is stripped rather than trusted — but it can only
  # see one body on one page, so what this method promises is held here.
  test "a body is rendered as markdown, without the paragraph wrapper the view adds" do
    message = @discussion.messages.build(user: users(:user_one), body: "She said **keep** the letter.")

    assert_equal "She said <strong>keep</strong> the letter.", message.rendered_body
  end

  test "a multi-paragraph body keeps the break between its paragraphs" do
    # `.strip` trims the ends rather than every gap, because the blank line between two
    # paragraphs is the author's and Redcarpet's alike.
    message = @discussion.messages.build(user: users(:user_one), body: "Is she the heir?\n\nI say yes.")

    assert_equal "Is she the heir?\n\nI say yes.", message.rendered_body
  end

  test "raw HTML in a body is not rendered as markup" do
    # The body is author-entered and every surface that prints it is somebody else's
    # page, so the renderer filters rather than trusts (`filter_html`).
    message = @discussion.messages.build(user: users(:user_one), body: "<script>alert('x')</script> Is she the heir?")

    assert_no_match(/<script>/, message.rendered_body)
    assert_includes message.rendered_body, "Is she the heir?"
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
