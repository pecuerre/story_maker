require "test_helper"

class MessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @character = characters(:character_one)
    @discussion = @character.find_or_create_discussion
    sign_in_as(users(:user_one))
  end

  test "a reply is stored against the signed-in author and redirects to the thread" do
    assert_difference("DiscussionMessage.count", 1) do
      post universe_discussion_messages_url(universe_slug: @universe.slug, discussion_id: @discussion.id),
        params: { discussion_message: { body: "Keep the letter." } }
    end

    message = @discussion.messages.last
    assert_equal users(:user_one), message.user
    assert_equal "Keep the letter.", message.body
    assert_redirected_to universe_discussion_url(universe_slug: @universe.slug, id: @discussion)
    follow_redirect!
    assert_select ".alert-success", text: /#{I18n.t('discussions.flash.message_created')}/
  end

  # Who a reply tells. The notice is written by the model inside the message's own
  # transaction, so the request suite is where it can be checked as a whole: that it
  # was written at all, that it reached the right people, and that a refused reply
  # wrote none.
  test "a reply tells the people already in the thread and nobody else" do
    @discussion.messages.create!(user: users(:user_two), body: "Is she the heir?")
    # A member who has never posted is not in the conversation, and the author of the
    # reply is the one person the news is not news for.
    bystander = User.create!(name: "User Three", email_address: "three@example.com", password: "password")
    UniverseMembership.create!(universe: @universe, user: bystander, access_level: "write")

    assert_difference("Notification.count", 1) do
      post universe_discussion_messages_url(universe_slug: @universe.slug, discussion_id: @discussion.id),
        params: { discussion_message: { body: "Keep the letter." } }
    end

    notification = users(:user_two).notifications.sole
    assert_equal "discussion_reply", notification.kind
    assert_empty users(:user_one).notifications
    assert_empty bystander.notifications
  end

  test "a reply to a thread nobody else has joined in is told to nobody" do
    assert_no_difference("Notification.count") do
      post universe_discussion_messages_url(universe_slug: @universe.slug, discussion_id: @discussion.id),
        params: { discussion_message: { body: "Nobody to hear this" } }
    end

    assert_response :see_other
  end

  test "a refused reply writes no message and no notice" do
    @discussion.messages.create!(user: users(:user_two), body: "Is she the heir?")

    assert_no_difference("Notification.count") do
      assert_no_difference("DiscussionMessage.count") do
        post universe_discussion_messages_url(universe_slug: @universe.slug, discussion_id: @discussion.id),
          params: { discussion_message: { body: "" } }
      end
    end

    assert_response :unprocessable_content
  end

  test "an empty reply is refused and keeps what was typed" do
    assert_no_difference("DiscussionMessage.count") do
      post universe_discussion_messages_url(universe_slug: @universe.slug, discussion_id: @discussion.id),
        params: { discussion_message: { body: "" } }
    end

    assert_response :unprocessable_content
    assert_select ".alert-danger[role=alert]", minimum: 1
    # The composer is re-rendered rather than the thread being redirected away, so
    # the author can see the reason and correct it instead of starting over.
    assert_select ".discussion-composer textarea", minimum: 1
  end

  test "a guest cannot post a reply" do
    sign_out

    assert_no_difference("DiscussionMessage.count") do
      post universe_discussion_messages_url(universe_slug: @universe.slug, discussion_id: @discussion.id),
        params: { discussion_message: { body: "Anonymous" } }
    end

    assert_redirected_to new_session_path
  end

  test "a read-only member cannot post a reply" do
    private_universe = Universe.create!(owner: users(:user_one), name: "Private replies", slug: "private-replies",
      private: true)
    character = private_universe.characters.create!(name: "Private character")
    discussion = character.find_or_create_discussion
    UniverseMembership.create!(universe: private_universe, user: users(:user_two), access_level: :read)
    sign_in_as(users(:user_two))

    assert_no_difference("DiscussionMessage.count") do
      post universe_discussion_messages_url(universe_slug: private_universe.slug, discussion_id: discussion.id),
        params: { discussion_message: { body: "Not allowed" } }
    end

    assert_response :forbidden
  end

  test "a reply to a thread in another universe is a 404" do
    assert_no_difference("DiscussionMessage.count") do
      post universe_discussion_messages_url(universe_slug: universes(:universe_two).slug, discussion_id: @discussion.id),
        params: { discussion_message: { body: "Wrong universe" } }
    end

    assert_response :not_found
  end

  test "a reply to an unknown thread is a 404" do
    assert_no_difference("DiscussionMessage.count") do
      post universe_discussion_messages_url(universe_slug: @universe.slug, discussion_id: 0),
        params: { discussion_message: { body: "No such thread" } }
    end

    assert_response :not_found
  end

  test "the author is the signed-in reader, not whoever the request names" do
    assert_difference("DiscussionMessage.count", 1) do
      post universe_discussion_messages_url(universe_slug: @universe.slug, discussion_id: @discussion.id),
        params: { discussion_message: { body: "Impersonation", user_id: users(:user_two).id } }
    end

    assert_equal users(:user_one), @discussion.messages.last.user
  end
end
