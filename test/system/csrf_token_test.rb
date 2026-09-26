require "application_system_test_case"

# Both shared editors mutate through `fetch`, so a real browser has to prove the
# request carries a valid CSRF token and the server accepts it — something no
# Ruby-side test can show, and something the test environment disables by default.
# Each case therefore turns forgery protection back on for its own window (see
# `test/test_helpers/forgery_protection_test_helper.rb`), and removing the page's
# `csrf-token` meta tag is how a browser is made to send the mutation without one.
class CsrfTokenTest < ApplicationSystemTestCase
  setup do
    @user = users(:user_one)
    @universe = universes(:universe_one)
  end

  test "the flat-list modal's write is accepted with forgery protection enabled" do
    with_forgery_protection do
      sign_in_via_form(@user)
      visit universe_characters_path(universe_slug: @universe.slug)
      assert_stimulus_loaded
      assert_selector "meta[name='csrf-token']", visible: :all

      click_button "Add character"
      within ".modal.show" do
        fill_in "Name", with: "Token verified in a browser"
        click_button "Save character"
      end

      # The row only appears if the server accepted the mutation, so a page that
      # stopped sending the token would fail here instead of passing quietly.
      assert_selector ".entity-row .entity-title", text: "Token verified in a browser", wait: REFRESH_WAIT
      assert_equal "Token verified in a browser", @universe.characters.order(:id).last.name
    end
  end

  test "a modal write without the page's token is refused, saves nothing, and says why" do
    with_forgery_protection do
      sign_in_via_form(@user)
      visit universe_characters_path(universe_slug: @universe.slug)
      assert_stimulus_loaded
      remove_csrf_token
      before = @universe.characters.count

      click_button "Add character"
      within ".modal.show" do
        fill_in "Name", with: "Never saved"
        click_button "Save character"

        assert_selector "[data-modal-form-target='errors'] .alert-danger", text: "no longer allowed"
        # The rejected entry is kept and the editor stays open so it can be retried.
        assert_field "Name", with: "Never saved"
      end

      assert_selector ".modal.show"
      assert_equal before, @universe.characters.count
      assert_nil Character.find_by(name: "Never saved")
    end
  end

  test "the taxonomy editor's write is accepted with a token and refused without one" do
    with_forgery_protection do
      tag = character_tags(:character_tag_one)
      sign_in_via_form(@user)
      visit universe_character_tags_path(universe_slug: @universe.slug)
      assert_stimulus_loaded

      within "li[data-node-id='#{tag.id}'] > .taxonomy-row" do
        find("button.taxonomy-name-trigger").click
        find("form.taxonomy-update-form input[name='name']").set("Renamed with a token")
        click_button "Save"
      end
      assert_selector "button.taxonomy-name-trigger", text: "Renamed with a token"

      remove_csrf_token
      within "li[data-node-id='#{tag.id}'] > .taxonomy-row" do
        find("button.taxonomy-name-trigger").click
        find("form.taxonomy-update-form input[name='name']").set("Renamed without a token")
        click_button "Save"
      end

      # The status region lives above the tree, not inside the row. The editor
      # stays open with the rejected value, and the name on the server is the one
      # the previous, authorized rename really saved.
      assert_selector "[data-taxonomy-tree-status].text-danger", text: "The name could not be saved."
      assert_selector "li[data-node-id='#{tag.id}'] form.taxonomy-update-form input[name='name']",
        visible: :all
      assert_equal "Renamed with a token", tag.reload.name
    end
  end

  private
    # Removes the page's published token so the editor's next `fetch` has nothing
    # to send. The server then sees exactly what it sees from a request that never
    # had a token, which is the request forgery protection exists to refuse.
    def remove_csrf_token
      page.execute_script(<<~JS)
        document.querySelector("meta[name='csrf-token']")?.remove()
      JS
      assert_no_selector "meta[name='csrf-token']", visible: :all
    end
end
