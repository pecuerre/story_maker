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

  # The Timeline is the second tab of the Event workspace rather than a page of its
  # own, so the strip below its header is the same one the Events list renders and
  # the Timeline tab is the active one. Both facts are asserted on both pages,
  # because a strip that rendered only one of the two would leave a reader with no
  # way back.
  test "the Timeline is the Event workspace's second tab, and is the active one here" do
    get universe_timeline_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "nav.content-tabs[aria-label=?]", "Event workspace"
    assert_select "nav.content-tabs a.active[aria-current=page][href=?]",
      universe_timeline_path(universe_slug: @universe.slug), text: "Timeline"
    assert_select "nav.content-tabs a[href=?]",
      universe_events_path(universe_slug: @universe.slug), text: "Events"
  end

  test "the Events list shows the Timeline as its second tab" do
    get universe_events_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "nav.content-tabs a.active[aria-current=page][href=?]",
      universe_events_path(universe_slug: @universe.slug), text: "Events"
    assert_select "nav.content-tabs a[href=?]",
      universe_timeline_path(universe_slug: @universe.slug), text: "Timeline"
  end

  # The workspace's own sentence now sits below the tab strip rather than in the
  # page header, so it describes the list the reader is looking at. Both the class
  # and the position are asserted: the copy is unchanged, only where it lives.
  test "the workspace sentence is below the tab strip, not in the page header" do
    {
      events: [ "Events", "Event workspace", "Record moments that shape" ],
      characters: [ "Characters", "Character workspace", "People and beings whose details" ],
      items: [ "Items", "Item workspace", "Objects and resources whose details" ],
      locations: [ "Locations", "Location workspace", "Build a hierarchy of places" ],
      relations: [ "Relations", "Character workspace", "Connect characters and record" ],
      ownerships: [ "Ownerships", "Item workspace", "Track which characters own items" ]
    }.each do |workspace, (title, tab_label, sentence)|
      url = send(:"universe_#{workspace}_url", universe_slug: @universe.slug)

      get url

      assert_response :success, url
      # Nothing about the tab strip is lost by the sentence moving out of the
      # header: the tabs are still a real `nav` between the two.
      assert_select "header.page-header + nav.content-tabs[aria-label=?]", tab_label
      intro = css_select("nav.content-tabs + p.page-description.content-intro").first

      assert_not_nil intro, "#{workspace}: the workspace sentence is below its tab strip"
      assert_includes intro.text, sentence, "#{workspace}: workspace sentence"
      # The header keeps only what identifies the page: eyebrow, title, count.
      assert_select "header.page-header p.page-description", count: 0
      assert_select "h1", text: title
    end
  end
end
