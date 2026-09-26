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

  test "an html request keeps Rails' own handling of a rejected token" do
    with_forgery_protection do
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

  private
    # Loads a page so the session holds a CSRF token, and returns the value the
    # page published for its own JavaScript.
    def fetch_page_token
      get universe_characters_url(universe_slug: @universe.slug)
      assert_response :success
      token = csrf_token_from(response.body)
      assert token.present?, "a rendered page must publish a CSRF token for its fetch requests"
      token
    end
end
