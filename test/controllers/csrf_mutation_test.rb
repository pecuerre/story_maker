require "test_helper"

# The shared editors mutate through `fetch`, so the server has to accept a real
# CSRF token and has to refuse a mutation that carries none, without writing
# anything. Test mode disables forgery protection by default; these cases turn it
# back on so the contract is actually exercised, and `CsrfTokenTest` proves the
# same thing through a real browser.
class CsrfMutationTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @user = users(:user_one)
    sign_in_as(@user)
  end

  test "a json mutation with the page's own token is accepted" do
    with_forgery_protection do
      token = fetch_page_token

      assert_difference("Character.count", 1) do
        post universe_characters_url(universe_slug: @universe.slug),
          params: { character: { name: "Token verified" } },
          headers: { "X-CSRF-Token" => token },
          as: :json
      end

      assert_response :created
      assert_equal "Token verified", Character.order(:id).last.name
    end
  end

  test "a json mutation without a token is refused and saves nothing" do
    with_forgery_protection do
      fetch_page_token

      assert_no_difference("Character.count") do
        post universe_characters_url(universe_slug: @universe.slug),
          params: { character: { name: "Never saved" } },
          as: :json
      end

      assert_response :forbidden
      assert_nil Character.find_by(name: "Never saved")
    end
  end

  test "a json mutation with a forged token is refused and saves nothing" do
    with_forgery_protection do
      fetch_page_token

      assert_no_difference("Character.count") do
        post universe_characters_url(universe_slug: @universe.slug),
          params: { character: { name: "Forged" } },
          headers: { "X-CSRF-Token" => "not-the-page-token" },
          as: :json
      end

      assert_response :forbidden
      assert_nil Character.find_by(name: "Forged")
    end
  end

  test "the taxonomy tree's own mutation endpoint refuses a tokenless write too" do
    with_forgery_protection do
      tag = character_tags(:character_tag_one)
      fetch_page_token

      assert_no_difference("CharacterTag.count") do
        post universe_character_tags_url(universe_slug: @universe.slug),
          params: { character_tag: { name: "Tokenless" } },
          as: :json
      end

      assert_response :forbidden
      assert_not_equal "Tokenless", tag.reload.name
    end
  end

  test "Faction create, update, and delete require the page token" do
    with_forgery_protection do
      index_path = universe_factions_path(universe_slug: @universe.slug)
      token = fetch_page_token(index_path)
      create_path = universe_factions_path(universe_slug: @universe.slug)

      assert_no_difference("Faction.count") do
        post create_path, params: { faction: { name: "Tokenless faction" } }, as: :json
      end
      assert_response :forbidden

      post create_path, params: { faction: { name: "Token-verified faction" } },
        headers: { "X-CSRF-Token" => token }, as: :json
      assert_response :created
      faction = Faction.find(response.parsed_body.fetch("id"))

      patch universe_faction_path(universe_slug: @universe.slug, id: faction),
        params: { faction: { mission: "Updated mission" } },
        headers: { "X-CSRF-Token" => token }, as: :json
      assert_response :success

      delete universe_faction_path(universe_slug: @universe.slug, id: faction),
        headers: { "X-CSRF-Token" => token }, as: :json
      assert_response :no_content
    end
  end

  test "Faction relationship HTML mutations require a page token" do
    with_forgery_protection do
      index_path = universe_faction_relationships_path(universe_slug: @universe.slug)
      token = fetch_page_token(index_path)
      from = factions(:faction_one)
      to = factions(:faction_two)

      assert_no_difference("FactionRelationship.count") do
        post index_path, params: { faction_relationship: { from_faction_id: from.id, to_faction_id: to.id } }
      end
      assert_includes 406..422, response.status

      assert_difference("FactionRelationship.count") do
        post index_path,
          params: { faction_relationship: { from_faction_id: from.id, to_faction_id: to.id } },
          headers: { "X-CSRF-Token" => token }
      end
      assert_response :found
    end
  end

  test "Faction Tag create, update, and delete require the page token" do
    with_forgery_protection do
      index_path = universe_faction_tags_path(universe_slug: @universe.slug)
      token = fetch_page_token(index_path)
      create_path = universe_faction_tags_path(universe_slug: @universe.slug)

      assert_no_difference("FactionTag.count") do
        post create_path, params: { faction_tag: { name: "Tokenless faction tag" } }, as: :json
      end
      assert_response :forbidden

      post create_path, params: { faction_tag: { name: "Token-verified faction tag" } },
        headers: { "X-CSRF-Token" => token }, as: :json
      assert_response :created
      tag = FactionTag.find(response.parsed_body.fetch("id"))

      patch universe_faction_tag_path(universe_slug: @universe.slug, id: tag),
        params: { faction_tag: { description: "Updated description" } },
        headers: { "X-CSRF-Token" => token }, as: :json
      assert_response :success

      delete universe_faction_tag_path(universe_slug: @universe.slug, id: tag),
        headers: { "X-CSRF-Token" => token }, as: :json
      assert_response :no_content
    end
  end

  test "Character knowledge mutations require the character details page token" do
    with_forgery_protection do
      character = characters(:character_one)
      index_path = universe_character_path(universe_slug: @universe.slug, id: character)
      token = fetch_page_token(index_path)
      create_path = universe_character_character_knowledges_path(
        universe_slug: @universe.slug, character_id: character
      )
      attributes = { when_text: "At the bridge", what_learned: "The guard left." }

      assert_no_difference("CharacterKnowledge.count") do
        post create_path, params: { character_knowledge: attributes }
      end
      assert_includes 406..422, response.status

      assert_difference("CharacterKnowledge.count", 1) do
        post create_path, params: { character_knowledge: attributes }, headers: { "X-CSRF-Token" => token }
      end
      assert_response :found
    end
  end

  test "a scene element mutation is accepted with the page's own token" do
    with_forgery_protection do
      scene = scenes(:scene_one)
      token = fetch_page_token(universe_story_scene_path(universe_slug: @universe.slug,
        story_id: scene.story, id: scene))

      assert_difference("SceneElement.count", 1) do
        post universe_story_scene_scene_elements_url(universe_slug: @universe.slug,
          story_id: scene.story, scene_id: scene),
          params: { scene_element: { kind: "narration", name: "Token verified" } },
          headers: { "X-CSRF-Token" => token },
          as: :json
      end

      assert_response :created
    end
  end

  test "a Plot mutation is refused without a token and accepted with one" do
    with_forgery_protection do
      story = stories(:story_one)
      path = universe_story_plots_url(universe_slug: @universe.slug, story_id: story)
      token = fetch_page_token(path)
      payload = { plot: { name: "CSRF verified" } }

      assert_no_difference("Plot.count") { post path, params: payload, as: :json }
      assert_response :forbidden

      assert_difference("Plot.count", 1) do
        post path, params: payload, headers: { "X-CSRF-Token" => token }, as: :json
      end
      assert_response :created
    end
  end

  test "a scene element mutation without a token is refused and saves nothing" do
    with_forgery_protection do
      scene = scenes(:scene_one)
      fetch_page_token(universe_story_scene_path(universe_slug: @universe.slug,
        story_id: scene.story, id: scene))

      assert_no_difference("SceneElement.count") do
        post universe_story_scene_scene_elements_url(universe_slug: @universe.slug,
          story_id: scene.story, scene_id: scene),
          params: { scene_element: { kind: "narration", name: "Never saved" } },
          as: :json
      end

      assert_response :forbidden
      assert_nil SceneElement.find_by(name: "Never saved")
    end
  end

  test "a scene dialogue turn mutation is refused without a token and accepted with one" do
    with_forgery_protection do
      scene = scenes(:scene_one)
      element = scene_elements(:dialogue_one)
      path = universe_story_scene_scene_element_scene_dialogue_turns_url(
        universe_slug: @universe.slug, story_id: scene.story, scene_id: scene, scene_element_id: element
      )
      payload = { scene_dialogue_turn: { speaker_id: characters(:character_one).id, body: "Token verified" } }
      token = fetch_page_token(universe_story_scene_path(universe_slug: @universe.slug,
        story_id: scene.story, id: scene))

      assert_no_difference("SceneDialogueTurn.count") do
        post path, params: payload, as: :json
      end
      assert_response :forbidden

      assert_difference("SceneDialogueTurn.count", 1) do
        post path, params: payload, headers: { "X-CSRF-Token" => token }, as: :json
      end
      assert_response :created
      assert_equal "Token verified", SceneDialogueTurn.order(:id).last.body
    end
  end

  test "a scene character mutation is refused without a token and accepted with one" do
    with_forgery_protection do
      scene = scenes(:scene_one)
      character = @universe.characters.create!(name: "Token test character")
      payload = { scene_character: { character_id: character.id, role: "setting" } }
      token = fetch_page_token(universe_story_scene_scene_characters_path(universe_slug: @universe.slug,
        story_id: scene.story, scene_id: scene))

      assert_no_difference("SceneCharacter.count") do
        post universe_story_scene_scene_characters_url(universe_slug: @universe.slug,
          story_id: scene.story, scene_id: scene), params: payload, as: :json
      end
      assert_response :forbidden

      assert_difference("SceneCharacter.count", 1) do
        post universe_story_scene_scene_characters_url(universe_slug: @universe.slug,
          story_id: scene.story, scene_id: scene), params: payload,
          headers: { "X-CSRF-Token" => token }, as: :json
      end
      assert_response :created
    end
  end

  test "a scene item mutation is refused without a token and accepted with one" do
    with_forgery_protection do
      scene = scenes(:scene_one)
      item = @universe.items.create!(name: "Token test item")
      payload = { scene_item: { item_id: item.id, role: "carries" } }
      token = fetch_page_token(universe_story_scene_scene_items_path(universe_slug: @universe.slug,
        story_id: scene.story, scene_id: scene))

      assert_no_difference("SceneItem.count") do
        post universe_story_scene_scene_items_url(universe_slug: @universe.slug,
          story_id: scene.story, scene_id: scene), params: payload, as: :json
      end
      assert_response :forbidden

      assert_difference("SceneItem.count", 1) do
        post universe_story_scene_scene_items_url(universe_slug: @universe.slug,
          story_id: scene.story, scene_id: scene), params: payload,
          headers: { "X-CSRF-Token" => token }, as: :json
      end
      assert_response :created
    end
  end

  test "a scene location mutation is refused without a token and accepted with one" do
    with_forgery_protection do
      scene = scenes(:scene_one)
      location = @universe.locations.create!(name: "Token test place")
      payload = { scene_location: { location_id: location.id, role: "setting" } }
      token = fetch_page_token(universe_story_scene_scene_locations_path(universe_slug: @universe.slug,
        story_id: scene.story, scene_id: scene))

      assert_no_difference("SceneLocation.count") do
        post universe_story_scene_scene_locations_url(universe_slug: @universe.slug,
          story_id: scene.story, scene_id: scene), params: payload, as: :json
      end
      assert_response :forbidden

      assert_difference("SceneLocation.count", 1) do
        post universe_story_scene_scene_locations_url(universe_slug: @universe.slug,
          story_id: scene.story, scene_id: scene), params: payload,
          headers: { "X-CSRF-Token" => token }, as: :json
      end
      assert_response :created
    end
  end

  test "a refused token remembers nothing in a draft-based universe" do
    # The interception is a call inside the action rather than a callback, so the
    # only thing standing between a forged request and a remembered change is the
    # order of the checks. The token is verified before any action code runs, and
    # this is what proves it: a universe that stores an author's pending changes
    # must not let an unauthenticated one fill them.
    @universe.update!(collaboration_mode: "wikipedia")

    with_forgery_protection do
      fetch_page_token

      assert_no_difference [ -> { Draft.count }, -> { DraftChange.count }, -> { Character.count } ] do
        post universe_characters_url(universe_slug: @universe.slug),
          params: { character: { name: "Never remembered" } },
          as: :json
      end

      assert_response :forbidden
    end
  end

  test "an html request keeps Rails' own handling of a rejected token" do    with_forgery_protection do
      fetch_page_token

      assert_no_difference("Character.count") do
        post universe_characters_url(universe_slug: @universe.slug), params: { character: { name: "Html submit" } }
      end

      # A browser form is protected by its own hidden field, and an ordinary HTML
      # refusal is still an unprocessable request rather than the JSON contract's
      # 403. The JSON-only format check answers 406 before the token is even read,
      # so only the response class is asserted here.
      assert_includes 406..422, response.status
    end
  end

  test "applying a draft is refused without a token and writes nothing" do
    # Applying is a Turbo `button_to`, so it is an ordinary HTML form post with its
    # own hidden token rather than a `fetch`. It is also the one mutation in this
    # application whose effect is a *bulk* write: a forged request that got
    # through would write every remembered change in a draft rather than one row.
    @universe.update!(collaboration_mode: "wikipedia")
    character = characters(:character_one)
    draft = Draft.create!(user: @user, universe: @universe)
    draft.draft_changes.create!(action: "update", record_type: "Character", record_id: character.id,
      base_version: DraftChange.capture_base_version(character), payload: { "name" => "Token verified apply" })
    token = nil

    with_forgery_protection do
      token = fetch_page_token(universe_drafts_path(universe_slug: @universe.slug))

      assert_no_difference -> { Character.count } do
        post apply_universe_draft_url(universe_slug: @universe.slug, id: draft)
      end

      assert_includes 406..422, response.status
      assert_not_equal "Token verified apply", character.reload.name
      assert_predicate draft.reload, :draft?, "a refused apply must leave the draft exactly as it was"

      post apply_universe_draft_url(universe_slug: @universe.slug, id: draft),
        headers: { "X-CSRF-Token" => token }

      assert_response :see_other
      assert_equal "Token verified apply", character.reload.name
      assert_predicate draft.reload, :applied?
    end
  end

  test "dropping a remembered change is refused without a token and removes nothing" do
    # Dropping is a Turbo `button_to`, so it is an ordinary HTML `DELETE` with the
    # form's own hidden token rather than a `fetch`. It is worth its own case because
    # its effect is the opposite of a write: a forged request would remove a change
    # from somebody's draft and there is nothing left of it to put back.
    @universe.update!(collaboration_mode: "wikipedia")
    draft = remembered_draft
    change = draft.draft_changes.sole
    token = nil

    with_forgery_protection do
      token = fetch_page_token(universe_draft_path(universe_slug: @universe.slug, id: draft))

      assert_no_difference -> { DraftChange.count } do
        delete universe_draft_change_url(universe_slug: @universe.slug, draft_id: draft, id: change)
      end

      assert_includes 406..422, response.status
      assert DraftChange.exists?(change.id), "a refused drop must leave the change in the draft"

      delete universe_draft_change_url(universe_slug: @universe.slug, draft_id: draft, id: change),
        headers: { "X-CSRF-Token" => token }

      assert_response :see_other
      refute DraftChange.exists?(change.id)
      assert_predicate draft.reload, :draft?
    end
  end

  test "starting an editing session is refused without a token and claims nothing" do
    # The editing toggle is a Turbo `button_to` like every other HTML control here,
    # so its token comes from the form's hidden field rather than a `fetch`. What
    # makes it worth its own case is what a forged request would achieve: it would
    # open a draft for this author that nothing else in the request asked for.
    @universe.update!(collaboration_mode: "wikipedia")
    token = nil

    with_forgery_protection do
      token = fetch_page_token(universe_url(@universe))

      assert_no_difference -> { Draft.count } do
        post universe_editing_url(universe_slug: @universe.slug)
      end

      assert_includes 406..422, response.status
      assert_nil Draft.open_for(@user, @universe), "a refused request must not have opened a draft"

      post universe_editing_url(universe_slug: @universe.slug),
        headers: { "X-CSRF-Token" => token }

      assert_redirected_to universe_url(@universe)
      assert_predicate Draft.open_for(@user, @universe), :open?
    end
  end

  test "approving a submission is refused without a token and writes nothing" do
    # Approving is a Turbo `button_to` like every other HTML control here, so its token
    # comes from the form's hidden field rather than a `fetch`. What makes it worth its
    # own case is the same thing that makes an apply worth one: the mutation whose
    # effect is a *bulk* write — every remembered change in somebody else's draft, and a
    # reviewer's decision recorded against it.
    review_request = submitted_review_request
    token = nil

    with_forgery_protection do
      token = fetch_page_token(universe_review_requests_path(universe_slug: @universe.slug))

      assert_no_difference [ -> { Character.count }, -> { ReviewRequest.where(status: "approved").count } ] do
        post approve_universe_review_request_url(universe_slug: @universe.slug, id: review_request)
      end

      assert_includes 406..422, response.status
      assert_nil Character.find_by(name: "Token verified approval")
      assert_predicate review_request.reload, :pending?, "a refused decision must leave the queue exactly as it was"

      post approve_universe_review_request_url(universe_slug: @universe.slug, id: review_request),
        headers: { "X-CSRF-Token" => token }

      assert_response :see_other
      assert Character.find_by(name: "Token verified approval").present?
      assert_predicate review_request.reload, :approved?
    end
  end

  test "rejecting a submission is refused without a token and decides nothing" do
    # The other half of the same decision, and the one that hands a draft back: a forged
    # rejection would take somebody's work out of the queue without their author ever
    # hearing about it.
    review_request = submitted_review_request
    token = nil

    with_forgery_protection do
      token = fetch_page_token(universe_review_request_path(universe_slug: @universe.slug, id: review_request))

      assert_no_difference [ -> { ReviewRequest.where(status: "rejected").count },
  -> { Draft.where(status: "submitted").count } ] do
        post reject_universe_review_request_url(universe_slug: @universe.slug, id: review_request),
          params: { review_request: { review_notes: "Never recorded" } }
      end

      assert_includes 406..422, response.status
      assert_predicate review_request.reload, :pending?
      assert_predicate review_request.draft.reload, :submitted?

      post reject_universe_review_request_url(universe_slug: @universe.slug, id: review_request),
        params: { review_request: { review_notes: "Recorded with the page's own token" } },
        headers: { "X-CSRF-Token" => token }

      assert_response :see_other
      assert_predicate review_request.reload, :rejected?
      assert_predicate review_request.draft.reload, :draft?
    end
  end

  test "submitting a draft for review is refused without a token and hands nothing over" do
    # The handover is a form with a field, like the reviewer's approval, so its token
    # comes from the form's own hidden field. What makes it worth a case is what a
    # forged request would achieve: it would put somebody's work into another person's
    # review queue with a message that reads as though they wrote it.
    @universe.update!(collaboration_mode: "github")
    draft = remembered_draft
    token = nil

    with_forgery_protection do
      token = fetch_page_token(universe_draft_path(universe_slug: @universe.slug, id: draft))

      assert_no_difference [ -> { ReviewRequest.count }, -> { Draft.where(status: "submitted").count } ] do
        post submit_universe_draft_url(universe_slug: @universe.slug, id: draft),
          params: { review_request: { submission_message: "Never recorded" } }
      end

      assert_includes 406..422, response.status
      assert_predicate draft.reload, :draft?, "a refused handover must leave the draft exactly as it was"
      assert_empty draft.review_requests

      post submit_universe_draft_url(universe_slug: @universe.slug, id: draft),
        params: { review_request: { submission_message: "Recorded with the page's own token" } },
        headers: { "X-CSRF-Token" => token }

      assert_response :see_other
      assert_predicate draft.reload, :submitted?
      assert_equal "Recorded with the page's own token", draft.pending_review_request.submission_message
    end
  end

  test "marking a notification read is refused without a token and marks nothing" do
    # Marking read is the only write the notifications pages have, and it is a POST
    # rather than a PATCH for exactly the reason every other case in this file is a
    # POST: a GET that marked a row read would let a link, a prefetch, or a crawler
    # answer a bell on the reader's behalf. A forged mark-all is the wider version of
    # the same hazard — it silences somebody else's queue.
    notification = Notification.create!(user: @user, kind: "review_submitted")
    Notification.create!(user: @user, kind: "review_approved")
    token = nil

    with_forgery_protection do
      token = fetch_page_token(notifications_path)

      assert_no_difference -> { Notification.where(read: true).count } do
        post read_notification_url(id: notification)
        post read_all_notifications_url
      end

      assert_includes 406..422, response.status
      assert_equal 0, Notification.where(read: true).count

      post read_all_notifications_url, headers: { "X-CSRF-Token" => token }

      assert_response :see_other
      assert_equal 2, Notification.where(read: true).count
    end
  end

  test "the settings form is refused without a token and accepted with one" do
    with_forgery_protection do
      token = fetch_page_token(settings_path)

      patch settings_url, params: { theme: "dark" }

      assert_includes 406..422, response.status
      # Nothing was written, so the next page still renders the default theme.
      get settings_path
      assert_equal "light", rendered_theme

      patch settings_url, params: { theme: "dark" }, headers: { "X-CSRF-Token" => token }

      assert_response :see_other
      get settings_path
      assert_equal "dark", rendered_theme
    end
  end

  test "revoking an API token is refused without a token and revokes nothing" do
    with_forgery_protection do
      get universe_api_tokens_path(universe_slug: @universe.slug)
      assert_response :success
      page_token = csrf_token_from(response.body)
      assert page_token.present?, "the token management page must publish a CSRF token"

      assert_no_difference -> { ApiToken.where(revoked_at: nil).count } do
        delete universe_api_token_url(universe_slug: @universe.slug, id: api_tokens(:token_one))
      end

      assert_includes 406..422, response.status
      refute api_tokens(:token_one).reload.revoked?, "a refused revoke must leave the token active"

      delete universe_api_token_url(universe_slug: @universe.slug, id: api_tokens(:token_one)),
        headers: { "X-CSRF-Token" => page_token }

      assert_response :see_other
      assert_redirected_to universe_api_tokens_url(universe_slug: @universe.slug)
      assert_predicate api_tokens(:token_one).reload, :revoked?
    end
  end

  private
    # Loads a page so the session holds a CSRF token, and returns the value the
    # page published for its own JavaScript.
    def fetch_page_token(path = universe_characters_path(universe_slug: @universe.slug))
      get path
      assert_response :success
      token = csrf_token_from(response.body)
      assert token.present?, "a rendered page must publish a CSRF token for its fetch requests"
      token
    end

    # The theme the last response rendered onto the root element.
    def rendered_theme
      Nokogiri::HTML(response.body).at_css("html")["data-bs-theme"]
    end

    # A draft an author is about to hand over: one remembered change and nothing
    # else, which is what the remembering path would have left behind.
    def remembered_draft
      draft = Draft.create!(user: @user, universe: @universe)
      draft.draft_changes.create!(action: "create", record_type: "Character",
        payload: { "name" => "Token verified handover", "universe_id" => @universe.id })

      draft
    end

    # A submitted draft waiting for a decision, in the mode that hands drafts over.
    # Built through the model's own workflow rather than by setting two columns, so
    # these cases exercise the same queue a reviewer would see.
    def submitted_review_request
      draft = Draft.create!(user: users(:user_two), universe: @universe)
      draft.draft_changes.create!(action: "create", record_type: "Character",
        payload: { "name" => "Token verified approval", "universe_id" => @universe.id })

      draft.submit!
    end
end
