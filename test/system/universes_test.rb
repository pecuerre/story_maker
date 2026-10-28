require "application_system_test_case"

# The Universes index is the landing page: where a reader chooses a workspace.
# `test/controllers/universes_controller_test.rb` proves the counts, the
# authorization, and that nothing is recounted per row; what only a browser
# shows is that the counts and the recent-activity cell actually render there.
class UniversesTest < ApplicationSystemTestCase
  test "the index shows each universe's contents and recent activity" do
    sign_in_via_form(users(:user_one))

    visit root_path

    within "table" do
      assert_selector "td", text: /2 stories/
      assert_selector "td", text: /17 entities/
      assert_selector "td", text: /1 story/
      assert_selector "td", text: /6 entities/
      assert_selector "time", count: 2
    end
  end
end
