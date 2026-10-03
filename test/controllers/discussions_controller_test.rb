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

  test "each message carries its author and the moment it was written" do
    message = @discussion.messages.create!(user: users(:user_two), body: "She was here in the spring.")

    get universe_discussion_url(universe_slug: @universe.slug, id: @discussion)

    assert_response :success
    assert_select ".discussion-message-author", text: users(:user_two).name
    # The machine value and the printed one are the same moment in two forms: the
    # `datetime` attribute is what anything that is not a human reading it uses,
    # so it has to be the exact instant rather than the localized string.
    time = css_select(".discussion-message time").first
    assert_equal message.created_at.iso8601, time["datetime"]
    assert_equal I18n.l(message.created_at, format: :short), time.text.strip
  end

  test "a message whose author has no name states it rather than rendering an empty author" do
    # `users.name` is `NOT NULL` but has no presence validation (known quirk 27),
    # and `NOT NULL` rejects only `NULL`, so an empty string is what a seed or
    # import caller leaves behind. A message with no visible author is exactly the
    # anonymous block the thread refuses to show, so the shared blank copy stands
    # in for it.
    author = User.create!(name: "", email_address: "nameless-#{SecureRandom.hex(4)}@example.com",
      password: "abcdefgh")
    @discussion.messages.create!(user: author, body: "Still says something.")

    get universe_discussion_url(universe_slug: @universe.slug, id: @discussion)

    assert_response :success
    assert_select ".discussion-message-author", text: I18n.t("shared.detail_fact.blank")
  end

  test "an empty thread invites a writer to start it but only states what will appear to a guest" do
    empty = @universe.characters.create!(name: "Undiscussed").find_or_create_discussion

    get universe_discussion_url(universe_slug: @universe.slug, id: empty)

    assert_response :success
    assert_select ".empty-description", text: I18n.t("discussions.show.empty_writable_description")

    # A guest has no composer, so being told to be the first to say something
    # names an action this page does not offer them. The split is the same one
    # every list in the application makes for its own empty state.
    sign_out
    get universe_discussion_url(universe_slug: @universe.slug, id: empty)

    assert_response :success
    assert_select ".empty-description", text: I18n.t("discussions.show.empty_read_only_description")
    assert_select ".discussion-composer", count: 0
  end

  test "the thread renders in Spanish, timestamps included" do
    message = @discussion.messages.create!(user: users(:user_two), body: "¿Es la heredera?")
    patch settings_url, params: { locale: "es" }

    get universe_discussion_url(universe_slug: @universe.slug, id: @discussion)

    assert_response :success
    assert_select ".discussion-message-body", text: "¿Es la heredera?"
    assert_select ".discussion-message-author", text: users(:user_two).name
    # `activesupport` ships no Spanish locale file at all, so `time.formats.short`
    # and the `%b` it is written with had to be translated here. Without them this
    # request raised `I18n::MissingTranslationData` rather than falling back,
    # because `raise_on_missing_translations` is on in the test environment.
    #
    # The expectation is built inside `with_locale` rather than against the
    # process default, which is English: the assertion that matters is that the
    # page rendered *Spanish*, so comparing against English would pass whether or
    # not the translation existed.
    spanish = I18n.with_locale(:es) { I18n.l(message.created_at, format: :short) }
    assert_select ".discussion-message time", text: spanish
    assert_match(/[a-záéíóú]/, spanish)
    assert_not_equal I18n.l(message.created_at, format: :short, locale: :en), spanish
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
