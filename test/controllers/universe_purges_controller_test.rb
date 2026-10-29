require "test_helper"

# The permanent delete is the one universe operation an administrator does not
# hold. `test/models/ability_test.rb` answers the policy question; these cases
# drive the request: who reaches the page, what the confirmation must be, and
# what a refused or accepted submission does to the rows.
class UniversePurgesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @owner = users(:user_one)
  end

  test "the owner can open the confirmation page" do
    sign_in_as(@owner)

    get universe_purge_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "h1", text: "Permanently delete Universe one"
    assert_select "a[href=?]", universe_backup_path, text: "Download a backup first"
    assert_select "form[autocomplete=off]"
    assert_select "input#confirmation[autocomplete=off][autocapitalize=none][autocorrect=off][spellcheck=false]"
    assert_select "input#confirmation[data-name-confirmation-target=input]"
    assert_select "input#confirmation[data-action='input->name-confirmation#check']"
    assert_select "form[data-controller=name-confirmation][data-name-confirmation-expected-value='Universe one']"
  end

  test "the owner's edit page offers the permanent delete" do
    sign_in_as(@owner)

    get edit_universe_url(@universe)

    assert_response :success
    assert_select "a[href=?]", universe_purge_path(universe_slug: @universe.slug),
      text: "Delete this universe permanently"
  end

  test "the owner's universe menus open the permanent delete page instead of deleting" do
    sign_in_as(@owner)

    get universes_url
    assert_response :success
    assert_select "a[href=?]", universe_purge_path(universe_slug: @universe.slug),
      text: "Delete universe permanently"

    get universe_url(@universe)
    assert_response :success
    assert_select "a[href=?]", universe_purge_path(universe_slug: @universe.slug),
      text: "Delete universe permanently"
    assert_select "form[action=?]", universe_path(@universe), count: 0
  end

  test "an administrator who is not the owner sees no permanent delete entry" do
    admin = users(:user_two)
    UniverseMembership.create!(universe: @universe, user: admin, access_level: :admin)
    sign_in_as(admin)

    get universes_url
    assert_response :success
    assert_select "a[href=?]", universe_purge_path(universe_slug: @universe.slug), count: 0

    get universe_url(@universe)
    assert_response :success
    assert_select "a[href=?]", universe_purge_path(universe_slug: @universe.slug), count: 0
    assert_select "form[action=?]", universe_path(@universe), count: 0
  end

  test "the confirmation page's delete button starts disabled" do
    sign_in_as(@owner)

    get universe_purge_url(universe_slug: @universe.slug)

    assert_select "input[type=submit][disabled]", value: "Delete this universe permanently"
    assert_select ".alert-danger", text: /This is irreversible, please confirm that you understand what you are doing/
  end

  test "an administrator who is not the owner cannot open or perform the permanent delete" do
    admin = users(:user_two)
    UniverseMembership.create!(universe: @universe, user: admin, access_level: :admin)
    sign_in_as(admin)

    get universe_purge_url(universe_slug: @universe.slug)
    assert_response :forbidden

    assert_no_difference("Universe.count") do
      delete universe_purge_url(universe_slug: @universe.slug), params: { confirmation: @universe.name }
    end
    assert_response :forbidden
    assert Universe.exists?(@universe.id)
  end

  test "an administrator who is not the owner is not offered the permanent delete" do
    admin = users(:user_two)
    UniverseMembership.create!(universe: @universe, user: admin, access_level: :admin)
    sign_in_as(admin)

    get edit_universe_url(@universe)

    assert_response :success
    assert_select "a", text: "Delete this universe permanently", count: 0
  end

  test "the exact name deletes the universe and everything in it" do
    character_id = characters(:character_one).id
    story_id = stories(:story_one).id
    sign_in_as(@owner)

    assert_difference("Universe.count", -1) do
      delete universe_purge_url(universe_slug: @universe.slug), params: { confirmation: @universe.name }
    end

    assert_redirected_to universes_url
    assert_not Universe.exists?(@universe.id)
    assert_nil Character.find_by(id: character_id),
      "a universe purge must take the content, not only the universe row"
    assert_nil Story.find_by(id: story_id)
    assert_equal 0, Photo.where(universe_id: @universe.id).count
  end

  test "the permanent delete redirects with a notice naming the universe" do
    sign_in_as(@owner)

    delete universe_purge_url(universe_slug: @universe.slug), params: { confirmation: @universe.name }
    follow_redirect!

    assert_response :success
    assert_select ".alert-success", text: /Universe one.*permanently deleted/
  end

  test "a name with the wrong case deletes nothing and explains why" do
    sign_in_as(@owner)

    assert_no_difference("Universe.count") do
      delete universe_purge_url(universe_slug: @universe.slug),
        params: { confirmation: @universe.name.downcase }
    end

    assert_response :unprocessable_content
    assert_select ".alert-danger", text: /does not match .* exactly/
    assert_select "input#confirmation[value=?]", @universe.name.downcase
    assert Universe.exists?(@universe.id)
  end

  test "extra whitespace is a different name" do
    sign_in_as(@owner)

    assert_no_difference("Universe.count") do
      delete universe_purge_url(universe_slug: @universe.slug),
        params: { confirmation: " #{@universe.name} " }
    end

    assert_response :unprocessable_content
    assert Universe.exists?(@universe.id)
  end

  test "punctuation in the name is part of the confirmation" do
    punctuation = Universe.create!(owner: @owner, name: "Eärendil, The Mariner!", slug: "earendil")
    sign_in_as(@owner)

    assert_no_difference("Universe.count") do
      delete universe_purge_url(universe_slug: punctuation.slug), params: { confirmation: "Eärendil The Mariner!" }
    end
    assert_response :unprocessable_content
    assert Universe.exists?(punctuation.id)

    assert_difference("Universe.count", -1) do
      delete universe_purge_url(universe_slug: punctuation.slug), params: { confirmation: punctuation.name }
    end
    assert_redirected_to universes_url
  end

  test "a blank confirmation deletes nothing" do
    sign_in_as(@owner)

    assert_no_difference("Universe.count") do
      delete universe_purge_url(universe_slug: @universe.slug), params: { confirmation: "" }
    end

    assert_response :unprocessable_content
    assert Universe.exists?(@universe.id)
  end

  test "a guest is sent to sign in from a public universe" do
    sign_out

    get universe_purge_url(universe_slug: @universe.slug)
    assert_redirected_to new_session_url

    assert_no_difference("Universe.count") do
      delete universe_purge_url(universe_slug: @universe.slug), params: { confirmation: @universe.name }
    end
    assert_redirected_to new_session_url
    assert Universe.exists?(@universe.id)
  end

  test "a non-member of a private universe sees the same 404 as a missing universe" do
    private_universe = Universe.create!(owner: @owner, name: "Private", slug: "private", private: true)
    sign_in_as(users(:user_two))

    get universe_purge_url(universe_slug: private_universe.slug)
    assert_response :not_found

    delete universe_purge_url(universe_slug: private_universe.slug), params: { confirmation: private_universe.name }
    assert_response :not_found
    assert Universe.exists?(private_universe.id)
  end
end
