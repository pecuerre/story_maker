require "application_system_test_case"

# The Events tab is a read page with a modal editor and Move controls. What only
# a browser can show is that the shared modal adds a link with its role, that the
# JSON Move control reorders the rows, and that removing a link leaves the Event.
class SceneEventsTest < ApplicationSystemTestCase
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    @scene = scenes(:scene_one)
    @second_event = events(:event_two)
  end

  test "a writer adds an event with a role, moves it, and removes the link" do
    sign_in_via_form(users(:user_one))
    visit universe_story_scene_scene_events_path(universe_slug: @universe.slug, story_id: @story, scene_id: @scene)

    assert_selector "h1", text: "Events"
    assert_selector ".entity-title", text: events(:event_one).display_label

    click_button "Add event"
    within ".modal.show" do
      select @second_event.display_label, from: "Event"
      fill_in "Role", with: "climax"
      click_button "Save event"
    end

    assert_selector ".entity-row", text: @second_event.display_label, wait: REFRESH_WAIT
    assert_text "climax"
    assert_equal 2, @scene.scene_events.count

    # The second link is appended; Move up puts it before the first.
    find("button[aria-label='Move #{@second_event.display_label} up in this scene']").click

    assert_selector ".entity-row:first-child", text: @second_event.display_label, wait: REFRESH_WAIT
    assert_equal [ @second_event, events(:event_one) ],
      @scene.scene_events.reorder(:position, :id).map(&:event)

    click_row_menu_action find(".entity-list .entity-row", text: @second_event.display_label), "Remove",
      confirm: "Remove #{@second_event.display_label} from Scene one?"

    assert_no_selector ".entity-row", text: @second_event.display_label
    assert_equal 1, @scene.scene_events.count
    # Removing a link never removes the event.
    assert Event.exists?(@second_event.id)
  end
end
