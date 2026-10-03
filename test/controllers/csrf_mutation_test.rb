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
end
