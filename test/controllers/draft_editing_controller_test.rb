require "test_helper"

# The **Start editing** / **Stop editing** control on the universe page.
#
# Three things are worth asserting here and nowhere else:
#
# - **the control's visibility**, which is the same rule the controller enforces —
#   a draft-based universe and `write` access, or neither renders it and neither
#   accepts the request;
# - **that starting opens the draft before the first change**, which is the whole
#   reason the control exists rather than a label;
# - **that the flag is not a gate.** A mutation in a draft-based universe is
#   remembered whether the reader pressed anything or not, and that is the property
#   a reader who forgot to press the button would depend on.
#
# The remembering half across all twenty controllers is
# `test/controllers/draft_mutation_test.rb`; the draft the flag opens is covered by
# `test/models/draft_editing_session_test.rb`.
class DraftEditingControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @user = users(:user_one)
    @universe.update!(collaboration_mode: "wikipedia")
    sign_in_as(@user)
  end

  # Starting and stopping

  test "starting claims the session, opens a draft, and returns to the universe" do
    assert_difference -> { Draft.count }, 1 do
      post universe_editing_url(universe_slug: @universe.slug)
    end

    assert_redirected_to universe_url(@universe)
    assert_equal I18n.t("drafts.flash.editing_started"), flash[:notice]

    draft = Draft.open_for(@user, @universe)
    assert_predicate draft, :open?

    # The claim lives in the session, so it survives navigation — which is the
    # difference between an editing session and a one-page banner.
    get universe_url(@universe)

    assert_response :success
    assert_select ".page-actions form[action=?]", universe_editing_path(universe_slug: @universe.slug), count: 1
    assert_select ".page-actions form[action=?] button", universe_editing_path(universe_slug: @universe.slug),
      text: I18n.t("drafts.editing.stop"), count: 1
  end

  test "the pending count on the universe page is this reader's own open changes" do
    post universe_editing_url(universe_slug: @universe.slug)
    get universe_url(@universe)

    # The count is asserted against the actions row as a substring rather than as the
    # row's whole text, because that row carries the other page actions too.
    assert_includes page_actions_text, I18n.t("drafts.pending.count", count: 0)

    draft = Draft.open_for(@user, @universe)
    draft.draft_changes.create!(action: "create", record_type: "Character",
      payload: { "name" => "Ariadne", "universe_id" => @universe.id })

    get universe_url(@universe)

    assert_includes page_actions_text, I18n.t("drafts.pending.count", count: 1)

    # Somebody else's pending work is not part of this reader's count, and neither
    # is the history of a draft that has already been applied.
    someone_else = Draft.create!(user: users(:user_two), universe: @universe)
    someone_else.draft_changes.create!(action: "create", record_type: "Character",
      payload: { "name" => "Theirs", "universe_id" => @universe.id })
    history = Draft.create!(user: @user, universe: universes(:universe_two))
    history.update!(status: "applied", closed_at: Time.current)
    history.draft_changes.create!(action: "create", record_type: "Character",
      payload: { "name" => "Old", "universe_id" => universes(:universe_two).id })

    get universe_url(@universe)

    assert_includes page_actions_text, I18n.t("drafts.pending.count", count: 1)
  end

  test "the count is a link into the changes it is counting" do
    post universe_editing_url(universe_slug: @universe.slug)
    get universe_url(@universe)

    # A number is only interesting as a way into the changes; a badge with nowhere
    # to go is a decoration. Scoped to the page's own actions, because the right
    # sidebar links to the same page and this is about the count's affordance.
    assert_select ".page-actions a[href=?]", universe_drafts_path(universe_slug: @universe.slug), count: 1
  end

  test "stopping releases the claim and says what is still waiting" do
    post universe_editing_url(universe_slug: @universe.slug)
    draft = Draft.open_for(@user, @universe)
    draft.draft_changes.create!(action: "create", record_type: "Character",
      payload: { "name" => "Ariadne", "universe_id" => @universe.id })

    delete universe_editing_url(universe_slug: @universe.slug)

    assert_redirected_to universe_url(@universe)
    assert_equal I18n.t("drafts.flash.editing_stopped", count: 1), flash[:notice],
      "stopping must not read as a loss: the changes are still on the draft, and the flash has to say so"
    assert_predicate draft.reload, :open?, "stopping an editing session is not discarding its draft"

    get universe_url(@universe)

    assert_response :success
    assert_includes page_actions_text, I18n.t("drafts.editing.start")
    assert_not_includes page_actions_text, I18n.t("drafts.editing.stop")
  end

  test "a draft with nothing in it is said to have nothing waiting" do
    post universe_editing_url(universe_slug: @universe.slug)

    delete universe_editing_url(universe_slug: @universe.slug)

    assert_equal I18n.t("drafts.flash.editing_stopped", count: 0), flash[:notice]
  end

  test "stopping without a session to release is accepted rather than refused" do
    # The reader reached **Stop editing** from a page rendered before they did, or
    # a second click arrived after the first released the claim. Either way there is
    # nothing left to undo, and refusing would make the control look broken.
    delete universe_editing_url(universe_slug: @universe.slug)

    assert_redirected_to universe_url(@universe)
    assert_equal I18n.t("drafts.flash.editing_stopped", count: 0), flash[:notice]
  end

  test "starting twice resumes the one open draft rather than opening a second" do
    post universe_editing_url(universe_slug: @universe.slug)
    draft = Draft.open_for(@user, @universe)
    draft.draft_changes.create!(action: "create", record_type: "Character",
      payload: { "name" => "Ariadne", "universe_id" => @universe.id })

    assert_no_difference -> { Draft.count } do
      post universe_editing_url(universe_slug: @universe.slug)
    end

    get universe_url(@universe)

    assert_includes page_actions_text, I18n.t("drafts.pending.count", count: 1),
      "a second start must not strand the change already waiting in the reader's draft"
  end

  # The flag is a claim, not a gate

  test "a mutation is remembered whether or not the reader is editing" do
    # The property this whole design rests on. If pressing **Start editing** were
    # required for a change to be remembered, a reader who forgot it would write
    # straight through a universe whose mode exists precisely to stop that.
    character = characters(:character_one)
    get universe_url(@universe)
    assert_not DraftEditingSession.active?(session: last_session, user: @user, universe: @universe)

    patch universe_character_url(universe_slug: @universe.slug, id: character.id),
      params: { character: { name: "Remembered without the toggle" } }, as: :json

    assert_response :accepted
    assert_equal "Remembered without the toggle", Draft.open_for(@user, @universe).draft_changes.last
      .payload["name"]
    assert_not_equal "Remembered without the toggle", character.reload.name,
      "a remembered change must not be written, whatever the editing session says"
  end

  test "a change remembered during an editing session is the same one remembered without it" do
    post universe_editing_url(universe_slug: @universe.slug)
    patch universe_character_url(universe_slug: @universe.slug, id: characters(:character_one).id),
      params: { character: { name: "Remembered while editing" } }, as: :json

    assert_response :accepted
    assert_equal 1, Draft.pending_changes_count(@user, @universe)
  end

  # Where the control appears

  test "a writer sees the control in a draft-based universe" do
    %w[wikipedia github].each do |mode|
      @universe.update!(collaboration_mode: mode)

      get universe_url(@universe)

      assert_response :success
      assert_includes page_actions_text, I18n.t("drafts.editing.start")
    end
  end

  test "a universe that writes changes straight through has no editing session" do
    @universe.update!(collaboration_mode: "direct")

    get universe_url(@universe)

    assert_response :success
    assert_not_includes page_actions_text, I18n.t("drafts.editing.start")
    assert_not_includes page_actions_text, I18n.t("drafts.editing.stop")
  end

  test "a reader who cannot write is offered nothing to edit" do
    # A read level only exists in a private universe: a public one grants every
    # signed-in user write regardless of what a membership row says.
    private_universe = Universe.create!(owner: users(:user_two), name: "Private one", slug: "private-one",
      private: true, collaboration_mode: "wikipedia")
    UniverseMembership.create!(user: @user, universe: private_universe, access_level: "read")

    get universe_url(private_universe)

    assert_response :success
    assert_not_includes page_actions_text, I18n.t("drafts.editing.start")
  end

  test "a guest is offered nothing to edit" do
    sign_out

    get universe_url(@universe)

    assert_response :success
    assert_not_includes page_actions_text, I18n.t("drafts.editing.start")
  end

  # Authorization and the stale page

  test "a reader who cannot write cannot start or stop an editing session" do
    private_universe = Universe.create!(owner: users(:user_two), name: "Private one", slug: "private-one",
      private: true, collaboration_mode: "wikipedia")
    UniverseMembership.create!(user: @user, universe: private_universe, access_level: "read")

    assert_no_difference -> { Draft.count } do
      post universe_editing_url(universe_slug: private_universe.slug)
    end

    assert_response :forbidden
    assert_not DraftEditingSession.active?(session: last_session, user: @user, universe: private_universe)

    delete universe_editing_url(universe_slug: private_universe.slug)

    assert_response :forbidden
  end

  test "a guest is sent to sign in rather than shown a session to start" do
    sign_out

    assert_no_difference -> { Draft.count } do
      post universe_editing_url(universe_slug: @universe.slug)
    end

    assert_redirected_to new_session_url
    assert_not DraftEditingSession.active?(session: last_session, user: nil, universe: @universe)
  end

  test "a toggle posted from a stale page in a direct universe is answered, not silently accepted" do
    @universe.update!(collaboration_mode: "direct")

    assert_no_difference -> { Draft.count } do
      post universe_editing_url(universe_slug: @universe.slug)
    end

    assert_redirected_to universe_url(@universe)
    assert_equal I18n.t("drafts.flash.not_draft_based"), flash[:alert]
    assert_not DraftEditingSession.active?(session: last_session, user: @user, universe: @universe)
  end

  test "the claim is dropped when the session ends" do
    post universe_editing_url(universe_slug: @universe.slug)

    assert DraftEditingSession.active?(session: last_session, user: @user, universe: @universe)

    # The real sign-out, not the test helper's cookie-only shortcut: the claim is
    # dropped by `Authentication#clear_session_context`, which is what a browser
    # actually goes through, and the helper would leave it in the session and make
    # this pass for the wrong reason.
    delete session_url

    assert_not DraftEditingSession.active?(session: last_session, user: @user, universe: @universe)

    # The draft is still there — a sign-out is not a discard — but the claim to be
    # editing is per-visit state and must not cross accounts on a shared browser.
    assert_predicate Draft.open_for(@user, @universe), :open?

    sign_in_as(@user)
    get universe_url(@universe)

    assert_includes page_actions_text, I18n.t("drafts.editing.start")
    assert_not_includes page_actions_text, I18n.t("drafts.editing.stop")
  end

  test "another reader's session claims nothing in this universe" do
    post universe_editing_url(universe_slug: @universe.slug)
    draft = Draft.open_for(@user, @universe)

    delete session_url
    sign_in_as(users(:user_two))

    get universe_url(@universe)

    assert_response :success
    # The second reader is offered to start their own session, and gets their own
    # draft rather than this one.
    assert_includes page_actions_text, I18n.t("drafts.editing.start")
    assert_nil Draft.open_for(users(:user_two), @universe)

    post universe_editing_url(universe_slug: @universe.slug)

    assert_not_equal draft, Draft.open_for(users(:user_two), @universe)
  end

  private
    # The session hash the last request was carrying, which is the only way to
    # observe a claim that is deliberately not a record.
    #
    # It is read off `response.request` rather than through the test's own `session`
    # because that reader needs a controller to have run, so it raises on a test that
    # asks before its first request. Every case that wants the claim has made one.
    def last_session
      response.request.session.to_hash.with_indifferent_access
    end

    # The universe page's action row as one string. The control is asserted this way
    # rather than with `assert_select` because that row also carries **New story**,
    # **All stories**, **Members**, and the overflow menu, so an element-scoped text
    # match would be asserting about the row rather than about the control.
    def page_actions_text
      css_select(".page-actions").text
    end
end
