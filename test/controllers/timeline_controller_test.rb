require "test_helper"

class TimelineControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    sign_in_as(users(:user_one))
  end

  test "should get timeline" do
    get universe_timeline_url(universe_slug: @universe.slug)

    assert_response :success
    assert_includes response.body, "Timeline"
  end

  test "each event node is a keyboard-operable button with an accessible name" do
    get universe_timeline_url(universe_slug: @universe.slug)

    assert_response :success
    # A focusable <div> announced only its record id; the node is a real button
    # whose label names the event the popover describes.
    assert_select "button.timeline-node", minimum: 1
    assert_select "button.timeline-node[aria-label=?]", "Show event details: The beginning"
    assert_select "button.timeline-node[tabindex]", false
  end

  test "a node for an event with no title is labelled with the id placeholder" do
    @universe.events.create!(title: nil, start_datetime: "2026-03-01 09:00")
    get universe_timeline_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "button.timeline-node[aria-label=?]", "Show event details: Event ##{@universe.events.order(:id).last.id}"
  end

  test "the popover can also be opened by click, not only by hover" do
    get universe_timeline_url(universe_slug: @universe.slug)

    assert_select "button.timeline-node[data-bs-trigger*=?]", "click"
  end
end
