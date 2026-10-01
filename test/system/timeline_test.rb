require "application_system_test_case"

# The Timeline's nodes, in a real browser. The request suite proves each node
# renders a labelled `<button>`; only a browser can show that the label is
# actually announced, that the node can be reached and operated from the
# keyboard, and that the popover opens without a pointer.
class TimelineTest < ApplicationSystemTestCase
  setup do
    @user = users(:user_one)
    @universe = universes(:universe_one)
    @event = events(:event_one)
  end

  test "a timeline node is reachable from the keyboard and opens its details on focus" do
    sign_in_via_form(@user)
    visit universe_timeline_path(universe_slug: @universe.slug)
    assert_stimulus_loaded

    node = first_timeline_node
    # The node carries the record's id as its text, so it is addressed by the
    # event it stands for rather than by that number.
    assert_equal "Show event details: #{@event.title}", node["aria-label"]

    # Tabbing forwards from the control just before the timeline lands on the
    # node, which is what makes it reachable without a pointer. That control is the
    # last link of the workspace's tab strip, because the strip sits between the
    # page header and the timeline now that the Timeline is one of its tabs.
    page.all("nav[aria-label='Event workspace'] a").last.send_keys(:tab)
    assert_equal node[:id], page.evaluate_script("document.activeElement.id")

    # Focus alone opens the popover, the keyboard path a hover-only trigger
    # could not offer.
    assert_selector ".popover", wait: 5
    within ".popover" do
      assert_selector ".popover-header", text: @event.title
    end
  end

  test "a timeline node opens its details on click" do
    sign_in_via_form(@user)
    visit universe_timeline_path(universe_slug: @universe.slug)
    assert_stimulus_loaded

    # A touch or click-only pointer never hovers, so the trigger has to include
    # click as well as hover and focus.
    first_timeline_node.click
    assert_selector ".popover", wait: 5
    within ".popover" do
      assert_selector ".popover-header", text: @event.title
    end
  end

  test "a node still renders as the documented circle after becoming a button" do
    sign_in_via_form(@user)
    visit universe_timeline_path(universe_slug: @universe.slug)

    # The node is a `<button>` for its semantics, not its looks: the UA's button
    # chrome must stay reset so the documented 40px circle and the author's tag
    # color are what the reader actually sees.
    geometry = first_timeline_node.evaluate_script(
      "(() => { const s = getComputedStyle(this); " \
      "return [ s.width, s.height, s.borderRadius, s.paddingTop ].join(' ') })()"
    )

    assert_equal "40px 40px 50% 0px", geometry
  end

  test "the Timeline is a tab of the Event workspace and can be reached from the Events list" do
    sign_in_via_form(@user)
    visit universe_events_path(universe_slug: @universe.slug)
    assert_stimulus_loaded

    # The sidebar has no Timeline entry of its own any more, so the strip is the
    # only place the two are joined. The strip also carries the universe's pinned
    # Event tags, so it is the two workspace tabs that are named here rather than
    # a count of every link in it.
    within "nav[aria-label='Event workspace']" do
      assert_selector "a.active", text: "Events"
      click_link "Timeline"
    end

    assert_current_path universe_timeline_path(universe_slug: @universe.slug)
    assert_selector "h1", text: "Timeline"
    # And the same strip offers the way back, so the two are one workspace rather
    # than two pages that happen to link to each other.
    within "nav[aria-label='Event workspace']" do
      assert_selector "a.active", text: "Timeline"
      assert_selector "a", text: "Events"
      click_link "Events"
    end

    assert_current_path universe_events_path(universe_slug: @universe.slug)
  end

  test "the timeline with no events explains itself instead of drawing nodes" do
    @universe.events.find_each(&:soft_delete)

    sign_in_via_form(@user)
    visit universe_timeline_path(universe_slug: @universe.slug)

    assert_selector ".empty-title"
    assert_no_selector "button.timeline-node"
  end

  private

  # `@event` is the earliest event in the fixture universe, so it heads the first
  # row and is the first node in the tab order.
  def first_timeline_node
    find("#timeline-event-#{@event.id}")
  end
end
