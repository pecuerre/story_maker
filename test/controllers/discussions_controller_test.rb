require "test_helper"

class DiscussionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @character = characters(:character_one)
    @discussion = @character.find_or_create_discussion
    sign_in_as(users(:user_one))
  end

  test "the thread renders with the record's own identity above it" do
    @discussion.messages.create!(user: users(:user_one), body: "Is she the heir?")

    get universe_discussion_url(universe_slug: @universe.slug, id: @discussion)

    assert_response :success
    assert_select "h1", text: @character.name
    assert_select ".discussion-message", count: 1
    assert_includes response.body, "Is she the heir?"
    # The back link is the record's own page, built from its search declaration, so
    # the thread and the page it came from cannot disagree about where it lives.
    assert_select "a[href=?]", universe_character_path(universe_slug: @universe.slug, id: @character)
  end

  test "the messages render in the order they were written" do
    @discussion.messages.create!(user: users(:user_one), body: "First")
    @discussion.messages.create!(user: users(:user_two), body: "Second")

    get universe_discussion_url(universe_slug: @universe.slug, id: @discussion)

    assert_response :success
    assert_equal [ "First", "Second" ], css_select(".discussion-message-body").map(&:text)
  end

  test "an empty thread states that it is empty rather than showing an empty list" do
    empty = @universe.characters.create!(name: "Undiscussed").find_or_create_discussion

    get universe_discussion_url(universe_slug: @universe.slug, id: empty)

    assert_response :success
    assert_select ".empty-state", text: /No messages yet/
    assert_select ".discussion-message", count: 0
  end

  test "a guest reads the thread and is offered no composer" do
    @discussion.messages.create!(user: users(:user_one), body: "Open to everyone")
    sign_out

    get universe_discussion_url(universe_slug: @universe.slug, id: @discussion)

    assert_response :success
    assert_includes response.body, "Open to everyone"
    assert_select ".discussion-composer", count: 0
  end

  test "a read-only member reads the same thread with no composer" do
    private_universe = Universe.create!(owner: users(:user_one), name: "Private threads", slug: "private-threads",
      private: true)
    character = private_universe.characters.create!(name: "Private character")
    discussion = character.find_or_create_discussion
    discussion.messages.create!(user: users(:user_one), body: "Members only")
    UniverseMembership.create!(universe: private_universe, user: users(:user_two), access_level: :read)
    sign_in_as(users(:user_two))

    get universe_discussion_url(universe_slug: private_universe.slug, id: discussion)

    assert_response :success
    assert_includes response.body, "Members only"
    assert_select ".discussion-composer", count: 0
  end

  test "a thread from another universe is a 404" do
    get universe_discussion_url(universe_slug: universes(:universe_two).slug, id: @discussion)

    assert_response :not_found
  end

  test "an unknown thread is a 404" do
    get universe_discussion_url(universe_slug: @universe.slug, id: 0)

    assert_response :not_found
  end

  test "a private universe's thread is a 404 for a non-member" do
    private_universe = Universe.create!(owner: users(:user_one), name: "Hidden threads", slug: "hidden-threads",
      private: true)
    discussion = private_universe.characters.create!(name: "Hidden").find_or_create_discussion
    sign_out

    get universe_discussion_url(universe_slug: private_universe.slug, id: discussion)

    assert_response :not_found
  end

  test "discussing a record finds its thread and redirects to it" do
    other = @universe.locations.create!(name: "Undiscussed location")

    assert_difference("Discussion.count", 1) do
      post universe_discussions_url(universe_slug: @universe.slug),
        params: { discussion: { record_type: "Location", record_id: other.id } }
    end

    assert_redirected_to universe_discussion_url(universe_slug: @universe.slug, id: other.reload.discussion)
  end

  test "discussing a record that already has a thread lands on it rather than failing" do
    assert_no_difference("Discussion.count") do
      post universe_discussions_url(universe_slug: @universe.slug),
        params: { discussion: { record_type: "Character", record_id: @character.id } }
    end

    assert_redirected_to universe_discussion_url(universe_slug: @universe.slug, id: @discussion)
  end

  test "a record of another universe cannot be discussed through this one" do
    # `RecordTarget` is asked to resolve the reference inside the universe the
    # request has already authorized, so a record from elsewhere is the same 404 as
    # an unknown one. A character of *this* universe would be discussed normally.
    elsewhere = universes(:universe_two).characters.create!(name: "Elsewhere")

    assert_no_difference("Discussion.count") do
      post universe_discussions_url(universe_slug: @universe.slug),
        params: { discussion: { record_type: "Character", record_id: elsewhere.id } }
    end

    assert_response :not_found
  end

  test "an unregistered record type is a 404 rather than a loaded constant" do
    assert_no_difference("Discussion.count") do
      post universe_discussions_url(universe_slug: @universe.slug),
        params: { discussion: { record_type: "Kernel", record_id: @character.id } }
    end

    assert_response :not_found
  end

  test "a guest cannot start a discussion" do
    sign_out

    assert_no_difference("Discussion.count") do
      post universe_discussions_url(universe_slug: @universe.slug),
        params: { discussion: { record_type: "Character", record_id: @character.id } }
    end

    assert_redirected_to new_session_path
  end

  test "an ordinary public contributor cannot discuss" do
    # A public universe grants every signed-in user write access, so this control
    # *is* offered to them. What it must never do is open a thread for a record in
    # a universe the request has not authorized.
    other_universe = Universe.create!(owner: users(:user_two), name: "Not yours", slug: "not-yours")
    foreign = other_universe.characters.create!(name: "Foreign")

    assert_no_difference("Discussion.count") do
      post universe_discussions_url(universe_slug: @universe.slug),
        params: { discussion: { record_type: "Character", record_id: foreign.id } }
    end

    assert_response :not_found
  end

  test "a record's details page offers Discuss to a writer and the thread to nobody else" do
    undiscussed = @universe.characters.create!(name: "Undiscussed")

    get universe_character_url(universe_slug: @universe.slug, id: undiscussed)

    assert_response :success
    assert_select ".page-actions form[action=?]", universe_discussions_path(universe_slug: @universe.slug)

    get universe_location_url(universe_slug: @universe.slug, id: locations(:location_one))
    assert_response :success
    assert_select ".page-actions form[action=?]", universe_discussions_path(universe_slug: @universe.slug)

    sign_out
    get universe_character_url(universe_slug: @universe.slug, id: @character)

    assert_response :success
    assert_select ".page-actions form", count: 0
    assert_select ".page-actions a", text: I18n.t("discussions.control.start"), count: 0
  end

  test "a record whose thread exists links to it instead of offering to create one" do
    @discussion.messages.create!(user: users(:user_one), body: "Already started")

    get universe_character_url(universe_slug: @universe.slug, id: @character)

    assert_response :success
    assert_select ".page-actions a[href=?]", universe_discussion_path(universe_slug: @universe.slug, id: @discussion),
      text: I18n.t("discussions.control.open")
    assert_select ".page-actions form", count: 0
  end
end
