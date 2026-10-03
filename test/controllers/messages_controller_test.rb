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
